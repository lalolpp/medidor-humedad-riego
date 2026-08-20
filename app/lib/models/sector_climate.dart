class SectorClimate {
  final String id;
  final String sectorId;
  final String? fieldId;
  final DateTime date;
  final double? avgHumidity;
  final double? minHumidity;
  final double? maxHumidity;
  final double? avgTemp;
  final double? minTemp;
  final double? maxTemp;
  final double? precipitationMm;
  final double? etpMm;

  const SectorClimate({
    required this.id,
    required this.sectorId,
    this.fieldId,
    required this.date,
    this.avgHumidity,
    this.minHumidity,
    this.maxHumidity,
    this.avgTemp,
    this.minTemp,
    this.maxTemp,
    this.precipitationMm,
    this.etpMm,
  });

  factory SectorClimate.fromMap(String id, Map<String, dynamic> data) {
    return SectorClimate(
      id: id,
      sectorId: data['sectorId'] as String? ?? '',
      fieldId: data['fieldId'] as String?,
      date: data['date'] != null
          ? DateTime.tryParse(data['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      avgHumidity: (data['avgHumidity'] as num?)?.toDouble(),
      minHumidity: (data['minHumidity'] as num?)?.toDouble(),
      maxHumidity: (data['maxHumidity'] as num?)?.toDouble(),
      avgTemp: (data['avgTemp'] as num?)?.toDouble(),
      minTemp: (data['minTemp'] as num?)?.toDouble(),
      maxTemp: (data['maxTemp'] as num?)?.toDouble(),
      precipitationMm: (data['precipitationMm'] as num?)?.toDouble(),
      etpMm: (data['etpMm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'sectorId': sectorId,
        if (fieldId != null) 'fieldId': fieldId,
        'date': date.toIso8601String().substring(0, 10),
        if (avgHumidity != null) 'avgHumidity': avgHumidity,
        if (minHumidity != null) 'minHumidity': minHumidity,
        if (maxHumidity != null) 'maxHumidity': maxHumidity,
        if (avgTemp != null) 'avgTemp': avgTemp,
        if (minTemp != null) 'minTemp': minTemp,
        if (maxTemp != null) 'maxTemp': maxTemp,
        if (precipitationMm != null) 'precipitationMm': precipitationMm,
        if (etpMm != null) 'etpMm': etpMm,
      };
}
