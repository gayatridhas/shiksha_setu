import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/initials_avatar.dart';

final localAttendanceProvider = StateNotifierProvider.family<
    LocalAttendanceNotifier, List<StudentModel>, String>((ref, classId) {
  return LocalAttendanceNotifier();
});

class LocalAttendanceNotifier extends StateNotifier<List<StudentModel>> {
  LocalAttendanceNotifier() : super(const []);

  void replaceStudents(List<StudentModel> students) {
    state = students;
  }

  void updateStatus(String studentId, AttendanceStatus status) {
    state = [
      for (final s in state)
        if (s.studentId == studentId) _copyStudentWithStatus(s, status) else s,
    ];
  }

  void markAllPresent() {
    state = [
      for (final s in state)
        _copyStudentWithStatus(s, AttendanceStatus.present),
    ];
  }

  static StudentModel _copyStudentWithStatus(
    StudentModel student,
    AttendanceStatus? status,
  ) {
    return StudentModel(
      studentId: student.studentId,
      fullName: student.fullName,
      rollNo: student.rollNo,
      srn: student.srn,
      classId: student.classId,
      gender: student.gender,
      dob: student.dob,
      isActive: student.isActive,
      academicYear: student.academicYear,
      approvalStatus: student.approvalStatus,
      submittedByUid: student.submittedByUid,
      approvedByUid: student.approvedByUid,
      approvedAt: student.approvedAt,
      status: status,
      hasConsecutiveAbsences: student.hasConsecutiveAbsences,
    );
  }
}

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState
    extends ConsumerState<StudentAttendanceScreen> {
  late DateTime _selectedDate;
  bool _isEditMode = false;
  bool _isSubmitting = false;
  String? _lastSyncedSignature;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isAttendanceComplete(List<StudentModel> students) {
    return students.every((student) => student.status != null);
  }

  bool _isPastDate(DateTime date) {
    final today = _dateOnly(DateTime.now());
    return _dateOnly(date).isBefore(today);
  }

  List<StudentModel> _mergeStudentsWithAttendance(
    List<StudentModel> students,
    List<AttendanceEntry> attendanceEntries,
  ) {
    final statusByStudentId = {
      for (final entry in attendanceEntries) entry.studentId: entry.status,
    };

    return [
      for (final student in students)
        LocalAttendanceNotifier._copyStudentWithStatus(
          student,
          statusByStudentId[student.studentId],
        ),
    ];
  }

  String _buildSyncSignature(
    DateTime selectedDate,
    List<StudentModel> syncedStudents,
  ) {
    final buffer = StringBuffer(DateFormat('yyyy-MM-dd').format(selectedDate));
    for (final student in syncedStudents) {
      buffer
        ..write('|')
        ..write(student.studentId)
        ..write(':')
        ..write(student.status?.name ?? 'null');
    }
    return buffer.toString();
  }

  void _syncLocalAttendance(
    String classId,
    DateTime selectedDate,
    List<StudentModel> syncedStudents,
  ) {
    final signature = _buildSyncSignature(selectedDate, syncedStudents);
    if (_lastSyncedSignature == signature) return;
    _lastSyncedSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(localAttendanceProvider(classId).notifier)
          .replaceStudents(syncedStudents);
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _dateOnly(DateTime.now()),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = _dateOnly(pickedDate);
      _isEditMode = false;
      _lastSyncedSignature = null;
    });
  }

  Future<void> _openAddStudentSheet(AppUser profile) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final srnController = TextEditingController();
    final dobController = TextEditingController();
    String gender = 'male';
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitStudent() async {
              if (!formKey.currentState!.validate()) return;
              setModalState(() => isSubmitting = true);
              try {
                final student = StudentModel(
                  studentId: DateTime.now().microsecondsSinceEpoch.toString(),
                  fullName: nameController.text.trim(),
                  rollNo: int.parse(rollController.text.trim()),
                  srn: srnController.text.trim(),
                  classId: profile.assignedClassId ?? '',
                  gender: gender,
                  dob: dobController.text.trim(),
                  academicYear: '',
                  approvalStatus: 'pending',
                  submittedByUid: profile.uid,
                );
                await ref
                    .read(firestoreServiceProvider)
                    .submitStudentForApproval(profile.schoolId, student);
                if (!mounted || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Student submitted for admin approval.'),
                  ),
                );
                ref.invalidate(
                    pendingStudentsProvider(profile.assignedClassId));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Unable to add student: $e')),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() => isSubmitting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Student For Approval',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter student name'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rollController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Roll No'),
                      validator: (value) => int.tryParse(value ?? '') == null
                          ? 'Enter a valid roll number'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: srnController,
                      decoration: const InputDecoration(labelText: 'SRN'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter student SRN'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dobController,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'female', child: Text('Female')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => gender = value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submitStudent,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.navyPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send To Admin For Approval'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profile.assignedClassId == null || profile.assignedClassId!.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundGray,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.class_outlined,
                    size: 64,
                    color: AppColors.warningOrange,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Class Assigned',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You haven\'t been assigned a class yet. Please contact your administrator to assign you to a class to begin marking attendance.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textGray,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final classId = profile.assignedClassId!;
    final studentsAsync = ref.watch(classStudentsProvider(classId));
    final pendingStudentsAsync = ref.watch(pendingStudentsProvider(classId));
    final attendanceAsync = ref.watch(
      attendanceByDateProvider((classId: classId, date: _selectedDate)),
    );

    return studentsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.backgroundGray,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.textGray,
                ),
                const SizedBox(height: 12),
                Text(
                  'Attendance data is unavailable',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textGray,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      data: (students) {
        return attendanceAsync.when(
          loading: () => Scaffold(
            backgroundColor: AppColors.backgroundGray,
            body: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _TopBar(
                    classId: classId,
                    pendingCount: pendingStudentsAsync.valueOrNull?.length ?? 0,
                    selectedDate: _selectedDate,
                    onAddStudent: () => _openAddStudentSheet(profile),
                    onPickDate: _pickDate,
                  ),
                ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
          error: (err, stack) => Scaffold(
            backgroundColor: AppColors.backgroundGray,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Unable to load attendance for this date: $err',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textGray,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          data: (attendanceEntries) {
            final syncedStudents =
                _mergeStudentsWithAttendance(students, attendanceEntries);
            _syncLocalAttendance(classId, _selectedDate, syncedStudents);

            final localStudents = ref.watch(localAttendanceProvider(classId));
            final displayStudents =
                localStudents.isEmpty && syncedStudents.isNotEmpty
                    ? syncedStudents
                    : localStudents;

            final hasSubmittedAttendance = attendanceEntries.isNotEmpty;
            final isPastDate = _isPastDate(_selectedDate);
            final isEditable =
                !hasSubmittedAttendance ? !isPastDate : _isEditMode;
            final showSubmitButton = isEditable;
            final showEditButton = hasSubmittedAttendance && !_isEditMode;

            final present = displayStudents
                .where((s) => s.status == AttendanceStatus.present)
                .length;
            final absent = displayStudents
                .where((s) => s.status == AttendanceStatus.absent)
                .length;
            final leave = displayStudents
                .where((s) => s.status == AttendanceStatus.leave)
                .length;
            final total = displayStudents.length;
            final rate = total > 0 ? (present / total * 100).round() : 0;

            Color bannerColor = AppColors.navyPrimary;
            if (rate < 60) {
              bannerColor = AppColors.warningRed;
            } else if (rate < 75) {
              bannerColor = AppColors.warningOrange;
            }

            final helperMessage = hasSubmittedAttendance
                ? (_isEditMode
                    ? 'Editing is enabled for ${DateFormat('dd MMM yyyy').format(_selectedDate)}. Make changes and submit again to save them.'
                    : 'Attendance for ${DateFormat('dd MMM yyyy').format(_selectedDate)} is view only. Tap Edit to make changes.')
                : (isPastDate
                    ? 'This past date is view only because no attendance was submitted for it.'
                    : 'Mark attendance for all students and submit once you are ready.');

            return Scaffold(
              backgroundColor: AppColors.backgroundGray,
              body: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: _TopBar(
                      classId: classId,
                      pendingCount:
                          pendingStudentsAsync.valueOrNull?.length ?? 0,
                      selectedDate: _selectedDate,
                      onAddStudent: () => _openAddStudentSheet(profile),
                      onPickDate: _pickDate,
                      onMarkAllPresent: isEditable
                          ? () {
                              ref
                                  .read(
                                      localAttendanceProvider(classId).notifier)
                                  .markAllPresent();
                            }
                          : null,
                      helperMessage: helperMessage,
                    ),
                  ),
                  if ((pendingStudentsAsync.valueOrNull?.isNotEmpty ?? false))
                    Container(
                      width: double.infinity,
                      color: AppColors.warningOrange.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        '${pendingStudentsAsync.valueOrNull!.length} student entries are waiting for admin approval. Approved students only appear in attendance.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: bannerColor,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATTENDANCE RATE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$rate%',
                              style: GoogleFonts.poppins(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              '$present of $total Students Present',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          Icons.people_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: displayStudents.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'No approved students are available for this class yet. Add students and wait for admin approval to begin attendance.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textGray,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                            itemCount: displayStudents.length,
                            itemBuilder: (context, index) {
                              final student = displayStudents[index];
                              return _StudentRow(
                                student: student,
                                readOnly: !isEditable,
                                onStatusChanged: (status) {
                                  if (!isEditable) return;
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(
                                        localAttendanceProvider(classId)
                                            .notifier,
                                      )
                                      .updateStatus(student.studentId, status);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              bottomNavigationBar: _BottomBar(
                total: total,
                present: present,
                absent: absent,
                leave: leave,
                isSubmitting: _isSubmitting,
                primaryLabel: showSubmitButton ? 'Submit Attendance' : null,
                primaryIcon: Icons.cloud_upload_rounded,
                onPrimaryPressed: showSubmitButton
                    ? () async {
                        if (_isSubmitting) return;
                        if (!_isAttendanceComplete(displayStudents)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please mark attendance for all students before submitting.',
                              ),
                            ),
                          );
                          return;
                        }

                        final confirmed =
                            await _showConfirmDialog(context, present, total);
                        if (!mounted || confirmed != true) return;

                        setState(() => _isSubmitting = true);
                        try {
                          await ref
                              .read(firestoreServiceProvider)
                              .submitAttendance(
                                profile.schoolId,
                                classId,
                                displayStudents,
                                profile.fullName,
                                date: _selectedDate,
                              );
                          if (!mounted) return;
                          setState(() {
                            _isSubmitting = false;
                            _isEditMode = false;
                            _lastSyncedSignature = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Attendance submitted successfully',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    : null,
                secondaryLabel: showEditButton ? 'Edit Attendance' : null,
                secondaryIcon: Icons.edit_rounded,
                onSecondaryPressed: showEditButton
                    ? () {
                        setState(() {
                          _isEditMode = true;
                        });
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context,
    int present,
    int total,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Text(
          'Are you sure you want to submit attendance for $total students ($present present)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String classId;
  final int pendingCount;
  final DateTime selectedDate;
  final VoidCallback onAddStudent;
  final VoidCallback onPickDate;
  final VoidCallback? onMarkAllPresent;
  final String? helperMessage;

  const _TopBar({
    super.key,
    required this.classId,
    required this.pendingCount,
    required this.selectedDate,
    required this.onAddStudent,
    required this.onPickDate,
    this.onMarkAllPresent,
    this.helperMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.navyPrimary,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Student Attendance',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onAddStudent,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.navyPrimary,
                      ),
                      if (pendingCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _ClassChip(label: 'Class $classId'),
                      const Spacer(),
                      InkWell(
                        onTap: onPickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: AppColors.navyPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navyPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          helperMessage ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: onMarkAllPresent,
                        icon: Icon(
                          Icons.done_all_rounded,
                          size: 16,
                          color: onMarkAllPresent == null
                              ? AppColors.textGray
                              : AppColors.navyPrimary,
                        ),
                        label: Text(
                          'Mark All Present',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: onMarkAllPresent == null
                                ? AppColors.textGray
                                : AppColors.navyPrimary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;

  const _ClassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navyPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final StudentModel student;
  final bool readOnly;
  final void Function(AttendanceStatus) onStatusChanged;

  const _StudentRow({
    required this.student,
    required this.readOnly,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: student.hasConsecutiveAbsences
                ? AppColors.warningRed
                : Colors.transparent,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(name: student.fullName, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Roll No: ${student.rollNo}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _StatusButton(
                  label: 'P',
                  selected: student.status == AttendanceStatus.present,
                  selectedColor: AppColors.presentGreen,
                  readOnly: readOnly,
                  onTap: () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 6),
                _StatusButton(
                  label: 'A',
                  selected: student.status == AttendanceStatus.absent,
                  selectedColor: AppColors.warningRed,
                  readOnly: readOnly,
                  onTap: () => onStatusChanged(AttendanceStatus.absent),
                ),
                const SizedBox(width: 6),
                _StatusButton(
                  label: 'L',
                  selected: student.status == AttendanceStatus.leave,
                  selectedColor: AppColors.accentBlue,
                  readOnly: readOnly,
                  onTap: () => onStatusChanged(AttendanceStatus.leave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final bool readOnly;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.readOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: readOnly ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? selectedColor : AppColors.borderGray,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textGray,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int total;
  final int present;
  final int absent;
  final int leave;
  final bool isSubmitting;
  final String? primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondaryPressed;

  const _BottomBar({
    required this.total,
    required this.present,
    required this.absent,
    required this.leave,
    required this.isSubmitting,
    this.primaryLabel,
    this.primaryIcon = Icons.cloud_upload_rounded,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.secondaryIcon = Icons.edit_rounded,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasActions = primaryLabel != null || secondaryLabel != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomStat(
                label: 'TOTAL',
                value: '$total',
                color: AppColors.textPrimary,
              ),
              _BottomStat(
                label: 'PRESENT',
                value: '$present',
                color: AppColors.presentGreen,
              ),
              _BottomStat(
                label: 'ABSENT',
                value: absent.toString().padLeft(2, '0'),
                color: AppColors.warningRed,
              ),
              _BottomStat(
                label: 'LEAVE',
                value: leave.toString().padLeft(2, '0'),
                color: AppColors.accentBlue,
              ),
            ],
          ),
          if (hasActions) ...[
            const SizedBox(height: 12),
            if (secondaryLabel != null)
              OutlinedButton.icon(
                onPressed: onSecondaryPressed,
                icon: Icon(secondaryIcon, size: 18),
                label: Text(secondaryLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navyPrimary,
                  side: const BorderSide(color: AppColors.navyPrimary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (secondaryLabel != null && primaryLabel != null)
              const SizedBox(height: 10),
            if (primaryLabel != null)
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : onPrimaryPressed,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(primaryIcon, size: 18),
                label: Text(primaryLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BottomStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BottomStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textGray,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
