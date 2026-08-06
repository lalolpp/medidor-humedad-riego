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
    apiKey: 'AIzaSyCcqtbCigQbxkKJ7zqFxbCuaygvBYTGIYw',
    appId: '1:270536769377:web:13d91518a31894cf4a0f20',
    messagingSenderId: '270536769377',
    projectId: 'medidor-de-humedad',
    authDomain: 'medidor-de-humedad.firebaseapp.com',
    storageBucket: 'medidor-de-humedad.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgF0enQM543WklTL7tocxtRA-k0r9kprg',
    appId: '1:270536769377:android:d7021f9bc93066704a0f20',
    messagingSenderId: '270536769377',
    projectId: 'medidor-de-humedad',
    storageBucket: 'medidor-de-humedad.firebasestorage.app',
  );
}
