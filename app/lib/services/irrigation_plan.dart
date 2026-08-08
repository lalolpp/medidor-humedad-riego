import '../models/crop.dart';
import '../models/sector.dart';

class PlanRow {
  final Sector sector;
  final Crop? crop;
  final double etcMmDay;
  final double dailyLaminaMm;
  final double efficiencyPct;
  final double timePerTurnH;
  final double totalFlowM3h;
  final int daysPerWeek;
  final int turns;

  PlanRow({
    required this.sector,
    required this.crop,
    required this.etcMmDay,
    required this.dailyLaminaMm,
    required this.efficiencyPct,
    required this.timePerTurnH,
    required this.totalFlowM3h,
    required this.daysPerWeek,
    required this.turns,
  });

  /// Lámina neta diaria = demanda del cultivo (ETc = ETo × Kc).
  double get laminaNetaMmDay => etcMmDay;

  /// Horas totales por día de riego (turnos × horas por turno).
  double get timePerDayH => timePerTurnH * turns;

  double get weeklyMm => dailyLaminaMm * daysPerWeek;
  double get weeklyHours => timePerDayH * daysPerWeek;
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

  /// Frecuencia recomendada según la demanda diaria ETc (método FAO: FR = Hd / ETc).
  static int daysPerWeekFor(double etc) {
    if (etc >= 6.0) return 7;
    if (etc >= 4.8) return 6;
    if (etc >= 3.8) return 5;
    if (etc >= 2.8) return 4;
    if (etc >= 1.8) return 3;
    return 2;
  }

  static double kcFor(Crop? crop) => crop?.kc ?? 0.9;

  static double laminaFor(Crop? crop) => crop?.laminaBrutaMmDay ?? 8.5;

  static double efficiencyFor(Crop? crop) => crop?.efficiencyPct ?? 85;

  /// Genera el plan por sector usando los datos reales del predio.
  /// Los ajustes manuales por sector (planLamina/planDays/planTurns/planEff)
  /// tienen prioridad sobre los valores por defecto del cultivo.
  static List<PlanRow> plan(
    List<Sector> sectors,
    Map<String, Crop> crops, {
    required double etoMmDay,
  }) {
    final rows = <PlanRow>[];
    for (final s in sectors) {
      final crop = s.cropId != null ? crops[s.cropId] : null;
      final etc = etoMmDay * kcFor(crop);
      final lamina = s.planLaminaMmDay ?? laminaFor(crop);
      final eff = s.planEfficiencyPct ?? efficiencyFor(crop);
      final turns = s.planTurns ?? 1;
      final flow = s.totalFlowM3h ?? 0;

      // Tiempo de riego diario necesario para aplicar la lámina bruta,
      // derivado del caudal del sector (1 mm sobre 1 ha = 10 m³).
      double timePerDay;
      if (flow > 0 && s.areaHa > 0) {
        timePerDay = lamina * s.areaHa * 10 / flow;
      } else {
        timePerDay = s.irrigationTimeH ?? 2.4;
      }

      rows.add(PlanRow(
        sector: s,
        crop: crop,
        etcMmDay: etc,
        dailyLaminaMm: lamina,
        efficiencyPct: eff,
        timePerTurnH: timePerDay / turns,
        totalFlowM3h: flow,
        daysPerWeek: s.planDaysPerWeek ?? daysPerWeekFor(etc),
        turns: turns,
      ));
    }
    return rows;
  }

  /// Compara la lámina que realmente entrega el sistema (tiempo × caudal)
  /// contra la lámina bruta objetivo del sector.
  static String checkLamina(PlanRow r) {
    final aplicada = r.timePerDayH * r.totalFlowM3h / (r.sector.areaHa * 10);
    final ref = r.dailyLaminaMm;
    if (ref <= 0) return '';
    final pct = aplicada / ref * 100;
    if (pct >= 95 && pct <= 108) return 'coherente';
    if (pct < 95) return 'bajo';
    return 'alto';
  }
}
