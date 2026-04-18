import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/app_models.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(authServiceProvider).userProfileStream(user.uid);
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    final result = await _authService.signIn(email: email, password: password);
    if (result.isSuccess) {
      state = const AsyncValue.data(null);
      return true;
    } else {
      state = AsyncValue.error(result.errorMessage ?? 'Sign-in failed', StackTrace.current);
      return false;
    }
  }

  Future<bool> signUpAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String schoolName,
    required String district,
    required String block,
    required String address,
  }) async {
    state = const AsyncValue.loading();
    final result = await _authService.signUpAdmin(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      schoolName: schoolName,
      district: district,
      block: block,
      address: address,
    );
    if (result.isSuccess) {
      state = const AsyncValue.data(null);
      return true;
    } else {
      final message = result.errorMessage ?? 'Sign-up failed';
      if (message.contains('permission-denied') ||
          message.contains('Missing or insufficient permissions')) {
        state = AsyncValue.error(
          'Admin sign-up is blocked by Firestore rules. Publish the repo\'s firestore.rules file in Firebase Console, then try again.',
          StackTrace.current,
        );
      } else {
        state = AsyncValue.error(message, StackTrace.current);
      }
      return false;
    }
  }

  Future<bool> signUpTeacher({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String schoolCode,
    String classId = '',
    String subject = '',
  }) async {
    state = const AsyncValue.loading();
    final result = await _authService.signUpTeacher(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      schoolCode: schoolCode,
      classId: classId,
      subject: subject,
    );
    if (result.isSuccess) {
      state = const AsyncValue.data(null);
      return true;
    } else {
      state = AsyncValue.error(result.errorMessage ?? 'Sign-up failed', StackTrace.current);
      return false;
    }
  }

  Future<bool> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String schoolId,
    required String schoolName,
    required String classId,
    String subject = '',
  }) async {
    state = const AsyncValue.loading();
    final result = await _authService.createTeacherAccount(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      schoolId: schoolId,
      schoolName: schoolName,
      classId: classId,
      subject: subject,
    );
    if (result.isSuccess) {
      state = const AsyncValue.data(null);
      return true;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Teacher creation failed',
        StackTrace.current,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
