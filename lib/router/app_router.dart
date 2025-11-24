import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/providers/firebase_providers.dart';
import '../features/auth/presentation/login/login_screen.dart';
import '../features/auth/presentation/verify/verify_email_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/inbox_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/posts/presentation/comments/comment_screen.dart';
import '../features/posts/presentation/create_post/create_post_screen.dart';
import '../features/profile/presentation/create_profile_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/user_profile_screen.dart';
import 'widgets/app_shell.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    debugLogDiagnostics: false,
    initialLocation: LoginScreen.routePath,
    redirect: (context, state) async {
      final user = ref.read(firebaseAuthProvider).currentUser;
      final isLoggedIn = user != null;
      final path = state.uri.path;
      final isLoggingIn = path == LoginScreen.routePath;
      final isVerifying = path == VerifyEmailScreen.routePath;
      final isCreatingProfile = path == CreateProfileScreen.routePath;

      // Not logged in → must be on login or verify pages
      if (!isLoggedIn && !isLoggingIn && !isVerifying) {
        return LoginScreen.routePath;
      }

      // Logged in but on login/verify page → check profile and redirect appropriately
      if (isLoggedIn && (isLoggingIn || isVerifying)) {
        // Check if user has a profile in Firestore
        final firestore = ref.read(firestoreProvider);
        final doc = await firestore.collection('users').doc(user!.uid).get();
        
        if (doc.exists) {
          return HomeScreen.routePath;
        } else {
          return CreateProfileScreen.routePath;
        }
      }

      // Logged in and trying to access app → check if profile exists
      if (isLoggedIn && !isCreatingProfile) {
        final firestore = ref.read(firestoreProvider);
        final doc = await firestore.collection('users').doc(user!.uid).get();
        
        if (!doc.exists) {
          return CreateProfileScreen.routePath;
        }
      }

      return null;
    },
    refreshListenable: _AuthNotifier(ref),
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        name: LoginScreen.routeName,
        pageBuilder:
            (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: VerifyEmailScreen.routePath,
        name: VerifyEmailScreen.routeName,
        pageBuilder:
            (context, state) =>
                const NoTransitionPage(child: VerifyEmailScreen()),
      ),
      GoRoute(
        path: CreateProfileScreen.routePath,
        name: CreateProfileScreen.routeName,
        pageBuilder:
            (context, state) =>
                const NoTransitionPage(child: CreateProfileScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeScreen.routePath,
                name: HomeScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ExploreScreen.routePath,
                name: ExploreScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: ExploreScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: NotificationsScreen.routePath,
                name: NotificationsScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: NotificationsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfileScreen.routePath,
                name: ProfileScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: EditProfileScreen.routeName,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: CreatePostScreen.routePath,
        name: CreatePostScreen.routeName,
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/post/:postId/comments',
        name: CommentScreen.routeName,
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return CommentScreen(postId: postId);
        },
      ),
      GoRoute(
        path: '/user/:userId',
        name: UserProfileScreen.routeName,
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: InboxScreen.routePath,
        name: InboxScreen.routeName,
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: '/chat/:userId',
        name: ChatScreen.routeName,
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final userName = state.extra as String?;
          return ChatScreen(targetUserId: userId, targetUserName: userName);
        },
      ),
    ],
  );
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this.ref) {
    ref.listen(
      authStateChangesProvider,
      (previous, next) => notifyListeners(),
    );
  }

  final Ref ref;
}
