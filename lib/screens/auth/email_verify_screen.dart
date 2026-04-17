import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  Timer? _timer;
  bool _canResend = false;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Periodically check if verified
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final verified = await ref.read(authServiceProvider).reloadUser();
      if (verified && mounted) {
        timer.cancel();
        context.go('/splash'); // Let splash handle re-routing
      }
    });
  }

  void _startTimer() {
    setState(() {
      _canResend = false;
      _countdown = 60;
    });
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.navyPrimary),
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: AppColors.lightBlue, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_unread_rounded, size: 60, color: AppColors.navyPrimary),
              ),
              const SizedBox(height: 40),
              Text(
                'Verify Your Email',
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.navyPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'We have sent a verification link to:',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: AppColors.textGray, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                ref.read(authServiceProvider).currentUser?.email ?? 'your email',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navyPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Please click the link in that email to secure your account and proceed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: AppColors.textGray, height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _canResend
                      ? () async {
                          await ref.read(authServiceProvider).resendVerificationEmail();
                          _startTimer();
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _canResend ? AppColors.navyPrimary : AppColors.borderGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _canResend ? 'Resend Verification' : 'Resend in ${_countdown}s',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _canResend ? AppColors.navyPrimary : AppColors.textGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Waiting for verification...', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textGray)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
