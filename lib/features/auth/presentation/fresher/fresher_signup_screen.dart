import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/cloudinary_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_destination.dart';
import 'fresher_controller.dart';
import 'fresher_signin_screen.dart';
import 'pending_verification_screen.dart';
import '../../../home/presentation/home_screen.dart';

class FresherSignUpScreen extends ConsumerStatefulWidget {
  const FresherSignUpScreen({super.key});

  static const routeName = 'fresher-signup';
  static const routePath = '/fresher-signup';

  @override
  ConsumerState<FresherSignUpScreen> createState() =>
      _FresherSignUpScreenState();
}

class _FresherSignUpScreenState extends ConsumerState<FresherSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jambController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedDepartment = 'Computer Science';
  File? _jambSlipImage;
  File? _admissionLetterImage;
  bool _isLoading = false;

  late final ProviderSubscription<AsyncValue<AuthDestination?>> _subscription;

  final List<String> _departments = [
    'Computer Science',
    'Information Technology',
    'Software Engineering',
    'Cyber Security',
    'Chemical Engineering',
    'Civil Engineering',
    'Electrical & Electronics Engineering',
    'Mechanical Engineering',
    'Accounting',
    'Banking & Finance',
    'Business Administration',
    'Economics',
    'International Relations',
    'Mass Communication',
    'Political Science',
    'Biochemistry',
    'Biology',
    'Chemistry',
    'Mathematics',
    'Microbiology',
    'Physics',
  ];

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
    _nameController.dispose();
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
        setState(() => _isLoading = false);
        final message = error is AuthFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
      data: (destination) {
        if (destination == null) return;
        setState(() => _isLoading = false);
        _navigate(destination);
        ref.read(fresherControllerProvider.notifier).reset();
      },
    );
  }

  void _navigate(AuthDestination destination) {
    switch (destination) {
      case AuthDestination.pendingVerification:
        context.go(PendingVerificationScreen.routePath);
        break;
      case AuthDestination.home:
        context.go(HomeScreen.routePath);
        break;
      default:
        break;
    }
  }

  Future<void> _pickImage({required bool isJambSlip}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        if (isJambSlip) {
          _jambSlipImage = File(picked.path);
        } else {
          _admissionLetterImage = File(picked.path);
        }
      });
    }
  }

  Future<void> _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) return;

    if (_jambSlipImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your JAMB slip.')),
      );
      return;
    }
    if (_admissionLetterImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload your RUN admission letter.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload both images to Cloudinary
      final cloudinary = ref.read(cloudinaryServiceProvider);

      final slipUrl = await cloudinary.uploadFile(
        _jambSlipImage!,
        folder: 'run_campus_verification',
      );
      if (slipUrl == null) throw Exception('Failed to upload JAMB slip.');

      final admissionUrl = await cloudinary.uploadFile(
        _admissionLetterImage!,
        folder: 'run_campus_verification',
      );
      if (admissionUrl == null) {
        throw Exception('Failed to upload admission letter.');
      }

      // Call the sign-up method (which also calls the Python backend)
      await ref.read(fresherControllerProvider.notifier).signUpFresher(
            fullName: _nameController.text.trim(),
            jambNumber: _jambController.text.trim(),
            department: _selectedDepartment,
            password: _passwordController.text,
            cloudinaryUrl1: slipUrl,
            cloudinaryUrl2: admissionUrl,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              _buildHeader(theme),
              const SizedBox(height: 32),

              // ── Form Card ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required.';
                            }
                            if (value.trim().length < 3) {
                              return 'Name must be at least 3 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // JAMB Number
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
                            if (value.trim().length < 8) {
                              return 'Enter a valid JAMB number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Department Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          items: _departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept,
                              child: Text(dept),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedDepartment = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
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

                        // ── Image Pickers ──
                        _buildImagePicker(
                          label: 'Upload JAMB Slip',
                          file: _jambSlipImage,
                          onTap: () => _pickImage(isJambSlip: true),
                          icon: Icons.receipt_long_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildImagePicker(
                          label: 'Upload RUN Admission Letter',
                          file: _admissionLetterImage,
                          onTap: () => _pickImage(isJambSlip: false),
                          icon: Icons.description_outlined,
                        ),
                        const SizedBox(height: 24),

                        // ── Register Button ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _onRegisterPressed,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Register',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () =>
                                  context.go(FresherSignInScreen.routePath),
                          child: const Text(
                            'Already registered? Sign In',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
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
          'Fresher Registration',
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
          'Upload your documents for verification.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker({
    required String label,
    required File? file,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: file != null ? const Color(0xFF2E7D32) : Colors.grey[400]!,
            width: file != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: file != null
              ? const Color(0xFF2E7D32).withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : icon,
              color: file != null ? const Color(0xFF2E7D32) : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file != null
                    ? '✓ ${file.path.split(Platform.pathSeparator).last}'
                    : label,
                style: TextStyle(
                  color: file != null ? const Color(0xFF2E7D32) : Colors.grey[700],
                  fontWeight: file != null ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (file == null)
              Icon(Icons.upload_outlined, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
