import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'background_task_handler.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.speedBps,
    required this.smoothedEta,
    required this.waitingForInternet,
  });

  final int bytesDownloaded;
  final int totalBytes;
  final double speedBps;
  final Duration? smoothedEta;
  final bool waitingForInternet;
}

class DownloadEngine {
  DownloadEngine._();
  static final DownloadEngine instance = DownloadEngine._();

  static const _boxName = 'download_engine';
  static const _stateKey = 'state';
  final Dio _dio = Dio();
  final StreamController<DownloadProgress> _progressController =
      StreamController.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  CancelToken? _cancelToken;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final List<_SpeedSample> _samples = <_SpeedSample>[];
  bool _pausedByConnectivity = false;
  bool _isPaused = false;
  bool _isCancelled = false;

  Future<Box<dynamic>> _box() => Hive.openBox<dynamic>(_boxName);

  Future<void> start({
    required String url,
    required String destinationFileName,
    String? expectedSha256,
  }) async {
    _isPaused = false;
    _isCancelled = false;
    _pausedByConnectivity = false;
    _cancelToken = CancelToken();

    final dir = await getApplicationDocumentsDirectory();
    final output = File('${dir.path}/$destinationFileName');
    final temp = File('${output.path}.tmp');
    final already = temp.existsSync() ? await temp.length() : 0;

    final box = await _box();
    await box.put(_stateKey, <String, dynamic>{
      'url': url,
      'destination': output.path,
      'expectedSha256': expectedSha256,
      'downloaded': already,
      'totalBytes': 0,
      'isPaused': false,
      'pausedByNetwork': false,
      'isReadyToInstall': false,
      'isDownloading': true,
    });

    _observeConnectivity();
    await _downloadWithRetries(
      url: url,
      tempFile: temp,
      outputFile: output,
      resumeFrom: already,
      expectedSha256: expectedSha256,
    );
  }

  Future<void> pause({bool pausedByNetwork = false}) async {
    _isPaused = true;
    _cancelToken?.cancel('paused');
    await FlutterForegroundTask.stopService();
    final box = await _box();
    final state = Map<String, dynamic>.from(box.get(_stateKey) ?? <String, dynamic>{});
    state['isDownloading'] = false;
    state['isPaused'] = true;
    state['pausedByNetwork'] = pausedByNetwork;
    await box.put(_stateKey, state);
  }

  Future<void> resume() async {
    final box = await _box();
    final state = Map<String, dynamic>.from(box.get(_stateKey) ?? <String, dynamic>{});
    final url = state['url'] as String?;
    final destination = state['destination'] as String?;
    final expectedSha256 = state['expectedSha256'] as String?;
    if (url == null || destination == null) return;
    state['isPaused'] = false;
    state['pausedByNetwork'] = false;
    await box.put(_stateKey, state);
    final output = File(destination);
    await start(
      url: url,
      destinationFileName: output.uri.pathSegments.last,
      expectedSha256: expectedSha256,
    );
  }

  Future<void> cancel() async {
    _isCancelled = true;
    _cancelToken?.cancel('cancelled');
    await FlutterForegroundTask.stopService();
    final box = await _box();
    final state = Map<String, dynamic>.from(box.get(_stateKey) ?? <String, dynamic>{});
    final destination = state['destination'] as String?;
    if (destination != null) {
      final tmp = File('$destination.tmp');
      if (tmp.existsSync()) {
        await tmp.delete();
      }
    }
    await box.delete(_stateKey);
  }

