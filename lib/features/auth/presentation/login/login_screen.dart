import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/auth_destination.dart';
import '../verify/verify_email_screen.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_form_scaffold.dart';
import 'login_controller.dart';
import '../../../home/presentation/home_screen.dart';
import '../../../profile/presentation/create_profile_screen.dart';
import '../fresher/fresher_signup_screen.dart';
import '../fresher/fresher_signin_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routeName = 'login';
  static const routePath = '/';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  late final ProviderSubscription<AsyncValue<AuthDestination?>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AsyncValue<AuthDestination?>>(
      loginControllerProvider,
      _handleAuthState,
    );
  }

  @override
  void dispose() {
    _subscription.close();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthState(
    AsyncValue<AuthDestination?>? previous,
    AsyncValue<AuthDestination?> next,
  ) {
    next.whenOrNull(
      error: (error, _) {
        final message =
            error is AuthFailure
                ? error.message
                : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      data: (destination) {
        if (destination == null) return;
        _navigate(destination);
        ref.read(loginControllerProvider.notifier).reset();
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
      case AuthDestination.verifyEmail:
        context.go(VerifyEmailScreen.routePath);
        break;
      case AuthDestination.pendingVerification:
        // Not expected from the regular login flow, but handled for exhaustiveness
        break;
    }
  }

  Future<void> _onPrimaryActionPressed() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(loginControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegisterMode) {
      await controller.registerWithEmail(email: email, password: password);
    } else {
      await controller.loginWithEmail(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final isLoading = state.isLoading;

    return AuthFormScaffold(
      children: [
        _HeaderSection(isRegisterMode: _isRegisterMode),
        const SizedBox(height: 32),
        AuthFormCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'RUN Email Address',
                            hintText: 'you@run.edu.ng',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required.';
                            }
                            if (!value.toLowerCase().endsWith('@run.edu.ng')) {
                              return 'Only @run.edu.ng emails are allowed.';
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
                            if (value.length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                isLoading ? null : _onPrimaryActionPressed,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                _isRegisterMode ? 'Register' : 'Login',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('— OR —'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                isLoading
                                    ? null
                                    : () =>
                                        ref
                                            .read(
                                              loginControllerProvider.notifier,
                                            )
                                            .signInWithGoogle(),
                            icon: const Icon(Icons.account_circle_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Sign in with School Google Account',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : () {
                                    setState(() {
                                      _isRegisterMode = !_isRegisterMode;
                                    });
                                  },
                          child: Text(
                            _isRegisterMode
                                ? 'Already have an account? Login'
                                : "Don't have an account? Register",
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
        const SizedBox(height: 16),
        // ── Fresher Links ──
        Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Are you a Fresher?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go(FresherSignUpScreen.routePath),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text('Fresher Sign Up'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go(FresherSignInScreen.routePath),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text('Fresher Login'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.isRegisterMode});

  final bool isRegisterMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF4169E1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Text(
              'RUN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Redeemer's University",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Campus Connect',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF4169E1),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isRegisterMode
              ? 'Create your account to join the community.'
              : 'Login with your RUN credentials.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
