class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.faculty,
    required this.department,
    required this.level,
    required this.photoUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final String faculty;
  final String department;
  final String level;
  final String photoUrl;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      faculty: data['faculty'] as String? ?? '',
      department: data['department'] as String? ?? '',
      level: data['level'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
    );
  }

  static const empty = UserProfile(
    uid: '',
    email: '',
    displayName: '',
    faculty: '',
    department: '',
    level: '',
    photoUrl: '',
  );
}
