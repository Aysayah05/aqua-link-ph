import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, misconfigured, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final FirebaseFirestore _db;
  final AuthService _authService = AuthService();

  AuthProvider(this._db);

  AuthStatus status = AuthStatus.uninitialized;
  User? fbUser;
  UserModel? profile;
  String? errorMessage;
  String statusMessage = 'Starting…';

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  bool get isSignedIn => status == AuthStatus.authenticated && profile != null;
  bool get isAdmin => profile?.isAdmin ?? false;
  bool get isStaff => profile?.isStaff ?? false;
  bool get isCustomer => profile?.isCustomer ?? false;

  void clearTransientError() {
    if (errorMessage != null) {
      errorMessage = null;
    }
  }

  void markMisconfigured() {
    status = AuthStatus.misconfigured;
    notifyListeners();
  }

  void _set(AuthStatus s, String message) {
    status = s;
    statusMessage = message;
    debugPrint('[Auth] $s — $message');
    notifyListeners();
  }

  void init() {
    _authSub?.cancel();
    _set(AuthStatus.uninitialized, 'Connecting to Firebase Authentication…');
    _authSub = _authService.authStateChanges.listen(
      _onAuthChanged,
      onError: (Object e) {
        debugPrint('[Auth] authStateChanges error: $e');
        errorMessage = 'Authentication connection failed ($e). '
            'If you use an ad-blocker or firewall, allowlist Google/Firebase domains.';
        profile = null;
        _set(AuthStatus.unauthenticated, 'Auth unavailable');
      },
    );
    Timer(const Duration(seconds: 8), () {
      if (status == AuthStatus.uninitialized) {
        debugPrint('[Auth] watchdog fired — auth stream silent');
        errorMessage = 'Could not reach Firebase Authentication. '
            'Check your internet connection, or disable ad-blockers for this site.';
        _set(AuthStatus.unauthenticated, 'Auth timed out');
      }
    });
  }

  Future<void> _onAuthChanged(User? user) async {
    fbUser = user;
    await _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      profile = null;
      _set(AuthStatus.unauthenticated, 'Not signed in');
      return;
    }

    debugPrint('[Auth] user detected: ${user.uid}');
    _set(AuthStatus.authenticated, 'Loading your profile…');
    notifyListeners();

    final Completer<void> firstSnapshot = Completer<void>();
    Timer? guard = Timer(const Duration(seconds: 7), () {
      if (!firstSnapshot.isCompleted) firstSnapshot.completeError('profile-timeout');
    });

    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    sub = _db
        .collection(Collections.users)
        .doc(user.uid)
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> doc) {
        if (!firstSnapshot.isCompleted) {
          guard.cancel();
          firstSnapshot.complete();
        }
        _onProfileSnapshot(doc);
      },
      onError: (Object e) {
        debugPrint('[Auth] profile stream error: $e');
        if (!firstSnapshot.isCompleted) {
          guard.cancel();
          firstSnapshot.completeError(e);
        }
      },
    );
    _profileSub = sub;

    try {
      await firstSnapshot.future;
    } catch (_) {
      debugPrint('[Auth] profile stream stalled — trying one-shot fetch');
      await _profileSub?.cancel();
      _profileSub = null;
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc = await _db
            .collection(Collections.users)
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists) {
          _onProfileSnapshot(doc);
          return;
        }
        throw StateError('profile document missing');
      } catch (e) {
        debugPrint('[Auth] profile fetch failed: $e');
        errorMessage = e is StateError
            ? 'Your account has no profile record. Contact the administrator.'
            : 'Could not load your profile from Firestore ($e). '
                'Check your connection or Firestore rules.';
        profile = null;
        try {
          await _authService.signOut();
        } catch (_) {}
        _set(AuthStatus.unauthenticated, 'Profile unavailable');
      }
    }
  }

  void _onProfileSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) {
      errorMessage = 'Your account has no profile record. Contact the administrator.';
      profile = null;
      _set(AuthStatus.unauthenticated, 'No profile');
      return;
    }
    final UserModel model = UserModel.fromDoc(doc);
    if (model.disabled) {
      errorMessage = 'This account has been deactivated by the administrator.';
      profile = null;
      _authService.signOut();
      _set(AuthStatus.unauthenticated, 'Account disabled');
      return;
    }
    profile = model;
    errorMessage = null;
    _set(AuthStatus.authenticated, 'Welcome, ${model.name}');
  }

  Future<AuthResult> signIn(String email, String password) async {
    errorMessage = null;
    notifyListeners();
    final AuthResult result = await _authService.signIn(email, password);
    if (!result.success) errorMessage = result.message;
    notifyListeners();
    return result;
  }

  Future<void> signOut() async {
    await _profileSub?.cancel();
    _profileSub = null;
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
