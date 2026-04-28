import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/firebase_providers.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/data/profile_repository.dart';
import 'router/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Listen to auth state changes to initialise/teardown FCM accordingly.
    ref.listen(authStateChangesProvider, (previous, next) async {
      final user = next.asData?.value;
      final previousUser = previous?.asData?.value;
      final fcm = ref.read(fcmServiceProvider);

      if (user != null) {
        // Logged in — fetch profile for topic subscriptions, then init FCM.
        final profile = await ref
            .read(profileRepositoryProvider)
            .fetchProfile(user.uid);
        await fcm.initialize(user.uid, profile);
      } else if (previousUser != null) {
        // Logged out — clean up token and unsubscribe topics.
        final prevUser = previousUser;
        final profile = await ref
            .read(profileRepositoryProvider)
            .fetchProfile(prevUser.uid);
        await fcm.onLogout(prevUser.uid, profile);
      }
    });

    return MaterialApp.router(
      title: 'RUN Campus Connect',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
