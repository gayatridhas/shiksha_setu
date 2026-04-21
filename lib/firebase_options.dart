import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD_00xB2xUNv6hsx37FAs2MKYeyTbfy6dc',
    appId: '1:143448413569:web:fe8afb115635f7e333c480',
    messagingSenderId: '143448413569',
    projectId: 'shiksha-setu-afb8d',
    authDomain: 'shiksha-setu-afb8d.firebaseapp.com',
    storageBucket: 'shiksha-setu-afb8d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAaM5PrO3Irz8hvzAnxYF8yew2Jx_bNU5U',
    appId: '1:143448413569:android:9db8253ad2c71b6e33c480',
    messagingSenderId: '143448413569',
    projectId: 'shiksha-setu-afb8d',
    storageBucket: 'shiksha-setu-afb8d.firebasestorage.app',
  );
}
