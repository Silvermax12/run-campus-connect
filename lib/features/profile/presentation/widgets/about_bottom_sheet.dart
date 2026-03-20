import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Returns the ordinal suffix for a day (e.g. 1 -> 'st', 2 -> 'nd').
String daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

/// Formats a birthday from month and day.
String formatBirthday(int month, int day) {
  const months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  if (month < 1 || month > 12) return '';
  return '${months[month]} $day${daySuffix(day)}';
}

/// Shows an "About" modal bottom sheet with profile details.
void showAboutBottomSheet(
  BuildContext context, {
  required String name,
  required String faculty,
  required String department,
  required String birthday,
  required String bio,
  String title = 'About Me',
}) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _aboutRow(Icons.person_outline, 'Name', name),
            _aboutRow(Icons.account_balance_outlined, 'Faculty', faculty),
            _aboutRow(Icons.school_outlined, 'Department', department),
            if (birthday.isNotEmpty)
              _aboutRow(Icons.cake_outlined, 'Birthday', birthday),
            if (bio.isNotEmpty) _aboutRow(Icons.info_outline, 'Bio', bio),
          ],
        ),
      ),
    ),
  );
}

Widget _aboutRow(IconData icon, String label, String value) {
  if (value.isEmpty) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.runBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    ),
  );
}
