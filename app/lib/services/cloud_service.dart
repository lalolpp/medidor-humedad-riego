import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
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

  Future<List<Reading>> readingsFor(String deviceId,
      {int limit = 2000, DateTime? from, DateTime? to}) async {
    var query = FirebaseFirestore.instance
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
  }) async {
    final ref = await FirebaseFirestore.instance.collection('fields').add({
      'name': name,
      'owner': uid,
      'lat': ?lat,
      'lon': ?lon,
      'cropId': ?cropId,
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
  }) async {
    await FirebaseFirestore.instance.collection('fields').doc(fieldId).update({
      if (name != null && name.isNotEmpty) 'name': name,
      'lat': ?lat,
      'lon': ?lon,
      'cropId': ?cropId,
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
    // (bloques, areaHa, variedad, emisor, flujo L/h, tiempo h, lineas, caudal m3/h, presion mca)
    ('1.3, 1.4, 1.6', 1.10, 'Manzanos', 'Goteo interior', 4.17, 2.36, 241, 43.0, 6),
    ('1.1, 1.4, 1.5', 0.90, 'Manzanos', 'Goteo interior', 4.17, 2.36, 234, 43.0, 8),
    ('1.7, 1.8, 1.9', 1.01, 'Manzanos', 'Goteo interior', 4.17, 2.36, 236, 36.0, 7.5),
    ('1.10, 1.11, 1.12', 1.01, 'Manzanos', 'Goteo interior', 4.17, 2.36, 236, 36.0, 7.5),
    ('2.3', 1.22, 'Kiwis', 'Microaspersión', 27.00, 2.63, 140, 36.0, 6),
    ('2.1', 1.00, 'Kiwis', 'Microaspersión', 27.00, 2.63, 132, 38.0, 8),
    ('2.2', 1.36, 'Kiwis', 'Microaspersión', 27.00, 2.63, 146, 34.0, 4),
    ('2.4', 1.38, 'Kiwis', 'Microaspersión', 27.00, 2.63, 145, 34.0, 4),
  ];

  /// Crea (si no existe) los perfiles Manzano/Kiwi y el campo "Nicolini 2"
  /// con sus 8 sectores de riego según el diseño del predio.
  Future<void> seedFieldLayout(String uid) async {
    final existingFields = await myFields(uid);
    if (existingFields.any((f) => f.name.toLowerCase().contains('nicolini'))) {
      return;
    }

    final crops = await myCrops(uid);
    String? cropIdFor(String name) {
      for (final c in crops) {
        if (c.name.toLowerCase() == name.toLowerCase()) return c.id;
      }
      return null;
    }

    var manzanoId = cropIdFor('Manzano');
    manzanoId ??= await createCrop(
      uid,
      Crop(
        id: '',
        name: 'Manzano',
        owner: uid,
        minHumidity: 40,
        maxHumidity: 70,
        minTemp: 8,
        maxTemp: 32,
        irrigateBelow: 45,
      ),
    );

    var kiwiId = cropIdFor('Kiwi');
    kiwiId ??= await createCrop(
      uid,
      Crop(
        id: '',
        name: 'Kiwi',
        owner: uid,
        minHumidity: 50,
        maxHumidity: 80,
        minTemp: 5,
        maxTemp: 30,
        irrigateBelow: 55,
      ),
    );

    final fieldId = await createField(uid, 'Nicolini 2', cropId: manzanoId);

    for (var i = 0; i < _layoutSectors.length; i++) {
      final s = _layoutSectors[i];
      final variety = s.$3;
      final isManzano = variety == 'Manzanos';
      await createSector(
        fieldId,
        Sector(
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
          cropId: isManzano ? manzanoId : kiwiId,
        ),
      );
    }
  }
}
