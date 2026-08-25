import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants/app_constants.dart';
import '../models/customer_model.dart';
import '../models/user_model.dart';

class AuthResult {
  const AuthResult({required this.success, this.message});
  final bool success;
  final String? message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<AuthResult> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    } catch (_) {
      return const AuthResult(
          success: false, message: 'Connection failed. Check your internet and Firebase setup.');
    }
  }

  Future<AuthResult> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final User? user = cred.user;
      if (user == null) {
        return const AuthResult(success: false, message: 'Registration failed.');
      }
      final UserModel model = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: Roles.customer,
        phone: phone.trim(),
        address: address.trim(),
      );
      await _db.collection(Collections.users).doc(user.uid).set(model.toCreateMap());
      final CustomerModel customer = CustomerModel(
        id: user.uid,
        userId: user.uid,
        fullName: name.trim(),
        contactNumber: phone.trim(),
        address: address.trim(),
      );
      await _db.collection(Collections.customers).doc(user.uid).set(customer.toMap());
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    } catch (_) {
      return const AuthResult(
          success: false, message: 'Registration failed. Check your connection.');
    }
  }

  Future<AuthResult> createStaffAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String phone = '',
  }) async {
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final UserCredential cred =
          await tempAuth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final String uid = cred.user!.uid;
      final UserModel model = UserModel(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        phone: phone.trim(),
      );
      await _db.collection(Collections.users).doc(uid).set(model.toCreateMap());
      if (role == Roles.customer) {
        await _db.collection(Collections.customers).doc(uid).set(
              CustomerModel(
                id: uid,
                userId: uid,
                fullName: name.trim(),
                contactNumber: phone.trim(),
                address: '',
              ).toMap(),
            );
      }
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    } catch (_) {
      return const AuthResult(success: false, message: 'Could not create the account.');
    } finally {
      try {
        await tempApp?.delete();
      } catch (_) {}
    }
  }

  Future<bool> anyAdminExists() async {
    final QuerySnapshot snap = await _db
        .collection(Collections.users)
        .where('role', isEqualTo: Roles.admin)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<bool> canClaimAdmin() async {
    try {
      final DocumentSnapshot doc =
          await _db.collection(Collections.config).doc('bootstrap').get();
      if (!doc.exists) return true;
      return (doc.data() as Map<String, dynamic>?)?['adminClaimed'] != true;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResult> claimAdminForCurrentUser(String uid) async {
    try {
      final WriteBatch batch = _db.batch();
      batch.set(_db.collection(Collections.config).doc('bootstrap'),
          {'adminClaimed': true, 'claimedBy': uid, 'at': FieldValue.serverTimestamp()});
      batch.update(_db.collection(Collections.users).doc(uid), {'role': Roles.admin});
      await batch.commit();
      return const AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, message: 'Could not claim admin: $e');
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in Firebase Console.';
      default:
        return e.message ?? 'Authentication error (${e.code}).';
    }
  }
}