  Future<void> _downloadWithRetries({
    required String url,
    required File tempFile,
    required File outputFile,
    required int resumeFrom,
    required String? expectedSha256,
  }) async {
    var nextResumeFrom = resumeFrom;
    var attempt = 0;
    
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Downloading update',
        notificationText: 'Preparing...',
        callback: startForegroundTaskCallback,
      );
    }

    while (attempt < 10 && !_isCancelled) {
      try {
        await _download(
          url: url,
          tempFile: tempFile,
          outputFile: outputFile,
          resumeFrom: nextResumeFrom,
          expectedSha256: expectedSha256,
        );
        return;
      } on DioException {
        if (_isPaused || _isCancelled) return;
        attempt += 1;
        final delay = Duration(seconds: 1 << attempt);
        await Future.delayed(delay);
        nextResumeFrom = tempFile.existsSync() ? await tempFile.length() : 0;
      }
    }
    throw Exception('Download failed after 10 retry attempts');
  }

  Future<void> _download({
    required String url,
    required File tempFile,
    required File outputFile,
    required int resumeFrom,
    required String? expectedSha256,
  }) async {
    final sink = tempFile.openWrite(mode: FileMode.append);
    var downloaded = resumeFrom;
    var totalSize = 0;

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{'Range': 'bytes=$resumeFrom-'},
        ),
        cancelToken: _cancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null) throw Exception('No response stream');
      final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
      final contentLength = int.tryParse(
            response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
          ) ??
          0;
      totalSize = _extractTotalSize(contentRange) ??
          (contentLength + resumeFrom);

      var lastTick = DateTime.now();
      var lastBytes = downloaded;
      await for (final chunk in stream) {
        if (_isPaused || _isCancelled) break;
        sink.add(chunk);
        downloaded += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastTick).inMilliseconds >= 500) {
          final deltaBytes = downloaded - lastBytes;
          final deltaSec = now.difference(lastTick).inMilliseconds / 1000;
          final speed = deltaSec <= 0 ? 0.0 : deltaBytes / deltaSec;
          _samples.add(_SpeedSample(now, speed));
          _samples.removeWhere((s) => now.difference(s.time).inSeconds > 5);
          final avgSpeed = _samples.isEmpty
              ? 0.0
              : _samples.map((s) => s.speed).reduce((a, b) => a + b) / _samples.length;
          final remaining = totalSize - downloaded;
          final eta =
              avgSpeed <= 0 ? null : Duration(seconds: (remaining / avgSpeed).round());
          _progressController.add(DownloadProgress(
            bytesDownloaded: downloaded,
            totalBytes: totalSize,
            speedBps: avgSpeed,
            smoothedEta: eta,
            waitingForInternet: _pausedByConnectivity,
          ));
          if (totalSize > 0) {
            FlutterForegroundTask.updateService(
              notificationTitle: 'Downloading update',
              notificationText: '${((downloaded / totalSize) * 100).toStringAsFixed(1)}%',
            );
          }
          lastTick = now;
          lastBytes = downloaded;
          final box = await _box();
          final state = Map<String, dynamic>.from(box.get(_stateKey) ?? <String, dynamic>{});
          state['downloaded'] = downloaded;
          state['totalBytes'] = totalSize;
          await box.put(_stateKey, state);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (_isPaused || _isCancelled) return;
    
    await FlutterForegroundTask.stopService();

    _progressController.add(
      DownloadProgress(
        bytesDownloaded: downloaded,
        totalBytes: totalSize,
        speedBps: 0,
        smoothedEta: Duration.zero,
        waitingForInternet: false,
      ),
    );

    await tempFile.rename(outputFile.path);
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final digest = await _sha256OfFile(outputFile);
      if (digest.toLowerCase() != expectedSha256.toLowerCase()) {
        throw Exception('SHA-256 mismatch');
      }
    }
    final box = await _box();
    final state = Map<String, dynamic>.from(box.get(_stateKey) ?? <String, dynamic>{});
    state['isDownloading'] = false;
    state['isPaused'] = false;
    state['pausedByNetwork'] = false;
    state['isReadyToInstall'] = true;
    state['downloaded'] = totalSize;
    state['totalBytes'] = totalSize;
    await box.put(_stateKey, state);
  }

  void _observeConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) async {
      final online = !result.contains(ConnectivityResult.none);
      if (!online) {
        _pausedByConnectivity = true;
        await pause(pausedByNetwork: true);
      } else if (_pausedByConnectivity) {
        _pausedByConnectivity = false;
        await resume();
      }
    });
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  int? _extractTotalSize(String? contentRange) {
    if (contentRange == null) return null;
    final slash = contentRange.lastIndexOf('/');
    if (slash == -1) return null;
    return int.tryParse(contentRange.substring(slash + 1));
  }
}

class _SpeedSample {
  _SpeedSample(this.time, this.speed);
  final DateTime time;
  final double speed;
}
