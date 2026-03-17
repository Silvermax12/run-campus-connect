import 'package:http/http.dart' as http;

/// Simple repository for fetching the latest Governance HTML from RUN website.
class GovernanceHtmlRepository {
  GovernanceHtmlRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const String _governanceUrl = 'https://run.edu.ng/governance/';

  final http.Client _client;

  /// Fetches the raw HTML for the governance page.
  ///
  /// Returns `null` if the request fails for any reason. The caller is expected
  /// to keep showing whatever content is already visible (typically the bundled
  /// HTML asset) when this happens.
  Future<String?> fetchLatestHtml() async {
    try {
      final response = await _client.get(Uri.parse(_governanceUrl));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (_) {
      // Intentionally ignore – background refresh should be silent.
    }
    return null;
  }
}

