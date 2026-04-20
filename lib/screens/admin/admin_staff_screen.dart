import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../widgets/admin_header.dart';

class AdminStaffScreen extends ConsumerStatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  ConsumerState<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends ConsumerState<AdminStaffScreen> {
  Future<void> _openCreateTeacherSheet(AppUser profile) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final subjectController = TextEditingController();
    final classController = TextEditingController();
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
            Future<void> submitTeacher() async {
              final fullName = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final password = passwordController.text.trim();
              final subject = subjectController.text.trim();
              final classId = classController.text.trim();

              if (fullName.isEmpty ||
                  email.isEmpty ||
                  phone.isEmpty ||
                  password.isEmpty ||
                  classId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter name, email, phone, password, and assigned class.',
                    ),
                  ),
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              final created = await ref.read(authNotifierProvider.notifier).createTeacherAccount(
                    email: email,
                    password: password,
                    fullName: fullName,
                    phone: phone,
                    schoolId: profile.schoolId,
                    schoolName: profile.schoolName,
                    classId: classId,
                    subject: subject,
                  );
              if (!mounted) return;
              if (!sheetContext.mounted) return;

              if (created) {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Teacher account created for $email. They can now sign in.',
                    ),
                  ),
                );
              } else {
                final error = ref.read(authNotifierProvider).error;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(error?.toString() ?? 'Teacher creation failed.'),
                  ),
                );
              }

              if (context.mounted) {
                setModalState(() => isSubmitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Teacher Account',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CreateTeacherField(
                      controller: nameController,
                      label: 'Full Name',
                    ),
                    const SizedBox(height: 12),
                    _CreateTeacherField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _CreateTeacherField(
                      controller: phoneController,
                      label: 'Phone',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _CreateTeacherField(
                      controller: passwordController,
                      label: 'Temporary Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    _CreateTeacherField(
                      controller: classController,
                      label: 'Assigned Class',
                      hintText: 'Example: 4 or Class 4',
                    ),
                    const SizedBox(height: 12),
                    _CreateTeacherField(
                      controller: subjectController,
                      label: 'Subject (optional)',
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: isSubmitting ? null : submitTeacher,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        isSubmitting ? 'Creating...' : 'Create Teacher Account',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
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

  @override
  Widget build(BuildContext context) {
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
            final pendingRequests = leaveRequests
                .where((r) => r.status == LeaveRequestStatus.pending)
                .toList();
            final staffPresent = stats.staffPresent;
            final staffTotal = stats.staffTotal;

            return Scaffold(
              backgroundColor: AppColors.backgroundGray,
              body: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: const AdminHeader()),
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
                      sliver: SliverToBoxAdapter(
                        child: _CreateTeacherButton(
                          onPressed: profile == null
                              ? null
                              : () => _openCreateTeacherSheet(profile),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: const SliverToBoxAdapter(child: _DownloadButton()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _AttendanceBadge(
                          rate: stats.staffTotal > 0
                              ? (stats.staffPresent / stats.staffTotal * 100)
                              : 0,
                        ),
                      ),
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
                      sliver: const SliverToBoxAdapter(
                        child: _ConsistencyCard(rate: 98.2),
                      ),
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

class _CreateTeacherField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;

  const _CreateTeacherField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _CreateTeacherButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _CreateTeacherButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Create Teacher Login'),
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
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.7), height: 1.4),
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
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), height: 1.2),
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
  const _DownloadButton();

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
  const _AttendanceBadge({super.key, required this.rate});

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
            ),
          )
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
      case StaffStatus.present:
        return AppColors.presentGreen;
      case StaffStatus.leave:
        return AppColors.warningOrange;
      case StaffStatus.duty:
        return AppColors.navyPrimary;
      case StaffStatus.absent:
        return AppColors.warningRed;
    }
  }

  String get _badgeLabel {
    switch (staff.status) {
      case StaffStatus.present:
        return 'P';
      case StaffStatus.leave:
        return 'L';
      case StaffStatus.duty:
        return 'D';
      case StaffStatus.absent:
        return 'A';
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
                  '${staff.subject} • ${staff.assignedClassId.isNotEmpty ? "Class ${staff.assignedClassId}" : "No Class"}',
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
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1.0),
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
