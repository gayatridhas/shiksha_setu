import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../providers/firestore_providers.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/initials_avatar.dart';

class MdmEntryScreen extends ConsumerStatefulWidget {
  const MdmEntryScreen({super.key});

  @override
  ConsumerState<MdmEntryScreen> createState() => _MdmEntryScreenState();
}

class _MdmEntryScreenState extends ConsumerState<MdmEntryScreen> {
  final _mealCountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  AppUser? _profile;
  SchoolModel? _school;
  MdmClassRecord? _existingRecord;
  int _presentCount = 0;
  int _classStrength = 0;
  String? _selectedMenu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(showErrorSnackBar: false);
    });
  }

  @override
  void dispose() {
    _mealCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showErrorSnackBar = true}) async {
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
          _loadError = 'Unable to load your teacher profile right now.';
        });
        return;
      }

      final classId = profile.classId;
      if (classId == null || classId.isEmpty) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _loadError = null;
        });
        return;
      }

      final firestore = ref.read(firestoreServiceProvider);
      final school = await firestore.getSchool(profile.schoolId);
      if (!mounted) return;

      if (school == null) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _loadError = 'School configuration could not be loaded.';
        });
        return;
      }

      final presentCount = await firestore.getTodayPresentCountForClass(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      final classStrength = await firestore.getActiveStudentCountForClass(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      final existingRecord = await firestore.getTodayMdmRecordForClass(
        profile.schoolId,
        classId,
      );
      if (!mounted) return;

      _mealCountController.text =
          existingRecord != null && existingRecord.mealCount > 0
              ? existingRecord.mealCount.toString()
              : '';
      _notesController.text = existingRecord?.notes ?? '';

      final menuItems = school.menuItems;
      final initialMenu = existingRecord?.menu;
      if (initialMenu != null && menuItems.contains(initialMenu)) {
        _selectedMenu = initialMenu;
      } else if (menuItems.isNotEmpty) {
        _selectedMenu = menuItems.first;
      } else {
        _selectedMenu = null;
      }

      setState(() {
        _profile = profile;
        _school = school;
        _existingRecord = existingRecord;
        _presentCount = presentCount;
        _classStrength = classStrength;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load MDM data right now. Please try again.';
      });
      if (showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load MDM data. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final profile = _profile;
    final school = _school;
    final classId = profile?.classId;
    final menu = _selectedMenu;
    final mealCount = int.tryParse(_mealCountController.text.trim());

    if (profile == null || school == null || classId == null || classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assigned class data is not available yet.'),
        ),
      );
      return;
    }

    if (school.menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No menu items are configured for this school yet.'),
        ),
      );
      return;
    }

    if (mealCount == null || mealCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid meal count greater than zero.'),
        ),
      );
      return;
    }

    if (mealCount > _classStrength && _classStrength > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meal count cannot exceed class strength of $_classStrength students.',
          ),
        ),
      );
      return;
    }

    if (menu == null || menu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the menu item for today.'),
        ),
      );
      return;
    }

    if (mealCount > _presentCount) {
      final shouldContinue = await _showDiscrepancyDialog(mealCount, _presentCount);
      if (!mounted) return;
      if (!shouldContinue) {
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(firestoreServiceProvider).saveTeacherMdmEntry(
            schoolId: profile.schoolId,
            classId: classId,
            className: classId,
            mealCount: mealCount,
            presentCount: _presentCount,
            menu: menu,
            notes: _notesController.text.trim(),
            submittedBy: profile.fullName,
          );
      if (!mounted) return;

      await _loadData(showErrorSnackBar: false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MDM entry saved successfully'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save MDM entry right now. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _showDiscrepancyDialog(int mealCount, int presentCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Meal Count'),
        content: Text(
          'Meal count ($mealCount) is higher than students present ($presentCount). Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const _MdmLoadingState(),
          error: (_, __) => _MdmMessageState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load your profile',
            message: 'Please try again to continue with today\'s MDM entry.',
            actionLabel: 'Retry',
            onPressed: _loadData,
          ),
          data: (_) {
            if (_isLoading) {
              return const _MdmLoadingState();
            }

            if (_loadError != null) {
              return _MdmMessageState(
                icon: Icons.cloud_off_rounded,
                title: 'MDM data unavailable',
                message: _loadError!,
                actionLabel: 'Retry',
                onPressed: _loadData,
              );
            }

            if (_profile?.classId == null || _profile!.classId!.isEmpty) {
              return _MdmMessageState(
                icon: Icons.class_outlined,
                title: 'No class assigned',
                message: 'Your account does not have an assigned class yet.',
                actionLabel: 'Reload',
                onPressed: _loadData,
              );
            }

            final menuItems = _school?.menuItems ?? const [];
            if (menuItems.isEmpty) {
              return _MdmMessageState(
                icon: Icons.restaurant_menu_outlined,
                title: 'Menu not configured',
                message: 'Ask the school admin to configure menu items before submitting MDM.',
                actionLabel: 'Reload',
                onPressed: _loadData,
              );
            }

            final profile = _profile!;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _AppHeader(
                    profile: profile,
                    onBack: () => Navigator.of(context).pop(),
                    onRefresh: () => _loadData(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _HeroCard(
                      classId: profile.classId!,
                      presentCount: _presentCount,
                      classStrength: _classStrength,
                    ),
                  ),
                ),
                if (_existingRecord != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SubmittedBanner(record: _existingRecord!),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _MealFormCard(
                      mealCountController: _mealCountController,
                      notesController: _notesController,
                      menuItems: menuItems,
                      selectedMenu: _selectedMenu,
                      onMenuChanged: (value) {
                        setState(() => _selectedMenu = value);
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _SubmitSection(
                      isLoading: _isSubmitting,
                      onSubmit: _submit,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  final AppUser profile;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _AppHeader({
    required this.profile,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.navyPrimary,
            ),
          ),
          Text(
            'ShikshaSetu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navyPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.navyPrimary,
            ),
          ),
          InitialsAvatar(name: profile.fullName, radius: 16),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String classId;
  final int presentCount;
  final int classStrength;

  const _HeroCard({
    required this.classId,
    required this.presentCount,
    required this.classStrength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF1B4F9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MID-DAY MEAL ENTRY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            classId,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Students Present Today',
                  value: '$presentCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  label: 'Class Strength',
                  value: '$classStrength',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedBanner extends StatelessWidget {
  final MdmClassRecord record;

  const _SubmittedBanner({required this.record});

  @override
  Widget build(BuildContext context) {
    final submittedAt = DateFormat('dd MMM yyyy, hh:mm a').format(record.submittedAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successGreenLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.successGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Already submitted today',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saved $submittedAt with ${record.mealCount} meals for ${record.menu}. You can edit and resave if needed.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealFormCard extends StatelessWidget {
  final TextEditingController mealCountController;
  final TextEditingController notesController;
  final List<String> menuItems;
  final String? selectedMenu;
  final ValueChanged<String?> onMenuChanged;

  const _MealFormCard({
    required this.mealCountController,
    required this.notesController,
    required this.menuItems,
    required this.selectedMenu,
    required this.onMenuChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S MDM DETAILS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textGray,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: mealCountController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Meal Count',
              hintText: 'Enter the number of meals served',
              prefixIcon: const Icon(Icons.restaurant_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedMenu,
            items: menuItems
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: onMenuChanged,
            decoration: InputDecoration(
              labelText: 'Menu Item',
              prefixIcon: const Icon(Icons.menu_book_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notesController,
            maxLines: 4,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: 'Add any notes or discrepancies for today',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 64),
                child: Icon(Icons.edit_note_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSubmit;

  const _SubmitSection({
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: isLoading ? null : onSubmit,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.cloud_upload_rounded),
          label: Text(isLoading ? 'Saving...' : 'Save MDM Entry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This will save today\'s meal count against your assigned class.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textGray,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MdmLoadingState extends StatelessWidget {
  const _MdmLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _ShimmerBox(height: 68, radius: 0),
        SizedBox(height: 16),
        _ShimmerBox(height: 180),
        SizedBox(height: 12),
        _ShimmerBox(height: 82),
        SizedBox(height: 12),
        _ShimmerBox(height: 280),
        SizedBox(height: 12),
        _ShimmerBox(height: 52),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.height,
    this.radius = 16,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
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
              AppColors.borderGray.withValues(alpha: 0.15),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class _MdmMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function({bool showErrorSnackBar}) onPressed;

  const _MdmMessageState({
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
