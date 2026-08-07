/// Configuración de automatización de riego de un dispositivo.
///
/// Se guarda en `devices/{id}/automation`. La lógica de decisión vive en
/// [AutomationService] (espejo de lo que haría una Cloud Function, sin costo
/// ni plan Blaze): cuando la app ve un reporte nuevo evalúa estas reglas y
/// escribe el comando `valveState` en `devices/{id}/config/current` para que
/// el nodo lo ejecute en su próximo ciclo.
class AutomationConfig {
  final bool enabled;
  final int threshold;
  final int durationMin;
  final int startMin;
  final int endMin;
  final bool rainPause;
  final int minIntervalMin;

  const AutomationConfig({
    this.enabled = false,
    this.threshold = 45,
    this.durationMin = 60,
    this.startMin = 0,
    this.endMin = 1440,
    this.rainPause = true,
    this.minIntervalMin = 120,
  });

  static const _allDayEnd = 1440; // 24 * 60

  /// Ventana [startMin, endMin) en minutos desde medianoche. Si empieza y
  /// termina igual, o cubre todo el día, riega a cualquier hora.
  bool inWindow(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (startMin == endMin) return true;
    if (startMin <= endMin) return m >= startMin && m < endMin;
    return m >= startMin || m < endMin; // cruza la medianoche
  }

  factory AutomationConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AutomationConfig();
    return AutomationConfig(
      enabled: data['enabled'] == true,
      threshold: (data['threshold'] as num?)?.toInt() ?? 45,
      durationMin: (data['durationMin'] as num?)?.toInt() ?? 60,
      startMin: (data['startMin'] as num?)?.toInt() ?? 0,
      endMin: (data['endMin'] as num?)?.toInt() ?? _allDayEnd,
      rainPause: data['rainPause'] != false,
      minIntervalMin: (data['minIntervalMin'] as num?)?.toInt() ?? 120,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'threshold': threshold,
        'durationMin': durationMin,
        'startMin': startMin,
        'endMin': endMin,
        'rainPause': rainPause,
        'minIntervalMin': minIntervalMin,
      };
}
