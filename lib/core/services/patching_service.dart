import 'dart:io';

import 'package:flutter/services.dart';

class PatchingService {
  const PatchingService._();

  static const MethodChannel _installerChannel =
      MethodChannel('com.run.campus.connect/installer');

  /// Applies a binary delta patch via the JNI bridge to libhpatchz.so.
  ///
  /// [patchFilePath] — path to the downloaded `.patch` file.
  /// [outputApkPath] — path where the reconstructed APK will be written.
  ///
  /// Throws an [Exception] with a descriptive message on failure.
  static Future<File> applyPatch({
    required String patchFilePath,
    required String outputApkPath,
  }) async {
    final sourceApkPath =
        await _installerChannel.invokeMethod<String>('getSourceApkPath');

    if (sourceApkPath == null || sourceApkPath.isEmpty) {
      throw Exception('Could not resolve installed APK path from native layer');
    }

    if (!File(patchFilePath).existsSync()) {
      throw Exception('Patch file not found at $patchFilePath');
    }

    // Delegates to HPatch.patch() in Kotlin which loads libhpatchz.so via JNI.
    // This avoids Process.run entirely — no W^X or Exec-format issues.
    try {
      await _installerChannel.invokeMethod<int>('applyPatch', <String, String>{
        'oldFile': sourceApkPath,
        'patchFile': patchFilePath,
        'outFile': outputApkPath,
      });
    } on PlatformException catch (e) {
      if (e.code == 'SPLIT_APK') {
        throw Exception(
          'Split APK install detected — delta patching requires a non-split installation.',
        );
      }
      throw Exception('Patch failed [${e.code}]: ${e.message ?? 'no details'}');
    }

    return File(outputApkPath);
  }

  static Future<void> triggerInstall(String apkPath) async {
    await _installerChannel.invokeMethod('installApkSession', <String, dynamic>{
      'apkPath': apkPath,
    });
  }
}
