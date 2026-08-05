import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Plataforma no soportada para Firebase: $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD9nLSqOKGgHYaJFEtve9G3jr4ykqAg0LQ',
    appId: '1:160786327743:web:752cd456eea0e69361be0a',
    messagingSenderId: '160786327743',
    projectId: 'mantencion-a56b4',
    authDomain: 'mantencion-a56b4.firebaseapp.com',
    storageBucket: 'mantencion-a56b4.firebasestorage.app',
    measurementId: 'G-7D28CKY10V',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsJdNvACj37nZB2lN8wv6SPX3em43fK8s',
    appId: '1:160786327743:android:425b35a801f715c661be0a',
    messagingSenderId: '160786327743',
    projectId: 'mantencion-a56b4',
    storageBucket: 'mantencion-a56b4.firebasestorage.app',
  );
}
