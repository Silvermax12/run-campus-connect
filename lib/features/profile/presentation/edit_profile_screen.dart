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

  Future<void> _pickDateOfBirth() async {
    int tempMonth = _birthMonth ?? 1;
    int tempDay = _birthDay ?? 1;

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            const months = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December',
            ];
            final daysInMonth = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
            final maxDay = daysInMonth[tempMonth];
            if (tempDay > maxDay) {
              tempDay = maxDay;
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Date of Birth',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: tempMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(12, (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(months[i]),
                          )),
                          onChanged: (v) {
                            if (v != null) setSheetState(() => tempMonth = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: tempDay,
                          decoration: const InputDecoration(
                            labelText: 'Day',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(maxDay, (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          )),
                          onChanged: (v) {
                            if (v != null) setSheetState(() => tempDay = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, {'month': tempMonth, 'day': tempDay}),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _birthMonth = result['month'];
        _birthDay = result['day'];
      });
    }
  }

  String get _formattedBirthday {
    if (_birthDay == null || _birthMonth == null) return 'Not set';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[_birthMonth!]} $_birthDay';
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

              // Date of Birth
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Date of Birth'),
                subtitle: Text(_formattedBirthday),
                trailing: const Icon(Icons.calendar_today_outlined, size: 20),
                onTap: _pickDateOfBirth,
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
