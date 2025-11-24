import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/auth_destination.dart';
import '../login/login_controller.dart';
import '../../data/auth_repository.dart';
import '../../../home/presentation/home_screen.dart';
import '../../../profile/presentation/create_profile_screen.dart';

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  static const routeName = 'verify-email';
  static const routePath = '/verify-email';

  Future<void> _handleResend(WidgetRef ref, BuildContext context) async {
    try {
      await ref
          .read(loginControllerProvider.notifier)
          .resendVerificationEmail();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    } on AuthFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _handleContinue(WidgetRef ref, BuildContext context) async {
    final controller = ref.read(loginControllerProvider.notifier);
    try {
      final destination = await controller.refreshEmailVerification();
      if (!context.mounted) return;
      if (destination == AuthDestination.home) {
        context.go(HomeScreen.routePath);
      } else if (destination == AuthDestination.createProfile) {
        context.go(CreateProfileScreen.routePath);
      }
    } on AuthFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Check your inbox',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'We sent a verification link to your RUN email. Verify your email '
              'to continue. You can resend the email or continue after you have verified.',
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isLoading ? null : () => _handleContinue(ref, context),
              child: const Text('I verified my email'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: isLoading ? null : () => _handleResend(ref, context),
              child: const Text('Resend verification email'),
            ),
          ],
        ),
      ),
    );
  }
}
