import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/services/device_service.dart';
import 'package:medidor_humedad/services/nodo_connection.dart';

const String kServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String kUuidInterval = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const String kUuidAutonomy = '6e6b9d01-1e0a-4f1e-b8e0-3f1a3f0c4a01';
const String kUuidLive = '3c8a2d6f-5b2a-4e3a-8f6d-9c1d0e2f3a4b';
const String kUuidBattery = '5a5b6c7d-8e9f-4a5b-8c7d-9e0f1a2b3c4d';
const String kUuidHistCount = '7d7e8f90-1234-4a5b-9c8d-1e2f3a4b5c6d';
const String kUuidHistNext = '8e8f9a0b-1234-4a5b-8c7d-9e0f1a2b3c4d';

class BleDeviceService implements DeviceService {
  final Map<String, BluetoothDevice> _found = {};

  @override
  bool get isDemo => false;

  @override
  Future<List<DiscoveredDevice>> discover() async {
    _found.clear();

    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      throw Exception('Activa el Bluetooth: $e');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception('Bluetooth no disponible (estado: $adapterState)');
    }

    final completer = Completer<List<ScanResult>>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      if (!completer.isCompleted) completer.complete(List.of(results));
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
    );
    await Future.delayed(const Duration(seconds: 10));
    await sub.cancel();
    await FlutterBluePlus.stopScan();

    final results = completer.isCompleted ? completer.future : null;
    final list = <DiscoveredDevice>[];
    if (results != null) {
      for (final r in await results) {
        _found[r.device.remoteId.str] = r.device;
        list.add(DiscoveredDevice(
          id: r.device.remoteId.str,
          name: r.device.platformName.isEmpty
              ? 'Medidor Humedad'
              : r.device.platformName,
          rssi: r.rssi,
        ));
      }
    }
    return list;
  }

  @override
  Future<NodoConnection> connect(DiscoveredDevice device) async {
    final dev = _found[device.id];
    if (dev == null) throw Exception('Dispositivo no encontrado');
    await FlutterBluePlus.adapterState.firstWhere(
      (state) => state == BluetoothAdapterState.on,
    );
    await dev.connect(license: License.nonprofit);
    await dev.discoverServices();
    return BleNodoConnection(dev);
  }
}

class BleNodoConnection implements NodoConnection {
  final BluetoothDevice _device;
  BluetoothCharacteristic? _intervalChr;
  BluetoothCharacteristic? _autonomyChr;
  BluetoothCharacteristic? _liveChr;
  BluetoothCharacteristic? _batteryChr;
  BluetoothCharacteristic? _histCountChr;
  BluetoothCharacteristic? _histNextChr;

  final _controller = StreamController<Reading?>.broadcast();
  StreamSubscription? _liveSub;

  BleNodoConnection(this._device) {
    _mapCharacteristics();
    _liveSub = _liveChr?.onValueReceived.listen((value) {
      final r = _parseLive(value);
      if (r != null && !_controller.isClosed) _controller.add(r);
    });
  }

  void _mapCharacteristics() {
    for (final service in _device.servicesList) {
      if (service.uuid.str != kServiceUuid) continue;
      for (final characteristic in service.characteristics) {
        switch (characteristic.uuid.str) {
          case kUuidInterval:
            _intervalChr = characteristic;
          case kUuidAutonomy:
            _autonomyChr = characteristic;
          case kUuidLive:
            _liveChr = characteristic;
            characteristic.setNotifyValue(true);
          case kUuidBattery:
            _batteryChr = characteristic;
          case kUuidHistCount:
            _histCountChr = characteristic;
          case kUuidHistNext:
            _histNextChr = characteristic;
        }
      }
    }
  }

  Reading? _parseLive(List<int> value) {
    final text = utf8.decode(value, allowMalformed: true).trim();
    if (text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) return Reading.fromJsonMap(json);
    } catch (_) {}
    return null;
  }

  @override
  Stream<Reading?> get liveReadingStream => _controller.stream;

  @override
  Future<int?> readInterval() async {
    final value = await _intervalChr?.read();
    if (value == null) return null;
    final text = utf8.decode(value, allowMalformed: true).trim();
    return int.tryParse(text);
  }

  @override
  Future<void> setInterval(int intervalMin) async {
    await _intervalChr?.write(utf8.encode('$intervalMin'));
  }

  @override
  Future<String> readAutonomy() async {
    final value = await _autonomyChr?.read();
    if (value == null) return '—';
    return utf8.decode(value, allowMalformed: true).trim();
  }

  @override
  Future<Reading?> readLive() async {
    final value = await _liveChr?.read();
    if (value == null) return null;
    return _parseLive(value);
  }

  @override
  Future<BatteryInfo?> readBattery() async {
    final value = await _batteryChr?.read();
    if (value == null) return null;
    final text = utf8.decode(value, allowMalformed: true).trim();
    final voltageMatch = RegExp(r'(\d+(?:\.\d+)?)V').firstMatch(text);
    final levelMatch = RegExp(r'\((\d+)%\)').firstMatch(text);
    if (voltageMatch == null) return null;
    return BatteryInfo(
      voltage: double.tryParse(voltageMatch.group(1)!) ?? 0,
      level: (double.tryParse(levelMatch?.group(1) ?? '') ?? 0) / 100,
    );
  }

  @override
  Future<int> readHistoryCount() async {
    final value = await _histCountChr?.read();
    if (value == null) return 0;
    return int.tryParse(utf8.decode(value, allowMalformed: true).trim()) ?? 0;
  }

  @override
  Future<List<Reading>> readHistory() async {
    final readings = <Reading>[];
    while (true) {
      final chunk = await _histNextChr?.read();
      if (chunk == null) break;
      final text = utf8.decode(chunk, allowMalformed: true).trim();
      if (text.isEmpty || text == '[]') break;
      final decoded = jsonDecode(text);
      if (decoded is! List) break;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          readings.add(Reading.fromJsonMap(item));
        }
      }
      if (decoded.length < 20) break;
    }
    return readings;
  }

  @override
  Future<void> close() async {
    await _liveSub?.cancel();
    if (!_controller.isClosed) await _controller.close();
    if (_device.isConnected) await _device.disconnect();
  }
}
