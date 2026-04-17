import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../models/app_models.dart';

class TeacherReportsScreen extends ConsumerWidget {
  const TeacherReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: Text(
          'Class Analysis',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttendanceChartCard(classId: profile.classId ?? 'Unknown'),
            const SizedBox(height: 20),
            Text(
              'Leave Management',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            _LeaveActionCard(profile: profile),
            const SizedBox(height: 20),
            Text(
              'Activity History',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const _ActivityHistoryList(),
          ],
        ),
      ),
    );
  }
}

class _AttendanceChartCard extends StatelessWidget {
  final String classId;
  const _AttendanceChartCard({required this.classId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Text(
                'Class $classId Attendance',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Icon(Icons.show_chart_rounded, color: AppColors.presentGreen),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S'];
                        if (v.toInt() >= 0 && v.toInt() < days.length) {
                          return Text(days[v.toInt()], style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 85),
                      FlSpot(1, 92),
                      FlSpot(2, 88),
                      FlSpot(3, 94),
                      FlSpot(4, 90),
                      FlSpot(5, 75),
                    ],
                    isCurved: true,
                    color: AppColors.navyPrimary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.navyPrimary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Running average: 89%',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _LeaveActionCard extends StatelessWidget {
  final AppUser profile;
  const _LeaveActionCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_note_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply for Leave',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                ),
                Text(
                  'Direct submission to Admin',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showLeaveSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navyPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
  }

  void _showLeaveSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave Application', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(hintText: 'Leave Type (e.g. Sick Leave)')),
            const SizedBox(height: 12),
            const TextField(maxLines: 3, decoration: InputDecoration(hintText: 'Reason for leave...')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyPrimary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit to Admin'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ActivityHistoryList extends StatelessWidget {
  const _ActivityHistoryList();

  @override
  Widget build(BuildContext context) {
    final mockHistory = [
      {'title': 'Attendance Submitted', 'date': 'Today, 09:15 AM', 'icon': Icons.how_to_reg_rounded, 'color': AppColors.presentGreen},
      {'title': 'MDM Recorded (32 meals)', 'date': 'Today, 01:20 PM', 'icon': Icons.restaurant_rounded, 'color': AppColors.accentBlue},
      {'title': 'Inventory Ledger Updated', 'date': 'Yesterday, 03:45 PM', 'icon': Icons.inventory_2_rounded, 'color': AppColors.navyPrimary},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = mockHistory[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            children: [
              Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(item['date'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGray)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textGray),
            ],
          ),
        );
      },
    );
  }
}
