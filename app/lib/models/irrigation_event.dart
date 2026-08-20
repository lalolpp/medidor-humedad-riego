class IrrigationEvent {
  final String id;
  final String deviceId;
  final String? fieldId;
  final String? sectorId;
  final String source;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? durationMin;
  final double? depthCmSnapshot;
  final double? humidityBefore;
  final double? humidityAfter;
  final String? status;

  const IrrigationEvent({
    required this.id,
    required this.deviceId,
    this.fieldId,
    this.sectorId,
    this.source = 'manual',
    required this.startedAt,
    this.endedAt,
    this.durationMin,
    this.depthCmSnapshot,
    this.humidityBefore,
    this.humidityAfter,
    this.status = 'completed',
  });

  factory IrrigationEvent.fromMap(String id, Map<String, dynamic> data) {
    return IrrigationEvent(
      id: id,
      deviceId: data['deviceId'] as String? ?? '',
      fieldId: data['fieldId'] as String?,
      sectorId: data['sectorId'] as String?,
      source: data['source'] as String? ?? 'manual',
      startedAt: data['startedAt'] != null
          ? DateTime.tryParse(data['startedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      endedAt: data['endedAt'] != null
          ? DateTime.tryParse(data['endedAt'] as String)
          : null,
      durationMin: (data['durationMin'] as num?)?.toDouble(),
      depthCmSnapshot: (data['depthCmSnapshot'] as num?)?.toDouble(),
      humidityBefore: (data['humidityBefore'] as num?)?.toDouble(),
      humidityAfter: (data['humidityAfter'] as num?)?.toDouble(),
      status: data['status'] as String? ?? 'completed',
    );
  }

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        if (fieldId != null) 'fieldId': fieldId,
        if (sectorId != null) 'sectorId': sectorId,
        'source': source,
        'startedAt': startedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (durationMin != null) 'durationMin': durationMin,
        if (depthCmSnapshot != null) 'depthCmSnapshot': depthCmSnapshot,
        if (humidityBefore != null) 'humidityBefore': humidityBefore,
        if (humidityAfter != null) 'humidityAfter': humidityAfter,
        if (status != null) 'status': status,
      };
}
