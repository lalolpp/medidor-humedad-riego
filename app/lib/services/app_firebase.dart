import 'package:firebase_core/firebase_core.dart';
import 'package:medidor_humedad/firebase_options.dart';

class AppFirebase {
  static bool configured = false;

  static Future<bool> initialize() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return false;
    try {
      await Firebase.initializeApp(options: options);
      configured = true;
    } catch (_) {
      configured = false;
    }
    return configured;
  }
}
