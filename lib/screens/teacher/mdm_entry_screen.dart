import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_providers.dart';
import '../../widgets/initials_avatar.dart';

// --- Local State for MDM Entry ---
final localMdmProvider = StateNotifierProvider.family<LocalMdmNotifier, List<MdmClassEntry>, List<MdmClassEntry>>((ref, initial) {
  return LocalMdmNotifier(initial);
});

class LocalMdmNotifier extends StateNotifier<List<MdmClassEntry>> {
  LocalMdmNotifier(List<MdmClassEntry> initial) : super(initial);

  void updateCount(String classId, int count) {
    state = [
      for (final e in state)
        if (e.classId == classId)
          MdmClassEntry(classId: e.classId, className: e.className, mealCount: count)
        else
          e,
    ];
  }
}

class MdmEntryScreen extends ConsumerStatefulWidget {
  const MdmEntryScreen({super.key});

  @override
  ConsumerState<MdmEntryScreen> createState() => _MdmEntryScreenState();
}

class _MdmEntryScreenState extends ConsumerState<MdmEntryScreen> {
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // For now, we assume fixed classes or fetch standard ones
    // In a real app, we'd fetch actual classes from the school
    final initialClasses = [
      MdmClassEntry(classId: '1', className: 'Class I'),
      MdmClassEntry(classId: '2', className: 'Class II'),
      MdmClassEntry(classId: '3', className: 'Class III'),
      MdmClassEntry(classId: '4', className: 'Class IV'),
      MdmClassEntry(classId: '5', className: 'Class V'),
    ];

    final entries = ref.watch(localMdmProvider(initialClasses));
    final total = entries.fold(0, (sum, e) => sum + e.mealCount);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AppHeader(profile: profile)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _TitleSection()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _MenuCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _KitchenStatus()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _AttendanceLogCard(
                  entries: entries,
                  total: total,
                  onCountChanged: (classId, count) {
                    ref.read(localMdmProvider(initialClasses).notifier).updateCount(classId, count);
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _NotesField(controller: _notesCtrl)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _QualityBanner()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverToBoxAdapter(
                child: _SubmitSection(
                  isLoading: _isSubmitting,
                  onSubmit: () async {
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(firestoreServiceProvider).submitMdm(
                            schoolId: profile.schoolId,
                            entries: entries,
                            menu: 'Standard Daily Menu', // Fetch from backend in future
                            notes: _notesCtrl.text,
                            submittedBy: profile.fullName,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('MDM entry submitted successfully')),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
                ),
              ),
            ),
          ],
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

class _TitleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATIVE RECORD',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textGray,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mid-Day Meal',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CURRENT DATE',
                    style: GoogleFonts.inter(fontSize: 9, color: AppColors.textGray, letterSpacing: 0.5),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(DateTime.now()),
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEAL MENU OF THE DAY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rice, Vegetable Dal, Seasonal Sabzi',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.restaurant_menu_rounded, size: 22, color: AppColors.navyPrimary),
        ],
      ),
    );
  }
}

class _KitchenStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.navyPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'STATUS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active Kitchen',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}

class _AttendanceLogCard extends StatelessWidget {
  final List<MdmClassEntry> entries;
  final int total;
  final void Function(String classId, int count) onCountChanged;

  const _AttendanceLogCard({
    required this.entries,
    required this.total,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Log',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.presentGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'VERIFIED INPUT',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return _ClassCountRow(
              roman: romanNumerals[i % romanNumerals.length],
              classEntry: e,
              onChanged: (v) => onCountChanged(e.classId, v),
            );
          }),
          const Divider(color: AppColors.borderGray),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL STUDENTS FED',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.3),
              ),
              Text(
                total == 0 ? '--' : '$total',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassCountRow extends StatefulWidget {
  final String roman;
  final MdmClassEntry classEntry;
  final void Function(int) onChanged;

  const _ClassCountRow({
    required this.roman,
    required this.classEntry,
    required this.onChanged,
  });

  @override
  State<_ClassCountRow> createState() => _ClassCountRowState();
}

class _ClassCountRowState extends State<_ClassCountRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.classEntry.mealCount > 0 ? '${widget.classEntry.mealCount}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.navyPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                widget.roman,
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRIMARY DIVISION', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textGray, letterSpacing: 0.5)),
                Text(widget.classEntry.className, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                widget.onChanged(parsed);
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                hintText: '0',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.navyPrimary),
              const SizedBox(width: 8),
              Text(
                'SPECIAL ADMINISTRATIVE NOTES',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter any discrepancies or quality notes...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textGray),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderGray)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyPrimary, AppColors.accentBlue.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'KITCHEN QUALITY STANDARD',
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.6), letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          Text(
            '"Ensuring every child receives nutrition today for a better tomorrow."',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white, fontStyle: FontStyle.italic, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SubmitSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSubmit;
  const _SubmitSection({required this.isLoading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: isLoading ? null : onSubmit,
          icon: isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.verified_rounded, size: 18),
          label: Text(isLoading ? 'Submitting...' : 'Submit & Verify Entry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'By clicking submit, you confirm the data is accurate according to the school records.',
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textGray, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
