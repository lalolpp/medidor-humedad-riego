import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:medidor_humedad/services/local_notifications.dart';

/// Push (FCM) del proyecto. Registra el token del dispositivo en
/// `users/{uid}.fcmToken` y muestra las alertas de "Requiere riego" que lleguen
/// por push, tanto con la app abierta (foreground) como cerrada (background).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  String? _token;
  String? get token => _token;

  /// Prepara FCM: pide permiso, registra handlers y guarda el token del
  /// usuario en Firestore. Se invoca tras iniciar sesión.
  Future<void> init(String uid) async {
    if (kIsWeb) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_show);
      FirebaseMessaging.onMessageOpenedApp.listen(_showOpened);
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
      final initial = await messaging.getInitialMessage();
      if (initial != null) await _showOpened(initial);

      messaging.onTokenRefresh.listen((t) => _storeToken(uid, t));

      final token = await messaging.getToken();
      if (token != null) {
        _token = token;
        await _storeToken(uid, token);
        debugPrint('[Push] Token FCM registrado');
      }
    } catch (e) {
      debugPrint('[Push] Error al inicializar FCM: $e');
    }
  }

  Future<void> _storeToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] Error al guardar token: $e');
    }
  }

  /// Muestra la alerta recibida por push usando la misma notificación local
  /// de "Requiere riego" (canal `riegos`, id estable por sector). Con la app
  /// en primer plano, los mensajes de notificación de la consola se muestran
  /// igual (no los auto-muestra el sistema).
  Future<void> _show(RemoteMessage message) async {
    try {
      final handled = await _showFromData(message);
      if (!handled) {
        final n = message.notification;
        if (n != null && (n.title ?? n.body) != null) {
          await LocalNotificationsService.instance.show(
            title: n.title ?? 'Medidor de Humedad',
            body: n.body ?? '',
          );
        }
      }
    } catch (e) {
      debugPrint('[Push] Error al mostrar notificación: $e');
    }
  }

  /// Al abrir la app desde una notificación, solo reproduce la alerta de
  /// sector (los mensajes de la consola ya los mostró el sistema).
  Future<void> _showOpened(RemoteMessage message) async {
    try {
      await _showFromData(message);
    } catch (e) {
      debugPrint('[Push] Error al procesar notificación abierta: $e');
    }
  }

  Future<bool> _showFromData(RemoteMessage message) async {
    final d = message.data;
    final sectorName = d['sectorName'];
    if (sectorName is String && sectorName.isNotEmpty) {
      final humidity = double.tryParse('${d['humidity']}');
      final threshold = double.tryParse('${d['threshold']}');
      if (humidity != null && threshold != null) {
        await LocalNotificationsService.instance.showLowHumidity(
          sectorName: sectorName,
          humidity: humidity,
          threshold: threshold,
        );
      }
      return true;
    }
    return false;
  }
}

/// Handler de primer plano/terminada. `flutter_local_notifications` funciona
/// en el isolate de background y reutiliza el canal de "Alertas de riego".
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await LocalNotificationsService.instance.init();
    final d = message.data;
    final sectorName = d['sectorName'];
    if (sectorName is String && sectorName.isNotEmpty) {
      final humidity = double.tryParse('${d['humidity']}');
      final threshold = double.tryParse('${d['threshold']}');
      if (humidity != null && threshold != null) {
        await LocalNotificationsService.instance.showLowHumidity(
          sectorName: sectorName,
          humidity: humidity,
          threshold: threshold,
        );
      }
    }
  } catch (e) {
    debugPrint('[Push] Error en background handler: $e');
  }
}
