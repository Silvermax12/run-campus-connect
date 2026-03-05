import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/firebase_providers.dart';
import 'profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  static const routeName = 'edit-profile';
  static const routePath = '/profile/edit';

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _facultyController = TextEditingController();
  final _deptController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final doc = await ref
        .read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['displayName'] as String? ?? user.displayName ?? '';
      _facultyController.text = data['faculty'] as String? ?? '';
      _deptController.text = data['department'] as String? ?? '';
      _bioController.text = data['bio'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _facultyController.dispose();
    _deptController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(profileControllerProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          faculty: _facultyController.text.trim(),
          department: _deptController.text.trim(),
          bio: _bioController.text.trim(),
        );

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _saveProfile,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _facultyController,
                decoration: const InputDecoration(
                  labelText: 'Faculty',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Faculty is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deptController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Department is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 150,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
