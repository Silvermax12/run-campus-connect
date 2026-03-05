import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:run_campus_connect/core/services/cloudinary_service.dart';
import 'package:run_campus_connect/features/posts/data/post_repository.dart';
import 'package:run_campus_connect/features/posts/domain/post_visibility.dart';
import 'package:run_campus_connect/features/profile/domain/user_profile.dart';

import 'post_creation_test.mocks.dart';

// Generate mocks
@GenerateMocks([CloudinaryService, FirebaseAuth, User])
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockCloudinaryService mockCloudinaryService;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late PostRepository postRepository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockCloudinaryService = MockCloudinaryService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-user-id');

    postRepository = PostRepository(
      firestore: fakeFirestore,
      cloudinaryService: mockCloudinaryService,
      auth: mockAuth,
    );
  });

  group('Post Denormalization Tests', () {
    test('createPost should denormalize user data into post document', () async {
      // Arrange: Create a fake user in the users collection
      const userId = 'test-user-id';
      const userName = 'Femi';
      const userDept = 'CS';
      const userEmail = 'femi@run.edu.ng';
      const userLevel = '300';
      const userPhoto = 'https://example.com/photo.jpg';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': userEmail,
        'displayName': userName,
        'department': userDept,
        'level': userLevel,
        'photoUrl': userPhoto,
      });

      // Create UserProfile object
      final userProfile = UserProfile(
        uid: userId,
        email: userEmail,
        displayName: userName,
        faculty: 'Natural Sciences',
        department: userDept,
        level: userLevel,
        photoUrl: userPhoto,
      );

      const postContent = 'This is a test post from Femi!';

      // Act: Call createPost
      await postRepository.createPost(
        content: postContent,
        author: userProfile,
        visibility: PostVisibility.public,
        imageFile: null,
      );

      // Assert: Check the posts collection for denormalized data
      final postsSnapshot = await fakeFirestore.collection('posts').get();
      
      expect(postsSnapshot.docs.length, 1, reason: 'Should have exactly one post');
      
      final postData = postsSnapshot.docs.first.data();
      
      // Verify denormalized author data
      expect(postData['authorSnapshot'], isNotNull, reason: 'authorSnapshot should exist');
      expect(postData['authorSnapshot']['uid'], userId);
      expect(postData['authorSnapshot']['name'], userName, 
        reason: 'Author name should be denormalized as "Femi"');
      expect(postData['authorSnapshot']['dept'], userDept,
        reason: 'Author department should be denormalized as "CS"');
      expect(postData['authorSnapshot']['photo'], userPhoto);
      
      // Verify other post fields
      expect(postData['content'], postContent);
      expect(postData['likeCount'], 0);
      expect(postData['commentCount'], 0);
      expect(postData['imageUrl'], isNull);
    });

    test('createPost with image should call CloudinaryService and store URL', () async {
      // Arrange
      const userId = 'test-user-id';
      final userProfile = UserProfile(
        uid: userId,
        email: 'user@run.edu.ng',
        displayName: 'Test User',
        faculty: 'Engineering',
        department: 'Engineering',
        level: '200',
        photoUrl: '',
      );

      // Mock Cloudinary upload to return a fake URL
      const fakeImageUrl = 'https://cloudinary.com/fake.jpg';
      when(mockCloudinaryService.uploadFile(any))
        .thenAnswer((_) async => fakeImageUrl);

      final mockImageFile = File('test_image.jpg');

      // Act
      await postRepository.createPost(
        content: 'Post with image',
        author: userProfile,
        visibility: PostVisibility.public,
        imageFile: mockImageFile,
      );

      // Assert: Verify CloudinaryService was called
      verify(mockCloudinaryService.uploadFile(mockImageFile)).called(1);

      // Assert: Check that the image URL is stored in the post
      final postsSnapshot = await fakeFirestore.collection('posts').get();
      final postData = postsSnapshot.docs.first.data();
      
      expect(postData['imageUrl'], fakeImageUrl,
        reason: 'Image URL from Cloudinary should be stored in post');
    });

    test('createPost should throw exception if user is not signed in', () async {
      // Arrange: No current user
      when(mockAuth.currentUser).thenReturn(null);

      final userProfile = UserProfile(
        uid: 'test-id',
        email: 'user@run.edu.ng',
        displayName: 'Test',
        faculty: 'Sciences',
        department: 'CS',
        level: '100',
        photoUrl: '',
      );

      // Act & Assert
      expect(
        () => postRepository.createPost(
          content: 'Test content',
          author: userProfile,
          visibility: PostVisibility.public,
        ),
        throwsException,
      );
    });
  });
}
