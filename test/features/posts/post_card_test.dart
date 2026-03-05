import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:run_campus_connect/core/providers/firebase_providers.dart';
import 'package:run_campus_connect/features/posts/application/like_service.dart';
import 'package:run_campus_connect/features/posts/data/post_repository.dart';
import 'package:run_campus_connect/features/posts/domain/post.dart';
import 'package:run_campus_connect/features/posts/domain/post_visibility.dart';
import 'package:run_campus_connect/features/posts/presentation/widgets/post_card.dart';

import 'post_card_test.mocks.dart';

// Generate mocks
@GenerateMocks([FirebaseAuth, User, DocumentSnapshot])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
  });

  // Helper function to create a test post
  Post createTestPost({
    required String authorId,
    required String authorName,
    required String authorDept,
  }) {
    final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    
    final authorSnapshot = PostAuthorSnapshot(
      uid: authorId,
      name: authorName,
      department: authorDept,
      photoUrl: '',
    );

    return Post(
      id: 'test-post-id',
      content: 'This is a test post',
      imageUrl: null,
      timestamp: DateTime.now(),
      likeCount: 5,
      commentCount: 3,
      author: authorSnapshot,
      snapshot: mockSnapshot,
      visibility: PostVisibility.public,
      faculty: '',
      department: authorDept,
    );
  }

  // Helper function to build widget with providers
  Widget buildTestWidget(Widget child, {String? currentUserId}) {
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn(currentUserId ?? 'current-user-id');

    return ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth),
        // Mock the like status check to avoid actual Firebase calls
        checkPostLikedProvider(postId: 'test-post-id').overrideWith(
          (ref) => Stream.value(false),
        ),
        // Mock the post stream
        postStreamProvider('test-post-id').overrideWith(
          (ref) => Stream.value(null),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('PostCard UI Security Tests', () {
    testWidgets('PostCard should display author name and department correctly', (tester) async {
      // Arrange
      const authorName = 'Femi';
      const authorDept = 'CS';
      final post = createTestPost(
        authorId: 'author-user-id',
        authorName: authorName,
        authorDept: authorDept,
      );

      // Act
      await tester.pumpWidget(buildTestWidget(PostCard(post: post)));
      await tester.pumpAndSettle();

      // Assert: Verify author name is displayed
      expect(find.text(authorName), findsOneWidget,
        reason: 'Author name should be displayed in PostCard');

      // Assert: Verify department is displayed
      expect(find.text(authorDept), findsOneWidget,
        reason: 'Author department should be displayed in PostCard');
    });

    testWidgets('PostCard should display post content', (tester) async {
      // Arrange
      const postContent = 'This is my test post content!';
      
      final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      final authorSnapshot = PostAuthorSnapshot(
        uid: 'author-id',
        name: 'John Doe',
        department: 'Engineering',
        photoUrl: '',
      );

      final post = Post(
        id: 'test-post-id',
        content: postContent,
        imageUrl: null,
        timestamp: DateTime.now(),
        likeCount: 10,
        commentCount: 5,
        author: authorSnapshot,
        snapshot: mockSnapshot,
        visibility: PostVisibility.public,
        faculty: '',
        department: 'Engineering',
      );

      // Act
      await tester.pumpWidget(buildTestWidget(PostCard(post: post)));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(postContent), findsOneWidget,
        reason: 'Post content should be displayed');
    });

    testWidgets('PostCard should display like and comment counts', (tester) async {
      // Arrange
      final post = createTestPost(
        authorId: 'author-id',
        authorName: 'Test Author',
        authorDept: 'Test Dept',
      );

      // Act
      await tester.pumpWidget(buildTestWidget(PostCard(post: post)));
      await tester.pumpAndSettle();

      // Assert: Verify like count is displayed
      expect(find.text('5'), findsOneWidget,
        reason: 'Like count should be displayed');

      // Assert: Verify comment count is displayed
      expect(find.text('3'), findsOneWidget,
        reason: 'Comment count should be displayed');
    });

    testWidgets('PostCard should show like button', (tester) async {
      // Arrange
      final post = createTestPost(
        authorId: 'different-author-id',
        authorName: 'Another User',
        authorDept: 'Another Dept',
      );

      // Act
      await tester.pumpWidget(
        buildTestWidget(PostCard(post: post), currentUserId: 'current-user-id'),
      );
      await tester.pumpAndSettle();

      // Assert: Like button should be present
      expect(find.byIcon(Icons.favorite_border), findsOneWidget,
        reason: 'Like button should be visible');
    });

    testWidgets('PostCard should show comment button', (tester) async {
      // Arrange
      final post = createTestPost(
        authorId: 'author-id',
        authorName: 'Test User',
        authorDept: 'Test Dept',
      );

      // Act
      await tester.pumpWidget(buildTestWidget(PostCard(post: post)));
      await tester.pumpAndSettle();

      // Assert: Comment button should be present
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget,
        reason: 'Comment button should be visible');
    });

    testWidgets('PostCard should display author avatar', (tester) async {
      // Arrange
      final post = createTestPost(
        authorId: 'author-id',
        authorName: 'Test User',
        authorDept: 'CS',
      );

      // Act
      await tester.pumpWidget(buildTestWidget(PostCard(post: post)));
      await tester.pumpAndSettle();

      // Assert: CircleAvatar should be present
      expect(find.byType(CircleAvatar), findsOneWidget,
        reason: 'Author avatar should be displayed');
    });
  });
}
