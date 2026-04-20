import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/university_data.dart';
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
  final _bioController = TextEditingController();

  String? _selectedFaculty;
  String? _selectedDepartment;
  int? _birthDay;
  int? _birthMonth;

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
      final savedFaculty = data['faculty'] as String? ?? '';
      final savedDept = data['department'] as String? ?? '';
      _bioController.text = data['bio'] as String? ?? '';
      setState(() {
        _selectedFaculty = RunUniversityData.faculties.contains(savedFaculty)
            ? savedFaculty
            : null;
        _selectedDepartment = RunUniversityData.departments.contains(savedDept)
            ? savedDept
            : null;
        _birthDay = (data['birthDay'] as num?)?.toInt();
        _birthMonth = (data['birthMonth'] as num?)?.toInt();
      });
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(profileControllerProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          faculty: _selectedFaculty ?? '',
          department: _selectedDepartment ?? '',
          bio: _bioController.text.trim(),
          birthDay: _birthDay,
          birthMonth: _birthMonth,
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
              DropdownButtonFormField<String>(
                value: _selectedFaculty,
                decoration: const InputDecoration(
                  labelText: 'Faculty',
                  prefixIcon: Icon(Icons.account_balance_outlined),
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
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.school_outlined),
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

              // Date of Birth — inline Month + Day dropdowns
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Date of Birth (optional)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          if (_birthDay != null) {
                            final max = _daysInMonth(v ?? 1);
                            if (_birthDay! > max) _birthDay = max;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
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
