import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_header.dart';

class AdminMdmSetupScreen extends ConsumerStatefulWidget {
  const AdminMdmSetupScreen({super.key});

  @override
  ConsumerState<AdminMdmSetupScreen> createState() => _AdminMdmSetupScreenState();
}

class _AdminMdmSetupScreenState extends ConsumerState<AdminMdmSetupScreen> {
  final _notesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  AppUser? _profile;
  SchoolModel? _school;
  DailyMealModel? _dailyMeal;
  String? _selectedMeal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(showSnackBar: false);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showSnackBar = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await ref.read(userProfileProvider.future);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load your admin profile.';
        });
        return;
      }

      final firestore = ref.read(firestoreServiceProvider);
      final school = await firestore.getSchool(profile.schoolId);
      if (!mounted) return;

      final dailyMeal = await firestore.getDailyMeal(profile.schoolId);
      if (!mounted) return;

      final menuItems = school?.menuItems.isNotEmpty == true
          ? school!.menuItems
          : FirestoreService.defaultMenuItems;

      _notesController.text = dailyMeal?.notes ?? '';

      setState(() {
        _profile = profile;
        _school = school;
        _dailyMeal = dailyMeal;
        _selectedMeal = dailyMeal?.menuItem ?? menuItems.first;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load today\'s meal setup right now.';
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load MDM setup. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _saveMeal() async {
    final profile = _profile;
    final selectedMeal = _selectedMeal;

    if (profile == null || selectedMeal == null || selectedMeal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a meal before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(firestoreServiceProvider).setDailyMeal(
            schoolId: profile.schoolId,
            menuItem: selectedMeal,
            notes: _notesController.text.trim(),
            setBy: profile.uid,
          );
      if (!mounted) return;

      await _loadData(showSnackBar: false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s meal has been set.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save today\'s meal right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _school?.menuItems.isNotEmpty == true
        ? _school!.menuItems
        : FirestoreService.defaultMenuItems;
    final dateLabel = DateFormat('dd MMM yyyy, EEEE').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: Column(
        children: [
          const AdminHeader(title: 'Set Today\'s Meal'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _MessageState(message: _error!, onRetry: _loadData)
                    : RefreshIndicator(
                        onRefresh: () => _loadData(showSnackBar: false),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _HeaderCard(
                              dateLabel: dateLabel,
                              currentMeal: _dailyMeal?.menuItem,
                              notes: _dailyMeal?.notes,
                            ),
                            const SizedBox(height: 16),
                            Container(
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
                                    'Today\'s date',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dateLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedMeal,
                                    decoration: const InputDecoration(
                                      labelText: 'Today\'s meal',
                                      prefixIcon: Icon(Icons.restaurant_menu_rounded),
                                    ),
                                    items: menuItems
                                        .map(
                                          (item) => DropdownMenuItem<String>(
                                            value: item,
                                            child: Text(item),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedMeal = value);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _notesController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes',
                                      hintText: 'No meal today - holiday',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _saveMeal,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.navyPrimary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 52),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Set Meal for Today'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String dateLabel;
  final String? currentMeal;
  final String? notes;

  const _HeaderCard({
    required this.dateLabel,
    this.currentMeal,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF2758A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY MDM SETUP',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentMeal ?? 'Meal not set yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          if ((notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final Future<void> Function({bool showSnackBar}) onRetry;

  const _MessageState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.textGray),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
