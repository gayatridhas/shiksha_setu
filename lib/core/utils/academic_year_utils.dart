class AcademicYearUtils {
  static String currentAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return '$startYear-${(startYear + 1).toString().substring(2)}';
  }

  static DateTime academicYearStart() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return DateTime(year, 4, 1);
  }

  static DateTime academicYearEnd() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year + 1 : now.year;
    return DateTime(year, 3, 31);
  }
}
