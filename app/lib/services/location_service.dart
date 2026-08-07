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
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
