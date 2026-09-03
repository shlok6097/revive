import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// Application-level authentication exception with human-readable error messages.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service managing merchant authentication state and Firebase Auth operations.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth;

  final FirebaseAuth? _firebaseAuth;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// The currently authenticated Firebase user, or null if unauthenticated.
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Whether a user session currently exists.
  bool get isAuthenticated => currentUser != null;

  /// Registers a new merchant user with email and password.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException('An unexpected error occurred during signup. Please try again.');
    }
  }

  /// Authenticates an existing merchant with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException('An unexpected error occurred during login. Please try again.');
    }
  }

  /// Sends a password reset email to the specified email address.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException('Failed to send password reset email. Please try again.');
    }
  }

  /// Terminates the current merchant session.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw const AuthException('Failed to sign out. Please try again.');
    }
  }

  /// Translates raw Firebase Auth error codes into professional application messages.
  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email address. Please log in instead.';
      case 'invalid-email':
        return 'The email address provided is not valid.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This merchant account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Access temporarily blocked due to multiple failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please verify your details.';
    }
  }
}
