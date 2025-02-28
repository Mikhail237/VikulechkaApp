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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAAt4LWwNgO9CGN4xSjn6WBAeSRW68SkOg',
    appId: '1:239810368534:web:df1e5cb3a9bf0eb2511137',
    messagingSenderId: '239810368534',
    projectId: 'vikulechkaappfirebase',
    authDomain: 'vikulechkaappfirebase.firebaseapp.com',
    storageBucket: 'vikulechkaappfirebase.firebasestorage.app',
    measurementId: 'G-BMZNHJ5C5Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyARczHVfG8N2EPg2tkJUCyV9AtZG100sk8',
    appId: '1:239810368534:android:cfa922f4ae458701511137',
    messagingSenderId: '239810368534',
    projectId: 'vikulechkaappfirebase',
    storageBucket: 'vikulechkaappfirebase.firebasestorage.app',
  );

} 