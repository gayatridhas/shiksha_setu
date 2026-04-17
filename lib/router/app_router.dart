import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/email_verify_screen.dart';
import '../screens/teacher/teacher_dashboard_screen.dart';
import '../screens/teacher/student_attendance_screen.dart';
import '../screens/teacher/mdm_entry_screen.dart';
import '../screens/teacher/inventory_screen.dart';
import '../screens/teacher/teacher_reports_screen.dart';
import '../screens/admin/admin_shell_screen.dart';
import '../providers/auth_provider.dart';
import '../models/app_models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Use read here to avoid recreating the GoRouter instance on every auth change.
  // The refreshListenable will still trigger redirects correctly.
  final authNotifier = ref.read(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) => authNotifier._redirect(context, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerifyScreen(),
      ),
      // Teacher routes
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: '/teacher/home',
            builder: (context, state) => const TeacherDashboardScreen(),
          ),
          GoRoute(
            path: '/teacher/attendance',
            builder: (context, state) => const StudentAttendanceScreen(),
          ),
          GoRoute(
            path: '/teacher/mdm',
            builder: (context, state) => const MdmEntryScreen(),
          ),
          GoRoute(
            path: '/teacher/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/teacher/reports',
            builder: (context, state) => const TeacherReportsScreen(),
          ),
        ],
      ),
      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminShellScreen(),
      ),
    ],
  );
});

final routerNotifierProvider = ChangeNotifierProvider((ref) => RouterNotifier(ref));

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      if (previous?.value != next.value) {
        notifyListeners();
      }
    });
    // Also listen to profile changes
    _ref.listen(userProfileProvider, (previous, next) {
      if (previous?.value != next.value) {
        notifyListeners();
      }
    });
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final profileState = _ref.read(userProfileProvider);

    final user = authState.value;
    final profile = profileState.value;

    final isSplash = state.matchedLocation == '/splash';
    final isLoggingIn = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/forgot-password';

    // 1. If still loading auth state, stay on splash ONLY for a short while
    if (authState.isLoading) {
      return isSplash ? null : '/splash';
    }

    // 2. Auth Logic
    if (user == null) {
      // If we are on Splash but Auth is NOT loading and NOT logged in -> go to Login
      if (isSplash) return '/login';
      return isLoggingIn ? null : '/login';
    }

    // 3. Email Verification
    if (!user.emailVerified) {
      if (state.matchedLocation == '/verify-email') return null;
      return '/verify-email';
    }

    // 4. Loading Profile (Database)
    if (profileState.isLoading || profileState.isRefreshing) {
      // Use splash as a buffer while loading the database record
      return isSplash ? null : '/splash';
    }

    // 5. Profile Check & Immediate Redirect
    // If profile is null but user is verified, they are likely a new user 
    // whose profile is being created. Don't hang! Go to Home.
    if (isLoggingIn || isSplash || state.matchedLocation == '/verify-email' || state.matchedLocation == '/') {
      final target = profile?.role == UserRole.admin ? '/admin' : '/teacher/home';
      debugPrint('DEBUG: [Router] Target path: $target');
      return target;
    }

    // 6. Role-based Access Guard
    final isTeacherRoute = state.matchedLocation.startsWith('/teacher');
    final isAdminRoute = state.matchedLocation.startsWith('/admin');

    if (profile?.role == UserRole.admin && isTeacherRoute) return '/admin';
    if (profile?.role == UserRole.teacher && isAdminRoute) return '/teacher/home';

    return null;
  }
}

class TeacherShell extends StatefulWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _currentIndex = 0;

  final List<String> _routes = [
    '/teacher/home',
    '/teacher/attendance',
    '/teacher/mdm',
    '/teacher/inventory',
    '/teacher/reports',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _TeacherBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.go(_routes[index]);
        },
      ),
    );
  }
}

class _TeacherBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _TeacherBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1B3A6B),
        unselectedItemColor: const Color(0xFF888888),
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        elevation: 0,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'HOME'),
          BottomNavigationBarItem(icon: const Icon(Icons.calendar_today_rounded), label: l10n.attendance.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.restaurant_rounded), label: l10n.mdm.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_rounded), label: l10n.inventory.toUpperCase()),
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_rounded), label: l10n.reports.toUpperCase()),
        ],
      ),
    );
  }
}
