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
  final String? classId;     // teacher only
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
    this.classId,
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
      classId: d['classId'],
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
    if (classId != null) 'classId': classId,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'emailVerified': emailVerified,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  AppUser copyWith({String? fullName, String? phone, String? photoUrl, String? classId}) =>
      AppUser(
        uid: uid,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
        role: role,
        schoolId: schoolId,
        schoolName: schoolName,
        classId: classId ?? this.classId,
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

  const StaffModel({
    required this.teacherId,
    required this.name,
    required this.subject,
    required this.grade,
    required this.status,
    this.photoUrl,
    this.phone = '',
    this.email = '',
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
