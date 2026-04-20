import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_service.dart';
import 'update_required_dialog.dart';
import '../../features/update/presentation/update_center_page.dart';
import '../../router/app_router.dart';

/// Wraps route content and runs a version check when mounted.
/// Must be used inside the router tree (e.g. ShellRoute) so context has Navigator.
/// If an update is required, shows a non-dismissible dialog.
class UpdateCheckWrapper extends ConsumerStatefulWidget {
  const UpdateCheckWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends ConsumerState<UpdateCheckWrapper> {
  var _checkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    if (_checkStarted) return;
    _checkStarted = true;

    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForRequiredUpdate();

      if (!mounted) return;
      if (!result.required) return;

      final router = ref.read(appRouterProvider);
      await UpdateRequiredDialog.show(
        context,
        result: result,
        onUpdateNow: () {
          router.go(
            UpdateCenterPage.routePath,
            extra: {
              'updateUrl': result.updateUrl,
              'newVersion': result.newVersion,
              'currentVersion': result.currentVersion,
            },
          );
        },
      );
    } catch (e, stack) {
      debugPrint('[UpdateCheckWrapper] Update check failed: $e');
      debugPrint('[UpdateCheckWrapper] $stack');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
