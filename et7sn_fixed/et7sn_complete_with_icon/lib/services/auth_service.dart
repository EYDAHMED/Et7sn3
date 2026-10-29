import 'package:firebase_auth/firebase_auth.dart';

/// A friendly, bilingual auth error.
class AuthFailure implements Exception {
  AuthFailure(this.code);

  final String code;

  String message({required bool isArabic}) {
    switch (code) {
      case 'invalid-email':
        return isArabic ? 'البريد الإلكتروني غير صالح' : 'The email address is invalid.';
      case 'user-disabled':
        return isArabic ? 'تم تعطيل هذا الحساب' : 'This account has been disabled.';
      case 'user-not-found':
        return isArabic ? 'لا يوجد حساب بهذا البريد' : 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return isArabic ? 'البريد أو كلمة المرور غير صحيحة' : 'Incorrect email or password.';
      case 'email-already-in-use':
        return isArabic ? 'هذا البريد مستخدم بالفعل' : 'This email is already in use.';
      case 'weak-password':
        return isArabic ? 'كلمة المرور ضعيفة (6 أحرف على الأقل)' : 'Password is too weak (min 6 characters).';
      case 'network-request-failed':
        return isArabic ? 'تحقق من اتصالك بالإنترنت' : 'Check your internet connection.';
      case 'too-many-requests':
        return isArabic ? 'محاولات كثيرة، حاول لاحقاً' : 'Too many attempts. Try again later.';
      default:
        return isArabic ? 'حدث خطأ غير متوقع' : 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'AuthFailure($code)';
}

/// Firebase Email/Password authentication.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      if (displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.code);
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.code);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
