import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medidor_humedad/models/cloud_device.dart';

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

  Future<void> claimDevice(String uid, String deviceId, String name) async {
    await FirebaseFirestore.instance.collection('devices').doc(deviceId).set({
      'owner': uid,
      'name': name,
      'claimedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
