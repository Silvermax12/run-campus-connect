class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.faculty,
    required this.department,
    required this.level,
    required this.photoUrl,
    this.bio = '',
    this.birthDay,
    this.birthMonth,
  });

  final String uid;
  final String email;
  final String displayName;
  final String faculty;
  final String department;
  final String level;
  final String photoUrl;
  final String bio;
  final int? birthDay;
  final int? birthMonth;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      faculty: data['faculty'] as String? ?? '',
      department: data['department'] as String? ?? '',
      level: data['level'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      birthDay: (data['birthDay'] as num?)?.toInt(),
      birthMonth: (data['birthMonth'] as num?)?.toInt(),
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

  /// Human-readable birthday string, e.g. "October 15th".
  String get formattedBirthday {
    if (birthDay == null || birthMonth == null) return '';
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    if (birthMonth! < 1 || birthMonth! > 12) return '';
    final suffix = _daySuffix(birthDay!);
    return '${months[birthMonth!]} $birthDay$suffix';
  }

  static String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
