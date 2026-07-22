import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_service.g.dart';

enum UpdatePackageType {
  patch,
  apk;

  static UpdatePackageType fromName(String value) {
    return UpdatePackageType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => UpdatePackageType.patch,
    );
  }
}

/// Result of checking whether an app update is required.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.majorUpdateRequired,
    required this.minVersion,
    required this.packageType,
    required this.patchUrl,
    required this.patchSha256,
    required this.patchSizeBytes,
    required this.updateUrl,
    required this.updateSha256,
    required this.updateSizeBytes,
    required this.rolloutPercentage,
    required this.minorPatchAvailable,
  });

  final String currentVersion;
  final bool majorUpdateRequired;
  final String minVersion;
  final UpdatePackageType packageType;
  final String patchUrl;
  final String patchSha256;
  final int patchSizeBytes;
  final String updateUrl;
  final String updateSha256;
  final int updateSizeBytes;
  final int rolloutPercentage;
  final bool minorPatchAvailable;

  bool get usesFullApk => packageType == UpdatePackageType.apk;

  String get selectedUrl => usesFullApk ? updateUrl : patchUrl;

  String get selectedSha256 => usesFullApk ? updateSha256 : patchSha256;

  int get selectedSizeBytes => usesFullApk ? updateSizeBytes : patchSizeBytes;
}

class UpdateService {
  static const _minVersionKey = 'min_version';
  static const _patchUrlKey = 'patch_url';
  static const _patchSha256Key = 'patch_sha256';
  static const _patchSizeBytesKey = 'patch_size_bytes';
  static const _updateUrlKey = 'update_url';
  static const _updateSha256Key = 'update_sha256';
  static const _updateSizeBytesKey = 'update_size_bytes';
  static const _rolloutPercentageKey = 'rollout_percentage';

  final FirebaseRemoteConfig _remoteConfig;
  final FirebaseAuth _firebaseAuth;
  final ShorebirdCodePush _shorebirdUpdater;

  UpdateService({
    FirebaseRemoteConfig? remoteConfig,
    FirebaseAuth? firebaseAuth,
    ShorebirdCodePush? shorebirdUpdater,
  }) : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _shorebirdUpdater = shorebirdUpdater ?? ShorebirdCodePush();

  Future<UpdateCheckResult> checkForRequiredUpdate() async {
    await _remoteConfig.setDefaults({
      _minVersionKey: '0.0.0',
      _patchUrlKey: '',
      _patchSha256Key: '',
      _patchSizeBytesKey: 0,
      _updateUrlKey: '',
      _updateSha256Key: '',
      _updateSizeBytesKey: 0,
      _rolloutPercentageKey: 100,
    });

    // Allow frequent fetches in debug for testing; 12h default in release
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 12),
      ),
    );

    final activated = await _remoteConfig.fetchAndActivate();
    // ignore: avoid_print
    debugPrint('[UpdateService] fetchAndActivate: $activated');

    final minVersion = _remoteConfig.getString(_minVersionKey).trim();
    final patchUrl = _remoteConfig.getString(_patchUrlKey).trim();
    final patchSha256 = _remoteConfig.getString(_patchSha256Key).trim();
    final patchSizeBytes = _remoteConfig.getInt(_patchSizeBytesKey);
    final updateUrl = _remoteConfig.getString(_updateUrlKey).trim();
    final updateSha256 = _remoteConfig.getString(_updateSha256Key).trim();
    final updateSizeBytes = _remoteConfig.getInt(_updateSizeBytesKey);
    final rolloutPercentage = _remoteConfig
        .getInt(_rolloutPercentageKey)
        .clamp(0, 100);

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _stripBuildNumber(packageInfo.version);

    final majorRequired = _isVersionLessThan(currentVersion, minVersion);
    final packageType =
        _isTwoOrMoreVersionsBehind(currentVersion, minVersion)
            ? UpdatePackageType.apk
            : UpdatePackageType.patch;
    final rolloutPass = _isInRolloutBucket(
      _firebaseAuth.currentUser?.uid,
      rolloutPercentage,
    );
    final majorUpdateRequired = majorRequired && rolloutPass;
    final minorPatchAvailable =
        !majorUpdateRequired && await _isMinorPatchAvailable();

    // ignore: avoid_print
    debugPrint(
      '[UpdateService] current=$currentVersion min=$minVersion major=$majorUpdateRequired package=${packageType.name} minor=$minorPatchAvailable',
    );

    return UpdateCheckResult(
      currentVersion: currentVersion,
      majorUpdateRequired: majorUpdateRequired,
      minVersion: minVersion,
      packageType: packageType,
      patchUrl: patchUrl,
      patchSha256: patchSha256,
      patchSizeBytes: patchSizeBytes,
      updateUrl: updateUrl,
      updateSha256: updateSha256,
      updateSizeBytes: updateSizeBytes,
      rolloutPercentage: rolloutPercentage,
      minorPatchAvailable: minorPatchAvailable,
    );
  }

  /// Returns true if this user is within the rollout bucket.
  /// Uses MD5 of the user UID so the same UID always maps to the
  /// exact same bucket number, independent of Dart runtime or restarts.
  bool _isInRolloutBucket(String? userUid, int rolloutPercentage) {
    if (rolloutPercentage >= 100) return true;
    if (userUid == null || userUid.isEmpty) return false;
    // Take the first 4 bytes of the MD5 digest and convert to an unsigned int.
    final hash = md5.convert(utf8.encode(userUid)).bytes;
    final bucket =
        ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]).abs() %
        100;
    return bucket < rolloutPercentage;
  }

  Future<bool> _isMinorPatchAvailable() async {
    try {
      return await _shorebirdUpdater.isNewPatchAvailableForDownload();
    } catch (_) {
      return false;
    }
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

  bool _isTwoOrMoreVersionsBehind(String current, String minimum) {
    if (!_isVersionLessThan(current, minimum)) return false;

    final currentParts = _normalizeVersionParts(_parseVersionParts(current));
    final minimumParts = _normalizeVersionParts(_parseVersionParts(minimum));

    if (minimumParts[0] != currentParts[0] ||
        minimumParts[1] != currentParts[1]) {
      return true;
    }

    return minimumParts[2] - currentParts[2] >= 2;
  }

  List<int> _normalizeVersionParts(List<int> parts) {
    return List<int>.generate(
      3,
      (index) => index < parts.length ? parts[index] : 0,
    );
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
