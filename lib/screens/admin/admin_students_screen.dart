import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../core/utils/academic_year_utils.dart';
import '../../core/utils/academic_year_utils.dart';

// --- Screen Providers ---
final studentSearchProvider = StateProvider<String>((ref) => '');
final studentClassFilterProvider = StateProvider<String>((ref) => 'All Classes');
final studentGenderFilterProvider = StateProvider<String>((ref) => 'All');
final studentPageProvider = StateProvider<int>((ref) => 1);

class AdminStudentsScreen extends ConsumerWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(studentSearchProvider);
    final classFilter = ref.watch(studentClassFilterProvider);
    final genderFilter = ref.watch(studentGenderFilterProvider);
    final page = ref.watch(studentPageProvider);
    
    final studentsAsync = ref.watch(studentsProvider);
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();

    return studentsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (allStudents) {
        final filtered = allStudents.where((s) {
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
                SliverToBoxAdapter(child: _AdminAppBar()),
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
                  sliver: SliverToBoxAdapter(child: _ExportButton()),
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

class _AdminAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: AppColors.navyPrimary, size: 22),
          const SizedBox(width: 12),
          Text('ShikshaSetu', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navyPrimary)),
          const Spacer(),
          const Icon(Icons.notifications_outlined, color: AppColors.navyPrimary, size: 22),
        ],
      ),
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
          Text('ACADEMIC SESSION ${AcademicYearUtils.currentAcademicYear()}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.6), letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${attendanceRate.round()}%', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('School Attendance', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                   Text('Running Average', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
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
  final void Function(String) onClassChanged;
  final void Function(String) onGenderChanged;

  const _FilterRow({
    required this.classFilter,
    required this.genderFilter,
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
            items: const ['All Classes', '1', '2', '3', '4', '5'],
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

class _ExportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.navyPrimary),
        label: Text('Export Student Ledger', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyPrimary)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: AppColors.navyPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
