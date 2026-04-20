import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../providers/locale_provider.dart';
import '../../models/app_models.dart';
import '../../widgets/admin_header.dart';
import '../../core/utils/academic_year_utils.dart';
import 'admin_mdm_setup_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final stats = ref.watch(dashboardStatsProvider).value ?? const DashboardStats();
    final school = ref.watch(schoolProvider).value;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    final name = profile?.fullName ?? 'Admin';
    final schoolName = profile?.schoolName ?? 'Loading...';

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AdminHeader(
                extraActions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.navyPrimary),
                    onPressed: () {},
                  ),
                ],
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
                      '$schoolName - Academic Year ${AcademicYearUtils.currentAcademicYear()}',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 24),
                    if (profile != null)
                      FutureBuilder<DailyMealModel?>(
                        future: ref
                            .read(firestoreServiceProvider)
                            .getDailyMeal(profile.schoolId),
                        builder: (context, snapshot) {
                          final mealName = snapshot.data?.menuItem;
                          final notes = snapshot.data?.notes;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MealSetupCard(
                              mealName: mealName,
                              notes: notes,
                              isConfigured: mealName != null && mealName.isNotEmpty,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AdminMdmSetupScreen(),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    
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
              color: color.withValues(alpha: 0.1),
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

class _MealSetupCard extends StatelessWidget {
  final String? mealName;
  final String? notes;
  final bool isConfigured;
  final VoidCallback onTap;

  const _MealSetupCard({
    required this.mealName,
    required this.notes,
    required this.isConfigured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isConfigured ? AppColors.presentGreen : AppColors.warningRed;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
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
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Meal',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mealName ?? 'Meal Not Set',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                    if ((notes ?? '').isNotEmpty)
                      Text(
                        notes!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textGray,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isConfigured ? 'READY' : 'SET NOW',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
