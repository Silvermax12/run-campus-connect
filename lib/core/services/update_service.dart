import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_service.g.dart';

/// Result of checking whether an app update is required.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.required,
    required this.updateUrl,
    required this.newVersion,
    required this.currentVersion,
  });

  final bool required;
  final String updateUrl;
  final String newVersion;
  final String currentVersion;
}

class UpdateService {
  static const _minVersionKey = 'min_version';
  static const _updateUrlKey = 'update_url';

  final FirebaseRemoteConfig _remoteConfig;

  UpdateService([FirebaseRemoteConfig? remoteConfig])
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  /// Fetches Remote Config, compares versions, and returns whether an update is required.
  Future<UpdateCheckResult> checkForRequiredUpdate() async {
    await _remoteConfig.setDefaults({
      _minVersionKey: '0.0.0',
      _updateUrlKey: 'https://run.edu.ng',
    });

    // Allow frequent fetches in debug for testing; 12h default in release
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 15),
      minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 12),
    ));

    final activated = await _remoteConfig.fetchAndActivate();
    // ignore: avoid_print
    debugPrint('[UpdateService] fetchAndActivate: $activated');

    final minVersion = _remoteConfig.getString(_minVersionKey).trim();
    final updateUrl = _remoteConfig.getString(_updateUrlKey).trim();

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _stripBuildNumber(packageInfo.version);

    final updateRequired = _isVersionLessThan(currentVersion, minVersion);

    // ignore: avoid_print
    debugPrint(
      '[UpdateService] current=$currentVersion min=$minVersion required=$updateRequired',
    );

    return UpdateCheckResult(
      required: updateRequired,
      updateUrl: updateUrl,
      newVersion: minVersion,
      currentVersion: currentVersion,
    );
  }

  String _stripBuildNumber(String version) {
    final plusIndex = version.indexOf('+');
    if (plusIndex >= 0) {
      return version.substring(0, plusIndex).trim();
    }
    return version.trim();
  }

  /// Returns true if [current] is less than [minimum] (semantic version comparison).
  bool _isVersionLessThan(String current, String minimum) {
    final currentParts = _parseVersionParts(current);
    final minimumParts = _parseVersionParts(minimum);

    for (var i = 0; i < 3; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final m = i < minimumParts.length ? minimumParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  List<int> _parseVersionParts(String version) {
    final parts = version.split('.');
    return parts.map((p) => int.tryParse(p.trim()) ?? 0).toList();
  }
}

@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) {
  return UpdateService();
}
