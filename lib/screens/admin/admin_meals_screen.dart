import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_header.dart';

class AdminMealsScreen extends ConsumerStatefulWidget {
  const AdminMealsScreen({super.key});

  @override
  ConsumerState<AdminMealsScreen> createState() => _AdminMealsScreenState();
}

class _AdminMealsScreenState extends ConsumerState<AdminMealsScreen> {
  bool _isLoading = true;
  String? _loadError;
  _AdminMealsData? _screenData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMeals(showSnackBar: false);
    });
  }

  Future<void> _loadMeals({bool showSnackBar = true}) async {
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
      final classIds = await firestore.getActiveClassIds(profile.schoolId);
      if (!mounted) return;

      final todayRecords = await firestore.getTodayMdmClassRecords(profile.schoolId);
      if (!mounted) return;

      final recentRecords = await firestore.getRecentMdmClassRecords(profile.schoolId);
      if (!mounted) return;

      final attendanceCounts = <String, int>{};
      for (final classId in classIds) {
        final count = await firestore.getTodayPresentCountForClass(
          profile.schoolId,
          classId,
        );
        if (!mounted) return;
        attendanceCounts[classId] = count;
      }

      setState(() {
        _screenData = _AdminMealsData(
          profile: profile,
          classIds: classIds,
          todayRecords: todayRecords,
          recentRecords: recentRecords,
          attendanceCounts: attendanceCounts,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load meals data right now.';
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load meals data. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: Column(
        children: [
          const AdminHeader(title: 'Meals Management'),
          Expanded(
            child: profileAsync.when(
        loading: () => const _AdminMealsLoadingState(),
        error: (_, __) => _AdminMealsMessageState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load your profile',
          message: 'Please try again to open meals management.',
          actionLabel: 'Retry',
          onPressed: _loadMeals,
        ),
        data: (_) {
          if (_isLoading) {
            return const _AdminMealsLoadingState();
          }

          if (_loadError != null) {
            return _AdminMealsMessageState(
              icon: Icons.cloud_off_rounded,
              title: 'Meals data unavailable',
              message: _loadError!,
              actionLabel: 'Retry',
              onPressed: _loadMeals,
            );
          }

          final screenData = _screenData;
          if (screenData == null) {
            return _AdminMealsMessageState(
              icon: Icons.fastfood_outlined,
              title: 'No meals data available',
              message: 'Try refreshing to load today\'s submissions.',
              actionLabel: 'Refresh',
              onPressed: _loadMeals,
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadMeals(showSnackBar: false),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MealSummaryCard(totalMeals: screenData.totalMealsToday),
                const SizedBox(height: 20),
                _WeeklyChart(dailyTotals: screenData.weeklyTotals),
                const SizedBox(height: 20),
                Text(
                  'Today\'s Class Submission Status',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                screenData.classRows.isEmpty
                    ? const _InlineEmptyState(
                        icon: Icons.restaurant_menu_outlined,
                        message: 'No MDM entries for today.',
                      )
                    : _ClassSubmissionList(rows: screenData.classRows),
                const SizedBox(height: 20),
                Text(
                  'Discrepancy Alerts',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                screenData.discrepancyRows.isEmpty
                    ? const _InlineEmptyState(
                        icon: Icons.verified_outlined,
                        message: 'No MDM discrepancies found in the last 7 days.',
                      )
                    : _DiscrepancyList(rows: screenData.discrepancyRows),
              ],
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }
}

class _AdminMealsData {
  final AppUser profile;
  final List<String> classIds;
  final List<MdmClassRecord> todayRecords;
  final List<MdmClassRecord> recentRecords;
  final Map<String, int> attendanceCounts;

  const _AdminMealsData({
    required this.profile,
    required this.classIds,
    required this.todayRecords,
    required this.recentRecords,
    required this.attendanceCounts,
  });

  int get totalMealsToday =>
      todayRecords.fold<int>(0, (sum, record) => sum + record.mealCount);

  Map<String, int> get weeklyTotals {
    final totals = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      totals[DateFormat('yyyy-MM-dd').format(date)] = 0;
    }

    for (final record in recentRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.submittedAt);
      if (totals.containsKey(dateKey)) {
        totals[dateKey] = (totals[dateKey] ?? 0) + record.mealCount;
      }
    }

    return totals;
  }

  List<_ClassSubmissionRowData> get classRows {
    final recordByClass = {
      for (final record in todayRecords) record.classId: record,
    };

    return classIds.map((classId) {
      final record = recordByClass[classId];
      final presentCount = attendanceCounts[classId] ?? 0;
      return _ClassSubmissionRowData(
        classId: classId,
        className: record?.className.isNotEmpty == true ? record!.className : classId,
        presentCount: record?.presentCount ?? presentCount,
        mealCount: record?.mealCount ?? 0,
        menu: record?.menu ?? 'Not submitted',
        isSubmitted: record != null,
        discrepancy: record?.discrepancy ?? false,
      );
    }).toList();
  }

  List<_DiscrepancyRowData> get discrepancyRows {
    return recentRecords
        .where((record) => record.discrepancy)
        .map(
          (record) => _DiscrepancyRowData(
            className: record.className.isNotEmpty ? record.className : record.classId,
            date: DateFormat('dd MMM yyyy').format(record.submittedAt),
            presentCount: record.presentCount,
            mealCount: record.mealCount,
          ),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _ClassSubmissionRowData {
  final String classId;
  final String className;
  final int presentCount;
  final int mealCount;
  final String menu;
  final bool isSubmitted;
  final bool discrepancy;

  const _ClassSubmissionRowData({
    required this.classId,
    required this.className,
    required this.presentCount,
    required this.mealCount,
    required this.menu,
    required this.isSubmitted,
    required this.discrepancy,
  });
}

class _DiscrepancyRowData {
  final String className;
  final String date;
  final int presentCount;
  final int mealCount;

  const _DiscrepancyRowData({
    required this.className,
    required this.date,
    required this.presentCount,
    required this.mealCount,
  });

  int get difference => mealCount - presentCount;
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
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalMeals',
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Across all active classes',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final Map<String, int> dailyTotals;

  const _WeeklyChart({required this.dailyTotals});

  @override
  Widget build(BuildContext context) {
    final entries = dailyTotals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxValue = entries.fold<int>(0, (maxMeals, entry) => entry.value > maxMeals ? entry.value : maxMeals);

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
          Text(
            'Weekly Trend',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          if (entries.every((entry) => entry.value == 0))
            const _InlineEmptyState(
              icon: Icons.bar_chart_rounded,
              message: 'No meal records were found in the last 7 days.',
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue + 10).toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) {
                            return const SizedBox();
                          }
                          final date = DateTime.tryParse(entries[index].key);
                          return Text(
                            date == null ? '--' : DateFormat('E').format(date),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: AppColors.navyPrimary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassSubmissionList extends StatelessWidget {
  final List<_ClassSubmissionRowData> rows;

  const _ClassSubmissionList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        final isPending = !row.isSubmitted;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: row.discrepancy
                ? AppColors.warningOrange.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: row.discrepancy
                  ? AppColors.warningOrange.withValues(alpha: 0.35)
                  : AppColors.borderGray,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.warningRedLight
                      : AppColors.successGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPending ? Icons.close_rounded : Icons.check_rounded,
                  size: 18,
                  color: isPending ? AppColors.warningRed : AppColors.successGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.className,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Present: ${row.presentCount} • Meals: ${row.mealCount}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                    Text(
                      row.menu,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.warningRed.withValues(alpha: 0.1)
                      : AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending ? 'PENDING' : 'SUBMITTED',
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

class _DiscrepancyList extends StatelessWidget {
  final List<_DiscrepancyRowData> rows;

  const _DiscrepancyList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningOrange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.className} • ${row.date}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Present: ${row.presentCount} • Meals: ${row.mealCount} • Difference: +${row.difference}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineEmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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

class _AdminMealsLoadingState extends StatelessWidget {
  const _AdminMealsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _MealsShimmerBox(height: 152),
        SizedBox(height: 20),
        _MealsShimmerBox(height: 220),
        SizedBox(height: 20),
        _MealsShimmerBox(height: 92),
        SizedBox(height: 10),
        _MealsShimmerBox(height: 92),
        SizedBox(height: 10),
        _MealsShimmerBox(height: 92),
      ],
    );
  }
}

class _MealsShimmerBox extends StatefulWidget {
  final double height;

  const _MealsShimmerBox({required this.height});

  @override
  State<_MealsShimmerBox> createState() => _MealsShimmerBoxState();
}

class _MealsShimmerBoxState extends State<_MealsShimmerBox>
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
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}

class _AdminMealsMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function({bool showSnackBar}) onPressed;

  const _AdminMealsMessageState({
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
