import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../main.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signIn(
          _emailController.text,
          _passwordController.text,
        );

    if (success && mounted) {
      // Navigation is handled by the router listener
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final firebaseState = ref.watch(firebaseInitProvider);
    final canAttemptLogin = firebaseState.isReady;

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<String>(
                      value: currentLocale.languageCode,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.language_rounded, color: AppColors.navyPrimary, size: 20),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                        DropdownMenuItem(value: 'mr', child: Text('मराठी')),
                      ],
                      onChanged: (lang) {
                        if (lang != null) {
                          ref.read(localeProvider.notifier).setLocale(lang);
                        }
                      },
                    ),
                  ],
                ),
                if (!canAttemptLogin) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warningRed.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warningRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            firebaseState.errorMessage ??
                                'Login is unavailable because Firebase has not finished initializing.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.warningRed,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.navyPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.security_rounded, size: 40, color: AppColors.navyPrimary),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    l10n.signIn,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Access your school dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  l10n.email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'name@school.gov.in',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter email';
                    if (!value.contains('@')) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.password,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter password';
                    if (value.length < 6) return 'Password too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Remember Me', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        l10n.forgotPassword,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (authState.hasError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.warningRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.warningRed, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authState.error.toString(),
                            style: GoogleFonts.inter(color: AppColors.warningRed, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading || !canAttemptLogin ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            l10n.login,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.dontHaveAccount, style: GoogleFonts.inter(color: AppColors.textGray)),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: Text(
                        l10n.signUp,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
