import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/services/auth_service.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/weather_service.dart';

/// Resultado de una evaluación de automatización.
class AutomationResult {
  final String state;
  final String reason;
  final String? valveState;
  final bool changed;

  const AutomationResult({
    required this.state,
    required this.reason,
    this.valveState,
    this.changed = false,
  });
}

/// Motor de reglas de riego (espejo en la app de lo que haría una Cloud
/// Function, sin plan Blaze). Evalúa cada vez que se carga/refresca un
/// dispositivo y escribe SOLO cuando el estado cambia (evita escrituras
/// redundantes y ciclos cortos de la válvula).
class AutomationService {
  AutomationService._();

  static final AutomationService instance = AutomationService._();

  static const String stateDisabled = 'disabled';
  static const String stateIdle = 'idle';
  static const String stateIrrigating = 'irrigating';
  static const String stateRainPaused = 'rain_paused';
  static const String stateOutsideWindow = 'outside_window';
  static const String stateCooldown = 'cooldown';

  bool _canManage(CloudDevice d) {
    final uid = AuthService.instance.currentUser?.uid;
    if (d.owner == uid) return true;
    final email = AuthService.instance.currentUser?.email?.toLowerCase();
    return email != null && d.shares[email] == 'manager';
  }

  Future<AutomationResult> checkDevice(
    String deviceId, {
    double? lat,
    double? lon,
  }) async {
    final device = await CloudService.instance.deviceFor(deviceId);
    if (device == null) {
      return const AutomationResult(state: 'unknown', reason: 'Dispositivo no encontrado');
    }
    return check(device, lat: lat, lon: lon);
  }

  Future<AutomationResult> check(
    CloudDevice device, {
    double? lat,
    double? lon,
  }) async {
    final canManage = _canManage(device);
    final cfg = device.automation;

    // 1) Automatización desactivada → válvula cerrada.
    if (!cfg.enabled) {
      return _apply(
        device,
        canManage,
        state: stateDisabled,
        reason: 'Automatización desactivada',
        valve: device.valveState == 'ON' ? 'OFF' : null,
      );
    }

    // 2) Sin lecturas todavía.
    if (device.humidity == null) {
      return _apply(
        device,
        canManage,
        state: stateIdle,
        reason: 'Sin lecturas todavía',
      );
    }

    final now = DateTime.now();

    // 3) Ya está regando: parar cuando la humedad suba o se cumpla la duración.
    if (device.valveState == 'ON') {
      if (device.humidity! >= cfg.threshold) {
        return _apply(
          device,
          canManage,
          state: stateIdle,
          reason: 'Humedad alcanzó el umbral (${cfg.threshold}%)',
          valve: 'OFF',
        );
      }
      final started = device.automationStartedAt;
      if (started != null &&
          now.difference(started) >= Duration(minutes: cfg.durationMin)) {
        return _apply(
          device,
          canManage,
          state: stateIdle,
          reason: 'Duración de riego cumplida (${cfg.durationMin} min)',
          valve: 'OFF',
        );
      }
      final end =
          (started ?? now).add(Duration(minutes: cfg.durationMin));
      return _apply(
        device,
        canManage,
        state: stateIrrigating,
        reason: 'Regando hasta las ${_fmtTime(end)}',
      );
    }

    // 4) Anti-rebote: mínimo entre arranques de riego (evita ciclos cortos).
    final last = device.automationLastToggleAt;
    if (last != null) {
      final remaining =
          Duration(minutes: cfg.minIntervalMin) - now.difference(last);
      if (remaining > Duration.zero) {
        return _apply(
          device,
          canManage,
          state: stateCooldown,
          reason: 'Anti-rebote: esperando ${_fmtDuration(remaining)}',
        );
      }
    }

    // 5) Ventana de tiempo.
    if (!cfg.inWindow(now)) {
      return _apply(
        device,
        canManage,
        state: stateOutsideWindow,
        reason: 'Fuera del horario de riego',
      );
    }

    // 6) Pausa por lluvia prevista (requiere coordenadas del campo).
    if (cfg.rainPause && lat != null && lon != null) {
      try {
        final w = await WeatherService.instance.forecast(lat, lon, days: 1);
        if (w.forecastRain) {
          return _apply(
            device,
            canManage,
            state: stateRainPaused,
            reason: 'Lluvia prevista (≥50%). Riego pospuesto',
          );
        }
      } catch (_) {
        // Sin clima disponible: se continúa con el umbral.
      }
    }

    // 7) Humedad sobre el umbral → esperando.
    if (device.humidity! >= cfg.threshold) {
      return _apply(
        device,
        canManage,
        state: stateIdle,
        reason: 'Humedad ${device.humidity!.toStringAsFixed(1)}% ≥ umbral '
            '(${cfg.threshold}%)',
      );
    }

    // 8) Todo en orden → encender riego.
    return _apply(
      device,
      canManage,
      state: stateIrrigating,
      reason: 'Humedad ${device.humidity!.toStringAsFixed(1)}% < umbral '
          '(${cfg.threshold}%)',
      valve: 'ON',
    );
  }

  Future<AutomationResult> _apply(
    CloudDevice device,
    bool canManage, {
    required String state,
    required String reason,
    String? valve,
  }) async {
    final stateChanged = state != device.automationState;
    final valveChanged = valve != null && valve != device.valveState;

    if (!stateChanged && !valveChanged) {
      return AutomationResult(
        state: state,
        reason: reason,
        valveState: valve ?? device.valveState,
      );
    }
    if (!canManage) {
      // Invitado de solo lectura: no escribe, solo reporta.
      return AutomationResult(
        state: state,
        reason: reason,
        valveState: valve ?? device.valveState,
      );
    }

    if (valveChanged) {
      await CloudService.instance.setValveCommand(device.deviceId, valve, reason);
    }
    await CloudService.instance.updateAutomationStatus(
      device.deviceId,
      state: state,
      reason: reason,
      valveState: valveChanged ? valve : null,
    );
    return AutomationResult(
      state: state,
      reason: reason,
      valveState: valve ?? device.valveState,
      changed: true,
    );
  }

  static String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _fmtDuration(Duration d) {
    if (d.inMinutes >= 60) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return '$h h $m min';
    }
    return '${d.inMinutes} min';
  }
}
