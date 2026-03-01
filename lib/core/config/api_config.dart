/// Centralized configuration for the Python verification backend.
class ApiConfig {
  /// Base URL for the Python FastAPI backend.
  ///
  /// Uses `localhost` which works with `adb reverse tcp:8000 tcp:8000`
  /// for physical devices connected via USB.
  /// For emulators without adb reverse, use `10.0.2.2` instead.
  static const String baseUrl = 'http://127.0.0.1:8000';

  /// Verification endpoint path.
  static const String verifyEndpoint = '$baseUrl/verify';
}
