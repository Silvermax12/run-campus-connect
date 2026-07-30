import 'package:firebase_performance/firebase_performance.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'performance_service.g.dart';

abstract final class PerformanceTraces {
  static const appStartup = 'app_startup';
  static const feedRefresh = 'feed_refresh';
  static const messageSend = 'message_send';
}

/// Wraps [FirebasePerformance] with trace lifecycle helpers.
class PerformanceService {
  static final PerformanceService instance = PerformanceService._();
  static final PerformanceService noop = PerformanceService._(noop: true);

  factory PerformanceService({FirebasePerformance? performance, bool noop = false}) {
    if (noop) return PerformanceService.noop;
    if (performance == null) return instance;
    return PerformanceService._(performance: performance);
  }

  PerformanceService._({FirebasePerformance? performance, bool noop = false})
      : _noop = noop,
        _performance =
            noop ? null : (performance ?? FirebasePerformance.instance);

  final FirebasePerformance? _performance;
  final bool _noop;
  final Map<String, Trace> _activeTraces = {};

  Future<void> startTrace(
    String name, {
    Map<String, String> attributes = const {},
  }) async {
    if (_noop || _performance == null || _activeTraces.containsKey(name)) {
      return;
    }
    final trace = _performance.newTrace(name);
    for (final entry in attributes.entries) {
      trace.putAttribute(entry.key, entry.value);
    }
    await trace.start();
    _activeTraces[name] = trace;
  }

  Future<void> stopTrace(String name) async {
    final trace = _activeTraces.remove(name);
    if (trace == null) return;
    await trace.stop();
  }

  Future<T> runTraced<T>(
    String name,
    Future<T> Function() action, {
    Map<String, String> attributes = const {},
  }) async {
    await startTrace(name, attributes: attributes);
    try {
      return await action();
    } finally {
      await stopTrace(name);
    }
  }
}

@Riverpod(keepAlive: true)
PerformanceService performanceService(PerformanceServiceRef ref) {
  return PerformanceService.instance;
}
