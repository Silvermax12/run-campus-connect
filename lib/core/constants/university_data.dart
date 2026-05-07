/// Centralized lists of faculties and departments at Redeemer's University.
///
/// Used in profile creation/editing dropdowns and any other UI that needs
/// these values.
class RunUniversityData {
  RunUniversityData._();

  static const Map<String, List<String>> facultyDepartments = {
    'Basic Medical Sciences': [
      'Biochemistry',
      'Human Anatomy',
      'Human Physiology',
      'Public Health',
      'Nursing Science',
      'Physiotherapy',
      'Medical Laboratory Science',
    ],
    'Engineering': [
      'Civil Engineering',
      'Computer Engineering',
      'Electrical & Electronic Engineering',
      'Mechanical Engineering',
    ],
    'Built Environment Studies': [
      'Architecture',
      'Building Technology',
      'Estate Management',
      'Quantity Surveying',
      'Urban & Regional Planning',
    ],
    'Humanities': [
      'Christian Religious Studies',
      'English',
      'French',
      'History & International Studies',
      'Philosophy',
      'Theatre Arts',
    ],
    'Law': ['Law'],
    'Management Sciences': [
      'Accounting',
      'Banking & Finance',
      'Business Administration',
      'Public Administration',
      'Hospitality & Tourism Management',
      'Insurance',
      'Marketing',
      'Transport Management',
      'Actuarial Science',
    ],
    'Natural Sciences': [
      'Environmental Management & Toxicology',
      'Geology',
      'Industrial Chemistry',
      'Industrial Mathematics',
      'Industrial Mathematics and Computer Science',
      'Microbiology',
      'Petroleum Chemistry',
      'Physics with Electronics',
      'Statistics',
      'Statistics & Data Science',
    ],
    'Social Sciences': [
      'Economics',
      'Mass Communication',
      'Political Science',
      'Psychology',
      'Sociology',
      'Social Work',
    ],
    'Computing and Digital Technology': [
      'Computer Science',
      'Cyber Security',
      'Information Technology',
    ],
  };

  static List<String> get faculties => facultyDepartments.keys.toList();

  static List<String> get departments =>
      facultyDepartments.values.expand((departments) => departments).toList();

  static List<String> departmentsForFaculty(String? faculty) {
    if (faculty == null || faculty.isEmpty) return const [];
    return facultyDepartments[faculty] ?? const [];
  }
}
