class Reading {
  final DateTime timestamp;
  final double humidity;
  final double soilTemp;
  final double? temperature30C;
  final double? temperature70C;
  final Map<int, double> humidityByDepth;
  final double batteryVoltage;
  final double batteryLevel;
  final int rssi;

  const Reading({
    required this.timestamp,
    required this.humidity,
    this.soilTemp = double.nan,
    this.temperature30C,
    this.temperature70C,
    this.humidityByDepth = const {},
    required this.batteryVoltage,
    required this.batteryLevel,
    required this.rssi,
  });

  bool get hasSoilProfile => humidityByDepth.isNotEmpty;

  double? humidityAt(int depthCm) => humidityByDepth[depthCm];

  factory Reading.fromJsonMap(Map<String, dynamic> json) {
    final profile = _profileFrom(json);
    final primaryHumidity = _number(json['h'] ?? json['humidity']);
    final average = profile.isEmpty
        ? 0.0
        : profile.values.reduce((a, b) => a + b) / profile.length;
    final rawBattery = _number(
      json['bL'] ?? json['batteryLevel'] ?? json['batteryPercent'],
    );
    final temp30 = _number(
      json['temperature30C'] ?? json['temp30'] ?? json['pt1000_30'],
    );
    final temp70 = _number(
      json['temperature70C'] ?? json['temp70'] ?? json['pt1000_70'],
    );
    final legacyTemp = _number(json['temp'] ?? json['soilTemp'] ?? json['st']);

    return Reading(
      timestamp: _timestamp(json['t'] ?? json['ts']),
      humidity: primaryHumidity ?? (profile.isEmpty ? 0 : average),
      soilTemp: legacyTemp ?? temp30 ?? double.nan,
      temperature30C: temp30,
      temperature70C: temp70,
      humidityByDepth: profile,
      batteryVoltage: _number(
            json['bV'] ?? json['batteryV'] ?? json['batteryVoltage'],
          ) ??
          0,
      batteryLevel: rawBattery == null
          ? 1
          : (rawBattery > 1 ? rawBattery / 100 : rawBattery).clamp(0, 1),
      rssi: (_number(json['rssi']) ?? -127).round(),
    );
  }

  static DateTime _timestamp(dynamic value) {
    if (value is num) {
      final raw = value.toInt();
      final millis = raw.abs() < 100000000000 ? raw * 1000 : raw;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    try {
      final date = (value as dynamic).toDate();
      if (date is DateTime) return date.toUtc();
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<int, double> _profileFrom(Map<String, dynamic> json) {
    final result = <int, double>{};
    final raw = json['humidityByDepth'] ??
        json['humidityProfile'] ??
        json['soilProfile'];

    if (raw is Map) {
      for (final entry in raw.entries) {
        final depth = int.tryParse(entry.key.toString());
        final humidity = _number(entry.value);
        if (depth != null && humidity != null) result[depth] = humidity;
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final depth = _number(item['depthCm'] ?? item['depth']);
        final humidity = _number(item['humidity'] ?? item['value']);
        if (depth != null && humidity != null) {
          result[depth.round()] = humidity;
        }
      }
    }

    for (var depth = 10; depth <= 100; depth += 10) {
      final humidity = _number(
        json['h$depth'] ?? json['humidity$depth'] ?? json['hs$depth'],
      );
      if (humidity != null) result[depth] = humidity;
    }
    return Map.unmodifiable(result);
  }
}
