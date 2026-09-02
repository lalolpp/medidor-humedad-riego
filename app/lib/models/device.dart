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

class WifiLinkInfo {
  final bool connected;
  final String? ssid;
  final String? ip;
  final int rssi;

  const WifiLinkInfo({
    required this.connected,
    this.ssid,
    this.ip,
    this.rssi = 0,
  });
}

class ConnectionStatus {
  final bool bluetooth;
  final WifiLinkInfo? wifi;

  const ConnectionStatus({required this.bluetooth, this.wifi});
}
