import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:run_campus_connect/features/auth/data/auth_repository.dart';

import 'auth_validation_test.mocks.dart';

// Generate mocks for Firebase services
@GenerateMocks([FirebaseAuth, FirebaseFirestore, GoogleSignIn, UserCredential, User])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthRepository authRepository;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockGoogleSignIn = MockGoogleSignIn();
    authRepository = AuthRepository(
      auth: mockAuth,
      firestore: mockFirestore,
      googleSignIn: mockGoogleSignIn,
    );
  });

  group('Email Validation Tests', () {
    test('Scenario A: Invalid email (student@gmail.com) should throw AuthFailure', () async {
      // Arrange
      const invalidEmail = 'student@gmail.com';
      const password = 'password123';

      // Act & Assert
      expect(
        () => authRepository.registerWithEmail(
          email: invalidEmail,
          password: password,
        ),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('@run.edu.ng'),
        )),
      );
    });

    test('Scenario B: Valid RUN email (student@run.edu.ng) should not throw error', () async {
      // Arrange
      const validEmail = 'student@run.edu.ng';
      const password = 'password123';
      
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      
      when(mockAuth.createUserWithEmailAndPassword(
        email: validEmail,
        password: password,
      )).thenAnswer((_) async => mockUserCredential);
      
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.sendEmailVerification()).thenAnswer((_) async => null);

      // Act & Assert
      // Should complete without throwing
      await expectLater(
        authRepository.registerWithEmail(email: validEmail, password: password),
        completes,
      );
    });

    test('Scenario C: Invalid alternative domain (vc@redeemers.edu.ng) should throw AuthFailure', () async {
      // Arrange - Only @run.edu.ng is allowed, not @redeemers.edu.ng
      const invalidEmail = 'vc@redeemers.edu.ng';
      const password = 'password123';

      // Act & Assert
      expect(
        () => authRepository.registerWithEmail(
          email: invalidEmail,
          password: password,
        ),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('@run.edu.ng'),
        )),
      );
    });

    test('Login with invalid email domain should throw AuthFailure', () async {
      // Arrange
      const invalidEmail = 'user@otherdomain.com';
      const password = 'password123';

      // Act & Assert
      expect(
        () => authRepository.loginWithEmail(
          email: invalidEmail,
          password: password,
        ),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('@run.edu.ng'),
        )),
      );
    });
  });
}
