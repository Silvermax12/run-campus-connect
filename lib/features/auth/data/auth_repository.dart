import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/auth_destination.dart';

part 'auth_repository.g.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
}

class AuthRepository {
  const AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  }) : _auth = auth,
       _firestore = firestore,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Future<AuthDestination> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw AuthFailure('Google Sign-In was cancelled.');
    }
    if (!_isRunEmail(account.email)) {
      await _googleSignIn.signOut();
      await _auth.signOut();
      throw AuthFailure('Only RUN emails allowed.');
    }

    final authentication = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
    final credentialResult = await _auth.signInWithCredential(credential);
    final user = credentialResult.user;
    if (user == null) {
      throw AuthFailure('Unable to sign in with Google at the moment.');
    }
    if (!_isRunEmail(user.email)) {
      await signOut();
      throw AuthFailure('Only RUN emails allowed.');
    }
    return _handleProfileCheck(user);
  }

  Future<AuthDestination> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_isRunEmail(email)) {
      throw AuthFailure('Use your @run.edu.ng email.');
    }
    final credentialResult = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credentialResult.user;
    if (user == null) {
      throw AuthFailure('Could not sign you in right now.');
    }
    if (!user.emailVerified) {
      return AuthDestination.verifyEmail;
    }
    return _handleProfileCheck(user);
  }

  Future<AuthDestination> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_isRunEmail(email)) {
      throw AuthFailure('Registration is limited to @run.edu.ng emails.');
    }
    final credentialResult = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credentialResult.user;
    if (user == null) {
      throw AuthFailure('Unable to create your account.');
    }
    await user.sendEmailVerification();
    return AuthDestination.verifyEmail;
  }

  Future<AuthDestination> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthFailure('No user is signed in.');
    }
    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      throw AuthFailure('Unable to refresh your session.');
    }
    if (!refreshedUser.emailVerified) {
      throw AuthFailure('Please verify your email to continue.');
    }
    return _handleProfileCheck(refreshedUser);
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthFailure('No user to verify.');
    }
    await user.sendEmailVerification();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<AuthDestination> _handleProfileCheck(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return AuthDestination.home;
    }
    return AuthDestination.createProfile;
  }

  bool _isRunEmail(String? email) {
    if (email == null) return false;
    return email.trim().toLowerCase().endsWith('@run.edu.ng');
  }
}
