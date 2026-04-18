import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_colors.dart';

class TeacherReportsScreen extends ConsumerStatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  ConsumerState<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends ConsumerState<TeacherReportsScreen> {
  bool _isLoading = true;
  String? _loadError;
  _TeacherReportsData? _reportData;

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
          _loadError = 'Unable to load your profile right now.';
        });
        return;
      }

      final classId = profile.classId;
      if (classId == null || classId.isEmpty) {
        setState(() {
          _isLoading = false;
          _loadError = null;
          _reportData = _TeacherReportsData.empty(profile);
        });
        return;
      }

      final firestore = ref.read(firestoreServiceProvider);
      final classStrength = await firestore.getActiveStudentCountForClass(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      final attendanceCounts = await firestore.getDailyAttendancePresentCounts(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      final hasAttendanceToday = await firestore.hasAttendanceForToday(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      final recentMealRecords = await firestore.getMdmRecordsForClassRange(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      final leaveRequests = await ref.read(leaveRequestsProvider.future);
      if (!mounted) return;

      final ownLeaveRequests = leaveRequests
          .where((request) => request.teacherId == profile.uid)
          .toList();

      setState(() {
        _reportData = _TeacherReportsData(
          profile: profile,
          classStrength: classStrength,
          attendanceCounts: attendanceCounts,
          hasAttendanceToday: hasAttendanceToday,
          recentMealRecords: recentMealRecords,
          ownLeaveRequests: ownLeaveRequests,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load teacher reports right now.';
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

  Future<void> _openLeaveSheet(AppUser profile) async {
    final leaveTypeController = TextEditingController();
    final reasonController = TextEditingController();
    DateTime? fromDate;
    DateTime? toDate;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate(bool isFromDate) async {
              final selected = await showDatePicker(
                context: context,
                initialDate: isFromDate ? (fromDate ?? DateTime.now()) : (toDate ?? fromDate ?? DateTime.now()),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selected == null) return;
              setModalState(() {
                if (isFromDate) {
                  fromDate = selected;
                  if (toDate != null && toDate!.isBefore(selected)) {
                    toDate = selected;
                  }
                } else {
                  toDate = selected;
                }
              });
            }

            Future<void> submitLeave() async {
              final leaveType = leaveTypeController.text.trim();
              final reason = reasonController.text.trim();
              if (leaveType.isEmpty || reason.isEmpty || fromDate == null || toDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fill in leave type, reason, from date, and to date.'),
                  ),
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                final request = LeaveRequestModel(
                  requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                  teacherId: profile.uid,
                  teacherName: profile.fullName,
                  leaveType: leaveType,
                  reason: reason,
                  fromDate: DateFormat('yyyy-MM-dd').format(fromDate!),
                  toDate: DateFormat('yyyy-MM-dd').format(toDate!),
                );
                await ref.read(firestoreServiceProvider).submitLeaveRequest(
                      profile.schoolId,
                      request,
                    );
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Leave request submitted successfully.'),
                  ),
                );
                await _loadReports(showSnackBar: false);
                if (!mounted) return;
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to submit leave request right now.'),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() => isSubmitting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Application',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: leaveTypeController,
                    decoration: const InputDecoration(
                      hintText: 'Leave Type (e.g. Sick Leave)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Reason for leave...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(true),
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            fromDate == null
                                ? 'From Date'
                                : DateFormat('dd MMM yyyy').format(fromDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(false),
                          icon: const Icon(Icons.event_available_rounded, size: 16),
                          label: Text(
                            toDate == null
                                ? 'To Date'
                                : DateFormat('dd MMM yyyy').format(toDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submitLeave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit to Admin'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

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
      body: profileAsync.when(
        loading: () => const _ReportsLoadingState(),
        error: (_, __) => _ReportsMessageState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load your profile',
          message: 'Please try again to open teacher reports.',
          actionLabel: 'Retry',
          onPressed: _loadReports,
        ),
        data: (_) {
          if (_isLoading) {
            return const _ReportsLoadingState();
          }

          if (_loadError != null) {
            return _ReportsMessageState(
              icon: Icons.cloud_off_rounded,
              title: 'Reports unavailable',
              message: _loadError!,
              actionLabel: 'Retry',
              onPressed: _loadReports,
            );
          }

          final reportData = _reportData;
          if (reportData == null || reportData.profile.classId == null || reportData.profile.classId!.isEmpty) {
            return _ReportsMessageState(
              icon: Icons.class_outlined,
              title: 'No class assigned',
              message: 'Your account does not have an assigned class yet.',
              actionLabel: 'Reload',
              onPressed: _loadReports,
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadReports(showSnackBar: false),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AttendanceChartCard(reportData: reportData),
                const SizedBox(height: 20),
                Text(
                  'Leave Management',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _LeaveActionCard(
                  profile: reportData.profile,
                  latestLeaveRequest: reportData.latestLeaveRequest,
                  onApply: () => _openLeaveSheet(reportData.profile),
                ),
                const SizedBox(height: 20),
                Text(
                  'Activity History',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                reportData.activities.isEmpty
                    ? const _InlineEmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        message: 'No recent class activity available yet.',
                      )
                    : _ActivityHistoryList(activities: reportData.activities),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeacherReportsData {
  final AppUser profile;
  final int classStrength;
  final Map<String, int> attendanceCounts;
  final bool hasAttendanceToday;
  final List<MdmClassRecord> recentMealRecords;
  final List<LeaveRequestModel> ownLeaveRequests;

  const _TeacherReportsData({
    required this.profile,
    required this.classStrength,
    required this.attendanceCounts,
    required this.hasAttendanceToday,
    required this.recentMealRecords,
    required this.ownLeaveRequests,
  });

  factory _TeacherReportsData.empty(AppUser profile) {
    return _TeacherReportsData(
      profile: profile,
      classStrength: 0,
      attendanceCounts: const {},
      hasAttendanceToday: false,
      recentMealRecords: const [],
      ownLeaveRequests: const [],
    );
  }

  List<FlSpot> get attendanceSpots {
    final orderedKeys = attendanceCounts.keys.toList()..sort();
    return orderedKeys.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final dateKey = entry.value;
      final present = attendanceCounts[dateKey] ?? 0;
      final percentage = classStrength > 0 ? (present / classStrength) * 100 : 0.0;
      return FlSpot(index, percentage);
    }).toList();
  }

  double get runningAverage {
    if (attendanceCounts.isEmpty || classStrength == 0) return 0;
    final totalPresent = attendanceCounts.values.fold<int>(0, (sum, value) => sum + value);
    final totalPossible = classStrength * attendanceCounts.length;
    if (totalPossible == 0) return 0;
    return (totalPresent / totalPossible) * 100;
  }

  LeaveRequestModel? get latestLeaveRequest {
    if (ownLeaveRequests.isEmpty) return null;
    final sorted = [...ownLeaveRequests]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first;
  }

  List<_ActivityItem> get activities {
    final items = <_ActivityItem>[];

    if (hasAttendanceToday) {
      items.add(
        _ActivityItem(
          title: 'Attendance submitted for ${profile.classId}',
          subtitle: 'Today\'s attendance has been recorded for your class.',
          icon: Icons.how_to_reg_rounded,
          color: AppColors.presentGreen,
          timestamp: DateTime.now(),
        ),
      );
    }

    for (final record in recentMealRecords) {
      items.add(
        _ActivityItem(
          title: 'MDM recorded for ${record.className}',
          subtitle: '${record.mealCount} meals served${record.discrepancy ? ' • discrepancy noted' : ''}',
          icon: Icons.restaurant_rounded,
          color: record.discrepancy ? AppColors.warningOrange : AppColors.accentBlue,
          timestamp: record.submittedAt,
        ),
      );
    }

    for (final request in ownLeaveRequests.take(3)) {
      items.add(
        _ActivityItem(
          title: '${request.leaveType} leave request submitted',
          subtitle: '${request.fromDate} to ${request.toDate} • ${request.status.name.toUpperCase()}',
          icon: Icons.event_note_rounded,
          color: AppColors.navyPrimary,
          timestamp: request.createdAt,
        ),
      );
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(6).toList();
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
  });
}

class _AttendanceChartCard extends StatelessWidget {
  final _TeacherReportsData reportData;

  const _AttendanceChartCard({required this.reportData});

  @override
  Widget build(BuildContext context) {
    final spots = reportData.attendanceSpots;
    final orderedKeys = reportData.attendanceCounts.keys.toList()..sort();

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
                '${reportData.profile.classId} Attendance',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Icon(Icons.show_chart_rounded, color: AppColors.presentGreen),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last 7 days attendance trend',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
          ),
          const SizedBox(height: 24),
          if (spots.isEmpty || reportData.classStrength == 0)
            const _InlineEmptyState(
              icon: Icons.bar_chart_rounded,
              message: 'No attendance data available for this class yet.',
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: max(100, spots.map((spot) => spot.y).fold<double>(0, max)).toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.borderGray.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= orderedKeys.length) {
                            return const SizedBox();
                          }
                          final date = DateTime.tryParse(orderedKeys[index]);
                          return Text(
                            date == null ? '--' : DateFormat('E').format(date),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 25,
                        getTitlesWidget: (value, _) => Text(
                          '${value.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.navyPrimary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.navyPrimary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Running average: ${reportData.runningAverage.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveActionCard extends StatelessWidget {
  final AppUser profile;
  final LeaveRequestModel? latestLeaveRequest;
  final VoidCallback onApply;

  const _LeaveActionCard({
    required this.profile,
    required this.latestLeaveRequest,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final latestStatus = latestLeaveRequest?.status.name.toUpperCase();
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  latestLeaveRequest == null
                      ? 'Direct submission to Admin'
                      : 'Latest request: $latestStatus • ${latestLeaveRequest!.leaveType}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onApply,
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
}

class _ActivityHistoryList extends StatelessWidget {
  final List<_ActivityItem> activities;

  const _ActivityHistoryList({required this.activities});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = activities[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textGray,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(item.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textGray.withValues(alpha: 0.8),
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
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(14),
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

class _ReportsLoadingState extends StatelessWidget {
  const _ReportsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _ReportShimmerBox(height: 260),
        SizedBox(height: 20),
        _ReportShimmerBox(height: 110),
        SizedBox(height: 20),
        _ReportShimmerBox(height: 86),
        SizedBox(height: 10),
        _ReportShimmerBox(height: 86),
        SizedBox(height: 10),
        _ReportShimmerBox(height: 86),
      ],
    );
  }
}

class _ReportShimmerBox extends StatefulWidget {
  final double height;

  const _ReportShimmerBox({required this.height});

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
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}

class _ReportsMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function({bool showSnackBar}) onPressed;

  const _ReportsMessageState({
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
