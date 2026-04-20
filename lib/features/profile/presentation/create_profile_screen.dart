import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/university_data.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../home/presentation/home_screen.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  static const routeName = 'create-profile';
  static const routePath = '/create-profile';

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  
  String? _selectedFaculty;
  String? _selectedDepartment;
  String _selectedLevel = '100';
  bool _isLoading = false;

  int? _birthDay;
  int? _birthMonth;

  final List<String> _levels = ['100', '200', '300', '400', '500'];

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  void _loadUserEmail() {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }


  /// Returns the maximum number of days for [month] (1-12).
  /// Uses 29 for February to allow leap-year birthdays.
  int _daysInMonth(int month) {
    const days = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      final firestore = ref.read(firestoreProvider);
      final displayName = _nameController.text.trim();
      final parts = displayName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final lastName = parts.isEmpty ? displayName : parts.last;

      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName,
        'lastName': lastName,
        'faculty': _selectedFaculty ?? '',
        'department': _selectedDepartment ?? '',
        'level': _selectedLevel,
        'bio': _bioController.text.trim(),
        'photoUrl': user.photoURL ?? '',
        'birthDay': _birthDay,
        'birthMonth': _birthMonth,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        context.go(HomeScreen.routePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Almost there!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your profile to start using RUN Campus Connect.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Faculty Dropdown
              DropdownButtonFormField<String>(
                value: _selectedFaculty,
                decoration: const InputDecoration(
                  labelText: 'Faculty',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: RunUniversityData.faculties.map((faculty) {
                  return DropdownMenuItem(
                    value: faculty,
                    child: Text(faculty, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedFaculty = value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Faculty is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Department Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.school_outlined),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: RunUniversityData.departments.map((dept) {
                  return DropdownMenuItem(
                    value: dept,
                    child: Text(dept, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDepartment = value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Department is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Level Dropdown
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: const InputDecoration(
                  labelText: 'Level',
                  prefixIcon: Icon(Icons.grade_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text('$level Level'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLevel = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date of Birth — inline Month + Day dropdowns
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Date of Birth (optional)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month dropdown
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      value: _birthMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 1,  child: Text('January')),
                        DropdownMenuItem(value: 2,  child: Text('February')),
                        DropdownMenuItem(value: 3,  child: Text('March')),
                        DropdownMenuItem(value: 4,  child: Text('April')),
                        DropdownMenuItem(value: 5,  child: Text('May')),
                        DropdownMenuItem(value: 6,  child: Text('June')),
                        DropdownMenuItem(value: 7,  child: Text('July')),
                        DropdownMenuItem(value: 8,  child: Text('August')),
                        DropdownMenuItem(value: 9,  child: Text('September')),
                        DropdownMenuItem(value: 10, child: Text('October')),
                        DropdownMenuItem(value: 11, child: Text('November')),
                        DropdownMenuItem(value: 12, child: Text('December')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _birthMonth = v;
                          // Clamp day if new month has fewer days
                          if (_birthDay != null) {
                            final max = _daysInMonth(v ?? 1);
                            if (_birthDay! > max) _birthDay = max;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Day dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: _birthDay,
                      decoration: const InputDecoration(
                        labelText: 'Day',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        _daysInMonth(_birthMonth ?? 1),
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ),
                      onChanged: (v) => setState(() => _birthDay = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bio (Optional)
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio (Optional)',
                  hintText: 'Tell us about yourself',
                  prefixIcon: Icon(Icons.info_outline),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 150,
              ),
              const SizedBox(height: 32),

              // Create Profile Button
              FilledButton(
                onPressed: _isLoading ? null : _createProfile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Complete Profile',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
