import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../models/app_models.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

// ─── School Provider ──────────────────────────────────────────
final schoolProvider = StreamProvider<SchoolModel?>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).schoolStream(user.schoolId);
});

// ─── Students Provider ────────────────────────────────────────
final studentsProvider = StreamProvider<List<StudentModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).studentsStream(user.schoolId);
});

final allCurrentYearStudentsProvider =
    StreamProvider<List<StudentModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).studentsStreamWithOptions(
        user.schoolId,
        includePending: true,
      );
});

final classStudentsProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, classId) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .studentsStream(user.schoolId, classId: classId);
});

final pendingStudentsProvider =
    FutureProvider.family<List<StudentModel>, String?>((ref, classId) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];
  return ref.watch(firestoreServiceProvider).getPendingStudents(
        user.schoolId,
        classId: classId,
      );
});

// ─── Attendance Providers ─────────────────────────────────────
final attendanceProvider =
    StreamProvider.family<List<AttendanceEntry>, String>((ref, classId) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .attendanceStream(user.schoolId, classId);
});

final attendanceByDateProvider = StreamProvider.family<List<AttendanceEntry>,
    ({String classId, DateTime date})>((ref, arg) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).attendanceStream(
        user.schoolId,
        arg.classId,
        date: arg.date.toIso8601String().split('T').first,
      );
});

// ─── Staff Providers ──────────────────────────────────────────
final staffProvider = StreamProvider<List<StaffModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).staffStream(user.schoolId);
});

final leaveRequestsProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).leaveRequestsStream(user.schoolId);
});

// ─── MDM Providers ────────────────────────────────────────────
final mdmTodayProvider = StreamProvider((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).mdmTodayStream(user.schoolId);
});

// ─── Inventory Providers ──────────────────────────────────────
final inventoryDistributionProvider = StreamProvider.family<
    List<DistributionStudentModel>,
    ({String year, String classId})>((ref, arg) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .distributionStream(user.schoolId, arg.year, arg.classId);
});

// ─── Dashboard Stats Provider ─────────────────────────────────
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return const DashboardStats();
  return ref.watch(firestoreServiceProvider).getDashboardStats(user.schoolId);
});
