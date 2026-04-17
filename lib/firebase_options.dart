import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    throw UnsupportedError(
      'ShikshaSetu is currently configured for web only. '
      'Add Android/iOS Firebase options when mobile support is ready.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD_00xB2xUNv6hsx37FAs2MKYeyTbfy6dc',
    appId: '1:143448413569:web:fe8afb115635f7e333c480',
    messagingSenderId: '143448413569',
    projectId: 'shiksha-setu-afb8d',
    authDomain: 'shiksha-setu-afb8d.firebaseapp.com',
    storageBucket: 'shiksha-setu-afb8d.firebasestorage.app',
  );
}
