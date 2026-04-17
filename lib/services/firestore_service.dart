import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';

class FirestoreService {
  FirebaseFirestore get _db {
    if (Firebase.apps.isEmpty) {
      throw FirebaseException(plugin: 'firestore', message: 'Firebase not initialized');
    }
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw FirebaseException(plugin: 'auth', message: 'Firebase not initialized');
    }
    return FirebaseAuth.instance;
  }

  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _uid {
    if (!_isFirebaseInitialized) return '';
    try {
      return _auth.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  // ─── School ──────────────────────────────────────────────────
  Future<SchoolModel?> getSchool(String schoolId) async {
    if (!_isFirebaseInitialized) return null;
    try {
      final doc = await _db.collection('schools').doc(schoolId).get();
      if (!doc.exists) return null;
      return SchoolModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Stream<SchoolModel?> schoolStream(String schoolId) {
    if (!_isFirebaseInitialized) return Stream.value(null);
    return _db.collection('schools').doc(schoolId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SchoolModel.fromFirestore(doc);
    });
  }

  // ─── Students ────────────────────────────────────────────────
  Stream<List<StudentModel>> studentsStream(String schoolId, {String? classId}) {
    if (!_isFirebaseInitialized) return Stream.value([]);
    Query query = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .orderBy('rollNo');
    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(StudentModel.fromFirestore).toList(),
    );
  }

  Future<void> addStudent(String schoolId, StudentModel student) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(student.studentId)
        .set(student.toFirestore());
    await _db.collection('schools').doc(schoolId).update({
      'totalStudents': FieldValue.increment(1),
    });
  }

  Future<void> updateStudent(String schoolId, String studentId, Map<String, dynamic> data) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update(data);
  }

  // ─── Attendance ───────────────────────────────────────────────
  Stream<List<AttendanceEntry>> attendanceStream(String schoolId, String classId, {String? date}) {
    if (!_isFirebaseInitialized) return Stream.value([]);
    final dateKey = date ?? _today;
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(dateKey)
        .collection('entries')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs.map(AttendanceEntry.fromFirestore).toList());
  }

  Future<void> submitAttendance(
    String schoolId,
    String classId,
    List<StudentModel> students,
    String submittedBy,
  ) async {
    if (!_isFirebaseInitialized) return;
    final dateKey = _today;
    final batch = _db.batch();
    final dayRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(dateKey);

    batch.set(
      dayRef,
      {
        'date': Timestamp.fromDate(DateTime.now()),
        'schoolId': schoolId,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'isLocked': false,
      },
      SetOptions(merge: true),
    );

    for (final s in students) {
      if (s.status == null) continue;
      final entryRef = dayRef.collection('entries').doc(s.studentId);
      batch.set(entryRef, {
        'studentId': s.studentId,
        'studentName': s.fullName,
        'status': s.status!.name,
        'classId': classId,
        'submittedBy': submittedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'isLocked': false,
      });
    }
    await batch.commit();
  }

  Future<Map<String, AttendanceStatus>> getTodayAttendanceMap(
    String schoolId,
    String classId,
  ) async {
    if (!_isFirebaseInitialized) return {};
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(_today)
        .collection('entries')
        .where('classId', isEqualTo: classId)
        .get();

    final map = <String, AttendanceStatus>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final studentId = data['studentId'] as String? ?? doc.id;
      final statusStr = data['status'] as String? ?? 'present';
      map[studentId] = AttendanceStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => AttendanceStatus.present,
      );
    }
    return map;
  }

  Future<Map<String, int>> getMonthlyPresentCount(
    String schoolId,
    String classId,
    int year,
    int month,
  ) async {
    if (!_isFirebaseInitialized) return {};
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final map = <String, int>{};

    final days = end.difference(start).inDays + 1;
    for (int i = 0; i < days; i++) {
      final dateKey = DateFormat('yyyy-MM-dd').format(start.add(Duration(days: i)));
      final snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('attendance')
          .doc(dateKey)
          .collection('entries')
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'present')
          .get();
      for (final doc in snap.docs) {
        final sid = (doc.data()['studentId'] as String?) ?? doc.id;
        map[sid] = (map[sid] ?? 0) + 1;
      }
    }
    return map;
  }

  // ─── MDM ─────────────────────────────────────────────────────
  Future<void> submitMdm({
    required String schoolId,
    required List<MdmClassEntry> entries,
    required String menu,
    required String notes,
    required String submittedBy,
  }) async {
    if (!_isFirebaseInitialized) return;
    final dateKey = _today;
    final batch = _db.batch();
    final dayRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('mdm')
        .doc(dateKey);

    final total = entries.fold(0, (sum, e) => sum + e.mealCount);

    batch.set(
      dayRef,
      {
        'date': Timestamp.fromDate(DateTime.now()),
        'schoolId': schoolId,
        'menu': menu,
        'notes': notes,
        'totalMeals': total,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'isVerified': false,
      },
      SetOptions(merge: true),
    );

    for (final e in entries) {
      final entryRef = dayRef.collection('classes').doc(e.classId);
      batch.set(entryRef, {
        'classId': e.classId,
        'className': e.className,
        'mealCount': e.mealCount,
        'submittedBy': submittedBy,
      });
    }
    await batch.commit();
  }

  Stream<DocumentSnapshot?> mdmTodayStream(String schoolId) {
    if (!_isFirebaseInitialized) return Stream.value(null);
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('mdm')
        .doc(_today)
        .snapshots()
        .map((doc) => doc.exists ? doc : null);
  }

  Future<List<Map<String, dynamic>>> getMdmWeekData(String schoolId) async {
    if (!_isFirebaseInitialized) return [];
    final result = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      try {
        final doc = await _db
            .collection('schools')
            .doc(schoolId)
            .collection('mdm')
            .doc(dateKey)
            .get();
        result.add({
          'date': DateFormat('EEE').format(date),
          'meals': doc.exists ? (doc.data()?['totalMeals'] ?? 0) : 0,
          'submitted': doc.exists,
        });
      } catch (_) {
        result.add({
          'date': DateFormat('EEE').format(date),
          'meals': 0,
          'submitted': false,
        });
      }
    }
    return result;
  }

  // ─── Staff / Leave Requests ───────────────────────────────────
  Stream<List<StaffModel>> staffStream(String schoolId) {
    if (!_isFirebaseInitialized) return Stream.value([]);
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .snapshots()
        .map((snap) => snap.docs.map(StaffModel.fromFirestore).toList());
  }

  Stream<List<LeaveRequestModel>> leaveRequestsStream(String schoolId) {
    if (!_isFirebaseInitialized) return Stream.value([]);
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('leave_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LeaveRequestModel.fromFirestore).toList());
  }

  Future<void> updateLeaveStatus(
    String schoolId,
    String requestId,
    LeaveRequestStatus status,
    String reviewedBy,
  ) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('leave_requests')
        .doc(requestId)
        .update({
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitLeaveRequest(String schoolId, LeaveRequestModel req) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('leave_requests')
        .doc(req.requestId)
        .set(req.toFirestore());
  }

  // ─── Inventory ────────────────────────────────────────────────
  Stream<List<DistributionStudentModel>> distributionStream(
    String schoolId,
    String year,
    String classId,
  ) {
    if (!_isFirebaseInitialized) return Stream.value([]);
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('inventory')
        .doc(year)
        .collection('distributions')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs.map(DistributionStudentModel.fromFirestore).toList());
  }

  Future<void> updateDistribution(
    String schoolId,
    String year,
    String studentId,
    bool uniformReceived,
    bool shoesReceived,
  ) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('inventory')
        .doc(year)
        .collection('distributions')
        .doc(studentId)
        .update({
      'uniformReceived': uniformReceived,
      'shoesReceived': shoesReceived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Dashboard Stats ──────────────────────────────────────────
  Future<DashboardStats> getDashboardStats(String schoolId) async {
    if (!_isFirebaseInitialized) return const DashboardStats();
    try {
      final schoolDoc = await _db.collection('schools').doc(schoolId).get();
      final schoolData = schoolDoc.data() ?? {};
      final totalStudents = schoolData['totalStudents'] ?? 0;

      final attSnap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('attendance')
          .doc(_today)
          .collection('entries')
          .get();
      final presentCount = attSnap.docs
          .where((d) => d.data()['status'] == 'present')
          .length;
      final absentCount = attSnap.docs
          .where((d) => d.data()['status'] == 'absent')
          .length;

      final staffSnap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .get();
      final staffPresent = staffSnap.docs
          .where((d) => d.data()['todayStatus'] == 'present')
          .length;

      final mdmDoc = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('mdm')
          .doc(_today)
          .get();
      final mealsToday = mdmDoc.exists ? (mdmDoc.data()?['totalMeals'] ?? 0) : 0;

      final leaveSnap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('leave_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      final rate = totalStudents > 0 ? presentCount / totalStudents * 100 : 0.0;

      return DashboardStats(
        totalStudents: totalStudents,
        presentToday: presentCount,
        absentToday: absentCount,
        mealsToday: mealsToday,
        staffPresent: staffPresent,
        staffTotal: staffSnap.docs.length,
        leavePending: leaveSnap.docs.length,
        attendanceRate: rate,
      );
    } catch (_) {
      return const DashboardStats();
    }
  }
}
