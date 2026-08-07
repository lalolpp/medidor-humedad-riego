class Crop {
  final String id;
  final String name;
  final String owner;
  final double minHumidity;
  final double maxHumidity;
  final double minTemp;
  final double maxTemp;
  final double irrigateBelow;
  final double? kc;
  final double? etpMmDay;
  final double? etActualMmDay;
  final double? efficiencyPct;
  final double? laminaBrutaMmDay;
  final DateTime? createdAt;

  const Crop({
    required this.id,
    required this.name,
    required this.owner,
    this.minHumidity = 30,
    this.maxHumidity = 70,
    this.minTemp = 8,
    this.maxTemp = 32,
    this.irrigateBelow = 35,
    this.kc,
    this.etpMmDay,
    this.etActualMmDay,
    this.efficiencyPct,
    this.laminaBrutaMmDay,
    this.createdAt,
  });

  factory Crop.fromMap(String id, Map<String, dynamic> data) {
    return Crop(
      id: id,
      name: data['name'] as String? ?? 'Cultivo $id',
      owner: data['owner'] as String? ?? '',
      minHumidity: (data['minHumidity'] as num?)?.toDouble() ?? 30,
      maxHumidity: (data['maxHumidity'] as num?)?.toDouble() ?? 70,
      minTemp: (data['minTemp'] as num?)?.toDouble() ?? 8,
      maxTemp: (data['maxTemp'] as num?)?.toDouble() ?? 32,
      irrigateBelow: (data['irrigateBelow'] as num?)?.toDouble() ?? 35,
      kc: (data['kc'] as num?)?.toDouble(),
      etpMmDay: (data['etpMmDay'] as num?)?.toDouble(),
      etActualMmDay: (data['etActualMmDay'] as num?)?.toDouble(),
      efficiencyPct: (data['efficiencyPct'] as num?)?.toDouble(),
      laminaBrutaMmDay: (data['laminaBrutaMmDay'] as num?)?.toDouble(),
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'owner': owner,
        'minHumidity': minHumidity,
        'maxHumidity': maxHumidity,
        'minTemp': minTemp,
        'maxTemp': maxTemp,
        'irrigateBelow': irrigateBelow,
        if (kc != null) 'kc': kc,
        if (etpMmDay != null) 'etpMmDay': etpMmDay,
        if (etActualMmDay != null) 'etActualMmDay': etActualMmDay,
        if (efficiencyPct != null) 'efficiencyPct': efficiencyPct,
        if (laminaBrutaMmDay != null) 'laminaBrutaMmDay': laminaBrutaMmDay,
        'createdAt': createdAt?.toIso8601String(),
      };
}
