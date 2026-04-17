import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../widgets/initials_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';

// --- Local State for Inventory Distribution ---
final localInventoryProvider = StateNotifierProvider.family<LocalInventoryNotifier, List<DistributionStudentModel>, List<DistributionStudentModel>>((ref, initial) {
  return LocalInventoryNotifier(initial);
});

class LocalInventoryNotifier extends StateNotifier<List<DistributionStudentModel>> {
  LocalInventoryNotifier(List<DistributionStudentModel> initial) : super(initial);

  void toggleUniform(String studentId) {
    state = [
      for (final s in state)
        if (s.studentId == studentId)
          DistributionStudentModel(
            studentId: s.studentId,
            fullName: s.fullName,
            srn: s.srn,
            uniformReceived: !s.uniformReceived,
            shoesReceived: s.shoesReceived,
          )
        else
          s,
    ];
  }

  void toggleShoes(String studentId) {
    state = [
      for (final s in state)
        if (s.studentId == studentId)
          DistributionStudentModel(
            studentId: s.studentId,
            fullName: s.fullName,
            srn: s.srn,
            uniformReceived: s.uniformReceived,
            shoesReceived: !s.shoesReceived,
          )
        else
          s,
    ];
  }

  void markAllUniform() {
    state = [
      for (final s in state)
        DistributionStudentModel(
          studentId: s.studentId,
          fullName: s.fullName,
          srn: s.srn,
          uniformReceived: true,
          shoesReceived: s.shoesReceived,
        ),
    ];
  }
}

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _itemType = 'uniform';
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final classId = profile.classId ?? 'Unknown';
    final currentYear = '2024-25';

    // Fetch live distribution data
    final distAsync = ref.watch(inventoryDistributionProvider((year: currentYear, classId: classId)));

    return distAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (backendStudents) {
        // Use local state for interaction
        final students = ref.watch(localInventoryProvider(backendStudents));

        final totalDistributed = students.where((s) => s.uniformReceived && s.shoesReceived).length;
        final progress = students.isEmpty ? 0 : (totalDistributed / students.length * 100).round();

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _AppHeader(profile: profile),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _ProgressBanner(progress: progress, year: currentYear)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _ItemTypeTabs(
                          selected: _itemType,
                          onChanged: (v) => setState(() => _itemType = v),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _ClassHeader(
                          classId: classId,
                          studentCount: students.length,
                          onBulkMark: () {
                            ref.read(localInventoryProvider(backendStudents).notifier).markAllUniform();
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _StudentDistributionRow(
                            student: students[i],
                            onToggleUniform: () {
                              HapticFeedback.lightImpact();
                              ref.read(localInventoryProvider(backendStudents).notifier).toggleUniform(students[i].studentId);
                            },
                            onToggleShoes: () {
                              HapticFeedback.lightImpact();
                              ref.read(localInventoryProvider(backendStudents).notifier).toggleShoes(students[i].studentId);
                            },
                          ),
                          childCount: students.length,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      sliver: SliverToBoxAdapter(
                        child: _ActionButtons(
                          isSaving: _isSaving,
                          onSave: () async {
                            setState(() => _isSaving = true);
                            try {
                              for (final s in students) {
                                await ref.read(firestoreServiceProvider).updateDistribution(
                                      profile.schoolId,
                                      currentYear,
                                      s.studentId,
                                      s.uniformReceived,
                                      s.shoesReceived,
                                    );
                              }
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Inventory data synced successfully')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sync Error: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _isSaving = false);
                            }
                          },
                        ),
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

class _AppHeader extends StatelessWidget {
  final AppUser profile;
  const _AppHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navyPrimary),
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
          InitialsAvatar(name: profile.fullName, radius: 16),
        ],
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final int progress;
  final String year;
  const _ProgressBanner({required this.progress, required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF1B4F9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISTRIBUTION PROGRESS',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.65), letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            '$progress%',
            style: GoogleFonts.poppins(fontSize: 44, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0),
          ),
          Text(
            'Academic Year $year',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

class _ItemTypeTabs extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  const _ItemTypeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          _Tab(
            icon: Icons.checkroom_rounded,
            label: 'Uniform',
            selected: selected == 'uniform',
            onTap: () => onChanged('uniform'),
          ),
          _Tab(
            icon: Icons.directions_walk_rounded,
            label: 'Shoes',
            selected: selected == 'shoes',
            onTap: () => onChanged('shoes'),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.navyPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textGray),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassHeader extends StatelessWidget {
  final String classId;
  final int studentCount;
  final VoidCallback onBulkMark;
  const _ClassHeader({required this.classId, required this.studentCount, required this.onBulkMark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Class $classId',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                '$studentCount Students enrolled',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onBulkMark,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, size: 14, color: AppColors.navyPrimary),
                const SizedBox(width: 6),
                Text('Bulk Mark', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentDistributionRow extends StatelessWidget {
  final DistributionStudentModel student;
  final VoidCallback onToggleUniform;
  final VoidCallback onToggleShoes;

  const _StudentDistributionRow({
    required this.student,
    required this.onToggleUniform,
    required this.onToggleShoes,
  });

  @override
  Widget build(BuildContext context) {
    final hasMismatch = (student.uniformReceived && !student.shoesReceived) ||
        (!student.uniformReceived && student.shoesReceived);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: hasMismatch ? AppColors.warningRed : Colors.transparent,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(name: student.fullName, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Text('SRN: ${student.srn}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray)),
                ],
              ),
            ),
            _DistButton(label: 'U', received: student.uniformReceived, onTap: onToggleUniform),
            const SizedBox(width: 8),
            _DistButton(label: 'S', received: student.shoesReceived, onTap: onToggleShoes),
          ],
        ),
      ),
    );
  }
}

class _DistButton extends StatelessWidget {
  final String label;
  final bool received;
  final VoidCallback onTap;
  const _DistButton({required this.label, required this.received, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: received ? AppColors.presentGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: received ? AppColors.presentGreen : AppColors.borderGray, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: received ? Colors.white : AppColors.textGray),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;
  const _ActionButtons({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save & Sync Ledger'),
      ),
    );
  }
}
