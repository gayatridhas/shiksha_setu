import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../providers/locale_provider.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../core/utils/academic_year_utils.dart';
import '../../core/utils/academic_year_utils.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    final name = profile?.fullName ?? 'Admin';
    final school = profile?.schoolName ?? 'Loading...';

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.cardWhite,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.menu_rounded, color: AppColors.navyPrimary),
                    const SizedBox(width: 12),
                    Text(
                      'ShikshaSetu',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
                    ),
                    const Spacer(),
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
                      icon: const Icon(Icons.notifications_outlined, color: AppColors.navyPrimary),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    InitialsAvatar(name: name, radius: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$school - Academic Year ${AcademicYearUtils.currentAcademicYear()}',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 24),
                    
                    _AdminQuickStat(
                      label: 'Total ${l10n.students}', 
                      value: '${stats.totalStudents}', 
                      icon: Icons.school_rounded, 
                      color: AppColors.navyPrimary
                    ),
                    const SizedBox(height: 12),
                    _AdminQuickStat(
                      label: "Today's School ${l10n.attendance}", 
                      value: '${stats.attendanceRate.round()}%', 
                      icon: Icons.how_to_reg_rounded, 
                      color: AppColors.presentGreen
                    ),
                    const SizedBox(height: 12),
                    _AdminQuickStat(
                      label: '${l10n.mdm} Served Today', 
                      value: '${stats.mealsToday}', 
                      icon: Icons.restaurant_rounded, 
                      color: AppColors.accentBlue
                    ),
                    const SizedBox(height: 12),
                    _AdminQuickStat(
                      label: '${l10n.staff} ${l10n.present}', 
                      value: '${stats.staffPresent}/${stats.staffTotal}', 
                      icon: Icons.badge_rounded, 
                      color: AppColors.warningOrange
                    ),
                    const SizedBox(height: 12),
                    _AdminQuickStat(
                      label: '${l10n.leave} Requests Pending', 
                      value: '${stats.leavePending}', 
                      icon: Icons.event_note_rounded, 
                      color: AppColors.warningRed
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminQuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _AdminQuickStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
