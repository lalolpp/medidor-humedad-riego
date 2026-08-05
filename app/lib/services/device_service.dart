import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/services/nodo_connection.dart';

abstract class DeviceService {
  bool get isDemo;
  Future<List<DiscoveredDevice>> discover();
  Future<NodoConnection> connect(DiscoveredDevice device);
}
