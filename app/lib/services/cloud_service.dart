import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:medidor_humedad/models/access_request.dart';
import 'package:medidor_humedad/models/automation_config.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/field.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/models/sector.dart';

class CloudService {
  static final CloudService instance = CloudService._();

  CloudService._();

  Future<String> roleFor(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return 'user';
    return (doc.data()?['rol'] as String?) ?? 'user';
  }

  Future<void> setRole(String uid, String role) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'rol': role}, SetOptions(merge: true));
  }

  Future<List<CloudDevice>> myDevices(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('owner', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map((doc) => CloudDevice.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> claimDevice(
    String uid,
    String deviceId,
    String name, {
    String? fieldId,
    String? cropId,
    String? sectorId,
  }) async {
    await FirebaseFirestore.instance.collection('devices').doc(deviceId).set({
      'owner': uid,
      'name': name,
      if (fieldId != null && fieldId.isNotEmpty) 'fieldId': fieldId,
      if (cropId != null && cropId.isNotEmpty) 'cropId': cropId,
      if (sectorId != null && sectorId.isNotEmpty) 'sectorId': sectorId,
      if (deviceId.startsWith('demo-')) 'isDemo': true,
      'claimedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDevice(
    String deviceId, {
    String? fieldId,
    String? cropId,
    String? sectorId,
  }) async {
    await FirebaseFirestore.instance.collection('devices').doc(deviceId).update({
      if (fieldId != null && fieldId.isNotEmpty) 'fieldId': fieldId,
      if (cropId != null && cropId.isNotEmpty) 'cropId': cropId,
      if (sectorId != null && sectorId.isNotEmpty) 'sectorId': sectorId,
    });
  }

  /// Configuración remota del nodo: intervalo de reporte (min) que el
  /// firmware lee en cada despertar para ajustar su deep sleep.
  Future<void> setIntervalConfig(String deviceId, int intervalMin) async {
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('config')
        .doc('current')
        .set({
      'intervalMin': intervalMin,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Dispositivos compartidos con mi correo (visto por el usuario invitado).
  /// Se busca por `sharedWith` (array de emails) porque una lista con
  /// `where('shares.<email>', isNotEqualTo: null)` no es validable por las
  /// reglas de Firestore (PERMISSION_DENIED en queries de lista sobre mapas).
  Future<List<CloudDevice>> devicesSharedWithEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final snapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('sharedWith', arrayContains: normalized)
        .get();
    return snapshot.docs
        .map((doc) => CloudDevice.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Comparte (o cambia el rol de) un dispositivo con otra persona por email.
  /// Mantiene ambos campos: `shares.<email>` (rol) y `sharedWith` (array para
  /// que la búsqueda del invitado sea validable por las reglas).
  Future<void> shareDevice(
    String deviceId,
    String email, {
    String role = 'viewer',
  }) async {
    final normalized = email.trim().toLowerCase();
    await FirebaseFirestore.instance.collection('devices').doc(deviceId).update({
      'shares.$normalized': role,
      'sharedWith': FieldValue.arrayUnion([normalized]),
    });
  }

  Future<void> unshareDevice(String deviceId, String email) async {
    final normalized = email.trim().toLowerCase();
    await FirebaseFirestore.instance.collection('devices').doc(deviceId).update({
      'shares.$normalized': FieldValue.delete(),
      'sharedWith': FieldValue.arrayRemove([normalized]),
    });
  }

  // ---- Invitaciones y accesos compartidos (invitados) ----

  /// Genera una invitación (token) para que otra persona pueda acceder a la
  /// app y ver el campo del dueño. El token viaja en el QR/enlace.
  Future<String> createInvite(String uid, String fieldId) async {
    final token = _randomToken();
    await FirebaseFirestore.instance.collection('invites').doc(token).set({
      'ownerUid': uid,
      'fieldId': fieldId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return token;
  }

  /// Valida un token de invitación; devuelve el fieldId o null si no existe.
  Future<String?> validateInvite(String token) async {
    final doc =
        await FirebaseFirestore.instance.collection('invites').doc(token).get();
    if (!doc.exists) return null;
    return doc.data()?['fieldId'] as String?;
  }

  /// Solicitudes de acceso a mis campos (pendientes e historial).
  Future<List<AccessRequest>> myAccessRequests(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('access_requests')
        .where('ownerUid', isEqualTo: uid)
        .get();
    final list = snapshot.docs
        .map((doc) => AccessRequest.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        final ta = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return list;
  }

  /// Stream en tiempo real de las solicitudes de acceso (para el aviso en la
  /// app cuando alguien pide acceso).
  Stream<List<AccessRequest>> streamAccessRequests(String uid) {
    return FirebaseFirestore.instance
        .collection('access_requests')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AccessRequest.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// El invitado crea su solicitud de acceso con el token de la invitación.
  /// Reutiliza una solicitud pendiente del mismo correo si ya existe.
  Future<String?> requestAccess({
    required String token,
    required String email,
    required String uid,
  }) async {
    final normalized = email.trim().toLowerCase();
    final invite =
        await FirebaseFirestore.instance.collection('invites').doc(token).get();
    if (!invite.exists) return null;
    final data = invite.data()!;
    final fieldId = data['fieldId'] as String?;
    final ownerUid = data['ownerUid'] as String?;
    if (fieldId == null || ownerUid == null) return null;

    final pending = await FirebaseFirestore.instance
        .collection('access_requests')
        .where('ownerUid', isEqualTo: ownerUid)
        .get();
    for (final doc in pending.docs) {
      final m = doc.data();
      if (m['email'] == normalized && m['status'] == 'pending') {
        await doc.reference.update({'uid': uid});
        return doc.id;
      }
    }
    final ref = await FirebaseFirestore.instance
        .collection('access_requests')
        .add({
      'ownerUid': ownerUid,
      'fieldId': fieldId,
      'token': token,
      'email': normalized,
      'uid': uid,
      'status': 'pending',
      'requestedAt': DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  /// Aprueba una solicitud: comparte el campo y sus dispositivos con el email.
  Future<void> approveAccess(AccessRequest req) async {
    await FirebaseFirestore.instance.collection('fields').doc(req.fieldId).update({
      'sharedWith': FieldValue.arrayUnion([req.email]),
    });
    final devices = await _devicesOfOwner(req.ownerUid);
    for (final d in devices) {
      try {
        await shareDevice(d.deviceId, req.email, role: 'viewer');
      } catch (_) {}
    }
    await FirebaseFirestore.instance
        .collection('access_requests')
        .doc(req.id)
        .update({
      'status': 'approved',
      'decidedAt': DateTime.now().toIso8601String(),
    });
    await FirebaseFirestore.instance
        .collection('users')
        .doc(req.uid)
        .update({'status': 'active'});
  }

  Future<void> rejectAccess(AccessRequest req) async {
    await FirebaseFirestore.instance
        .collection('access_requests')
        .doc(req.id)
        .update({
      'status': 'rejected',
      'decidedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Bloquea/revoca el acceso: quita el email del campo y de los dispositivos.
  Future<void> revokeAccess(AccessRequest req) async {
    await FirebaseFirestore.instance
        .collection('fields')
        .doc(req.fieldId)
        .update({'sharedWith': FieldValue.arrayRemove([req.email])});
    final devices = await _devicesOfOwner(req.ownerUid);
    for (final d in devices) {
      try {
        await unshareDevice(d.deviceId, req.email);
      } catch (_) {}
    }
    await FirebaseFirestore.instance
        .collection('access_requests')
        .doc(req.id)
        .update({
      'status': 'revoked',
      'decidedAt': DateTime.now().toIso8601String(),
    });
    await FirebaseFirestore.instance
        .collection('users')
        .doc(req.uid)
        .update({'status': 'blocked'});
  }

  /// Campos compartidos con mi correo (visto por el invitado aprobado).
  Future<List<Field>> fieldsSharedWithEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final snapshot = await FirebaseFirestore.instance
        .collection('fields')
        .where('sharedWith', arrayContains: normalized)
        .get();
    return snapshot.docs.map((doc) => Field.fromMap(doc.id, doc.data())).toList();
  }

  /// Estado de la solicitud del invitado (uid): 'pending' | 'approved' |
  /// 'rejected' | 'revoked', o null si nunca solicitó acceso.
  Future<String?> myRequestStatus(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('access_requests')
        .where('uid', isEqualTo: uid)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final docs = snapshot.docs.map((d) => d.data()).toList()
      ..sort((a, b) =>
          (a['requestedAt'] ?? '').toString().compareTo((b['requestedAt'] ?? '').toString()));
    return docs.last['status'] as String?;
  }

  Future<List<CloudDevice>> _devicesOfOwner(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('devices')
        .where('owner', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map((doc) => CloudDevice.fromMap(doc.id, doc.data()))
        .toList();
  }

  String _randomToken() {
    final rand = math.Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Configuración OTA: el nodo descargará el firmware .bin cuando su
  /// versión local difiera de `version`.
  Future<void> setOtaConfig(
    String deviceId, {
    required String url,
    required String version,
  }) async {
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('config')
        .doc('current')
        .set({
      'otaUrl': url,
      'otaVersion': version,
      'otaRequestedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Guarda la configuración de automatización de riego (dueño/manager).
  Future<void> saveAutomation(String deviceId, AutomationConfig cfg) async {
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .set({'automation': cfg.toMap()}, SetOptions(merge: true));
  }

  /// Escribe el comando de válvula que el ESP32 lee en su próximo ciclo
  /// (junto al resto de la configuración remota).
  Future<void> setValveCommand(
    String deviceId,
    String valveState,
    String reason,
  ) async {
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('config')
        .doc('current')
        .set({
      'valveState': valveState,
      'valveStateAt': DateTime.now().toIso8601String(),
      'valveReason': reason,
    }, SetOptions(merge: true));
  }

  /// Lee el comando de válvula REAL pendiente en config/current (lo que el
  /// nodo aplica). Es la fuente de verdad para el switch de riego manual:
  /// el campo automationStatus del doc puede quedar desactualizado.
  Future<String?> readValveCommand(String deviceId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .collection('config')
          .doc('current')
          .get();
      return snap.data()?['valveState'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Actualiza el estado resumido de automatización que muestra la app.
  Future<void> updateAutomationStatus(
    String deviceId, {
    required String state,
    required String reason,
    String? valveState,
  }) async {
    final now = DateTime.now();
    final map = <String, dynamic>{
      'state': state,
      'reason': reason,
      'updatedAt': now.toIso8601String(),
    };
    if (valveState != null) {
      map['valveState'] = valveState;
      map['lastToggleAt'] = now.toIso8601String();
      if (valveState == 'ON') map['startedAt'] = now.toIso8601String();
    }
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .update({'automationStatus': map});
  }

  Future<List<Reading>> readingsFor(String deviceId,
      {int limit = 2000, DateTime? from, DateTime? to}) async {    var query = FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('readings') as Query;
    if (from != null) {
      query = query.where('ts', isGreaterThanOrEqualTo: from.millisecondsSinceEpoch ~/ 1000);
    }
    if (to != null) {
      query = query.where('ts', isLessThanOrEqualTo: to.millisecondsSinceEpoch ~/ 1000);
    }
    final snapshot = await query
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => _readingFromDoc(doc)).toList();
  }

  Reading _readingFromDoc(QueryDocumentSnapshot doc) {
    final data =
        (doc.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return Reading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (data['ts'] as num?)?.toInt() ?? 0),
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0,
      soilTemp: (data['soilTemp'] as num?)?.toDouble() ?? double.nan,
      batteryVoltage: (data['batteryV'] as num?)?.toDouble() ?? 0,
      batteryLevel: (data['batteryLevel'] as num?)?.toDouble() ?? 1,
      rssi: (data['rssi'] as num?)?.toInt() ?? -127,
    );
  }

  /// Última telemetría resumida de un dispositivo (refresca la pantalla).
  Future<CloudDevice?> deviceFor(String deviceId) async {
    final doc = await FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .get();
    if (!doc.exists) return null;
    return CloudDevice.fromMap(doc.id, doc.data() ?? {});
  }

  /// Genera lecturas simuladas (humedad, temperatura de suelo, batería y RSSI)
  /// para el dispositivo de demostración durante `days` días, con eventos de
  /// riego y su drenaje exponencial para que el índice de infiltración tenga
  /// datos realistas. Reemplaza cualquier lectura previa del dispositivo.
  Future<int> seedDemoReadings(String deviceId, {int days = 7}) async {
    final doc = FirebaseFirestore.instance.collection('devices').doc(deviceId);
    final readings = doc.collection('readings');

    // 1) Limpiar lecturas previas del demo (regeneración limpia).
    final previous = await readings.get();
    if (previous.docs.isNotEmpty) {
      final clear = FirebaseFirestore.instance.batch();
      for (final d in previous.docs) {
        clear.delete(d.reference);
      }
      await clear.commit();
    }

    // 2) Serie horaria. Riegos cada ~44 h; el último (hace 28 h) es el de
    //    mayor aporte para que el pico máximo quede dentro de la ventana de
    //    análisis de infiltración (48 h).
    final now = DateTime.now();
    final random = math.Random();
    final events = <(double, double)>[
      (28, 30), // hace 28 h — riego reciente (pico máximo)
      (72, 18),
      (116, 18),
      (160, 18),
    ];
    const tau = 14.0; // horas de drenaje (constante de tiempo exponencial)
    final hours = days * 24;
    final batch = FirebaseFirestore.instance.batch();
    Map<String, dynamic>? latest;

    for (var i = 0; i < hours; i++) {
      final t = now.subtract(Duration(hours: hours - 1 - i));
      final hour = t.hour + t.minute / 60.0;

      double irrigation = 0;
      for (final (hoursAgo, amp) in events) {
        final since = now.difference(t).inMinutes / 60.0;
        if (since >= hoursAgo) {
          irrigation += amp * math.exp(-(since - hoursAgo) / tau);
        }
      }
      final humidity = (34.0 +
              4.0 * math.sin(2 * math.pi * (hour - 6) / 24) +
              irrigation +
              random.nextDouble() * 4 -
              2)
          .clamp(8.0, 92.0);
      final soilTemp = 14.0 +
          5.0 * math.sin(2 * math.pi * (hour - 14) / 24) +
          random.nextDouble() -
          0.5;
      final dayFrac = i / (hours - 1);
      final batteryV =
          4.15 - 0.30 * dayFrac + (random.nextDouble() * 0.03 - 0.015);
      final batteryLevel = ((batteryV - 3.3) / 0.9).clamp(0.0, 1.0);
      final rssi = (-68 + (random.nextInt(17) - 8)).clamp(-90, -40);

      // Perfil de humedad multi-depth (10 sensores cada 10 cm).
      // La superficie (10 cm) fluctúa más; la profundidad (100 cm) es más estable.
      final profile = <String, double>{};
      for (var depth = 10; depth <= 100; depth += 10) {
        final depthFactor = depth / 100.0; // 0.1 → 1.0
        final surfaceSensitivity = 1.0 - depthFactor * 0.6;
        final noise = (random.nextDouble() - 0.5) * 3.0;
        final profileHumidity = (humidity * surfaceSensitivity +
                irrigation * surfaceSensitivity * 0.8 +
                20.0 * depthFactor + // la profundidad retiene más agua
                noise)
            .clamp(5.0, 95.0);
        profile['$depth'] = double.parse(profileHumidity.toStringAsFixed(1));
      }

      // Temperaturas PT1000: 30 cm y 70 cm (la profunda es más estable).
      final temp30 = (soilTemp + 0.5 + random.nextDouble() * 0.5 - 0.25);
      final temp70 = (soilTemp - 1.5 + random.nextDouble() * 0.3 - 0.15);

      latest = {
        'ts': t.millisecondsSinceEpoch ~/ 1000,
        'humidity': double.parse(humidity.toStringAsFixed(1)),
        'soilTemp': double.parse(soilTemp.toStringAsFixed(1)),
        'batteryV': double.parse(batteryV.toStringAsFixed(2)),
        'batteryLevel': double.parse(batteryLevel.toStringAsFixed(3)),
        'rssi': rssi,
        'intervalMin': 30,
        'humidityByDepth': profile,
        'temperature30C': double.parse(temp30.toStringAsFixed(1)),
        'temperature70C': double.parse(temp70.toStringAsFixed(1)),
      };
      batch.set(readings.doc(), latest);
    }
    await batch.commit();

    // 3) Refrescar la telemetría resumida (como hace el firmware real).
    if (latest != null) {
      await doc.update({
        'humidity': latest['humidity'],
        'soilTemp': latest['soilTemp'],
        'batteryLevel': latest['batteryLevel'],
        'rssi': latest['rssi'],
        'intervalMin': latest['intervalMin'],
        'autonomyDays': 20.0,
        'lastReportAt': now.toIso8601String(),
        'isDemo': true,
        'hasSoilProfile': true,
      });
    }
    return hours;
  }

  Future<List<Field>> myFields(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fields')
        .where('owner', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) => Field.fromMap(doc.id, doc.data())).toList();
  }

  Future<String> createField(
    String uid,
    String name, {
    double? lat,
    double? lon,
    String? cropId,
    String? pumpModel,
    String? pumpHp,
    String? filterType,
    String? filterInches,
    String? filterModel,
  }) async {
    final ref = await FirebaseFirestore.instance.collection('fields').add({
      'name': name,
      'owner': uid,
      'lat': ?lat,
      'lon': ?lon,
      'cropId': ?cropId,
      'pumpModel': ?pumpModel,
      'pumpHp': ?pumpHp,
      'filterType': ?filterType,
      'filterInches': ?filterInches,
      'filterModel': ?filterModel,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  Future<void> updateField(
    String fieldId, {
    String? name,
    double? lat,
    double? lon,
    String? cropId,
    String? pumpModel,
    String? pumpHp,
    String? filterType,
    String? filterInches,
    String? filterModel,
  }) async {
    await FirebaseFirestore.instance.collection('fields').doc(fieldId).update({
      if (name != null && name.isNotEmpty) 'name': name,
      'lat': ?lat,
      'lon': ?lon,
      'cropId': ?cropId,
      'pumpModel': ?pumpModel,
      'pumpHp': ?pumpHp,
      'filterType': ?filterType,
      'filterInches': ?filterInches,
      'filterModel': ?filterModel,
    });
  }

  Future<void> deleteField(String fieldId) async {
    await FirebaseFirestore.instance.collection('fields').doc(fieldId).delete();
  }

  Future<List<Crop>> myCrops(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('crops')
        .where('owner', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) => Crop.fromMap(doc.id, doc.data())).toList();
  }

  Future<String> createCrop(String uid, Crop crop) async {
    final ref = await FirebaseFirestore.instance
        .collection('crops')
        .add(crop.toMap()..['owner'] = uid);
    return ref.id;
  }

  Future<void> updateCrop(String cropId, Crop crop) async {
    await FirebaseFirestore.instance
        .collection('crops')
        .doc(cropId)
        .update(crop.toMap());
  }

  Future<void> deleteCrop(String cropId) async {
    await FirebaseFirestore.instance.collection('crops').doc(cropId).delete();
  }

  Future<List<Sector>> sectorsFor(String fieldId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fields')
        .doc(fieldId)
        .collection('sectors')
        .orderBy('number')
        .get();
    return snapshot.docs
        .map((doc) => Sector.fromMap(doc.id, fieldId, doc.data()))
        .toList();
  }

  Future<String> createSector(String fieldId, Sector sector) async {
    final ref = await FirebaseFirestore.instance
        .collection('fields')
        .doc(fieldId)
        .collection('sectors')
        .add(sector.toMap());
    return ref.id;
  }

  Future<void> updateSector(String fieldId, Sector sector) async {
    await FirebaseFirestore.instance
        .collection('fields')
        .doc(fieldId)
        .collection('sectors')
        .doc(sector.id)
        .update(sector.toMap());
  }

  Future<void> deleteSector(String fieldId, String sectorId) async {
    await FirebaseFirestore.instance
        .collection('fields')
        .doc(fieldId)
        .collection('sectors')
        .doc(sectorId)
        .delete();
  }

  static const _layoutSectors = [
    // (bloques, areaHa, variedad, emisor, flujo L/h, tiempo h, lineas, caudal m3/h,
    //  presion mca, entreHilera m, sobreHilera m, sepEmisor m)
    ('1.3 - 1.4 - 1.6', 1.10, 'Manzanos', 'GOT.INTE', 4.17, 2.36, 2, 41.4, 36, 3.80, 1.2, 0.60),
    ('1.1 - 1.4 - 2.1 - 1.5', 0.90, 'Manzanos', 'GOT.INTE', 4.17, 2.36, 2, 34.4, 38, 3.80, 1.2, 0.60),
    ('1.7 - 1.8 - 1.9', 1.01, 'Manzanos', 'GOT.INTE', 4.17, 2.36, 2, 36.9, 37.5, 3.80, 1.2, 0.60),
    ('1.10 - 1.11 - 1.12', 1.01, 'Manzanos', 'GOT.INTE', 4.17, 2.36, 2, 36.8, 37.5, 3.80, 1.2, 0.60),
    ('2.3', 1.22, 'Kiwis', 'MICROASP', 27.00, 2.63, 1, 40.7, 36, 4.00, 2.0, 2.00),
    ('2.1', 1.00, 'Kiwis', 'MICROASP', 27.00, 2.63, 1, 32.9, 38, 4.00, 2.0, 2.00),
    ('2.2', 1.36, 'Kiwis', 'MICROASP', 27.00, 2.63, 1, 46.9, 34, 4.00, 2.0, 2.00),
    ('2.4', 1.38, 'Kiwis', 'MICROASP', 27.00, 2.63, 1, 45.9, 34, 4.00, 2.0, 2.00),
  ];

  /// Crea (si no existe) los perfiles Manzano/Kiwi y el campo "Nicolini"
  /// con sus 8 sectores de riego según el diseño real del predio.
  /// Actualiza (upsert) los datos existentes con los valores reales del campo.
  Future<void> seedFieldLayout(String uid) async {
    final crops = await myCrops(uid);
    String? cropIdFor(String name) {
      for (final c in crops) {
        if (c.name.toLowerCase() == name.toLowerCase()) return c.id;
      }
      return null;
    }

    Crop manzano(String id, String owner) => Crop(
          id: id,
          name: 'Manzano',
          owner: owner,
          minHumidity: 40,
          maxHumidity: 70,
          minTemp: 8,
          maxTemp: 32,
          irrigateBelow: 45,
          kc: 1.25,
          etpMmDay: 6.3,
          etActualMmDay: 7.8,
          efficiencyPct: 90,
          laminaBrutaMmDay: 8.7,
        );

    Crop kiwi(String id, String owner) => Crop(
          id: id,
          name: 'Kiwi',
          owner: owner,
          minHumidity: 50,
          maxHumidity: 80,
          minTemp: 5,
          maxTemp: 30,
          irrigateBelow: 55,
          kc: 1.2,
          etpMmDay: 6.3,
          etActualMmDay: 7.56,
          efficiencyPct: 85,
          laminaBrutaMmDay: 8.9,
        );

    var manzanoId = cropIdFor('Manzano');
    if (manzanoId == null) {
      manzanoId = await createCrop(uid, manzano('', uid));
    } else {
      await updateCrop(manzanoId, manzano(manzanoId, uid));
    }

    var kiwiId = cropIdFor('Kiwi');
    if (kiwiId == null) {
      kiwiId = await createCrop(uid, kiwi('', uid));
    } else {
      await updateCrop(kiwiId, kiwi(kiwiId, uid));
    }

    var fieldId = '';
    final existingFields = await myFields(uid);
    for (final f in existingFields) {
      if (f.name.toLowerCase().contains('nicolini')) {
        fieldId = f.id;
        break;
      }
    }
    // Si el usuario ya tiene un único campo, completar el diseño en él en
    // lugar de crear un campo "Nicolini" adicional.
    if (fieldId.isEmpty && existingFields.length == 1) {
      fieldId = existingFields.first.id;
    }
    if (fieldId.isEmpty) {
      fieldId = await createField(uid, 'Nicolini',
          cropId: manzanoId,
          pumpModel: 'H 625 ROD 170',
          pumpHp: '10 HP',
          filterType: 'Metálico de malla automático',
          filterInches: '4"',
          filterModel: 'ODIS 851');
    } else {
      await updateField(fieldId,
          pumpModel: 'H 625 ROD 170',
          pumpHp: '10 HP',
          filterType: 'Metálico de malla automático',
          filterInches: '4"',
          filterModel: 'ODIS 851');
    }

    final existing = await sectorsFor(fieldId);
    for (var i = 0; i < _layoutSectors.length; i++) {
      final s = _layoutSectors[i];
      final variety = s.$3;
      final isManzano = variety == 'Manzanos';
      final sector = Sector(
        id: '',
        fieldId: fieldId,
        number: i + 1,
        name: 'Sector ${i + 1}',
        variety: variety,
        blocks: s.$1,
        areaHa: s.$2,
        emitterType: s.$4,
        emitterFlowLh: s.$5,
        irrigationTimeH: s.$6,
        numLines: s.$7,
        totalFlowM3h: s.$8,
        pressureMca: s.$9.toDouble(),
        rowSpacing: s.$10,
        inRowSpacing: s.$11,
        emitterSpacing: s.$12,
        cropId: isManzano ? manzanoId : kiwiId,
      );
      final prev = existing.where((e) => e.number == sector.number).toList();
      if (prev.isNotEmpty) {
        await updateSector(fieldId,
            Sector(id: prev.first.id, fieldId: fieldId, number: sector.number,
                name: sector.name, variety: sector.variety, blocks: sector.blocks,
                areaHa: sector.areaHa, emitterType: sector.emitterType,
                emitterFlowLh: sector.emitterFlowLh, irrigationTimeH: sector.irrigationTimeH,
                numLines: sector.numLines, totalFlowM3h: sector.totalFlowM3h,
                pressureMca: sector.pressureMca, rowSpacing: sector.rowSpacing,
                inRowSpacing: sector.inRowSpacing, emitterSpacing: sector.emitterSpacing,
                cropId: sector.cropId));
      } else {
        await createSector(fieldId, sector);
      }
    }
  }
}
