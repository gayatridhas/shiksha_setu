import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/firestore_providers.dart';
import '../../models/app_models.dart';

class AdminMealsScreen extends ConsumerWidget {
  const AdminMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: Text(
          'Meals Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MealSummaryCard(totalMeals: stats.mealsToday),
            const SizedBox(height: 20),
            _WeeklyChart(),
            const SizedBox(height: 20),
            Text(
              'Class Submissions',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const _ClassSubmissionList(),
          ],
        ),
      ),
    );
  }
}

class _MealSummaryCard extends StatelessWidget {
  final int totalMeals;
  const _MealSummaryCard({required this.totalMeals});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navyPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL MEALS TODAY',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7), letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalMeals',
            style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            'Across all primary & upper primary sections',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Trend', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 200,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                        return Text(days[val.toInt() % 6], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroup(0, 140),
                  _makeGroup(1, 152),
                  _makeGroup(2, 148),
                  _makeGroup(3, 130),
                  _makeGroup(4, 155),
                  _makeGroup(5, 90),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.navyPrimary,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _ClassSubmissionList extends StatelessWidget {
  const _ClassSubmissionList();

  @override
  Widget build(BuildContext context) {
    // This would typically come from a specific admin-view MDM stream
    final mockClasses = [
      {'name': 'Class I', 'count': 32, 'status': 'Submitted'},
      {'name': 'Class II', 'count': 28, 'status': 'Submitted'},
      {'name': 'Class III', 'count': 0, 'status': 'Pending'},
      {'name': 'Class IV', 'count': 30, 'status': 'Submitted'},
      {'name': 'Class V', 'count': 26, 'status': 'Submitted'},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockClasses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = mockClasses[i];
        final isPending = c['status'] == 'Pending';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isPending ? AppColors.warningRedLight : AppColors.successGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPending ? Icons.pending_actions_rounded : Icons.restaurant_rounded,
                  size: 18,
                  color: isPending ? AppColors.warningRed : AppColors.successGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['name'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      isPending ? 'Action Required' : '${c['count']} Meals marked',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? AppColors.warningRed.withOpacity(0.1) : AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (c['status'] as String).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPending ? AppColors.warningRed : AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
