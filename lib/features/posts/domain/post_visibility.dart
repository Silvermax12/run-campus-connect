/// Controls who can see a post in the feed.
enum PostVisibility {
  /// Visible to everyone (appears in the Global tab).
  public,

  /// Visible only to users in the same faculty.
  faculty,

  /// Visible only to users in the same department.
  department;

  /// Serialize to a Firestore-safe string.
  String toFirestoreValue() => name; // 'public', 'faculty', 'department'

  /// Deserialize from Firestore. Falls back to [public] for old/missing data.
  static PostVisibility fromString(String? value) {
    switch (value) {
      case 'faculty':
        return PostVisibility.faculty;
      case 'department':
        return PostVisibility.department;
      default:
        return PostVisibility.public;
    }
  }

  /// Human-readable label for the UI.
  String get label {
    switch (this) {
      case PostVisibility.public:
        return 'Global';
      case PostVisibility.faculty:
        return 'Faculty';
      case PostVisibility.department:
        return 'Department';
    }
  }
}
