import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../core/utils/academic_year_utils.dart';
import '../models/app_models.dart';

class FirestoreService {
  static const List<String> defaultMenuItems = [
    'Rice & Dal',
    'Khichdi',
    'Poha',
    'Upma',
    'Special',
  ];

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

  String _dateKey([DateTime? date]) =>
      DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());

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

  Future<List<ClassModel>> getClassesForSchool(String schoolId) async {
    if (!_isFirebaseInitialized) return [];
    final classesSnapshot = await _db
        .collection('classes')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    final classes = classesSnapshot.docs
        .map(ClassModel.fromFirestore)
        .toList()
      ..sort((a, b) => a.className.compareTo(b.className));

    if (classes.isNotEmpty) {
      return classes;
    }

    final studentsSnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .where(
          'academicYear',
          isEqualTo: AcademicYearUtils.currentAcademicYear(),
        )
        .where('approvalStatus', isEqualTo: 'approved')
        .get();

    final classIds = studentsSnapshot.docs
        .map((doc) => (doc.data()['classId'] as String?) ?? '')
        .where((classId) => classId.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return classIds
        .map(
          (classId) => ClassModel(
            classId: classId,
            className: classId,
            schoolId: schoolId,
            totalStudents: studentsSnapshot.docs
                .where((doc) => doc.data()['classId'] == classId)
                .length,
          ),
        )
        .toList();
  }

  Future<DailyMealModel?> getDailyMeal(
    String schoolId, {
    DateTime? date,
  }) async {
    if (!_isFirebaseInitialized) return null;
    final dateKey = _dateKey(date);
    final doc = await _db.collection('dailyMeal').doc('${schoolId}_$dateKey').get();
    if (!doc.exists) return null;
    return DailyMealModel.fromFirestore(doc);
  }

  Future<void> setDailyMeal({
    required String schoolId,
    required String menuItem,
    required String notes,
    required String setBy,
    DateTime? date,
  }) async {
    if (!_isFirebaseInitialized) return;
    final selectedDate = date ?? DateTime.now();
    final dateKey = _dateKey(selectedDate);
    await _db.collection('dailyMeal').doc('${schoolId}_$dateKey').set(
      {
        'schoolId': schoolId,
        'date': dateKey,
        'menuItem': menuItem,
        'notes': notes,
        'setBy': setBy,
        'setAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ─── Students ────────────────────────────────────────────────
  Stream<List<StudentModel>> studentsStream(String schoolId, {String? classId}) {
    return studentsStreamWithOptions(
      schoolId,
      classId: classId,
    );
  }

  Stream<List<StudentModel>> studentsStreamWithOptions(
    String schoolId, {
    String? classId,
    bool includePending = false,
    String? academicYear,
  }) {
    if (!_isFirebaseInitialized) return Stream.value([]);
    Query query = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('isActive', isEqualTo: true);
    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }
    final year = academicYear ?? AcademicYearUtils.currentAcademicYear();
    query = query.where('academicYear', isEqualTo: year);
    if (!includePending) {
      query = query.where('approvalStatus', isEqualTo: 'approved');
    }
    return query.snapshots().map(
      (snap) {
        final students = snap.docs.map(StudentModel.fromFirestore).toList()
          ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
        return students;
      },
    );
  }

  Future<void> addStudent(String schoolId, StudentModel student) async {
    if (!_isFirebaseInitialized) return;
    final docRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(student.studentId);
    final existing = await docRef.get();
    await docRef.set(student.toFirestore(), SetOptions(merge: true));
    if (!existing.exists) {
      await _db.collection('schools').doc(schoolId).set({
        'totalStudents': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
  }

  Future<List<StudentModel>> getActiveStudentsForClass(
    String schoolId,
    String classId,
  ) async {
    if (!_isFirebaseInitialized) return [];
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .where(
          'academicYear',
          isEqualTo: AcademicYearUtils.currentAcademicYear(),
        )
        .where('approvalStatus', isEqualTo: 'approved')
        .get();

    final students = snap.docs.map(StudentModel.fromFirestore).toList()
      ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
    return students;
  }

  Future<void> saveStudentRemark(
    String schoolId,
    String studentId,
    String remark,
  ) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .set(
      {
        'teacherRemark': remark,
        'remarkUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, int>> getStudentAttendanceBreakdown({
    required String schoolId,
    required String classId,
    required String studentId,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!_isFirebaseInitialized) {
      return {'P': 0, 'A': 0, 'L': 0};
    }

    final start = from ?? AcademicYearUtils.academicYearStart();
    final end = to ?? DateTime.now();

    final snapshot = await _db
        .collection('attendance')
        .where('schoolId', isEqualTo: schoolId)
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: _dateKey(start))
        .where('date', isLessThanOrEqualTo: _dateKey(end))
        .get();

    final counts = {'P': 0, 'A': 0, 'L': 0};
    for (final doc in snapshot.docs) {
      final record = AttendanceRecordModel.fromFirestore(doc);
      final status = record.records[studentId];
      if (status != null && counts.containsKey(status)) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<List<String>> getActiveClassIds(String schoolId) async {
    if (!_isFirebaseInitialized) return [];
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .where('academicYear',
            isEqualTo: AcademicYearUtils.currentAcademicYear())
        .where('approvalStatus', isEqualTo: 'approved')
        .get();

    final classIds = snap.docs
        .map((doc) => (doc.data()['classId'] as String?) ?? '')
        .where((classId) => classId.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return classIds;
  }

  Future<void> updateStudent(String schoolId, String studentId, Map<String, dynamic> data) async {
    if (!_isFirebaseInitialized) return;
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> submitStudentForApproval(
    String schoolId,
    StudentModel student,
  ) async {
    if (!_isFirebaseInitialized) return;
    await addStudent(
      schoolId,
      StudentModel(
        studentId: student.studentId,
        fullName: student.fullName,
        rollNo: student.rollNo,
        srn: student.srn,
        classId: student.classId,
        gender: student.gender,
        dob: student.dob,
        isActive: true,
        academicYear: student.academicYear.isEmpty
            ? AcademicYearUtils.currentAcademicYear()
            : student.academicYear,
        approvalStatus: 'pending',
        submittedByUid: student.submittedByUid.isEmpty ? _uid : student.submittedByUid,
      ),
    );
  }

  Future<List<StudentModel>> getPendingStudents(
    String schoolId, {
    String? classId,
  }) async {
    if (!_isFirebaseInitialized) return [];
    Query query = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .where('academicYear',
            isEqualTo: AcademicYearUtils.currentAcademicYear())
        .where('approvalStatus', isEqualTo: 'pending');
    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }
    final snap = await query.get();
    final students = snap.docs.map(StudentModel.fromFirestore).toList()
      ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
    return students;
  }

  Future<void> approveStudents(
    String schoolId,
    List<String> studentIds, {
    required String approvedByUid,
  }) async {
    if (!_isFirebaseInitialized || studentIds.isEmpty) return;
    final batch = _db.batch();
    final studentsRef =
        _db.collection('schools').doc(schoolId).collection('students');
    for (final studentId in studentIds) {
      batch.set(
        studentsRef.doc(studentId),
        {
          'approvalStatus': 'approved',
          'approvedByUid': approvedByUid,
          'approvedAt': FieldValue.serverTimestamp(),
          'academicYear': AcademicYearUtils.currentAcademicYear(),
          'isActive': true,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> resetAcademicYearRoster(
    String schoolId, {
    required String archivedByUid,
  }) async {
    if (!_isFirebaseInitialized) return;
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('academicYear',
            isEqualTo: AcademicYearUtils.currentAcademicYear())
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.set(
        doc.reference,
        {
          'isActive': false,
          'approvalStatus': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedByUid': archivedByUid,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    await _db.collection('schools').doc(schoolId).set({
      'totalStudents': 0,
      'academicYear': AcademicYearUtils.currentAcademicYear(),
    }, SetOptions(merge: true));
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
    final hasIncompleteAttendance = students.any((student) => student.status == null);
    if (hasIncompleteAttendance) {
      throw ArgumentError('Attendance is incomplete for one or more students.');
    }

    final dateKey = _today;
    final batch = _db.batch();
    final dayRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(dateKey);
    final classRef = dayRef.collection('classes').doc(classId);
    final attendanceRef = _db.collection('attendance').doc('${classId}_$dateKey');
    final presentCount = students
        .where((student) => student.status == AttendanceStatus.present)
        .length;
    final absentCount = students
        .where((student) => student.status == AttendanceStatus.absent)
        .length;
    final leaveCount = students
        .where((student) => student.status == AttendanceStatus.leave)
        .length;
    final records = {
      for (final student in students)
        student.studentId: switch (student.status!) {
          AttendanceStatus.present => 'P',
          AttendanceStatus.absent => 'A',
          AttendanceStatus.leave => 'L',
        },
    };

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
    batch.set(
      classRef,
      {
        'classId': classId,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'presentCount': presentCount,
        'absentCount': absentCount,
        'leaveCount': leaveCount,
      },
      SetOptions(merge: true),
    );
    batch.set(
      attendanceRef,
      {
        'classId': classId,
        'schoolId': schoolId,
        'date': dateKey,
        'markedBy': submittedBy,
        'markedAt': FieldValue.serverTimestamp(),
        'isSubmitted': true,
        'records': records,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'leaveCount': leaveCount,
        'editHistory': const [],
      },
      SetOptions(merge: true),
    );

    for (final s in students) {
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

  Future<AttendanceRecordModel?> getAttendanceRecord(
    String schoolId,
    String classId, {
    DateTime? date,
  }) async {
    if (!_isFirebaseInitialized) return null;
    final dateKey = _dateKey(date);
    final doc = await _db.collection('attendance').doc('${classId}_$dateKey').get();
    if (doc.exists) {
      return AttendanceRecordModel.fromFirestore(doc);
    }

    final nestedEntries = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(dateKey)
        .collection('entries')
        .where('classId', isEqualTo: classId)
        .get();

    if (nestedEntries.docs.isEmpty) return null;

    final records = <String, String>{};
    for (final entry in nestedEntries.docs) {
      final data = entry.data();
      final status = data['status'] as String? ?? 'present';
      records[(data['studentId'] as String?) ?? entry.id] = switch (status) {
        'absent' => 'A',
        'leave' => 'L',
        _ => 'P',
      };
    }

    return AttendanceRecordModel(
      id: '${classId}_$dateKey',
      classId: classId,
      schoolId: schoolId,
      date: dateKey,
      markedBy: '',
      markedAt: DateTime.now(),
      isSubmitted: true,
      records: records,
    );
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecordsForRange({
    required String schoolId,
    required DateTime from,
    required DateTime to,
    String? classId,
  }) async {
    if (!_isFirebaseInitialized) return [];
    Query<Map<String, dynamic>> query = _db
        .collection('attendance')
        .where('schoolId', isEqualTo: schoolId)
        .where('date', isGreaterThanOrEqualTo: _dateKey(from))
        .where('date', isLessThanOrEqualTo: _dateKey(to));
    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }

    final snapshot = await query.get();
    final records = snapshot.docs
        .map<AttendanceRecordModel>(AttendanceRecordModel.fromFirestore)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  Future<List<AttendanceRecordModel>> getRecentAttendanceRecords(
    String schoolId, {
    int limit = 10,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final snapshot = await _db
        .collection('attendance')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('markedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map<AttendanceRecordModel>(AttendanceRecordModel.fromFirestore)
        .toList();
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

  Future<Map<String, int>> getDailyAttendancePresentCounts(
    String schoolId,
    String classId, {
    int days = 7,
  }) async {
    if (!_isFirebaseInitialized) return {};
    final counts = <String, int>{};

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('attendance')
          .doc(dateKey)
          .collection('entries')
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'present')
          .get();
      counts[dateKey] = snap.docs.length;
    }

    return counts;
  }

  Future<bool> hasAttendanceForToday(String schoolId, String classId) async {
    if (!_isFirebaseInitialized) return false;
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(_today)
        .collection('entries')
        .where('classId', isEqualTo: classId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<List<MdmClassRecord>> getMdmRecordsForClassRange(
    String schoolId,
    String classId, {
    int days = 7,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final records = <MdmClassRecord>[];

    for (int i = days - 1; i >= 0; i--) {
      final dateKey = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: i)));
      final doc = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('mdm')
          .doc(dateKey)
          .collection('classes')
          .doc(classId)
          .get();
      if (doc.exists) {
        records.add(MdmClassRecord.fromFirestore(doc));
      }
    }

    return records;
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

    final total = entries.fold(0, (totalMeals, e) => totalMeals + e.mealCount);

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

  Future<void> saveMealRecord({
    required String classId,
    required String schoolId,
    required int mealCount,
    required String menuItem,
    required int presentCount,
    required String markedBy,
    String notes = '',
    String photoUrl = '',
    DateTime? date,
  }) async {
    if (!_isFirebaseInitialized) return;
    final dateKey = _dateKey(date);
    await _db.collection('mealRecords').doc('${classId}_$dateKey').set(
      {
        'classId': classId,
        'schoolId': schoolId,
        'date': dateKey,
        'mealCount': mealCount,
        'menuItem': menuItem,
        'presentCount': presentCount,
        'discrepancy': mealCount > presentCount,
        'photoUrl': photoUrl,
        'notes': notes,
        'markedBy': markedBy,
        'markedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await saveTeacherMdmEntry(
      schoolId: schoolId,
      classId: classId,
      className: classId,
      mealCount: mealCount,
      presentCount: presentCount,
      menu: menuItem,
      notes: notes,
      submittedBy: markedBy,
      photoUrl: photoUrl,
    );
  }

  Future<MealRecordModel?> getMealRecordForClass(
    String schoolId,
    String classId, {
    DateTime? date,
  }) async {
    if (!_isFirebaseInitialized) return null;
    final dateKey = _dateKey(date);
    final doc = await _db.collection('mealRecords').doc('${classId}_$dateKey').get();
    if (doc.exists) {
      return MealRecordModel.fromFirestore(doc);
    }

    final nested = await getTodayMdmRecordForClass(schoolId, classId);
    if (nested == null) return null;
    return MealRecordModel(
      id: '${classId}_$dateKey',
      classId: nested.classId,
      schoolId: schoolId,
      date: dateKey,
      mealCount: nested.mealCount,
      menuItem: nested.menu,
      presentCount: nested.presentCount,
      discrepancy: nested.discrepancy,
      markedBy: nested.submittedBy,
      markedAt: nested.submittedAt,
      notes: nested.notes,
      photoUrl: nested.photoUrl,
    );
  }

  Future<List<MealRecordModel>> getMealRecordsForDate({
    required String schoolId,
    required DateTime date,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final snapshot = await _db
        .collection('mealRecords')
        .where('schoolId', isEqualTo: schoolId)
        .where('date', isEqualTo: _dateKey(date))
        .get();
    return snapshot.docs.map(MealRecordModel.fromFirestore).toList();
  }

  Future<List<MealRecordModel>> getMealRecordsForRange({
    required String schoolId,
    required DateTime from,
    required DateTime to,
    String? classId,
  }) async {
    if (!_isFirebaseInitialized) return [];
    Query<Map<String, dynamic>> query = _db
        .collection('mealRecords')
        .where('schoolId', isEqualTo: schoolId)
        .where('date', isGreaterThanOrEqualTo: _dateKey(from))
        .where('date', isLessThanOrEqualTo: _dateKey(to));
    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }
    final snapshot = await query.get();
    final records = snapshot.docs.map(MealRecordModel.fromFirestore).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  Future<List<MealRecordModel>> getRecentMealRecords(
    String schoolId, {
    int limit = 10,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final snapshot = await _db
        .collection('mealRecords')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('markedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(MealRecordModel.fromFirestore).toList();
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

  Future<int> getActiveStudentCountForClass(String schoolId, String classId) async {
    if (!_isFirebaseInitialized) return 0;
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .where('academicYear',
            isEqualTo: AcademicYearUtils.currentAcademicYear())
        .where('approvalStatus', isEqualTo: 'approved')
        .get();
    return snap.docs.length;
  }

  Future<int> getTodayPresentCountForClass(String schoolId, String classId) async {
    if (!_isFirebaseInitialized) return 0;
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc(_today)
        .collection('entries')
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: 'present')
        .get();
    return snap.docs.length;
  }

  Future<List<AttendanceClassSummary>> getAttendanceSummariesForRange(
    String schoolId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final summaries = <AttendanceClassSummary>[];
    final dayCount = to.difference(from).inDays;

    for (int i = 0; i <= dayCount; i++) {
      final dateKey =
          DateFormat('yyyy-MM-dd').format(from.add(Duration(days: i)));
      final snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('attendance')
          .doc(dateKey)
          .collection('classes')
          .get();
      summaries.addAll(snap.docs.map(AttendanceClassSummary.fromFirestore));
    }

    return summaries;
  }

  Future<List<AttendanceClassSummary>> getRecentAttendanceSummaries(
    String schoolId, {
    int days = 7,
  }) async {
    final from = DateTime.now().subtract(Duration(days: days - 1));
    final to = DateTime.now();
    return getAttendanceSummariesForRange(
      schoolId,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
    );
  }

  Future<MdmClassRecord?> getTodayMdmRecordForClass(
    String schoolId,
    String classId,
  ) async {
    if (!_isFirebaseInitialized) return null;
    final doc = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('mdm')
        .doc(_today)
        .collection('classes')
        .doc(classId)
        .get();

    if (!doc.exists) return null;
    return MdmClassRecord.fromFirestore(doc);
  }

  Future<void> saveTeacherMdmEntry({
    required String schoolId,
    required String classId,
    required String className,
    required int mealCount,
    required int presentCount,
    required String menu,
    required String notes,
    required String submittedBy,
    String photoUrl = '',
  }) async {
    if (!_isFirebaseInitialized) return;
    final dayRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('mdm')
        .doc(_today);
    final classRef = dayRef.collection('classes').doc(classId);

    final existingEntries = await dayRef.collection('classes').get();
    final otherMealsTotal = existingEntries.docs.fold<int>(0, (totalMeals, doc) {
      if (doc.id == classId) {
        return totalMeals;
      }
      return totalMeals + ((doc.data()['mealCount'] as num?)?.toInt() ?? 0);
    });

    final batch = _db.batch();
    batch.set(
      dayRef,
      {
        'date': Timestamp.fromDate(DateTime.now()),
        'schoolId': schoolId,
        'totalMeals': otherMealsTotal + mealCount,
        'submittedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      classRef,
      {
        'classId': classId,
        'className': className,
        'mealCount': mealCount,
        'presentCount': presentCount,
        'menu': menu,
        'notes': notes,
        'photoUrl': photoUrl,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'discrepancy': mealCount > presentCount,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<List<MdmClassRecord>> getTodayMdmClassRecords(String schoolId) async {
    if (!_isFirebaseInitialized) return [];
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('mdm')
        .doc(_today)
        .collection('classes')
        .get();

    return snap.docs.map(MdmClassRecord.fromFirestore).toList();
  }

  Future<List<MdmClassRecord>> getRecentMdmClassRecords(
    String schoolId, {
    int days = 7,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final records = <MdmClassRecord>[];

    for (int i = days - 1; i >= 0; i--) {
      final dateKey = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: i)));
      final snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('mdm')
          .doc(dateKey)
          .collection('classes')
          .get();
      records.addAll(snap.docs.map(MdmClassRecord.fromFirestore));
    }

    return records;
  }

  Future<List<MdmClassRecord>> getMdmRecordsForRange(
    String schoolId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isFirebaseInitialized) return [];
    final records = <MdmClassRecord>[];
    final dayCount = to.difference(from).inDays;

    for (int i = 0; i <= dayCount; i++) {
      final dateKey =
          DateFormat('yyyy-MM-dd').format(from.add(Duration(days: i)));
      final snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('mdm')
          .doc(dateKey)
          .collection('classes')
          .get();
      records.addAll(snap.docs.map(MdmClassRecord.fromFirestore));
    }

    return records;
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
        .set({
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<int> getPendingLeaveRequestsCount(String schoolId) async {
    if (!_isFirebaseInitialized) return 0;
    final snapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('leave_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.length;
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
        .set({
      'uniformReceived': uniformReceived,
      'shoesReceived': shoesReceived,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncDistributionRecords(
    String schoolId,
    String year,
    String classId,
    List<DistributionStudentModel> students,
  ) async {
    if (!_isFirebaseInitialized) return;
    final batch = _db.batch();
    final distributionsRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('inventory')
        .doc(year)
        .collection('distributions');

    for (final student in students) {
      final docRef = distributionsRef.doc(student.studentId);
      batch.set(docRef, {
        ...student.toFirestore(),
        'classId': classId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<List<DistributionStudentModel>> getDistributionRoster(
    String schoolId,
    String year, {
    String? classId,
  }) async {
    if (!_isFirebaseInitialized) return [];
    Query studentQuery = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .where('academicYear',
            isEqualTo: AcademicYearUtils.currentAcademicYear())
        .where('approvalStatus', isEqualTo: 'approved');
    if (classId != null && classId.isNotEmpty) {
      studentQuery = studentQuery.where('classId', isEqualTo: classId);
    }

    final studentsSnap = await studentQuery.get();
    final distSnap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('inventory')
        .doc(year)
        .collection('distributions')
        .get();

    final distByStudent = {
      for (final doc in distSnap.docs)
        doc.id: DistributionStudentModel.fromFirestore(doc),
    };

    final roster = studentsSnap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final existing = distByStudent[doc.id];
      return DistributionStudentModel(
        studentId: doc.id,
        fullName: data['fullName'] ?? '',
        rollNo: data['rollNo'] ?? 0,
        srn: data['srn'] ?? '',
        uniformReceived: existing?.uniformReceived ?? false,
        shoesReceived: existing?.shoesReceived ?? false,
        uniformSize: existing?.uniformSize ?? 'M',
        shoesSize: existing?.shoesSize ?? '7',
      );
    }).toList()
      ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
    return roster;
  }

  Future<Map<String, int>> getInventorySummary(
    String schoolId,
    String year, {
    String? classId,
  }) async {
    final roster = await getDistributionRoster(
      schoolId,
      year,
      classId: classId,
    );
    final uniformReceived =
        roster.where((student) => student.uniformReceived).length;
    final shoesReceived =
        roster.where((student) => student.shoesReceived).length;
    return {
      'uniformReceived': uniformReceived,
      'shoesReceived': shoesReceived,
      'totalStudents': roster.length,
    };
  }

  // ─── Dashboard Stats ──────────────────────────────────────────
  Future<DashboardStats> getDashboardStats(String schoolId) async {
    if (!_isFirebaseInitialized) return const DashboardStats();
    try {
      final currentRoster = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('isActive', isEqualTo: true)
          .where('academicYear',
              isEqualTo: AcademicYearUtils.currentAcademicYear())
          .where('approvalStatus', isEqualTo: 'approved')
          .get();
      final totalStudents = currentRoster.docs.length;

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
