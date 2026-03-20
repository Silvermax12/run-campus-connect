import 'package:flutter/material.dart';

/// Shows a modal bottom sheet to pick month and day of birth.
/// Returns a map with 'month' (1-12) and 'day' (1-31) if confirmed, null if dismissed.
Future<Map<String, int>?> showDateOfBirthPicker(
  BuildContext context, {
  int? initialMonth,
  int? initialDay,
}) async {
  int tempMonth = initialMonth ?? 1;
  int tempDay = initialDay ?? 1;

  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const daysInMonth = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  final result = await showModalBottomSheet<Map<String, int>>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Date of Birth',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(months[i]),
                          ),
                        ),
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
                        items: List.generate(
                          maxDay,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => tempDay = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    {'month': tempMonth, 'day': tempDay},
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  return result;
}
