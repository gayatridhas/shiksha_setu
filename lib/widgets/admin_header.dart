import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../providers/locale_provider.dart';
import 'profile_menu.dart';

class AdminHeader extends ConsumerWidget {
  final String title;
  final List<Widget>? extraActions;

  const AdminHeader({
    super.key,
    this.title = 'ShikshaSetu',
    this.extraActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: AppColors.navyPrimary, size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
          const Spacer(),
          if (extraActions != null) ...extraActions!,
          
          // Language Picker (Standard for Admin Header)
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
          const SizedBox(width: 4),
          
          // Profile Menu
          const ProfileMenu(),
        ],
      ),
    );
  }
}
