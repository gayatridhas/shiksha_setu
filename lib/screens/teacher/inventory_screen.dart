import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/academic_year_utils.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/initials_avatar.dart';

enum InventoryFilter { all, received, pending }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final String _academicYear = AcademicYearUtils.currentAcademicYear();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  AppUser? _profile;
  List<DistributionStudentModel> _students = const [];
  String _itemType = 'uniform';
  InventoryFilter _filter = InventoryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventory(showSnackBar: false);
    });
  }

  Future<void> _loadInventory({bool showSnackBar = true}) async {
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
          _loadError = 'Unable to load your profile right now.';
        });
        return;
      }

      final classId = profile.classId;
      if (classId == null || classId.isEmpty) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _students = const [];
        });
        return;
      }

      final roster = await ref.read(firestoreServiceProvider).getDistributionRoster(
            profile.schoolId,
            _academicYear,
            classId: classId,
          );
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _students = roster;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load inventory data right now.';
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load inventory data. Please try again.'),
          ),
        );
      }
    }
  }

  void _toggleReceived(String studentId, bool value) {
    setState(() {
      _students = _students.map((student) {
        if (student.studentId != studentId) return student;
        return DistributionStudentModel(
          studentId: student.studentId,
          fullName: student.fullName,
          rollNo: student.rollNo,
          srn: student.srn,
          uniformReceived:
              _itemType == 'uniform' ? value : student.uniformReceived,
          shoesReceived: _itemType == 'shoes' ? value : student.shoesReceived,
          uniformSize: student.uniformSize,
          shoesSize: student.shoesSize,
        );
      }).toList();
    });
  }

  void _updateSize(String studentId, String size) {
    setState(() {
      _students = _students.map((student) {
        if (student.studentId != studentId) return student;
        return DistributionStudentModel(
          studentId: student.studentId,
          fullName: student.fullName,
          rollNo: student.rollNo,
          srn: student.srn,
          uniformReceived: student.uniformReceived,
          shoesReceived: student.shoesReceived,
          uniformSize: _itemType == 'uniform' ? size : student.uniformSize,
          shoesSize: _itemType == 'shoes' ? size : student.shoesSize,
        );
      }).toList();
    });
  }

  Future<void> _saveAll() async {
    final profile = _profile;
    final classId = profile?.classId;
    if (profile == null || classId == null || classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assigned class data is unavailable.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(firestoreServiceProvider).syncDistributionRecords(
            profile.schoolId,
            _academicYear,
            classId,
            _students,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory data synced successfully.'),
        ),
      );
      await _loadInventory(showSnackBar: false);
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save inventory changes right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<DistributionStudentModel> get _filteredStudents {
    return _students.where((student) {
      final isReceived = _itemType == 'uniform'
          ? student.uniformReceived
          : student.shoesReceived;

      switch (_filter) {
        case InventoryFilter.received:
          return isReceived;
        case InventoryFilter.pending:
          return !isReceived;
        case InventoryFilter.all:
          return true;
      }
    }).toList();
  }

  int get _receivedCount {
    return _students.where((student) {
      return _itemType == 'uniform'
          ? student.uniformReceived
          : student.shoesReceived;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const _InventoryLoadingState(),
          error: (_, __) => _InventoryMessageState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load your profile',
            message: 'Please try again to open the inventory ledger.',
            actionLabel: 'Retry',
            onPressed: _loadInventory,
          ),
          data: (_) {
            if (_isLoading) {
              return const _InventoryLoadingState();
            }

            if (_loadError != null) {
              return _InventoryMessageState(
                icon: Icons.cloud_off_rounded,
                title: 'Inventory unavailable',
                message: _loadError!,
                actionLabel: 'Retry',
                onPressed: _loadInventory,
              );
            }

            final profile = _profile;
            if (profile == null || profile.classId == null || profile.classId!.isEmpty) {
              return _InventoryMessageState(
                icon: Icons.class_outlined,
                title: 'No class assigned',
                message: 'Your account does not have an assigned class yet.',
                actionLabel: 'Reload',
                onPressed: _loadInventory,
              );
            }

            final visibleStudents = _filteredStudents;

            return RefreshIndicator(
              onRefresh: () => _loadInventory(showSnackBar: false),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _AppHeader(profile: profile),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ProgressBanner(
                        itemType: _itemType,
                        year: _academicYear,
                        receivedCount: _receivedCount,
                        totalCount: _students.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ItemTypeTabs(
                        selected: _itemType,
                        onChanged: (value) {
                          setState(() => _itemType = value);
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ClassHeader(
                        classId: profile.classId!,
                        studentCount: _students.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _FilterChips(
                        selected: _filter,
                        onChanged: (value) {
                          setState(() => _filter = value);
                        },
                      ),
                    ),
                  ),
                  if (visibleStudents.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InlineEmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'No students match the current filter.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final student = visibleStudents[index];
                            return _StudentDistributionRow(
                              itemType: _itemType,
                              student: student,
                              onSizeChanged: (value) =>
                                  _updateSize(student.studentId, value),
                              onReceivedChanged: (value) =>
                                  _toggleReceived(student.studentId, value),
                            );
                          },
                          childCount: visibleStudents.length,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverToBoxAdapter(
                      child: _ActionButtons(
                        isSaving: _isSaving,
                        onSave: _saveAll,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
          InitialsAvatar(name: profile.fullName, radius: 16),
        ],
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final String itemType;
  final String year;
  final int receivedCount;
  final int totalCount;

  const _ProgressBanner({
    required this.itemType,
    required this.year,
    required this.receivedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalCount == 0 ? 0 : ((receivedCount / totalCount) * 100).round();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyPrimary, Color(0xFF1B4F9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${itemType.toUpperCase()} DISTRIBUTION',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$progress%',
            style: GoogleFonts.poppins(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$receivedCount of $totalCount students received ${itemType == 'uniform' ? 'uniforms' : 'shoes'}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Academic Year $year',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTypeTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ItemTypeTabs({
    required this.selected,
    required this.onChanged,
  });

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

  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textGray,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
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

  const _ClassHeader({
    required this.classId,
    required this.studentCount,
  });

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
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$studentCount students in this roster',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Text(
            AcademicYearUtils.currentAcademicYear(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navyPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final InventoryFilter selected;
  final ValueChanged<InventoryFilter> onChanged;

  const _FilterChips({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _FilterChipItem(
          label: 'All',
          selected: selected == InventoryFilter.all,
          onTap: () => onChanged(InventoryFilter.all),
        ),
        _FilterChipItem(
          label: 'Received',
          selected: selected == InventoryFilter.received,
          onTap: () => onChanged(InventoryFilter.received),
        ),
        _FilterChipItem(
          label: 'Pending',
          selected: selected == InventoryFilter.pending,
          onTap: () => onChanged(InventoryFilter.pending),
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navyPrimary : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textGray,
          ),
        ),
      ),
    );
  }
}

class _StudentDistributionRow extends StatelessWidget {
  final String itemType;
  final DistributionStudentModel student;
  final ValueChanged<String> onSizeChanged;
  final ValueChanged<bool> onReceivedChanged;

  const _StudentDistributionRow({
    required this.itemType,
    required this.student,
    required this.onSizeChanged,
    required this.onReceivedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isReceived =
        itemType == 'uniform' ? student.uniformReceived : student.shoesReceived;
    final selectedSize =
        itemType == 'uniform' ? student.uniformSize : student.shoesSize;
    final sizeOptions = itemType == 'uniform'
        ? const ['XS', 'S', 'M', 'L', 'XL']
        : const ['4', '5', '6', '7', '8', '9', '10'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                InitialsAvatar(name: student.fullName, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Roll No: ${student.rollNo} • SRN: ${student.srn}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: isReceived,
                  onChanged: (value) => onReceivedChanged(value ?? false),
                  activeColor: AppColors.presentGreen,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSize,
                    items: sizeOptions
                        .map(
                          (size) => DropdownMenuItem<String>(
                            value: size,
                            child: Text(size),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onSizeChanged(value);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: itemType == 'uniform'
                          ? 'Uniform Size'
                          : 'Shoe Size',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isReceived
                        ? AppColors.successGreenLight
                        : AppColors.warningRedLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isReceived ? 'Received' : 'Pending',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isReceived
                          ? AppColors.successGreen
                          : AppColors.warningRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const _ActionButtons({
    required this.isSaving,
    required this.onSave,
  });

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
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text('Save Inventory Changes'),
      ),
    );
  }
}

class _InventoryLoadingState extends StatelessWidget {
  const _InventoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _InventoryShimmerBox(height: 64, radius: 0),
        SizedBox(height: 16),
        _InventoryShimmerBox(height: 170),
        SizedBox(height: 16),
        _InventoryShimmerBox(height: 52),
        SizedBox(height: 16),
        _InventoryShimmerBox(height: 52),
        SizedBox(height: 16),
        _InventoryShimmerBox(height: 110),
        SizedBox(height: 10),
        _InventoryShimmerBox(height: 110),
      ],
    );
  }
}

class _InventoryShimmerBox extends StatefulWidget {
  final double height;
  final double radius;

  const _InventoryShimmerBox({
    required this.height,
    this.radius = 16,
  });

  @override
  State<_InventoryShimmerBox> createState() => _InventoryShimmerBoxState();
}

class _InventoryShimmerBoxState extends State<_InventoryShimmerBox>
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
              AppColors.borderGray.withValues(alpha: 0.16),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class _InventoryMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function({bool showSnackBar}) onPressed;

  const _InventoryMessageState({
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

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineEmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textGray),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
