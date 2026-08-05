import 'package:firebase_core/firebase_core.dart';
import 'package:medidor_humedad/firebase_options.dart';

class AppFirebase {
  static bool configured = false;

  static Future<bool> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      configured = true;
    } catch (_) {
      configured = false;
    }
    return configured;
  }
}
