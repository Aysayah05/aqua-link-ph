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

  void init() {
    _authSub?.cancel();
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    fbUser = user;
    await _profileSub?.cancel();
    _profileSub = null;
    if (user == null) {
      profile = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    status = AuthStatus.authenticated;
    notifyListeners();
    _profileSub = _db
        .collection(Collections.users)
        .doc(user.uid)
        .snapshots()
        .listen(_onProfileSnapshot, onError: (_) {});
  }

  void _onProfileSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) {
      errorMessage = 'Your account has no profile record. Contact the administrator.';
      profile = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    final UserModel model = UserModel.fromDoc(doc);
    if (model.disabled) {
      errorMessage = 'This account has been deactivated by the administrator.';
      profile = null;
      _authService.signOut();
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    profile = model;
    errorMessage = null;
    status = AuthStatus.authenticated;
    notifyListeners();
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
