class Reading {
  final DateTime timestamp;
  final double humidity;
  final double batteryVoltage;
  final double batteryLevel;
  final int rssi;

  const Reading({
    required this.timestamp,
    required this.humidity,
    required this.batteryVoltage,
    required this.batteryLevel,
    required this.rssi,
  });

  factory Reading.fromJsonMap(Map<String, dynamic> json) {
    final ts = json['t'] ?? json['ts'];
    final seconds = (ts is num) ? ts.toInt() : 0;
    return Reading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      humidity: ((json['h'] ?? json['humidity']) as num?)?.toDouble() ?? 0,
      batteryVoltage: ((json['bV'] ?? json['batteryV']) as num?)?.toDouble() ?? 0,
      batteryLevel: ((json['bL'] ?? json['batteryLevel']) as num?)?.toDouble() ?? 1,
      rssi: (json['rssi'] as num?)?.toInt() ?? -127,
    );
  }
}
