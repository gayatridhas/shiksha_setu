import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';

// --- Local State Provider for Attendance Entry ---
final localAttendanceProvider = StateNotifierProvider.family<LocalAttendanceNotifier, List<StudentModel>, List<StudentModel>>((ref, initialStudents) {
  return LocalAttendanceNotifier(initialStudents);
});

class LocalAttendanceNotifier extends StateNotifier<List<StudentModel>> {
  LocalAttendanceNotifier(List<StudentModel> initial) : super(initial);

  void updateStatus(String studentId, AttendanceStatus status) {
    state = [
      for (final s in state)
        if (s.studentId == studentId)
          StudentModel(
            studentId: s.studentId,
            fullName: s.fullName,
            rollNo: s.rollNo,
            srn: s.srn,
            classId: s.classId,
            status: status,
            hasConsecutiveAbsences: s.hasConsecutiveAbsences,
          )
        else
          s,
    ];
  }

  void markAllPresent() {
    state = [
      for (final s in state)
        StudentModel(
          studentId: s.studentId,
          fullName: s.fullName,
          rollNo: s.rollNo,
          srn: s.srn,
          classId: s.classId,
          status: AttendanceStatus.present,
          hasConsecutiveAbsences: s.hasConsecutiveAbsences,
        ),
    ];
  }
}

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends ConsumerState<StudentAttendanceScreen> {
  bool _isInitialized = false;

  bool _isAttendanceComplete(List<StudentModel> students) {
    return students.every((student) => student.status != null);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final classId = profile.classId ?? 'Unknown';
    final studentsAsync = ref.watch(classStudentsProvider(classId));

    return studentsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (students) {
        // We use a separate provider for the local interactive state
        // We initialize it once when students load
        final localStudents = ref.watch(localAttendanceProvider(students));

        final present = localStudents.where((s) => s.status == AttendanceStatus.present).length;
        final absent = localStudents.where((s) => s.status == AttendanceStatus.absent).length;
        final leave = localStudents.where((s) => s.status == AttendanceStatus.leave).length;
        final total = localStudents.length;
        final rate = total > 0 ? (present / total * 100).round() : 0;

        Color bannerColor = AppColors.navyPrimary;
        if (rate < 60) {
          bannerColor = AppColors.warningRed;
        } else if (rate < 75) {
          bannerColor = AppColors.warningOrange;
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _TopBar(
                  classId: classId,
                  onMarkAllPresent: () {
                    ref.read(localAttendanceProvider(students).notifier).markAllPresent();
                  },
                ),
              ),
              // Banner
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
                            color: Colors.white.withOpacity(0.7),
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
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.people_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: localStudents.length,
                  itemBuilder: (context, index) {
                    final student = localStudents[index];
                    return _StudentRow(
                      student: student,
                      onStatusChanged: (status) {
                        HapticFeedback.lightImpact();
                        ref.read(localAttendanceProvider(students).notifier).updateStatus(student.studentId, status);
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
            onSubmit: () async {
              if (!_isAttendanceComplete(localStudents)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please mark attendance for all students before submitting.'),
                  ),
                );
                return;
              }

              final confirmed = await _showConfirmDialog(context, present, total);
              if (!mounted) return;
              if (confirmed == true) {
                try {
                  await ref.read(firestoreServiceProvider).submitAttendance(
                        profile.schoolId,
                        classId,
                        localStudents,
                        profile.fullName,
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance submitted successfully')),
                  );
                  if (!mounted) return;
                  context.pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, int present, int total) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Text('Are you sure you want to submit attendance for $total students ($present present)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String classId;
  final VoidCallback onMarkAllPresent;
  const _TopBar({required this.classId, required this.onMarkAllPresent});

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
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navyPrimary),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.navyPrimary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd,\nyyyy').format(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navyPrimary,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                _ClassChip(label: 'Class $classId'),
                const Spacer(),
                TextButton.icon(
                  onPressed: onMarkAllPresent,
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.navyPrimary),
                  label: Text(
                    'Mark All Present',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
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
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final StudentModel student;
  final void Function(AttendanceStatus) onStatusChanged;

  const _StudentRow({
    required this.student,
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
            color: student.hasConsecutiveAbsences ? AppColors.warningRed : Colors.transparent,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  onTap: () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 6),
                _StatusButton(
                  label: 'A',
                  selected: student.status == AttendanceStatus.absent,
                  selectedColor: AppColors.warningRed,
                  onTap: () => onStatusChanged(AttendanceStatus.absent),
                ),
                const SizedBox(width: 6),
                _StatusButton(
                  label: 'L',
                  selected: student.status == AttendanceStatus.leave,
                  selectedColor: AppColors.accentBlue,
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
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
  final int total, present, absent, leave;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.total,
    required this.present,
    required this.absent,
    required this.leave,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomStat(label: 'TOTAL', value: '$total', color: AppColors.textPrimary),
              _BottomStat(label: 'PRESENT', value: '$present', color: AppColors.presentGreen),
              _BottomStat(label: 'ABSENT', value: absent.toString().padLeft(2, '0'), color: AppColors.warningRed),
              _BottomStat(label: 'LEAVE', value: leave.toString().padLeft(2, '0'), color: AppColors.accentBlue),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Submit Attendance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BottomStat({required this.label, required this.value, required this.color});

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
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGray, letterSpacing: 0.5),
        ),
      ],
    );
  }
}
