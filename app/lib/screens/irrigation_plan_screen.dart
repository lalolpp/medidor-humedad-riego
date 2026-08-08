import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/sector.dart';
import 'package:medidor_humedad/services/irrigation_plan.dart';
import 'package:medidor_humedad/widgets/smart_dashboard.dart';

class IrrigationPlanScreen extends StatefulWidget {
  final List<Sector> sectors;
  final Map<String, Crop> crops;
  const IrrigationPlanScreen({
    super.key,
    required this.sectors,
    required this.crops,
  });

  @override
  State<IrrigationPlanScreen> createState() => _IrrigationPlanScreenState();
}

class _IrrigationPlanScreenState extends State<IrrigationPlanScreen> {
  int _month = DateTime.now().month - 1;
  double _eto = IrrigationPlan.typicalEtoMmDay[DateTime.now().month - 1];

  @override
  Widget build(BuildContext context) {
    final rows = IrrigationPlan.plan(widget.sectors, widget.crops,
        etoMmDay: _eto);
    final days = IrrigationPlan.daysPerWeekFor(_eto);

    final weekM3 = rows.fold<double>(0, (a, r) => a + r.weeklyM3);
    final weekH = rows.fold<double>(0, (a, r) => a + r.weeklyHours);
    final monthM3 = rows.fold<double>(0, (a, r) => a + r.monthlyM3);
    final monthH = rows.fold<double>(0, (a, r) => a + r.monthlyHours);

    return Scaffold(
      backgroundColor: kDbg,
      appBar: AppBar(
        backgroundColor: kCard,
        foregroundColor: kText,
        title: const Text('Plan de riego'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            'Configuración',
            Column(
              children: [
                Row(
                  children: [
                    const Text('Mes',
                        style: TextStyle(fontSize: 13, color: kText2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _month,
                        isExpanded: true,
                        dropdownColor: kCard,
                        style: const TextStyle(color: kText, fontSize: 14),
                        underline: Container(
                          height: 1,
                          color: kBorder,
                        ),
                        items: [
                          for (var i = 0;
                              i < IrrigationPlan.monthNames.length;
                              i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(IrrigationPlan.monthNames[i]),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _month = v!;
                          _eto =
                              IrrigationPlan.typicalEtoMmDay[_month];
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('ETP (mm/día)',
                        style: TextStyle(fontSize: 13, color: kText2)),
                    const SizedBox(width: 8),
                    Text(_eto.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kBlue)),
                  ],
                ),
                Slider(
                  value: _eto.clamp(0.5, 7.5),
                  min: 0.5,
                  max: 7.5,
                  divisions: 70,
                  activeColor: kBlue,
                  inactiveColor: kBorder,
                  onChanged: (v) => setState(() => _eto = v),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_repeat, size: 15, color: kGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Frecuencia recomendada: $days días por semana',
                      style: const TextStyle(fontSize: 13, color: kText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            'Totales del predio',
            Column(
              children: [
                _totalRow('Por semana', '$weekH h', '$weekM3 m³'),
                _totalRow('Por mes', '$monthH h', '$monthM3 m³'),
                const Divider(color: kBorder, height: 16),
                Text(
                  'Lámina semanal equivalente: '
                  '${weekM3 > 0 && rows.isNotEmpty ? weekMm(rows).toStringAsFixed(1) : '—'} mm',
                  style: const TextStyle(fontSize: 12, color: kText2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card('Recomendaciones', _recommendations(rows)),
          const SizedBox(height: 12),
          _card('Detalle por sector', _sectorRows(rows)),
        ],
      ),
    );
  }

  double weekMm(List<PlanRow> rows) {
    final weighted =
        rows.fold<double>(0, (a, r) => a + r.weeklyMm * r.sector.areaHa);
    final area = rows.fold<double>(0, (a, r) => a + r.sector.areaHa);
    return area <= 0 ? 0 : weighted / area;
  }

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: kText2),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _totalRow(String label, String hours, String volume) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: kText2)),
          ),
          Text(hours,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: kYellow)),
          const SizedBox(width: 14),
          Text(volume,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: kBlue)),
        ],
      ),
    );
  }

  Widget _recommendations(List<PlanRow> rows) {
    final hasManzano =
        rows.any((r) => r.sector.variety.toLowerCase().contains('manzano'));
    final hasKiwi =
        rows.any((r) => r.sector.variety.toLowerCase().contains('kiwi'));
    final items = <String>[];
    if (hasManzano) {
      items.addAll(const [
        'Manzano (goteo): en el peak regar cada 1-2 días; no dejar más de 2 días sin agua. Periodos críticos: floración-cuaja (sep-oct) y crecimiento del fruto (nov-feb); el estrés reduce el calibre.',
        'Regar de madrugada y, si la infiltración no alcanza, fraccionar en 2 turnos. Lámina de diseño: 8.7 mm/día (ETc 7.8 con 90% de eficiencia).',
      ]);
    }
    if (hasKiwi) {
      items.addAll(const [
        'Kiwi (microaspersión): demanda muy alta (800-1200 mm/año); el estrés hídrico detiene el crecimiento del fruto. Regar diario o cada 2 días en verano.',
        'Preferir la madrugada, nunca regar al anochecer (riesgo de hongos) y evitar el encharcamiento (pudrición radicular). Lámina de diseño: 8.9 mm/día (ETc 7.56 con 85% de eficiencia).',
      ]);
    }
    if (items.isEmpty) {
      items.add(
          'Ajusta la frecuencia al consumo (ETc = ETo × Kc) y repón la lámina descontando lluvia.');
    }
    items.add(
        'Si llueve ≥ 10 mm, pausa el riego y reprograma; valida semanalmente con las sondas de humedad.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 15, color: kGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(fontSize: 12, color: kText),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectorRows(List<PlanRow> rows) {
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kCardHi,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.sector.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kText),
                        ),
                      ),
                      _badge(
                          '${r.daysPerWeek} d/sem',
                          r.daysPerWeek >= 6 ? kOrange : kGreen),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.sector.variety} · ${r.sector.areaHa.toStringAsFixed(2)} ha · '
                    '${r.dailyLaminaMm.toStringAsFixed(1)} mm/día',
                    style: const TextStyle(fontSize: 11, color: kText2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat('Semana', '${r.weeklyHours.toStringAsFixed(1)} h',
                            '${r.weeklyM3.toStringAsFixed(0)} m³'),
                      ),
                      Expanded(
                        child: _miniStat('Mes', '${r.monthlyHours.toStringAsFixed(1)} h',
                            '${r.monthlyM3.toStringAsFixed(0)} m³'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniStat(String label, String hours, String volume) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: kText2)),
        Text(hours,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kYellow)),
        Text(volume,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: kBlue)),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
