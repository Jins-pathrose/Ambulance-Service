
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
class AuthError {
  final String message;
  AuthError(this.message);
}
class AuthService {
  final _auth = FirebaseAuth.instance;

  // Sign up a user
  Future<User?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      log('Error during sign-up: $e');
      return null;
    }
  }

  // Log in a user
  Future<User?> loginUserWithEmailAndPassword(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      log('Error during login: $e');
      return null;
    }
  }

  // Log out the user
  Future<void> signOut() async {
    await _auth.signOut();
  }

    Future<AuthError?> sendPasswordResetLink(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return AuthError(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      return AuthError('An unexpected error occurred: ${e.toString()}');
    }
  }

   String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password provided';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'This sign in method is not enabled';
      case 'user-disabled':
        return 'This user account has been disabled';
      default:
        return e.message ?? 'An unknown error occurred';
    }
  }
}
