// ============================================================
// ShikshaSetu — Complete App Models with Firestore serialization
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/academic_year_utils.dart';

// ─── Role ────────────────────────────────────────────────────
enum UserRole { admin, teacher }

extension UserRoleExt on UserRole {
  String get name => this == UserRole.admin ? 'admin' : 'teacher';
  static UserRole fromString(String s) =>
      s == 'admin' ? UserRole.admin : UserRole.teacher;
}

// ─── App User ────────────────────────────────────────────────
class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String schoolId;
  final String schoolName;
  final String? assignedClassId;     // teacher only
  final String? photoUrl;
  final bool emailVerified;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.schoolId,
    required this.schoolName,
    this.assignedClassId,
    this.photoUrl,
    this.emailVerified = false,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      fullName: d['fullName'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      role: UserRoleExt.fromString(d['role'] ?? 'teacher'),
      schoolId: d['schoolId'] ?? '',
      schoolName: d['schoolName'] ?? '',
      assignedClassId: d['assignedClassId'],
      photoUrl: d['photoUrl'],
      emailVerified: d['emailVerified'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'role': role.name,
    'schoolId': schoolId,
    'schoolName': schoolName,
    if (assignedClassId != null) 'assignedClassId': assignedClassId,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'emailVerified': emailVerified,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  AppUser copyWith({String? fullName, String? phone, String? photoUrl, String? assignedClassId}) =>
      AppUser(
        uid: uid,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
        role: role,
        schoolId: schoolId,
        schoolName: schoolName,
        assignedClassId: assignedClassId ?? this.assignedClassId,
        photoUrl: photoUrl ?? this.photoUrl,
        emailVerified: emailVerified,
        createdAt: createdAt,
      );
}

// ─── School ───────────────────────────────────────────────────
class SchoolModel {
  final String schoolId;
  final String name;
  final String district;
  final String block;
  final String address;
  final String schoolCode;
  final int totalStudents;
  final int totalStaff;
  final String academicYear;
  final List<String> menuItems;

  const SchoolModel({
    required this.schoolId,
    required this.name,
    required this.district,
    required this.block,
    required this.address,
    required this.schoolCode,
    this.totalStudents = 0,
    this.totalStaff = 0,
    this.academicYear = '',
    this.menuItems = const [],
  });

  factory SchoolModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SchoolModel(
      schoolId: doc.id,
      name: d['name'] ?? '',
      district: d['district'] ?? '',
      block: d['block'] ?? '',
      address: d['address'] ?? '',
      schoolCode: d['schoolCode'] ?? '',
      totalStudents: d['totalStudents'] ?? 0,
      totalStaff: d['totalStaff'] ?? 0,
      academicYear:
          d['academicYear'] ?? AcademicYearUtils.currentAcademicYear(),
      menuItems: (d['menuItems'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'district': district,
    'block': block,
    'address': address,
    'schoolCode': schoolCode,
    'totalStudents': totalStudents,
    'totalStaff': totalStaff,
    'academicYear': academicYear.isEmpty
        ? AcademicYearUtils.currentAcademicYear()
        : academicYear,
    'menuItems': menuItems,
  };
}

class ClassModel {
  final String classId;
  final String className;
  final String schoolId;
  final String assignedTeacherUid;
  final int totalStudents;
  final String section;

  const ClassModel({
    required this.classId,
    required this.className,
    required this.schoolId,
    this.assignedTeacherUid = '',
    this.totalStudents = 0,
    this.section = '',
  });

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClassModel(
      classId: d['classId'] ?? doc.id,
      className: d['className'] ?? doc.id,
      schoolId: d['schoolId'] ?? '',
      assignedTeacherUid: d['assignedTeacherUid'] ?? '',
      totalStudents: d['totalStudents'] ?? 0,
      section: d['section'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'classId': classId,
        'className': className,
        'schoolId': schoolId,
        'assignedTeacherUid': assignedTeacherUid,
        'totalStudents': totalStudents,
        'section': section,
      };
}

class DailyMealModel {
  final String id;
  final String schoolId;
  final String date;
  final String menuItem;
  final String notes;
  final String setBy;
  final DateTime setAt;

  const DailyMealModel({
    required this.id,
    required this.schoolId,
    required this.date,
    required this.menuItem,
    required this.notes,
    required this.setBy,
    required this.setAt,
  });

  factory DailyMealModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DailyMealModel(
      id: doc.id,
      schoolId: d['schoolId'] ?? '',
      date: d['date'] ?? '',
      menuItem: d['menuItem'] ?? '',
      notes: d['notes'] ?? '',
      setBy: d['setBy'] ?? '',
      setAt: (d['setAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'date': date,
        'menuItem': menuItem,
        'notes': notes,
        'setBy': setBy,
        'setAt': Timestamp.fromDate(setAt),
      };
}

// ─── Student ──────────────────────────────────────────────────
class StudentModel {
  final String studentId;
  final String fullName;
  final int rollNo;
  final String srn;
  final String classId;
  final String gender;
  final String dob;
  final bool isActive;
  final String academicYear;
  final String approvalStatus;
  final String submittedByUid;
  final String approvedByUid;
  final DateTime? approvedAt;
  AttendanceStatus? status;
  bool hasConsecutiveAbsences;

  StudentModel({
    required this.studentId,
    required this.fullName,
    required this.rollNo,
    required this.srn,
    required this.classId,
    this.gender = 'male',
    this.dob = '',
    this.isActive = true,
    this.academicYear = '',
    this.approvalStatus = 'approved',
    this.submittedByUid = '',
    this.approvedByUid = '',
    this.approvedAt,
    this.status,
    this.hasConsecutiveAbsences = false,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StudentModel(
      studentId: doc.id,
      fullName: d['fullName'] ?? '',
      rollNo: d['rollNo'] ?? 0,
      srn: d['srn'] ?? '',
      classId: d['classId'] ?? '',
      gender: d['gender'] ?? 'male',
      dob: d['dob'] ?? '',
      isActive: d['isActive'] ?? true,
      academicYear:
          d['academicYear'] ?? AcademicYearUtils.currentAcademicYear(),
      approvalStatus: d['approvalStatus'] ?? 'approved',
      submittedByUid: d['submittedByUid'] ?? '',
      approvedByUid: d['approvedByUid'] ?? '',
      approvedAt: (d['approvedAt'] as Timestamp?)?.toDate(),
      hasConsecutiveAbsences: d['hasConsecutiveAbsences'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName,
    'rollNo': rollNo,
    'srn': srn,
    'classId': classId,
    'gender': gender,
    'dob': dob,
    'isActive': isActive,
    'academicYear': academicYear.isEmpty
        ? AcademicYearUtils.currentAcademicYear()
        : academicYear,
    'approvalStatus': approvalStatus,
    'submittedByUid': submittedByUid,
    'approvedByUid': approvedByUid,
    if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
  };
}

enum AttendanceStatus { present, absent, leave }

// ─── Attendance Entry ─────────────────────────────────────────
class AttendanceEntry {
  final String studentId;
  final String studentName;
  final AttendanceStatus status;
  final String classId;
  final String submittedBy;
  final DateTime timestamp;
  final bool isLocked;

  const AttendanceEntry({
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.classId,
    required this.submittedBy,
    required this.timestamp,
    this.isLocked = false,
  });

  factory AttendanceEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceEntry(
      studentId: d['studentId'] ?? doc.id,
      studentName: d['studentName'] ?? '',
      status: _statusFromString(d['status']),
      classId: d['classId'] ?? '',
      submittedBy: d['submittedBy'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLocked: d['isLocked'] ?? false,
    );
  }

  static AttendanceStatus _statusFromString(String? s) {
    switch (s) {
      case 'absent': return AttendanceStatus.absent;
      case 'leave': return AttendanceStatus.leave;
      default: return AttendanceStatus.present;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'studentName': studentName,
    'status': status.name,
    'classId': classId,
    'submittedBy': submittedBy,
    'timestamp': Timestamp.fromDate(timestamp),
    'isLocked': isLocked,
  };
}

class AttendanceClassSummary {
  final String classId;
  final String submittedBy;
  final DateTime submittedAt;
  final int presentCount;
  final int absentCount;
  final int leaveCount;

  const AttendanceClassSummary({
    required this.classId,
    required this.submittedBy,
    required this.submittedAt,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
  });

  int get totalCount => presentCount + absentCount + leaveCount;

  factory AttendanceClassSummary.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceClassSummary(
      classId: d['classId'] ?? doc.id,
      submittedBy: d['submittedBy'] ?? '',
      submittedAt:
          (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      presentCount: d['presentCount'] ?? 0,
      absentCount: d['absentCount'] ?? 0,
      leaveCount: d['leaveCount'] ?? 0,
    );
  }
}

class AttendanceRecordModel {
  final String id;
  final String classId;
  final String schoolId;
  final String date;
  final String markedBy;
  final DateTime markedAt;
  final bool isSubmitted;
  final Map<String, String> records;
  final List<Map<String, dynamic>> editHistory;

  const AttendanceRecordModel({
    required this.id,
    required this.classId,
    required this.schoolId,
    required this.date,
    required this.markedBy,
    required this.markedAt,
    required this.isSubmitted,
    required this.records,
    this.editHistory = const [],
  });

  factory AttendanceRecordModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceRecordModel(
      id: doc.id,
      classId: d['classId'] ?? '',
      schoolId: d['schoolId'] ?? '',
      date: d['date'] ?? '',
      markedBy: d['markedBy'] ?? '',
      markedAt: (d['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSubmitted: d['isSubmitted'] ?? false,
      records: (d['records'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      editHistory: ((d['editHistory'] as List<dynamic>?) ?? const [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(),
    );
  }

  int get presentCount => records.values.where((value) => value == 'P').length;
  int get absentCount => records.values.where((value) => value == 'A').length;
  int get leaveCount => records.values.where((value) => value == 'L').length;
  int get totalCount => records.length;
}

// ─── Staff ────────────────────────────────────────────────────
class StaffModel {
  final String teacherId;
  final String name;
  final String subject;
  final String grade;
  final StaffStatus status;
  final String? photoUrl;
  final String phone;
  final String email;
  final String assignedClassId;
  final DateTime? lastAttendanceDate;

  const StaffModel({
    required this.teacherId,
    required this.name,
    required this.subject,
    required this.grade,
    required this.status,
    this.photoUrl,
    this.phone = '',
    this.email = '',
    this.assignedClassId = '',
    this.lastAttendanceDate,
  });

  factory StaffModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StaffModel(
      teacherId: doc.id,
      name: d['fullName'] ?? '',
      subject: d['subject'] ?? '',
      grade: d['grade'] ?? '',
      status: _statusFromString(d['todayStatus']),
      photoUrl: d['photoUrl'],
      phone: d['phone'] ?? '',
      email: d['email'] ?? '',
      assignedClassId: d['assignedClassId'] ?? d['classId'] ?? '',
      lastAttendanceDate: (d['lastAttendanceDate'] as Timestamp?)?.toDate(),
    );
  }

  static StaffStatus _statusFromString(String? s) {
    switch (s) {
      case 'leave': return StaffStatus.leave;
      case 'duty': return StaffStatus.duty;
      case 'absent': return StaffStatus.absent;
      default: return StaffStatus.present;
    }
  }
}

enum StaffStatus { present, leave, duty, absent }

class TeacherAttendanceRecord {
  final String id;
  final String teacherId;
  final String teacherName;
  final String schoolId;
  final String classId;
  final String date;
  final String status;
  final DateTime markedAt;

  const TeacherAttendanceRecord({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.schoolId,
    required this.classId,
    required this.date,
    required this.status,
    required this.markedAt,
  });

  factory TeacherAttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TeacherAttendanceRecord(
      id: doc.id,
      teacherId: d['teacherId'] ?? '',
      teacherName: d['teacherName'] ?? '',
      schoolId: d['schoolId'] ?? '',
      classId: d['classId'] ?? '',
      date: d['date'] ?? '',
      status: d['status'] ?? 'present',
      markedAt: (d['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── Leave Request ────────────────────────────────────────────
class LeaveRequestModel {
  final String requestId;
  final String teacherId;
  final String teacherName;
  final String leaveType;
  final String reason;
  final String fromDate;
  final String toDate;
  LeaveRequestStatus status;
  final DateTime createdAt;

  LeaveRequestModel({
    required this.requestId,
    required this.teacherId,
    required this.teacherName,
    required this.leaveType,
    required this.reason,
    this.fromDate = '',
    this.toDate = '',
    this.status = LeaveRequestStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory LeaveRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel(
      requestId: doc.id,
      teacherId: d['teacherId'] ?? '',
      teacherName: d['teacherName'] ?? '',
      leaveType: d['leaveType'] ?? '',
      reason: d['reason'] ?? '',
      fromDate: d['fromDate'] ?? '',
      toDate: d['toDate'] ?? '',
      status: _statusFromString(d['status']),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static LeaveRequestStatus _statusFromString(String? s) {
    switch (s) {
      case 'approved': return LeaveRequestStatus.approved;
      case 'rejected': return LeaveRequestStatus.rejected;
      default: return LeaveRequestStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'teacherId': teacherId,
    'teacherName': teacherName,
    'leaveType': leaveType,
    'reason': reason,
    'fromDate': fromDate,
    'toDate': toDate,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

enum LeaveRequestStatus { pending, approved, rejected }

// ─── MDM Entry ────────────────────────────────────────────────
class MdmDayEntry {
  final String id;
  final String schoolId;
  final String classId;
  final String className;
  final int mealCount;
  final int enrolledCount;
  final String menu;
  final String notes;
  final String submittedBy;
  final DateTime date;
  final bool isVerified;

  const MdmDayEntry({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.mealCount,
    this.enrolledCount = 0,
    this.menu = '',
    this.notes = '',
    required this.submittedBy,
    required this.date,
    this.isVerified = false,
  });

  factory MdmDayEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MdmDayEntry(
      id: doc.id,
      schoolId: d['schoolId'] ?? '',
      classId: d['classId'] ?? '',
      className: d['className'] ?? '',
      mealCount: d['mealCount'] ?? 0,
      enrolledCount: d['enrolledCount'] ?? 0,
      menu: d['menu'] ?? '',
      notes: d['notes'] ?? '',
      submittedBy: d['submittedBy'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: d['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId,
    'classId': classId,
    'className': className,
    'mealCount': mealCount,
    'enrolledCount': enrolledCount,
    'menu': menu,
    'notes': notes,
    'submittedBy': submittedBy,
    'date': Timestamp.fromDate(date),
    'isVerified': isVerified,
  };
}

// ─── Legacy helper classes (kept for UI compatibility) ────────
class MdmClassEntry {
  final String classId;
  final String className;
  int mealCount;
  MdmClassEntry({required this.classId, required this.className, this.mealCount = 0});
}

class MdmClassRecord {
  final String classId;
  final String className;
  final int mealCount;
  final int presentCount;
  final String menu;
  final String notes;
  final String submittedBy;
  final DateTime submittedAt;
  final bool discrepancy;
  final String photoUrl;

  const MdmClassRecord({
    required this.classId,
    required this.className,
    required this.mealCount,
    required this.presentCount,
    required this.menu,
    required this.notes,
    required this.submittedBy,
    required this.submittedAt,
    required this.discrepancy,
    this.photoUrl = '',
  });

  factory MdmClassRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MdmClassRecord(
      classId: d['classId'] ?? doc.id,
      className: d['className'] ?? '',
      mealCount: d['mealCount'] ?? 0,
      presentCount: d['presentCount'] ?? 0,
      menu: d['menu'] ?? '',
      notes: d['notes'] ?? '',
      submittedBy: d['submittedBy'] ?? '',
      submittedAt:
          (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      discrepancy: d['discrepancy'] ?? false,
      photoUrl: d['photoUrl'] ?? '',
    );
  }
}

class MealRecordModel {
  final String id;
  final String classId;
  final String schoolId;
  final String date;
  final int mealCount;
  final String menuItem;
  final int presentCount;
  final bool discrepancy;
  final String markedBy;
  final DateTime markedAt;
  final String notes;
  final String photoUrl;

  const MealRecordModel({
    required this.id,
    required this.classId,
    required this.schoolId,
    required this.date,
    required this.mealCount,
    required this.menuItem,
    required this.presentCount,
    required this.discrepancy,
    required this.markedBy,
    required this.markedAt,
    this.notes = '',
    this.photoUrl = '',
  });

  factory MealRecordModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MealRecordModel(
      id: doc.id,
      classId: d['classId'] ?? '',
      schoolId: d['schoolId'] ?? '',
      date: d['date'] ?? '',
      mealCount: (d['mealCount'] as num?)?.toInt() ?? 0,
      menuItem: d['menuItem'] ?? '',
      presentCount: (d['presentCount'] as num?)?.toInt() ?? 0,
      discrepancy: d['discrepancy'] ?? false,
      markedBy: d['markedBy'] ?? '',
      markedAt: (d['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
    );
  }
}

// ─── Student Ledger (admin view) ──────────────────────────────
class StudentLedgerModel {
  final String studentId;
  final String fullName;
  final String srn;
  final String classId;
  final String dob;
  final String gender;

  const StudentLedgerModel({
    required this.studentId,
    required this.fullName,
    required this.srn,
    required this.classId,
    required this.dob,
    required this.gender,
  });

  factory StudentLedgerModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StudentLedgerModel(
      studentId: doc.id,
      fullName: d['fullName'] ?? '',
      srn: d['srn'] ?? '',
      classId: d['classId'] ?? '',
      dob: d['dob'] ?? '',
      gender: d['gender'] ?? 'male',
    );
  }
}

// ─── Inventory / Distribution ─────────────────────────────────
class DistributionStudentModel {
  final String studentId;
  final String fullName;
  final int rollNo;
  final String srn;
  bool uniformReceived;
  bool shoesReceived;
  final bool hasMismatch;
  final String uniformSize;
  final String shoesSize;

  DistributionStudentModel({
    required this.studentId,
    required this.fullName,
    this.rollNo = 0,
    required this.srn,
    this.uniformReceived = false,
    this.shoesReceived = false,
    this.hasMismatch = false,
    this.uniformSize = 'M',
    this.shoesSize = '7',
  });

  factory DistributionStudentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DistributionStudentModel(
      studentId: doc.id,
      fullName: d['fullName'] ?? '',
      rollNo: d['rollNo'] ?? 0,
      srn: d['srn'] ?? '',
      uniformReceived: d['uniformReceived'] ?? false,
      shoesReceived: d['shoesReceived'] ?? false,
      uniformSize: d['uniformSize'] ?? 'M',
      shoesSize: d['shoesSize'] ?? '7',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName,
    'rollNo': rollNo,
    'srn': srn,
    'uniformReceived': uniformReceived,
    'shoesReceived': shoesReceived,
    'uniformSize': uniformSize,
    'shoesSize': shoesSize,
  };
}

// ─── Dashboard Stats ──────────────────────────────────────────
class DashboardStats {
  final int totalStudents;
  final int presentToday;
  final int absentToday;
  final int mealsToday;
  final int staffPresent;
  final int staffTotal;
  final int leavePending;
  final double attendanceRate;

  const DashboardStats({
    this.totalStudents = 0,
    this.presentToday = 0,
    this.absentToday = 0,
    this.mealsToday = 0,
    this.staffPresent = 0,
    this.staffTotal = 0,
    this.leavePending = 0,
    this.attendanceRate = 0,
  });
}
