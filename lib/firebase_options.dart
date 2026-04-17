// ⚠️  IMPORTANT: This file is a TEMPLATE.
// You MUST replace the placeholder values with your actual Firebase project config.
//
// HOW TO GENERATE THIS FILE AUTOMATICALLY:
//   1. Install FlutterFire CLI:
//      dart pub global activate flutterfire_cli
//   2. From this project root, run:
//      flutterfire configure
//   3. Select your Firebase project and target platforms.
//   4. The CLI will replace this file with real values automatically.
//
// OR manually get values from Firebase Console → Project Settings → Your apps → Android

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web; // Fallback to web/dummy instead of throwing
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyD_00xB2xUNv6hsx37FAs2MKYeyTbfy6dc",
    appId: "1:143448413569:web:fe8afb115635f7e333c480",
    messagingSenderId:  "143448413569",
    projectId: "shiksha-setu-afb8d",
    authDomain: "shiksha-setu-afb8d.firebaseapp.com",
    storageBucket:"shiksha-setu-afb8d.firebasestorage.app",
  );

  /// ⚠️ Replace ALL values below with your real Firebase config
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAaM5PrO3Irz8hvzAnxYF8yew2Jx_bNU5U',
    appId: '1:143448413569:android:9db8253ad2c71b6e33c480',
    messagingSenderId: '143448413569',
    projectId: 'shiksha-setu-afb8d',
    storageBucket: 'shiksha-setu-afb8d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.shikshasetu2',
  );
}
