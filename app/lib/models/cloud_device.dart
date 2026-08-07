import 'automation_config.dart';

class CloudDevice {
  final String deviceId;
  final String name;
  final String? fieldId;
  final String? cropId;
  final String? sectorId;
  final String? location;
  final DateTime? lastReportAt;
  final double? humidity;
  final double? soilTemp;
  final double? batteryLevel;
  final double? autonomyDays;
  final int? intervalMin;
  final int? rssi;
  final String owner;
  final Map<String, String> shares;
  final bool isDemo;
  final AutomationConfig automation;
  final String? automationState;
  final String? automationReason;
  final String? valveState;
  final DateTime? automationStartedAt;
  final DateTime? automationLastToggleAt;

  const CloudDevice({
    required this.deviceId,
    required this.name,
    required this.owner,
    this.fieldId,
    this.cropId,
    this.sectorId,
    this.location,
    this.lastReportAt,
    this.humidity,
    this.soilTemp,
    this.batteryLevel,
    this.autonomyDays,
    this.intervalMin,
    this.rssi,
    this.shares = const {},
    this.isDemo = false,
    this.automation = const AutomationConfig(),
    this.automationState,
    this.automationReason,
    this.valveState,
    this.automationStartedAt,
    this.automationLastToggleAt,
  });

  factory CloudDevice.fromMap(String id, Map<String, dynamic> data) {
    final status = data['automationStatus'] as Map<String, dynamic>? ?? {};
    return CloudDevice(
      deviceId: id,
      name: data['name'] as String? ?? 'Medidor $id',
      owner: data['owner'] as String? ?? '',
      fieldId: data['fieldId'] as String?,
      cropId: data['cropId'] as String?,
      sectorId: data['sectorId'] as String?,
      location: data['location'] as String?,
      lastReportAt: data['lastReportAt'] != null
          ? DateTime.tryParse(data['lastReportAt'] as String)
          : null,
      humidity: (data['humidity'] as num?)?.toDouble(),
      soilTemp: (data['soilTemp'] as num?)?.toDouble(),
      batteryLevel: (data['batteryLevel'] as num?)?.toDouble(),
      autonomyDays: (data['autonomyDays'] as num?)?.toDouble(),
      intervalMin: (data['intervalMin'] as num?)?.toInt(),
      rssi: (data['rssi'] as num?)?.toInt(),
      shares: (data['shares'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? 'viewer')),
      isDemo: data['isDemo'] == true || id.startsWith('demo-'),
      automation:
          AutomationConfig.fromMap(data['automation'] as Map<String, dynamic>?),
      automationState: status['state'] as String?,
      automationReason: status['reason'] as String?,
      valveState: status['valveState'] as String?,
      automationStartedAt: status['startedAt'] != null
          ? DateTime.tryParse(status['startedAt'] as String)
          : null,
      automationLastToggleAt: status['lastToggleAt'] != null
          ? DateTime.tryParse(status['lastToggleAt'] as String)
          : null,
    );
  }
}
