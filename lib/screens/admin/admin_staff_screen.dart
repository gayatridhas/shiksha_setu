import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';

class AdminStaffScreen extends ConsumerWidget {
  const AdminStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsProvider);
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();
    final profile = ref.watch(userProfileProvider).value;

    return staffAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (staff) {
        return leaveRequestsAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
          data: (leaveRequests) {
            final pendingRequests = leaveRequests.where((r) => r.status == LeaveRequestStatus.pending).toList();
            final staffPresent = stats.staffPresent;
            final staffTotal = stats.staffTotal;

            return Scaffold(
              backgroundColor: AppColors.backgroundGray,
              body: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _AdminAppBar(profile: profile)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _StaffOverviewCard(
                          presentCount: staffPresent,
                          totalCount: staffTotal,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(child: _DownloadButton()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(child: _AttendanceBadge(rate: stats.staffTotal > 0 ? (stats.staffPresent / stats.staffTotal * 100) : 0)),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _LiveActivitySection(staff: staff),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _LeaveRequestsSection(
                          requests: leaveRequests,
                          pendingCount: pendingRequests.length,
                          onApprove: (id) async {
                            if (profile == null) return;
                            await ref.read(firestoreServiceProvider).updateLeaveStatus(
                              profile.schoolId,
                              id,
                              LeaveRequestStatus.approved,
                              profile.fullName,
                            );
                          },
                          onReject: (id) async {
                            if (profile == null) return;
                            await ref.read(firestoreServiceProvider).updateLeaveStatus(
                              profile.schoolId,
                              id,
                              LeaveRequestStatus.rejected,
                              profile.fullName,
                            );
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      sliver: SliverToBoxAdapter(child: _ConsistencyCard(rate: 98.2)), // Calculated logic could go here
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          Text(
            'ShikshaSetu',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
          ),
          const Spacer(),
          InitialsAvatar(name: profile?.fullName ?? 'Admin', radius: 14),
        ],
      ),
    );
  }
}

class _StaffOverviewCard extends StatelessWidget {
  final int presentCount;
  final int totalCount;
  const _StaffOverviewCard({required this.presentCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF1B4F9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff Overview',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daily Attendance &\nActivity Tracking',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7), height: 1.4),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$presentCount/$totalCount',
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0),
              ),
              Text(
                'TEACHERS\nPRESENT',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7), height: 1.2),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Download Staff Attendance PDF'),
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

class _AttendanceBadge extends StatelessWidget {
  final double rate;
  const _AttendanceBadge({required this.rate});

  @override
  Widget build(BuildContext context) {
    final color = rate >= 80 ? AppColors.presentGreen : AppColors.warningRed;
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          '${rate.toStringAsFixed(1)}% ATTENDANCE',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _LiveActivitySection extends StatelessWidget {
  final List<StaffModel> staff;
  const _LiveActivitySection({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Activity',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            Text(
              'Synced Live',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (staff.isEmpty)
          Center(
              child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('No staff registered yet.', style: GoogleFonts.inter(color: AppColors.textGray)),
          ))
        else
          ...staff.map((s) => _StaffActivityRow(staff: s)),
      ],
    );
  }
}

class _StaffActivityRow extends StatelessWidget {
  final StaffModel staff;
  const _StaffActivityRow({required this.staff});

  Color get _badgeColor {
    switch (staff.status) {
      case StaffStatus.present: return AppColors.presentGreen;
      case StaffStatus.leave: return AppColors.warningOrange;
      case StaffStatus.duty: return AppColors.navyPrimary;
      case StaffStatus.absent: return AppColors.warningRed;
    }
  }

  String get _badgeLabel {
    switch (staff.status) {
      case StaffStatus.present: return 'P';
      case StaffStatus.leave: return 'L';
      case StaffStatus.duty: return 'D';
      case StaffStatus.absent: return 'A';
    }
  }

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
          InitialsAvatar(name: staff.name, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(
                  '${staff.subject} • ${staff.grade}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _badgeLabel,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestsSection extends StatelessWidget {
  final List<LeaveRequestModel> requests;
  final int pendingCount;
  final void Function(String) onApprove;
  final void Function(String) onReject;

  const _LeaveRequestsSection({
    required this.requests,
    required this.pendingCount,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Leave Requests', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.warningRed, borderRadius: BorderRadius.circular(20)),
              child: Text(
                '$pendingCount PENDING',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('No leave requests.', style: GoogleFonts.inter(color: AppColors.textGray))),
          )
        else
          Container(
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderGray)),
            child: Column(
              children: requests.map((r) {
                return _LeaveRequestCard(
                  request: r,
                  onApprove: () => onApprove(r.requestId),
                  onReject: () => onReject(r.requestId),
                  showDivider: r != requests.last,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequestModel request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool showDivider;

  const _LeaveRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == LeaveRequestStatus.pending;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: request.teacherName, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.teacherName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(request.leaveType, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray)),
                      ],
                    ),
                  ),
                  if (!isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: request.status == LeaveRequestStatus.approved ? AppColors.successGreenLight : AppColors.warningRedLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.status == LeaveRequestStatus.approved ? 'Approved' : 'Rejected',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: request.status == LeaveRequestStatus.approved ? AppColors.successGreen : AppColors.warningRed,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.reason,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray, fontStyle: FontStyle.italic, height: 1.4),
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.presentGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('APPROVE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textGray,
                          side: const BorderSide(color: AppColors.borderGray, width: 1.5),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('REJECT'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.borderGray),
      ],
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  final double rate;
  const _ConsistencyCard({required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF1B4F9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: -10,
            child: Opacity(
              opacity: 0.08,
              child: Text(
                '${rate.round()}',
                style: GoogleFonts.poppins(fontSize: 80, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAFF CONSISTENCY',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.6), letterSpacing: 1.0),
              ),
              const SizedBox(height: 6),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 16, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Text(
                    '+1.2% from last month',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
