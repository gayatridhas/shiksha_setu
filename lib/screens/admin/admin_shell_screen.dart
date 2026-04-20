import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'admin_home_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_students_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_meals_screen.dart';

final adminTabProvider = StateProvider<int>((ref) => 0);

class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(adminTabProvider);

    final tabs = [
      const AdminHomeScreen(),
      const AdminStaffScreen(),
      const AdminStudentsScreen(),
      const AdminMealsScreen(),
      const AdminReportsScreen(),
    ];

    return Scaffold(
      body: tabs[currentTab],
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: currentTab,
        onTap: (i) => ref.read(adminTabProvider.notifier).state = i,
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _AdminBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.navyPrimary,
        unselectedItemColor: AppColors.textGray,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        elevation: 0,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'HOME'),
          BottomNavigationBarItem(icon: const Icon(Icons.people_rounded), label: l10n.staff.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.school_rounded), label: l10n.students.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.restaurant_rounded), label: l10n.mdm.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_rounded), label: l10n.reports.toUpperCase()),
        ],
      ),
    );
  }
}
