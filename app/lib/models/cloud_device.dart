class CloudDevice {
  final String deviceId;
  final String name;
  final String? location;
  final DateTime? lastReportAt;
  final double? humidity;
  final double? batteryLevel;
  final double? autonomyDays;
  final int? intervalMin;
  final String owner;

  const CloudDevice({
    required this.deviceId,
    required this.name,
    required this.owner,
    this.location,
    this.lastReportAt,
    this.humidity,
    this.batteryLevel,
    this.autonomyDays,
    this.intervalMin,
  });

  factory CloudDevice.fromMap(String id, Map<String, dynamic> data) {
    return CloudDevice(
      deviceId: id,
      name: data['name'] as String? ?? 'Medidor $id',
      owner: data['owner'] as String? ?? '',
      location: data['location'] as String?,
      lastReportAt: data['lastReportAt'] != null
          ? DateTime.tryParse(data['lastReportAt'] as String)
          : null,
      humidity: (data['humidity'] as num?)?.toDouble(),
      batteryLevel: (data['batteryLevel'] as num?)?.toDouble(),
      autonomyDays: (data['autonomyDays'] as num?)?.toDouble(),
      intervalMin: (data['intervalMin'] as num?)?.toInt(),
    );
  }
}
