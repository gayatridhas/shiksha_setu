import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../widgets/initials_avatar.dart';
import '../../models/app_models.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AdminAppBar(profile: profile)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(child: _PageHeader()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(child: _GenerateReportButton(context: context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _MetricCard(
                icon: Icons.people_alt_rounded,
                iconColor: AppColors.presentGreen,
                badge: 'LIVE',
                badgeColor: AppColors.presentGreen,
                value: '${stats.attendanceRate.round()}%',
                valueIcon: Icons.trending_up_rounded,
                label: 'School-wide Attendance',
                onViewDetails: () {},
                onExport: () {},
              )),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _MetricCard(
                icon: Icons.restaurant_rounded,
                iconColor: AppColors.warningOrange,
                badge: 'DAILY SYNC',
                badgeColor: AppColors.accentBlue,
                value: '${stats.mealsToday}',
                label: 'Mid-Day Meals Served Today',
                onViewDetails: () {},
                onExport: () {},
              )),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _MetricCard(
                icon: Icons.badge_rounded,
                iconColor: AppColors.navyPrimary,
                badge: 'STAFF',
                badgeColor: AppColors.navyPrimary,
                value: '${stats.staffPresent}/${stats.staffTotal}',
                label: 'Teachers On-Duty Today',
                onViewDetails: () {},
                onExport: () {},
              )),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(child: _RecentActivity(stats: stats)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              sliver: SliverToBoxAdapter(child: _RegionalCoverage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAppBar extends StatelessWidget {
  final AppUser? profile;
  const _AdminAppBar({this.profile});

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
          InitialsAvatar(name: profile?.fullName ?? 'Admin', radius: 14),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATIVE INTELLIGENCE',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGray, letterSpacing: 1.0),
        ),
        const SizedBox(height: 4),
        Text('System Reports', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'Comprehensive overview of school educational health, resource utilization, and student engagement metrics.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray, height: 1.4),
        ),
      ],
    );
  }
}

class _GenerateReportButton extends StatelessWidget {
  final BuildContext context;
  const _GenerateReportButton({required this.context});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating monthly PDF report...')),
        );
      },
      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
      label: const Text('Generate Monthly PDF Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navyPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String badge;
  final Color badgeColor;
  final String value;
  final IconData? valueIcon;
  final String label;
  final VoidCallback onViewDetails;
  final VoidCallback onExport;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.badge,
    required this.badgeColor,
    required this.value,
    this.valueIcon,
    required this.label,
    required this.onViewDetails,
    required this.onExport,
  });

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badge == 'LIVE') ...[
                      _PulsingDot(color: badgeColor),
                      const SizedBox(width: 4),
                    ],
                    Text(badge, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(value, style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.0)),
              if (valueIcon != null) ...[
                const SizedBox(width: 6),
                Icon(valueIcon, size: 20, color: AppColors.textGray.withOpacity(0.5)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGray)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewDetails,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyPrimary,
                side: const BorderSide(color: AppColors.borderGray),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final DashboardStats stats;
  const _RecentActivity({required this.stats});

  @override
  Widget build(BuildContext context) {
    final activities = [
      (Icons.check_circle_rounded, AppColors.presentGreen, '${stats.attendanceRate.round()}% Attendance Logged', 'Running average updated live'),
      (Icons.restaurant_rounded, AppColors.warningOrange, '${stats.mealsToday} Meals Recorded', 'Class-wise submissions synced'),
      (Icons.pending_actions_rounded, AppColors.warningRed, '${stats.leavePending} Leave Requests', 'Require immediate review'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text('View All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyPrimary)),
          ],
        ),
        const SizedBox(height: 10),
        ...activities.map((a) => _ActivityRow(icon: a.$1, iconColor: a.$2, title: a.$3, subtitle: a.$4)),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _ActivityRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGray, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionalCoverage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Operations Map', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFD0D8E8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.public_rounded, size: 48, color: AppColors.navyPrimary),
                const SizedBox(height: 12),
                Text('Active School Wing Tracked', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
