import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../providers/locale_provider.dart';
import '../../models/app_models.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(profile: profile)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _QuickActions(l10n: l10n)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _SecondaryChips(l10n: l10n)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _SummaryBanner(stats: stats, l10n: l10n)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _StatsGrid(stats: stats, l10n: l10n)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(child: _PendingTasks(l10n: l10n)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverToBoxAdapter(child: _AcademicCalendar(l10n: l10n)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final AppUser? profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.fullName ?? 'Teacher';
    final school = profile?.schoolName ?? 'Loading School...';
    final currentLocale = ref.watch(localeProvider);

    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME, ${name.toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  school,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyPrimary,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: currentLocale.languageCode,
            underline: const SizedBox(),
            icon: const Icon(Icons.language_rounded, color: AppColors.navyPrimary, size: 24),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('EN')),
              DropdownMenuItem(value: 'hi', child: Text('HI')),
              DropdownMenuItem(value: 'mr', child: Text('MR')),
            ],
            onChanged: (lang) {
              if (lang != null) {
                ref.read(localeProvider.notifier).setLocale(lang);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26, color: AppColors.navyPrimary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AppLocalizations l10n;
  const _QuickActions({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 55,
          child: GestureDetector(
            onTap: () => context.go('/teacher/attendance'),
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.navyPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 28, color: Colors.white),
                  const SizedBox(height: 6),
                  Text(
                    'Mark ${l10n.attendance}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 42,
          child: GestureDetector(
            onTap: () => context.go('/teacher/mdm'),
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant_rounded, size: 28, color: AppColors.navyPrimary),
                  const SizedBox(height: 6),
                  Text(
                    'Record ${l10n.mdm}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryChips extends StatelessWidget {
  final AppLocalizations l10n;
  const _SecondaryChips({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SecondaryChip(
          icon: Icons.inventory_2_rounded,
          label: l10n.inventory,
          onTap: () => context.go('/teacher/inventory'),
        ),
        const SizedBox(width: 10),
        _SecondaryChip(
          icon: Icons.bar_chart_rounded,
          label: l10n.reports,
          onTap: () => context.go('/teacher/reports'),
        ),
        const SizedBox(width: 10),
        _SecondaryChip(
          icon: Icons.people_rounded,
          label: l10n.students,
          onTap: () => context.go('/teacher/attendance'),
        ),
      ],
    );
  }
}

class _SecondaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.navyPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final DashboardStats stats;
  final AppLocalizations l10n;
  const _SummaryBanner({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final rate = stats.attendanceRate.round();
    Color statusColor = AppColors.successGreen;
    String statusText = 'Attendance Stable';

    if (rate < 75) {
      statusColor = AppColors.warningRed;
      statusText = 'Attendance Low';
    } else if (rate < 85) {
      statusColor = AppColors.warningOrange;
      statusText = 'Attendance Dropping';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S SUMMARY",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.65),
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(
              rate >= 85 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  final AppLocalizations l10n;
  const _StatsGrid({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _StatCard(
          icon: Icons.people_rounded,
          iconColor: AppColors.navyPrimary,
          value: '${stats.totalStudents}',
          label: 'Total ${l10n.students}',
          bgColor: AppColors.cardWhite,
          valueColor: AppColors.textPrimary,
        ),
        _StatCard(
          icon: Icons.how_to_reg_rounded,
          iconColor: AppColors.successGreen,
          value: '${stats.presentToday}',
          label: '${l10n.present} Today',
          bgColor: AppColors.successGreenLight,
          valueColor: AppColors.successGreen,
        ),
        _StatCard(
          icon: Icons.person_off_rounded,
          iconColor: AppColors.warningRed,
          value: '${stats.absentToday}',
          label: '${l10n.absent} Today',
          bgColor: AppColors.warningRedLight,
          valueColor: AppColors.warningRed,
        ),
        _StatCard(
          icon: Icons.restaurant_rounded,
          iconColor: AppColors.accentBlue,
          value: '${stats.mealsToday}',
          label: '${l10n.mdm} Marked',
          bgColor: AppColors.lightBlue,
          valueColor: AppColors.navyPrimary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color bgColor;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.bgColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 24, color: iconColor),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  height: 1.0,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: iconColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingTasks extends ConsumerWidget {
  final AppLocalizations l10n;
  const _PendingTasks({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAttendance = ref.watch(hasAttendanceForTodayProvider).value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasks & Alerts',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (!hasAttendance)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ACTION REQUIRED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _TaskCard(
          icon: hasAttendance ? Icons.check_circle_rounded : Icons.warning_rounded,
          iconBg: hasAttendance ? AppColors.successGreenLight : AppColors.warningRedLight,
          iconColor: hasAttendance ? AppColors.successGreen : AppColors.warningRed,
          title: hasAttendance ? '${l10n.attendance} Marked' : '${l10n.attendance} not marked',
          subtitle: hasAttendance ? 'Successfully submitted for today' : 'System deadline: 10:30 AM',
          onTap: () => context.go('/teacher/attendance'),
        ),
        const SizedBox(height: 10),
        _TaskCard(
          icon: Icons.inventory_2_rounded,
          iconBg: const Color(0xFFFFF3E0),
          iconColor: AppColors.warningOrange,
          title: '${l10n.inventory} update due',
          subtitle: 'Update seasonal requirements',
          onTap: () => context.go('/teacher/inventory'),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TaskCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }
}

class _AcademicCalendar extends StatelessWidget {
  final AppLocalizations l10n;
  const _AcademicCalendar({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Calendar',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preparation for Mid-term assessments starts next Monday. Ensure all digital ledgers are updated.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textGray,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {},
            child: Text(
              'VIEW SCHEDULE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.navyPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
