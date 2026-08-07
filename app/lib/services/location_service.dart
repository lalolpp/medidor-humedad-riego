import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Resultado de posición con latitud/longitud.
typedef LatLon = ({double lat, double lon});

/// Obtiene la ubicación GPS actual del dispositivo.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Solicita permisos y devuelve la posición actual. Retorna `null` si el GPS
  /// no está disponible, los permisos fueron rechazados o hubo un error.
  Future<LatLon?> getPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint('[GPS] Servicio de ubicación desactivado');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Permiso de ubicación denegado: $permission');
        return null;
      }

      // Primero la última posición conocida (instantánea, no espera un fix).
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          debugPrint(
              '[GPS] Última posición: ${last.latitude},${last.longitude}');
          return (lat: last.latitude, lon: last.longitude);
        }
        debugPrint('[GPS] Sin última posición conocida, pidiendo fix...');
      } catch (e) {
        debugPrint('[GPS] Error al leer última posición: $e');
      }

      // Si no hay, pedimos un fix con tiempo amplio.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      debugPrint('[GPS] Fix actual: ${pos.latitude},${pos.longitude}');
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (e) {
      debugPrint('[GPS] No se pudo obtener posición: $e');
      return null;
    }
  }
}
