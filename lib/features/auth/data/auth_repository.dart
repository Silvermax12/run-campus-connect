import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_config.dart';
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

  // ─── Fresher Auth ───────────────────────────────────────────────────

  Future<AuthDestination> signUpFresher({
    required String fullName,
    required String jambNumber,
    required String department,
    required String password,
    required String cloudinaryUrl1,
    required String cloudinaryUrl2,
  }) async {
    final email = '${jambNumber.trim().toLowerCase()}@fresher.run.edu.ng';

    // 1. Create Firebase Auth user
    final credentialResult = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credentialResult.user;
    if (user == null) {
      throw AuthFailure('Unable to create your fresher account.');
    }

    final displayName = fullName.trim();
    final parts = displayName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final lastName = parts.isEmpty ? displayName : parts.last;

    // 2. Save user data to Firestore
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'displayName': displayName,
      'lastName': lastName,
      'jambNumber': jambNumber.trim().toUpperCase(),
      'department': department.trim(),
      'isVerified': false,
      'role': 'fresher',
      'photoUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Call the Python verification backend (fire-and-forget style)
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'jambNumber': jambNumber.trim().toUpperCase(),
          'fullName': fullName.trim(),
          'slipUrl': cloudinaryUrl1,
          'admissionUrl': cloudinaryUrl2,
        }),
      );
      debugPrint('Verification API response: ${response.statusCode} ${response.body}');
    } catch (e) {
      // Don't block sign-up if the verification call fails
      debugPrint('Verification API call failed (non-fatal): $e');
    }

    return AuthDestination.pendingVerification;
  }

  Future<AuthDestination> signInFresher({
    required String jambNumber,
    required String password,
  }) async {
    final email = '${jambNumber.trim().toLowerCase()}@fresher.run.edu.ng';

    final credentialResult = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credentialResult.user;
    if (user == null) {
      throw AuthFailure('Could not sign you in. Please try again.');
    }

    // Check verification status
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['isVerified'] == false) {
        return AuthDestination.pendingVerification;
      }
    }

    return AuthDestination.home;
  }

  // ─── Common ────────────────────────────────────────────────────────

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
    final lower = email.trim().toLowerCase();
    return lower.endsWith('@run.edu.ng') || lower.endsWith('@fresher.run.edu.ng');
  }
}
