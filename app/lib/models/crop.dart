class Crop {
  final String id;
  final String name;
  final String owner;
  final double minHumidity;
  final double maxHumidity;
  final double minTemp;
  final double maxTemp;
  final double irrigateBelow;
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
        'createdAt': createdAt?.toIso8601String(),
      };
}
