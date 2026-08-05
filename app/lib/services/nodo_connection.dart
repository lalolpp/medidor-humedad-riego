import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/models/reading.dart';

abstract class NodoConnection {
  Stream<Reading?> get liveReadingStream;

  Future<int?> readInterval();
  Future<void> setInterval(int intervalMin);
  Future<String> readAutonomy();
  Future<Reading?> readLive();
  Future<BatteryInfo?> readBattery();
  Future<int> readHistoryCount();
  Future<List<Reading>> readHistory();
  Future<void> close();
}
