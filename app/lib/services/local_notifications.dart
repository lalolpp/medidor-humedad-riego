import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones locales del teléfono (sin nube): avisos cuando un sector
/// del predio baja del umbral de riego definido en el cultivo. Se disparan al
/// abrir la app o al refrescar el dashboard con datos recién descargados.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      windows: WindowsInitializationSettings(
        appName: 'Medidor de Humedad',
        appUserModelId: 'cl.riego.medidor_humedad',
        guid: 'f2643538-016d-415e-98fe-edce78cb5332',
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Muestra la alerta de "Requiere riego" para un sector. Reutiliza el mismo
  /// id por sector para no acumular notificaciones repetidas.
  Future<void> showLowHumidity({
    required String sectorName,
    required double humidity,
    required double threshold,
  }) async {
    await init();
    await _requestAndroidPermission();
    const android = AndroidNotificationDetails(
      'riegos',
      'Alertas de riego',
      channelDescription: 'Avisos cuando un sector baja del umbral de riego',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    final id = sectorName.hashCode & 0x7fffffff;
    await _plugin.show(
      id: id,
      title: 'Requiere riego: $sectorName',
      body: 'Humedad ${humidity.toStringAsFixed(1)}% · '
          'límite ${threshold.toStringAsFixed(0)}%',
      notificationDetails: details,
    );
  }

  /// Muestra una notificación push genérica (mensajes de la consola FCM que
  /// llegan con la app en primer plano y no traen datos de sector).
  Future<void> show({required String title, required String body}) async {
    await init();
    const android = AndroidNotificationDetails(
      'riegos',
      'Alertas de riego',
      channelDescription: 'Avisos cuando un sector baja del umbral de riego',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    final id = title.hashCode & 0x7fffffff;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> _requestAndroidPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final granted = await android.requestNotificationsPermission();
    debugPrint('[Notif] Permiso Android: $granted');
  }
}
