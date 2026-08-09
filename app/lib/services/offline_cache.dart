import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Caché local del último estado cargado del dashboard. Permite mostrar los
/// datos guardados cuando no hay conexión a Firestore (modo offline).
///
/// El payload es el JSON del resultado de carga (campos, cultivos, sectores,
/// dispositivos y nombre de usuario), por usuario, en un archivo propio.
class OfflineCache {
  static final OfflineCache instance = OfflineCache._();

  OfflineCache._();

  static const _fileName = 'offline_dashboard.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> save(String uid, Map<String, dynamic> payload) async {
    try {
      final file = await _file();
      final data = {
        'uid': uid,
        'savedAt': DateTime.now().toIso8601String(),
        'data': payload,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[OfflineCache] No se pudo guardar: $e');
    }
  }

  /// Devuelve el payload guardado para `uid`, o null si no existe/es de otro
  /// usuario/está corrupto.
  Future<Map<String, dynamic>?> load(String uid) async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      if (map['uid'] != uid) return null;
      final data = map['data'];
      if (data is! Map) return null;
      return data.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[OfflineCache] No se pudo leer: $e');
      return null;
    }
  }

  /// Fecha en que se guardó el caché (para mostrarla en el banner offline).
  Future<DateTime?> savedAt(String uid) async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      if (map['uid'] != uid) return null;
      final t = DateTime.tryParse(map['savedAt'] as String? ?? '');
      return t;
    } catch (e) {
      return null;
    }
  }
}
