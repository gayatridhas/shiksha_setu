import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_models.dart';
import '../core/utils/academic_year_utils.dart';
import '../firebase_options.dart';

class AuthService {
  // Safe getters to prevent crash if Firebase is not initialized
  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      debugPrint('CRITICAL: Accessing FirebaseAuth before initialization!');
      throw FirebaseException(plugin: 'auth', message: 'Firebase not initialized');
    }
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _db {
    if (Firebase.apps.isEmpty) {
      debugPrint('CRITICAL: Accessing FirebaseFirestore before initialization!');
      throw FirebaseException(plugin: 'firestore', message: 'Firebase not initialized');
    }
    return FirebaseFirestore.instance;
  }

  bool get _isFirebaseInitialized {
    final initialized = Firebase.apps.isNotEmpty;
    if (!initialized) {
      debugPrint('WARNING: Firebase is NOT initialized.');
    }
    return initialized;
  }

  // ─── Auth State ─────────────────────────────────────────────
  Stream<User?> get authStateChanges {
    if (!_isFirebaseInitialized) return Stream.value(null);
    return _auth.authStateChanges();
  }

  User? get currentUser {
    if (!_isFirebaseInitialized) return null;
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn {
    if (!_isFirebaseInitialized) return false;
    return currentUser != null;
  }

  // ─── Sign In ────────────────────────────────────────────────
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isFirebaseInitialized) return AuthResult.error('Firebase not configured. Please check your setup.');
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user == null) return AuthResult.error('Sign-in failed. Please try again.');
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // ─── Admin Sign Up (creates school + account) ────────────────
  Future<AuthResult> signUpAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String schoolName,
    required String district,
    required String block,
    required String address,
  }) async {
    if (!_isFirebaseInitialized) return AuthResult.error('Firebase not configured.');
    User? createdUser;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = cred.user;
      if (createdUser == null) {
        return AuthResult.error('Sign-up failed. Please try again.');
      }

      final uid = createdUser.uid;
      final schoolCode = _generateSchoolCode();
      final schoolRef = _db.collection('schools').doc();
      final batch = _db.batch();

      batch.set(schoolRef, {
        'name': schoolName,
        'district': district,
        'block': block,
        'address': address,
        'schoolCode': schoolCode,
        'adminUid': uid,
        'totalStudents': 0,
        'totalStaff': 0,
        'academicYear': AcademicYearUtils.currentAcademicYear(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(_db.collection('users').doc(uid), {
        'fullName': fullName,
        'email': email.trim(),
        'phone': phone,
        'role': 'admin',
        'schoolId': schoolRef.id,
        'schoolName': schoolName,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await createdUser.updateDisplayName(fullName);
      await createdUser.sendEmailVerification();

      return AuthResult.success(createdUser);
    } on FirebaseAuthException catch (e) {
      await _cleanupFailedSignup(createdUser);
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      await _cleanupFailedSignup(createdUser);
      return AuthResult.error('Sign-up failed: $e');
    }
  }

  // ─── Teacher Sign Up ────────────────────────────────────────
  Future<AuthResult> signUpTeacher({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String schoolCode,
    String classId = '',
    String subject = '',
  }) async {
    return AuthResult.error(
      'Teacher self-sign-up is disabled. Please ask a school administrator to create your account.',
    );
  }

  Future<AuthResult> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String schoolId,
    required String schoolName,
    required String classId,
    String subject = '',
  }) async {
    if (!_isFirebaseInitialized) {
      return AuthResult.error('Firebase not configured.');
    }

    FirebaseApp? secondaryApp;
    UserCredential? credential;

    try {
      if (!kIsWeb) {
        return AuthResult.error(
          'Teacher creation is currently supported on web only.',
        );
      }

      final appName =
          'teacher-creator-${DateTime.now().microsecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final teacherUser = credential.user;
      if (teacherUser == null) {
        return AuthResult.error('Teacher account could not be created.');
      }

      await teacherUser.updateDisplayName(fullName);

      final batch = _db.batch();
      final userRef = _db.collection('users').doc(teacherUser.uid);
      final staffRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(teacherUser.uid);
      final schoolRef = _db.collection('schools').doc(schoolId);

      batch.set(userRef, {
        'fullName': fullName,
        'email': email.trim(),
        'phone': phone,
        'role': 'teacher',
        'schoolId': schoolId,
        'schoolName': schoolName,
        'classId': classId,
        'emailVerified': false,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(staffRef, {
        'fullName': fullName,
        'email': email.trim(),
        'phone': phone,
        'subject': subject,
        'grade': classId,
        'todayStatus': 'present',
        'classId': classId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(schoolRef, {
        'totalStaff': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();
      await teacherUser.sendEmailVerification();
      await secondaryAuth.signOut();

      return AuthResult.success(teacherUser);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Teacher creation failed: $e');
    } finally {
      try {
        await secondaryApp?.delete();
      } catch (e) {
        debugPrint('WARNING: Failed to delete secondary Firebase app: $e');
      }
    }
  }

  Future<AuthResult> sendPasswordReset(String email) async {
    if (!_isFirebaseInitialized) return AuthResult.error('Firebase not configured.');
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Failed to send reset email: $e');
    }
  }

  Future<void> resendVerificationEmail() async {
    if (!_isFirebaseInitialized) return;
    await currentUser?.sendEmailVerification();
  }

  Future<bool> reloadUser() async {
    if (!_isFirebaseInitialized || currentUser == null) return false;
    await currentUser!.reload();
    return currentUser!.emailVerified;
  }

  Future<AuthResult> updateProfile({
    required String uid,
    String? fullName,
    String? phone,
    String? photoUrl,
  }) async {
    if (!_isFirebaseInitialized) return AuthResult.error('Firebase not configured.');
    try {
      final Map<String, dynamic> updates = {};
      if (fullName != null) {
        updates['fullName'] = fullName;
        await currentUser?.updateDisplayName(fullName);
      }
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      await _db.collection('users').doc(uid).update(updates);
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.error('Update failed: $e');
    }
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_isFirebaseInitialized || currentUser == null) return AuthResult.error('Firebase not configured.');
    try {
      final user = currentUser!;
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Password change failed: $e');
    }
  }

  Future<void> signOut() async {
    if (!_isFirebaseInitialized) return;
    await _auth.signOut();
  }

  Future<AuthResult> deleteAccount(String password) async {
    if (!_isFirebaseInitialized || currentUser == null) return AuthResult.error('Firebase not configured.');
    try {
      final user = currentUser!;
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Account deletion failed: $e');
    }
  }

  Future<AppUser?> fetchUserProfile(String uid) async {
    if (!_isFirebaseInitialized) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Stream<AppUser?> userProfileStream(String uid) {
    if (!_isFirebaseInitialized) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  String _generateSchoolCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _cleanupFailedSignup(User? user) async {
    if (user == null) return;

    try {
      await user.delete();
    } catch (e) {
      debugPrint('WARNING: Failed to clean up partially created signup user: $e');
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password. Please try again.';
      case 'invalid-credential': return 'Invalid email or password.';
      case 'email-already-in-use': return 'An account with this email already exists.';
      case 'weak-password': return 'Password must be at least 8 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'No internet connection. Please check your network.';
      case 'user-disabled': return 'This account has been disabled.';
      case 'operation-not-allowed': return 'Sign-in method not enabled. Contact support.';
      default: return 'An error occurred ($code). Please try again.';
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;
  const AuthResult._({required this.isSuccess, this.errorMessage, this.user});
  factory AuthResult.success(User? user) => AuthResult._(isSuccess: true, user: user);
  factory AuthResult.error(String message) => AuthResult._(isSuccess: false, errorMessage: message);
}
