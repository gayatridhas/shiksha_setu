import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../core/utils/academic_year_utils.dart';
import '../../widgets/admin_header.dart';

// --- Screen Providers ---
final studentSearchProvider = StateProvider<String>((ref) => '');
final studentClassFilterProvider = StateProvider<String>((ref) => 'All Classes');
final studentGenderFilterProvider = StateProvider<String>((ref) => 'All');
final studentPageProvider = StateProvider<int>((ref) => 1);

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  bool _isApproving = false;
  bool _isResetting = false;

  Future<void> _approveStudents(List<String> studentIds) async {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null || studentIds.isEmpty) return;

    setState(() => _isApproving = true);
    try {
      await ref.read(firestoreServiceProvider).approveStudents(
            profile.schoolId,
            studentIds,
            approvedByUid: profile.uid,
          );
      if (!mounted) return;
      ref.invalidate(allCurrentYearStudentsProvider);
      ref.invalidate(studentsProvider);
      ref.invalidate(dashboardStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${studentIds.length} student entries approved.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to approve students: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _resetRoster() async {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Current Year Roster'),
        content: Text(
          'This will archive all active student entries for ${AcademicYearUtils.currentAcademicYear()}. You can then start a fresh approved list for the next cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    try {
      await ref.read(firestoreServiceProvider).resetAcademicYearRoster(
            profile.schoolId,
            archivedByUid: profile.uid,
          );
      if (!mounted) return;
      ref.invalidate(allCurrentYearStudentsProvider);
      ref.invalidate(studentsProvider);
      ref.invalidate(dashboardStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current academic roster archived.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to reset roster: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(studentSearchProvider);
    final classFilter = ref.watch(studentClassFilterProvider);
    final genderFilter = ref.watch(studentGenderFilterProvider);
    final page = ref.watch(studentPageProvider);
    
    final studentsAsync = ref.watch(allCurrentYearStudentsProvider);
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();

    return studentsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (allStudents) {
        final classItems = <String>{
          'All Classes',
          ...allStudents
              .map((student) => student.classId)
              .where((classId) => classId.isNotEmpty),
        }.toList()
          ..sort((a, b) {
            if (a == 'All Classes') return -1;
            if (b == 'All Classes') return 1;
            return a.compareTo(b);
          });
        final pendingStudents = allStudents
            .where((student) => student.approvalStatus == 'pending')
            .toList()
          ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
        final approvedStudents = allStudents
            .where((student) => student.approvalStatus == 'approved')
            .toList();

        final filtered = approvedStudents.where((s) {
          final matchSearch = search.isEmpty ||
              s.fullName.toLowerCase().contains(search.toLowerCase()) ||
              s.srn.toLowerCase().contains(search.toLowerCase());
          final matchClass = classFilter == 'All Classes' || s.classId == classFilter;
          final matchGender = genderFilter == 'All' ||
              (genderFilter == 'Male' && s.gender.toLowerCase() == 'male') ||
              (genderFilter == 'Female' && s.gender.toLowerCase() == 'female');
          return matchSearch && matchClass && matchGender;
        }).toList();

        const pageSize = 8;
        final totalPages = (filtered.length / pageSize).ceil().clamp(1, 999);
        final pagedItems = filtered.skip((page - 1) * pageSize).take(pageSize).toList();

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: const AdminHeader()),
                SliverToBoxAdapter(child: _LedgerBanner(attendanceRate: stats.attendanceRate)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _SearchBar(
                      onChanged: (v) {
                        ref.read(studentSearchProvider.notifier).state = v;
                        ref.read(studentPageProvider.notifier).state = 1;
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FilterRow(
                      classFilter: classFilter,
                      genderFilter: genderFilter,
                      classItems: classItems,
                      onClassChanged: (v) {
                        ref.read(studentClassFilterProvider.notifier).state = v;
                        ref.read(studentPageProvider.notifier).state = 1;
                      },
                      onGenderChanged: (v) {
                        ref.read(studentGenderFilterProvider.notifier).state = v;
                        ref.read(studentPageProvider.notifier).state = 1;
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _RosterActions(
                      pendingCount: pendingStudents.length,
                      isApproving: _isApproving,
                      isResetting: _isResetting,
                      onApproveAll: pendingStudents.isEmpty
                          ? null
                          : () => _approveStudents(
                                pendingStudents
                                    .map((student) => student.studentId)
                                    .toList(),
                              ),
                      onResetYear: _resetRoster,
                    ),
                  ),
                ),
                if (pendingStudents.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _PendingApprovalSection(
                        students: pendingStudents,
                        isApproving: _isApproving,
                        onApproveSingle: (studentId) =>
                            _approveStudents([studentId]),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: const SliverToBoxAdapter(child: _ApprovedLabel()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StudentTable(students: pagedItems),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _PageInfo(
                      showing: pagedItems.length,
                      total: filtered.length,
                      page: page,
                      totalPages: totalPages,
                      onPageChanged: (p) => ref.read(studentPageProvider.notifier).state = p,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  sliver: SliverToBoxAdapter(child: _AlertCards(stats: stats)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _LedgerBanner extends StatelessWidget {
  final double attendanceRate;
  const _LedgerBanner({required this.attendanceRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF1B4F9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student Ledger', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('ACADEMIC SESSION ${AcademicYearUtils.currentAcademicYear()}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${attendanceRate.round()}%', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('School Attendance', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                   Text('Running Average', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final void Function(String) onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by Name or SRN...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textGray),
        filled: true,
        fillColor: AppColors.cardWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderGray)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navyPrimary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String classFilter;
  final String genderFilter;
  final List<String> classItems;
  final void Function(String) onClassChanged;
  final void Function(String) onGenderChanged;

  const _FilterRow({
    required this.classFilter,
    required this.genderFilter,
    required this.classItems,
    required this.onClassChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterDropdown(
            label: 'CLASS',
            value: classFilter,
            items: classItems,
            onChanged: onClassChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterDropdown(
            label: 'GENDER',
            value: genderFilter,
            items: const ['All', 'Male', 'Female'],
            onChanged: onGenderChanged,
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String) onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGray, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textGray),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class _RosterActions extends StatelessWidget {
  final int pendingCount;
  final bool isApproving;
  final bool isResetting;
  final VoidCallback? onApproveAll;
  final VoidCallback onResetYear;

  const _RosterActions({
    required this.pendingCount,
    required this.isApproving,
    required this.isResetting,
    required this.onApproveAll,
    required this.onResetYear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isApproving ? null : onApproveAll,
            icon: isApproving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.verified_rounded, size: 16),
            label: Text(
              pendingCount == 0 ? 'No Pending Entries' : 'Approve All Pending ($pendingCount)',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: isResetting ? null : onResetYear,
          icon: isResetting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.restart_alt_rounded, size: 16),
          label: Text(
            'Reset Year',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            side: const BorderSide(color: AppColors.warningRed),
            foregroundColor: AppColors.warningRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

class _ApprovedLabel extends StatelessWidget {
  const _ApprovedLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Approved Roster',
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PendingApprovalSection extends StatelessWidget {
  final List<StudentModel> students;
  final bool isApproving;
  final void Function(String studentId) onApproveSingle;

  const _PendingApprovalSection({
    required this.students,
    required this.isApproving,
    required this.onApproveSingle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher Submitted Entries Awaiting Approval',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Only approved students will appear in attendance, reports, MDM, and inventory for the current academic year.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray, height: 1.4),
          ),
          const SizedBox(height: 12),
          ...students.map(
            (student) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Class ${student.classId} • Roll ${student.rollNo} • ${student.srn}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: isApproving ? null : () => onApproveSingle(student.studentId),
                    child: const Text('Approve'),
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

class _StudentTable extends StatelessWidget {
  final List<StudentModel> students;
  const _StudentTable({required this.students});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('STUDENT NAME', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('SRN NUMBER', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('CLASS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderGray),
          if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No students found', style: GoogleFonts.inter(color: AppColors.textGray)),
            )
          else
            ...students.asMap().entries.map((entry) {
              final s = entry.value;
              return Column(
                children: [
                  InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                InitialsAvatar(name: s.fullName, radius: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.fullName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      Text('Roll: ${s.rollNo}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGray)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '#${s.srn}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Class ${s.classId}',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (entry.key < students.length - 1) const Divider(height: 1, color: AppColors.borderGray),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _PageInfo extends StatelessWidget {
  final int showing;
  final int total;
  final int page;
  final int totalPages;
  final void Function(int) onPageChanged;

  const _PageInfo({
    required this.showing,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'SHOWING $showing OF $total STUDENTS',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray, letterSpacing: 0.3),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              onTap: page > 1 ? () => onPageChanged(page - 1) : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Page $page of $totalPages',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            _PageButton(
              icon: Icons.chevron_right_rounded,
              onTap: page < totalPages ? () => onPageChanged(page + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Icon(icon, size: 20, color: onTap != null ? AppColors.navyPrimary : AppColors.textGray),
      ),
    );
  }
}

class _AlertCards extends StatelessWidget {
  final DashboardStats stats;
  const _AlertCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AlertCard(
          icon: Icons.pending_actions_rounded,
          iconBg: AppColors.warningRedLight,
          iconColor: AppColors.warningRed,
          title: 'PENDING TASKS',
          value: '${stats.leavePending}',
          valueColor: AppColors.warningRed,
          subtitle: 'Staff leave requests require your immediate review and approval.',
        ),
        const SizedBox(height: 12),
        _AlertCard(
          icon: Icons.restaurant_rounded,
          iconBg: AppColors.successGreenLight,
          iconColor: AppColors.presentGreen,
          title: 'MIDDAY MEAL INTAKE',
          value: '${stats.mealsToday}',
          valueColor: AppColors.presentGreen,
          subtitle: 'Total students recorded for lunch today across all school sections.',
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;
  final String subtitle;

  const _AlertCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.07,
              child: Icon(icon, size: 64, color: iconColor),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Text(value, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: valueColor, height: 1.0)),
              const SizedBox(height: 6),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray, height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }
}
