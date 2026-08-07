class Sector {
  final String id;
  final String fieldId;
  final int number;
  final String name;
  final String variety;
  final String? blocks;
  final double areaHa;
  final String emitterType;
  final double? emitterFlowLh;
  final double? irrigationTimeH;
  final int? numLines;
  final double? totalFlowM3h;
  final double? pressureMca;
  final double? rowSpacing;
  final double? inRowSpacing;
  final double? emitterSpacing;
  final String? cropId;

  const Sector({
    required this.id,
    required this.fieldId,
    required this.number,
    required this.name,
    required this.variety,
    this.blocks,
    required this.areaHa,
    required this.emitterType,
    this.emitterFlowLh,
    this.irrigationTimeH,
    this.numLines,
    this.totalFlowM3h,
    this.pressureMca,
    this.rowSpacing,
    this.inRowSpacing,
    this.emitterSpacing,
    this.cropId,
  });

  factory Sector.fromMap(String id, String fieldId, Map<String, dynamic> data) {
    return Sector(
      id: id,
      fieldId: fieldId,
      number: (data['number'] as num?)?.toInt() ?? 0,
      name: data['name'] as String? ?? 'Sector',
      variety: data['variety'] as String? ?? '',
      blocks: data['blocks'] as String?,
      areaHa: (data['areaHa'] as num?)?.toDouble() ?? 0,
      emitterType: data['emitterType'] as String? ?? '',
      emitterFlowLh: (data['emitterFlowLh'] as num?)?.toDouble(),
      irrigationTimeH: (data['irrigationTimeH'] as num?)?.toDouble(),
      numLines: (data['numLines'] as num?)?.toInt(),
      totalFlowM3h: (data['totalFlowM3h'] as num?)?.toDouble(),
      pressureMca: (data['pressureMca'] as num?)?.toDouble(),
      rowSpacing: (data['rowSpacing'] as num?)?.toDouble(),
      inRowSpacing: (data['inRowSpacing'] as num?)?.toDouble(),
      emitterSpacing: (data['emitterSpacing'] as num?)?.toDouble(),
      cropId: data['cropId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'fieldId': fieldId,
        'number': number,
        'name': name,
        'variety': variety,
        if (blocks != null) 'blocks': blocks,
        'areaHa': areaHa,
        'emitterType': emitterType,
        if (emitterFlowLh != null) 'emitterFlowLh': emitterFlowLh,
        if (irrigationTimeH != null) 'irrigationTimeH': irrigationTimeH,
        if (numLines != null) 'numLines': numLines,
        if (totalFlowM3h != null) 'totalFlowM3h': totalFlowM3h,
        if (pressureMca != null) 'pressureMca': pressureMca,
        if (rowSpacing != null) 'rowSpacing': rowSpacing,
        if (inRowSpacing != null) 'inRowSpacing': inRowSpacing,
        if (emitterSpacing != null) 'emitterSpacing': emitterSpacing,
        if (cropId != null) 'cropId': cropId,
      };
}
