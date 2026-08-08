import '../models/crop.dart';
import '../models/sector.dart';

class PlanRow {
  final Sector sector;
  final Crop? crop;
  final double dailyLaminaMm;
  final double efficiencyPct;
  final double irrigationTimeH;
  final double totalFlowM3h;
  final int daysPerWeek;

  PlanRow({
    required this.sector,
    required this.crop,
    required this.dailyLaminaMm,
    required this.efficiencyPct,
    required this.irrigationTimeH,
    required this.totalFlowM3h,
    required this.daysPerWeek,
  });

  double get weeklyMm => dailyLaminaMm * daysPerWeek;
  double get weeklyHours => irrigationTimeH * daysPerWeek;
  double get weeklyM3 => totalFlowM3h * weeklyHours;
  double get monthlyMm => weeklyMm * 4.345;
  double get monthlyHours => weeklyHours * 4.345;
  double get monthlyM3 => totalFlowM3h * monthlyHours;
}

class IrrigationPlan {
  static const List<double> typicalEtoMmDay = [
    6.6, // Ene
    6.0, // Feb
    5.2, // Mar
    3.6, // Abr
    2.1, // May
    1.3, // Jun
    1.3, // Jul
    1.8, // Ago
    2.8, // Sep
    4.2, // Oct
    5.3, // Nov
    6.3, // Dic
  ];

  static const List<String> monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Frecuencia recomendada según la ETo (método FAO: FR = Hd / ETc).
  static int daysPerWeekFor(double eto) {
    if (eto >= 6.0) return 7;
    if (eto >= 4.8) return 6;
    if (eto >= 3.8) return 5;
    if (eto >= 2.8) return 4;
    if (eto >= 1.8) return 3;
    return 2;
  }

  /// Genera el plan por sector usando los datos reales del predio.
  static List<PlanRow> plan(
    List<Sector> sectors,
    Map<String, Crop> crops, {
    required double etoMmDay,
  }) {
    final rows = <PlanRow>[];
    for (final s in sectors) {
      final crop = s.cropId != null ? crops[s.cropId] : null;
      rows.add(PlanRow(
        sector: s,
        crop: crop,
        dailyLaminaMm: crop?.laminaBrutaMmDay ?? 8.5,
        efficiencyPct: crop?.efficiencyPct ?? 85,
        irrigationTimeH: s.irrigationTimeH ?? 2.4,
        totalFlowM3h: s.totalFlowM3h ?? 0,
        daysPerWeek: daysPerWeekFor(etoMmDay),
      ));
    }
    return rows;
  }

  /// Verifica la lámina contra la referencia de diseño diaria del sector.
  static String checkLamina(PlanRow r) {
    final aplicada = r.irrigationTimeH * r.totalFlowM3h / (r.sector.areaHa * 10);
    final ref = r.dailyLaminaMm;
    if (ref <= 0) return '';
    final pct = aplicada / ref * 100;
    if (pct >= 95 && pct <= 108) return 'coherente';
    if (pct < 95) return 'bajo';
    return 'alto';
  }
}
