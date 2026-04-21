import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiksha_setu_2/services/firestore_service.dart';
import 'package:shiksha_setu_2/providers/auth_provider.dart';
import 'package:shiksha_setu_2/models/app_models.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

// ─── School Provider ──────────────────────────────────────────
final schoolProvider = StreamProvider<SchoolModel?>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<SchoolModel?>.value(null);
  return ref.watch(firestoreServiceProvider).schoolStream(user.schoolId);
});

// ─── Students Provider ────────────────────────────────────────
final studentsProvider = StreamProvider<List<StudentModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<StudentModel>>.value([]);
  return ref.watch(firestoreServiceProvider).studentsStream(user.schoolId);
});

final allCurrentYearStudentsProvider =
    StreamProvider<List<StudentModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<StudentModel>>.value([]);
  return ref.watch(firestoreServiceProvider).studentsStreamWithOptions(
        user.schoolId,
        includePending: true,
      );
});

final classStudentsProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, classId) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<StudentModel>>.value([]);
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
  if (user == null) return Stream<List<AttendanceEntry>>.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .attendanceStream(user.schoolId, classId);
});

final schoolAttendanceTodayProvider =
    StreamProvider<List<AttendanceEntry>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<AttendanceEntry>>.value([]);
  return ref.watch(firestoreServiceProvider).schoolAttendanceTodayStream(user.schoolId);
});

final attendanceByDateProvider = StreamProvider.family<List<AttendanceEntry>,
    ({String classId, DateTime date})>((ref, arg) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<AttendanceEntry>>.value([]);
  return ref.watch(firestoreServiceProvider).attendanceStream(
        user.schoolId,
        arg.classId,
        date: arg.date.toIso8601String().split('T').first,
      );
});

// ─── Staff Providers ──────────────────────────────────────────
final staffProvider = StreamProvider<List<StaffModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<StaffModel>>.value([]);
  return ref.watch(firestoreServiceProvider).staffStream(user.schoolId);
});

final leaveRequestsProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<List<LeaveRequestModel>>.value([]);
  return ref.watch(firestoreServiceProvider).leaveRequestsStream(user.schoolId);
});

// ─── MDM Providers ────────────────────────────────────────────
final mdmTodayProvider = StreamProvider<MdmSummary?>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<MdmSummary?>.value(null);
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
final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream<DashboardStats>.value(const DashboardStats());

  final studentsAsync = ref.watch(allCurrentYearStudentsProvider);
  final attendanceAsync = ref.watch(schoolAttendanceTodayProvider);
  final staffAsync = ref.watch(staffProvider);
  final mdmAsync = ref.watch(mdmTodayProvider);
  final leaveRequestsAsync = ref.watch(leaveRequestsProvider);

  // Return a combined snackshot
  final students = studentsAsync.valueOrNull ?? [];
  final attendance = attendanceAsync.valueOrNull ?? [];
  final staff = staffAsync.valueOrNull ?? [];
  final mdm = mdmAsync.valueOrNull;
  final leaves = leaveRequestsAsync.valueOrNull ?? [];

  final totalStudents = students.length;
  final presentToday = attendance.where((e) => e.status == AttendanceStatus.present).length;
  final absentToday = attendance.where((e) => e.status == AttendanceStatus.absent).length;
  final mealsToday = mdm?.totalMeals ?? 0;
  final leavePending = leaves.length;
  
  final rate = totalStudents > 0 ? (presentToday / totalStudents * 100) : 0.0;

  return Stream.value(DashboardStats(
    totalStudents: totalStudents,
    presentToday: presentToday,
    absentToday: absentToday,
    mealsToday: mealsToday,
    staffPresent: staff.where((s) => s.status == StaffStatus.present).length,
    staffTotal: staff.length,
    leavePending: leavePending,
    attendanceRate: rate,
  ));
});

final hasAttendanceForTodayProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null || user.assignedClassId == null) return Stream<bool>.value(false);
  
  return ref.watch(schoolAttendanceTodayProvider).when(
    data: (list) => Stream.value(list.any((e) => e.classId == user.assignedClassId)),
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});
