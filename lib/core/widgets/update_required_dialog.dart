import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Non-dismissible dialog shown when a hard update is required.
/// User must tap "Update Now" (navigates to UpdateCenterPage) or "Exit" (closes app).
class UpdateRequiredDialog extends StatelessWidget {
  const UpdateRequiredDialog({
    super.key,
    required this.result,
    required this.onNavigateToUpdate,
  });

  final UpdateCheckResult result;
  final VoidCallback onNavigateToUpdate;

  /// Shows the update required dialog. Use [onUpdateNow] to handle navigation.
  static Future<void> show(
    BuildContext context, {
    required UpdateCheckResult result,
    required VoidCallback onUpdateNow,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: UpdateRequiredDialog(
          result: result,
          onNavigateToUpdate: () {
            Navigator.of(context, rootNavigator: true).pop();
            onUpdateNow();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'New Version Available',
        style: TextStyle(
          color: AppTheme.runBlue,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const Text(
        'To continue using Run Campus Connect and access new features, '
        'please download the latest update.',
        style: TextStyle(fontSize: 15, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => SystemNavigator.pop(),
          child: Text(
            'Exit',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
        FilledButton(
          onPressed: onNavigateToUpdate,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.runGold,
            foregroundColor: AppTheme.runBlue,
          ),
          child: const Text('Update Now'),
        ),
      ],
    );
  }
}
