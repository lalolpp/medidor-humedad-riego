class Field {
  final String id;
  final String name;
  final String owner;
  final double? lat;
  final double? lon;
  final String? cropId;
  final String? pumpModel;
  final String? pumpHp;
  final String? filterType;
  final String? filterInches;
  final String? filterModel;
  final DateTime? createdAt;

  const Field({
    required this.id,
    required this.name,
    required this.owner,
    this.lat,
    this.lon,
    this.cropId,
    this.pumpModel,
    this.pumpHp,
    this.filterType,
    this.filterInches,
    this.filterModel,
    this.createdAt,
  });

  factory Field.fromMap(String id, Map<String, dynamic> data) {
    return Field(
      id: id,
      name: data['name'] as String? ?? 'Campo $id',
      owner: data['owner'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lon: (data['lon'] as num?)?.toDouble(),
      cropId: data['cropId'] as String?,
      pumpModel: data['pumpModel'] as String?,
      pumpHp: data['pumpHp'] as String?,
      filterType: data['filterType'] as String?,
      filterInches: data['filterInches'] as String?,
      filterModel: data['filterModel'] as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'owner': owner,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (cropId != null) 'cropId': cropId,
        if (pumpModel != null) 'pumpModel': pumpModel,
        if (pumpHp != null) 'pumpHp': pumpHp,
        if (filterType != null) 'filterType': filterType,
        if (filterInches != null) 'filterInches': filterInches,
        if (filterModel != null) 'filterModel': filterModel,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
