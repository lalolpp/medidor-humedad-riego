import 'dart:async';
import 'dart:math' as math;

import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/services/autonomy.dart';
import 'package:medidor_humedad/services/device_service.dart';
import 'package:medidor_humedad/services/nodo_connection.dart';

class DemoDeviceService implements DeviceService {
  @override
  bool get isDemo => true;

  @override
  Future<List<DiscoveredDevice>> discover() async {
    return const [
      DiscoveredDevice(id: 'demo-001', name: 'Medidor Humedad Demo', rssi: -45),
    ];
  }

  @override
  Future<NodoConnection> connect(DiscoveredDevice device) async {
    return DemoNodoConnection();
  }
}

class DemoNodoConnection implements NodoConnection {
  int _interval = 30;
  double _batteryLevel = 0.82;
  final List<Reading> _history = [];
  final _controller = StreamController<Reading?>.broadcast();
  final math.Random _random = math.Random(7);
  Timer? _timer;

  DemoNodoConnection() {
    for (int i = 48; i > 0; i--) {
      _history.add(
        _nextReading(DateTime.now().subtract(Duration(minutes: 30 * i))),
      );
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final r = _nextReading(DateTime.now());
      _history.add(r);
      if (_history.length > 600) _history.removeAt(0);
      _controller.add(r);
    });
  }

  Reading _nextReading(DateTime ts) {
    final base = 55.0 + 18.0 * math.sin(ts.millisecondsSinceEpoch / 900000);
    final humidity = (base + _random.nextDouble() * 6 - 3).clamp(0.0, 100.0);
    final soilBase = 18.0 + 4.0 * math.sin(ts.millisecondsSinceEpoch / 5400000);
    final soilTemp = soilBase + _random.nextDouble() * 1.5 - 0.75;
    _batteryLevel = (_batteryLevel - 0.00008).clamp(0.0, 1.0);
    final batteryV = 3.1 + _batteryLevel * 1.1;
    return Reading(
      timestamp: ts,
      humidity: humidity,
      soilTemp: soilTemp,
      batteryVoltage: batteryV,
      batteryLevel: _batteryLevel,
      rssi: -45,
    );
  }

  @override
  Stream<Reading?> get liveReadingStream => _controller.stream;

  @override
  Future<int?> readInterval() async => _interval;

  @override
  Future<void> setInterval(int intervalMin) async {
    if (!isValidInterval(intervalMin)) return;
    _interval = intervalMin;
  }

  @override
  Future<String> readAutonomy() async {
    final days = autonomyDays(_interval, kDefaultBatteryCapacityMah, _batteryLevel);
    return formatAutonomy(days);
  }

  @override
  Future<Reading?> readLive() async => _history.isEmpty ? null : _history.last;

  @override
  Future<BatteryInfo?> readBattery() async {
    return BatteryInfo(voltage: 3.1 + _batteryLevel * 1.1, level: _batteryLevel);
  }

  @override
  Future<int> readHistoryCount() async => _history.length;

  @override
  Future<List<Reading>> readHistory() async => List.of(_history);

  @override
  Future<ConnectionStatus?> readConnectionStatus() async {
    return const ConnectionStatus(
      bluetooth: true,
      wifi: null,
    );
  }

  bool _valve = false;

  @override
  Future<void> setValve(bool on) async => _valve = on;

  @override
  Future<bool?> readValve() async => _valve;

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _controller.close();
  }
}
