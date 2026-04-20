import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' show TableHelper;
import 'package:printing/printing.dart';
import '../../core/utils/academic_year_utils.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/initials_avatar.dart';
import 'admin_shell_screen.dart';
import '../../providers/firestore_providers.dart';
import '../../widgets/admin_header.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _loadError;
  _AdminReportsData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports(showSnackBar: false);
    });
  }

  Future<void> _loadReports({bool showSnackBar = true}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await ref.read(userProfileProvider.future);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load your admin profile right now.';
        });
        return;
      }

      final firestore = ref.read(firestoreServiceProvider);
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final classIds = await firestore.getActiveClassIds(profile.schoolId);
      if (!mounted) return;

      final attendanceSummaries = await firestore.getAttendanceSummariesForRange(
        profile.schoolId,
        from: monthStart,
        to: monthEnd,
      );
      if (!mounted) return;

      final mealRecords = await firestore.getMdmRecordsForRange(
        profile.schoolId,
        from: monthStart,
        to: monthEnd,
      );
      if (!mounted) return;

      final inventorySummary = await firestore.getInventorySummary(
        profile.schoolId,
        AcademicYearUtils.currentAcademicYear(),
      );
      if (!mounted) return;

      final recentAttendance = await firestore.getRecentAttendanceSummaries(
        profile.schoolId,
        days: 10,
      );
      if (!mounted) return;

      final recentMeals = await firestore.getRecentMdmClassRecords(
        profile.schoolId,
        days: 10,
      );
      if (!mounted) return;

      int classesWithAttendanceToday = 0;
      for (final classId in classIds) {
        final hasAttendance =
            await firestore.hasAttendanceForToday(profile.schoolId, classId);
        if (!mounted) return;
        if (hasAttendance) {
          classesWithAttendanceToday++;
        }
      }

      setState(() {
        _data = _AdminReportsData(
          profile: profile,
          classIds: classIds,
          attendanceSummaries: attendanceSummaries,
          mealRecords: mealRecords,
          inventorySummary: inventorySummary,
          classesWithAttendanceToday: classesWithAttendanceToday,
          recentAttendance: recentAttendance,
          recentMeals: recentMeals,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load reports right now.';
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load reports. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _generateMonthlyReportPdf() async {
    final data = _data;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report data is not ready yet.')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);
    try {
      final pdfDoc = pw.Document();
      final attendanceRows = data.attendanceSummaries;
      final mealRows = data.mealRecords;

      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'ShikshaSetu - Monthly Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text('School: ${data.profile.schoolName}'),
            pw.Text(
              'Period: ${DateFormat('MMMM yyyy').format(DateTime.now())}',
            ),
            pw.Text(
              'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'ATTENDANCE SUMMARY',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
            pw.SizedBox(height: 8),
            TableHelper.fromTextArray(
              headers: const ['Class', 'Present', 'Absent', 'Leave', '%'],
              data: attendanceRows.map((summary) {
                final total = summary.totalCount;
                final pct = total > 0
                    ? (summary.presentCount / total * 100).toStringAsFixed(1)
                    : '0';
                return [
                  summary.classId,
                  '${summary.presentCount}',
                  '${summary.absentCount}',
                  '${summary.leaveCount}',
                  '$pct%',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'MID-DAY MEAL SUMMARY',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
            pw.SizedBox(height: 8),
            TableHelper.fromTextArray(
              headers: const ['Class', 'Present', 'Meals', 'Menu', 'OK?'],
              data: mealRows.map((record) {
                return [
                  record.className.isNotEmpty ? record.className : record.classId,
                  '${record.presentCount}',
                  '${record.mealCount}',
                  record.menu,
                  record.discrepancy ? 'Check' : 'OK',
                ];
              }).toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdfDoc.save(),
        filename:
            'ShikshaSetu_Report_${DateFormat('yyyy_MM').format(DateTime.now())}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly PDF report generated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to generate the PDF report right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _goToAdminTab(int index) {
    ref.read(adminTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const _AdminReportsLoadingState(),
          error: (_, __) => _AdminReportsMessageState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load your profile',
            message: 'Please try again to open system reports.',
            actionLabel: 'Retry',
            onPressed: _loadReports,
          ),
          data: (_) {
            if (_isLoading) {
              return const _AdminReportsLoadingState();
            }

            if (_loadError != null) {
              return _AdminReportsMessageState(
                icon: Icons.cloud_off_rounded,
                title: 'Reports unavailable',
                message: _loadError!,
                actionLabel: 'Retry',
                onPressed: _loadReports,
              );
            }

            final data = _data;
            if (data == null) {
              return _AdminReportsMessageState(
                icon: Icons.analytics_outlined,
                title: 'No report data',
                message: 'Refresh to load the latest school metrics.',
                actionLabel: 'Refresh',
                onPressed: _loadReports,
              );
            }

            return RefreshIndicator(
              onRefresh: () => _loadReports(showSnackBar: false),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: const AdminHeader(),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: const SliverToBoxAdapter(child: _PageHeader()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _GenerateReportButton(
                        isGenerating: _isGeneratingPdf,
                        onPressed: _generateMonthlyReportPdf,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MetricCard(
                        icon: Icons.people_alt_rounded,
                        iconColor: AppColors.presentGreen,
                        badge: 'LIVE',
                        badgeColor: AppColors.presentGreen,
                        value:
                            '${data.attendanceRateThisMonth.toStringAsFixed(1)}%',
                        valueIcon: Icons.trending_up_rounded,
                        label: 'Attendance Rate This Month',
                        onViewDetails: () => _goToAdminTab(4),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MetricCard(
                        icon: Icons.restaurant_rounded,
                        iconColor: AppColors.warningOrange,
                        badge: 'MONTH',
                        badgeColor: AppColors.accentBlue,
                        value: '${data.totalMealsThisMonth}',
                        label: 'Total Meals Served This Month',
                        onViewDetails: () => _goToAdminTab(3),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MetricCard(
                        icon: Icons.inventory_2_rounded,
                        iconColor: AppColors.navyPrimary,
                        badge: 'YEAR',
                        badgeColor: AppColors.navyPrimary,
                        value:
                            '${data.distributionCompletion.toStringAsFixed(1)}%',
                        label: 'Distribution Completion',
                        onViewDetails: () => _goToAdminTab(2),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _MetricCard(
                        icon: Icons.pending_actions_rounded,
                        iconColor: AppColors.warningRed,
                        badge: 'TODAY',
                        badgeColor: AppColors.warningRed,
                        value: '${data.classesMissingAttendanceToday}',
                        label: 'Classes Missing Attendance Today',
                        onViewDetails: () => _goToAdminTab(4),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _RecentActivity(
                        activities: data.recentActivities,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: _RegionalCoverage(
                        schoolName: data.profile.schoolName,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminReportsData {
  final AppUser profile;
  final List<String> classIds;
  final List<AttendanceClassSummary> attendanceSummaries;
  final List<MdmClassRecord> mealRecords;
  final Map<String, int> inventorySummary;
  final int classesWithAttendanceToday;
  final List<AttendanceClassSummary> recentAttendance;
  final List<MdmClassRecord> recentMeals;

  const _AdminReportsData({
    required this.profile,
    required this.classIds,
    required this.attendanceSummaries,
    required this.mealRecords,
    required this.inventorySummary,
    required this.classesWithAttendanceToday,
    required this.recentAttendance,
    required this.recentMeals,
  });

  double get attendanceRateThisMonth {
    final present = attendanceSummaries.fold<int>(
      0,
      (presentTotal, summary) => presentTotal + summary.presentCount,
    );
    final total = attendanceSummaries.fold<int>(
      0,
      (recordTotal, summary) => recordTotal + summary.totalCount,
    );
    if (total == 0) return 0;
    return present / total * 100;
  }

  int get totalMealsThisMonth =>
      mealRecords.fold<int>(0, (mealTotal, record) => mealTotal + record.mealCount);

  double get distributionCompletion {
    final totalStudents = inventorySummary['totalStudents'] ?? 0;
    if (totalStudents == 0) return 0;
    final uniformReceived = inventorySummary['uniformReceived'] ?? 0;
    final shoesReceived = inventorySummary['shoesReceived'] ?? 0;
    return ((uniformReceived + shoesReceived) / (totalStudents * 2)) * 100;
  }

  int get classesMissingAttendanceToday =>
      classIds.length - classesWithAttendanceToday;

  List<_AdminActivityItem> get recentActivities {
    final items = <_AdminActivityItem>[
      ...recentAttendance.map(
        (summary) => _AdminActivityItem(
          title:
              '${summary.classId} attendance marked by ${summary.submittedBy}',
          subtitle:
              '${summary.presentCount} present, ${summary.absentCount} absent, ${summary.leaveCount} on leave',
          timestamp: summary.submittedAt,
          icon: Icons.how_to_reg_rounded,
          color: AppColors.presentGreen,
        ),
      ),
      ...recentMeals.map(
        (record) => _AdminActivityItem(
          title:
              '${record.className.isNotEmpty ? record.className : record.classId} MDM submitted',
          subtitle:
              '${record.mealCount} meals served${record.discrepancy ? ' • discrepancy flagged' : ''}',
          timestamp: record.submittedAt,
          icon: Icons.restaurant_rounded,
          color:
              record.discrepancy ? AppColors.warningOrange : AppColors.accentBlue,
        ),
      ),
    ];

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(10).toList();
  }
}

class _AdminActivityItem {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const _AdminActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

class _AdminAppBar extends StatelessWidget {
  final AppUser profile;

  const _AdminAppBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: AppColors.navyPrimary, size: 22),
          const SizedBox(width: 12),
          Text(
            'ShikshaSetu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
          const Spacer(),
          InitialsAvatar(name: profile.fullName, radius: 14),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATIVE INTELLIGENCE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textGray,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'System Reports',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Academic year ${AcademicYearUtils.currentAcademicYear()} overview of attendance, meals, and school operations.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textGray,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _GenerateReportButton extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onPressed;

  const _GenerateReportButton({
    required this.isGenerating,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isGenerating ? null : onPressed,
      icon: isGenerating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
      label: Text(
        isGenerating ? 'Generating PDF...' : 'Generate Monthly PDF Report',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navyPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
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

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.badge,
    required this.badgeColor,
    required this.value,
    this.valueIcon,
    required this.label,
    required this.onViewDetails,
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
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
              ),
              if (valueIcon != null) ...[
                const SizedBox(width: 6),
                Icon(
                  valueIcon,
                  size: 20,
                  color: AppColors.textGray.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGray),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewDetails,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyPrimary,
                side: const BorderSide(color: AppColors.borderGray),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<_AdminActivityItem> activities;

  const _RecentActivity({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (activities.isEmpty)
          const _InlineMessageCard(
            icon: Icons.history_toggle_off_rounded,
            message: 'No recent attendance or meal activity found.',
          )
        else
          ...activities.map(
            (activity) => _ActivityRow(
              icon: activity.icon,
              iconColor: activity.color,
              title: activity.title,
              subtitle:
                  '${activity.subtitle} • ${DateFormat('dd MMM, hh:mm a').format(activity.timestamp)}',
            ),
          ),
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
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
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
                    fontSize: 11,
                    color: AppColors.textGray,
                    height: 1.3,
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

class _RegionalCoverage extends StatelessWidget {
  final String schoolName;

  const _RegionalCoverage({required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operations Map',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFD8E5F5), Color(0xFFEAF1FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.public_rounded,
                  size: 48,
                  color: AppColors.navyPrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  schoolName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Active school wing tracked for ${AcademicYearUtils.currentAcademicYear()}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineMessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineMessageCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textGray),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AdminReportsLoadingState extends StatelessWidget {
  const _AdminReportsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _ReportShimmerBox(height: 64, radius: 0),
        SizedBox(height: 16),
        _ReportShimmerBox(height: 88),
        SizedBox(height: 16),
        _ReportShimmerBox(height: 52),
        SizedBox(height: 16),
        _ReportShimmerBox(height: 172),
        SizedBox(height: 12),
        _ReportShimmerBox(height: 172),
        SizedBox(height: 12),
        _ReportShimmerBox(height: 172),
        SizedBox(height: 16),
        _ReportShimmerBox(height: 90),
        SizedBox(height: 10),
        _ReportShimmerBox(height: 90),
      ],
    );
  }
}

class _ReportShimmerBox extends StatefulWidget {
  final double height;
  final double radius;

  const _ReportShimmerBox({
    required this.height,
    this.radius = 16,
  });

  @override
  State<_ReportShimmerBox> createState() => _ReportShimmerBoxState();
}

class _ReportShimmerBoxState extends State<_ReportShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.borderGray.withValues(alpha: 0.45),
              AppColors.borderGray.withValues(alpha: 0.16),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class _AdminReportsMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function({bool showSnackBar}) onPressed;

  const _AdminReportsMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textGray),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => onPressed(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyPrimary,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
