class Field {
  final String id;
  final String name;
  final String owner;
  final double? lat;
  final double? lon;
  final String? cropId;
  final DateTime? createdAt;

  const Field({
    required this.id,
    required this.name,
    required this.owner,
    this.lat,
    this.lon,
    this.cropId,
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
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
    );
  }
}
