import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shiksha_setu_2/l10n/generated/app_localizations.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'providers/locale_provider.dart';

final firebaseInitProvider = Provider<FirebaseInitState>((ref) {
  return FirebaseInitState.instance;
});

class FirebaseInitState {
  final bool isReady;
  final String? errorMessage;

  const FirebaseInitState._({
    required this.isReady,
    this.errorMessage,
  });

  static FirebaseInitState instance = const FirebaseInitState._(isReady: false);

  static void setReady() {
    instance = const FirebaseInitState._(isReady: true);
  }

  static void setError(String message) {
    instance = FirebaseInitState._(isReady: false, errorMessage: message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('DEBUG: Starting Firebase initialization...');
    debugPrint('DEBUG: Platform: ${kIsWeb ? "Web" : "Native"}');

    if (kIsWeb) {
      final options = DefaultFirebaseOptions.currentPlatform;
      debugPrint('DEBUG: Project: ${options.projectId}');
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp();
    }

    debugPrint('DEBUG: Firebase initializeApp completed successfully.');
    FirebaseInitState.setReady();
  } catch (e, stack) {
    debugPrint('ERROR: Firebase initialization failed.');
    debugPrint('Error details: $e');
    debugPrint('Stack trace: $stack');
    FirebaseInitState.setError(
      kIsWeb
          ? 'Firebase web initialization failed. Check your web Firebase project settings.'
          : 'Firebase initialization failed on this device.',
    );
  }

  runApp(const ProviderScope(child: ShikshaSetu()));
}

class ShikshaSetu extends ConsumerWidget {
  const ShikshaSetu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'ShikshaSetu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
