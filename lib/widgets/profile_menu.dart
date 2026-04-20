import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/initials_avatar.dart';

class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        
        final name = profile.fullName;
        final role = profile.role.name.toUpperCase();

        return PopupMenuButton<String>(
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(authNotifierProvider.notifier).signOut();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: InitialsAvatar(name: name, radius: 18),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                  Text(
                    'ROLE: $role',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                   const Icon(Icons.logout_rounded, color: AppColors.warningRed, size: 20),
                   const SizedBox(width: 12),
                   Text(
                     'Logout',
                     style: GoogleFonts.inter(
                       fontSize: 14,
                       fontWeight: FontWeight.w600,
                       color: AppColors.warningRed,
                     ),
                   ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error_outline, color: AppColors.warningRed),
    );
  }
}
