import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_destination.dart';
import '../widgets/auth_form_scaffold.dart';
import 'fresher_controller.dart';
import 'fresher_signup_screen.dart';
import 'pending_verification_screen.dart';
import '../../../home/presentation/home_screen.dart';
import '../../../profile/presentation/create_profile_screen.dart';

class FresherSignInScreen extends ConsumerStatefulWidget {
  const FresherSignInScreen({super.key});

  static const routeName = 'fresher-signin';
  static const routePath = '/fresher-signin';

  @override
  ConsumerState<FresherSignInScreen> createState() =>
      _FresherSignInScreenState();
}

class _FresherSignInScreenState extends ConsumerState<FresherSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jambController = TextEditingController();
  final _passwordController = TextEditingController();

  late final ProviderSubscription<AsyncValue<AuthDestination?>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AsyncValue<AuthDestination?>>(
      fresherControllerProvider,
      _handleAuthState,
    );
  }

  @override
  void dispose() {
    _subscription.close();
    _jambController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthState(
    AsyncValue<AuthDestination?>? previous,
    AsyncValue<AuthDestination?> next,
  ) {
    next.whenOrNull(
      error: (error, _) {
        final message = error is AuthFailure
            ? error.message
            : 'Invalid JAMB number or password.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
      data: (destination) {
        if (destination == null) return;
        _navigate(destination);
        ref.read(fresherControllerProvider.notifier).reset();
      },
    );
  }

  void _navigate(AuthDestination destination) {
    switch (destination) {
      case AuthDestination.home:
        context.go(HomeScreen.routePath);
        break;
      case AuthDestination.createProfile:
        context.go(CreateProfileScreen.routePath);
        break;
      case AuthDestination.pendingVerification:
        context.go(PendingVerificationScreen.routePath);
        break;
      default:
        break;
    }
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(fresherControllerProvider.notifier).signInFresher(
          jambNumber: _jambController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fresherControllerProvider);
    final isLoading = state.isLoading;
    final theme = Theme.of(context);

    return AuthFormScaffold(
      children: [
        // ── Header ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(Icons.school, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fresher Login',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'RUN Campus Connect',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with your JAMB number.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // ── Form Card ──
        AuthFormCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _jambController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'JAMB Registration Number',
                    hintText: 'e.g., 12345678AB',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'JAMB number is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onLoginPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.go(FresherSignUpScreen.routePath),
                  child: const Text("Don't have an account? Register"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
