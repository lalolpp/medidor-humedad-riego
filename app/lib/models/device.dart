class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

class BatteryInfo {
  final double voltage;
  final double level;

  const BatteryInfo({required this.voltage, required this.level});
}
