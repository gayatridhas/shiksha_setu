import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _blockController = TextEditingController();
  final _addressController = TextEditingController();
  final _schoolCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _schoolNameController.dispose();
    _districtController.dispose();
    _blockController.dispose();
    _addressController.dispose();
    _schoolCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    bool success = false;
    if (_tabController.index == 0) {
      success = await ref.read(authNotifierProvider.notifier).signUpAdmin(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _nameController.text,
            phone: _phoneController.text,
            schoolName: _schoolNameController.text,
            district: _districtController.text,
            block: _blockController.text,
            address: _addressController.text,
          );
    } else {
      success = await ref.read(authNotifierProvider.notifier).signUpTeacher(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _nameController.text,
            phone: _phoneController.text,
            schoolCode: _schoolCodeController.text,
          );
    }

    if (success && mounted) {
      context.go('/verify-email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navyPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.signUp,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyPrimary,
                  ),
                ),
                Text(
                  'Join ShikshaSetu school network',
                  style: GoogleFonts.inter(fontSize: 16, color: AppColors.textGray),
                ),
                const SizedBox(height: 32),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.navyPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textGray,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: l10n.roleAdmin),
                      Tab(text: l10n.roleTeacher),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildLabel('Full Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'John Doe', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => v!.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel(l10n.email),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(hintText: 'email@domain.com', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => v!.isEmpty || !v.contains('@') ? 'Invalid email' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Phone Number'),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(hintText: '+91 00000 00000', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => v!.isEmpty ? 'Enter phone' : null,
                ),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_tabController.index == 0) ...[
                          const SizedBox(height: 20),
                          _buildLabel('School Name'),
                          TextFormField(
                            controller: _schoolNameController,
                            decoration: const InputDecoration(hintText: 'Government School', prefixIcon: Icon(Icons.school_outlined)),
                            validator: (v) => v!.isEmpty ? 'Enter school name' : null,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('District'),
                                    TextFormField(controller: _districtController, validator: (v) => v!.isEmpty ? 'Required' : null),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Block'),
                                    TextFormField(controller: _blockController, validator: (v) => v!.isEmpty ? 'Required' : null),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          _buildLabel('School Code'),
                          TextFormField(
                            controller: _schoolCodeController,
                            decoration: const InputDecoration(hintText: '6-digit unique code', prefixIcon: Icon(Icons.vpn_key_outlined)),
                            validator: (v) => v!.isEmpty ? 'Enter school code' : null,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildLabel(l10n.password),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Min. 8 characters', prefixIcon: Icon(Icons.lock_outline_rounded)),
                  validator: (v) => v!.length < 8 ? 'Min. 8 chars' : null,
                ),
                const SizedBox(height: 40),
                if (authState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(authState.error.toString(), style: GoogleFonts.inter(color: AppColors.warningRed)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: authState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(l10n.createAccount, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    );
  }
}
