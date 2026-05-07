class FcmTopicHelper {
  const FcmTopicHelper._();

  static const global = 'global';

  static String? facultyTopic(String faculty) {
    return _scopedTopic('faculty', faculty);
  }

  static String? departmentTopic(String department) {
    return _scopedTopic('department', department);
  }

  static String? _scopedTopic(String scope, String rawSegment) {
    final segment = sanitizeTopicSegment(rawSegment);
    if (segment == null) return null;
    return '${scope}_$segment';
  }

  /// FCM topics may only contain: a-zA-Z0-9-_.~%
  /// Normalize profile strings so subscription and publish paths match.
  static String? sanitizeTopicSegment(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9\-_.~%]'), '_');
    final compact = normalized.replaceAll(RegExp(r'_+'), '_');
    if (compact.isEmpty) return null;
    return compact;
  }
}
