import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/sector.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/irrigation_plan.dart';
import 'package:medidor_humedad/widgets/smart_dashboard.dart';

enum _PlanMode { general, sector }

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
  late List<Sector> _sectors;
  int _month = DateTime.now().month - 1;
  double _eto = IrrigationPlan.typicalEtoMmDay[DateTime.now().month - 1];
  _PlanMode _mode = _PlanMode.general;
  String? _selectedSectorId;
  bool _saving = false;

  // Campos de edición del sector seleccionado.
  String? _editCropId;
  double _editLamina = 8.5;
  int _editDays = 3;
  int _editTurns = 1;
  double _editEff = 85;

  @override
  void initState() {
    super.initState();
    _sectors = List.of(widget.sectors);
    if (_sectors.isNotEmpty) {
      _selectedSectorId = _sectors.first.id;
      _loadEdit(_selectedSectorId!);
    }
  }

  Sector? get _selectedSector {
    for (final s in _sectors) {
      if (s.id == _selectedSectorId) return s;
    }
    return null;
  }

  Crop? _cropFor(Sector s) {
    return s.cropId != null ? widget.crops[s.cropId] : null;
  }

  void _selectSector(String id) {
    setState(() {
      _selectedSectorId = id;
      _loadEdit(id);
    });
  }

  void _loadEdit(String id) {
    final s = _sectors.firstWhere((x) => x.id == id);
    final crop = _cropFor(s);
    _editCropId = s.cropId;
    _editLamina = s.planLaminaMmDay ?? IrrigationPlan.laminaFor(crop);
    _editDays = s.planDaysPerWeek ??
        IrrigationPlan.daysPerWeekFor(_eto * IrrigationPlan.kcFor(crop));
    _editTurns = s.planTurns ?? 1;
    _editEff = s.planEfficiencyPct ?? IrrigationPlan.efficiencyFor(crop);
  }

  Sector _buildEditedSector(Sector s, {bool clearPlan = false}) {
    return Sector(
      id: s.id,
      fieldId: s.fieldId,
      number: s.number,
      name: s.name,
      variety: s.variety,
      blocks: s.blocks,
      areaHa: s.areaHa,
      emitterType: s.emitterType,
      emitterFlowLh: s.emitterFlowLh,
      irrigationTimeH: s.irrigationTimeH,
      numLines: s.numLines,
      totalFlowM3h: s.totalFlowM3h,
      pressureMca: s.pressureMca,
      rowSpacing: s.rowSpacing,
      inRowSpacing: s.inRowSpacing,
      emitterSpacing: s.emitterSpacing,
      cropId: _editCropId,
      planLaminaMmDay: clearPlan ? null : _editLamina,
      planDaysPerWeek: clearPlan ? null : _editDays,
      planTurns: clearPlan ? null : _editTurns,
      planEfficiencyPct: clearPlan ? null : _editEff,
    );
  }

  Future<void> _save({bool clearPlan = false}) async {
    final s = _selectedSector;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      final updated = _buildEditedSector(s, clearPlan: clearPlan);
      await CloudService.instance.updateSector(s.fieldId, updated);
      if (mounted) {
        setState(() {
          final idx = _sectors.indexWhere((x) => x.id == s.id);
          if (idx >= 0) _sectors[idx] = updated;
          _loadEdit(s.id);
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(clearPlan
              ? 'Ajustes restablecidos para ${s.name}'
              : 'Ajustes guardados para ${s.name}'),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = IrrigationPlan.plan(_sectors, widget.crops, etoMmDay: _eto);

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
          _card('Configuración', _configCard()),
          const SizedBox(height: 12),
          if (_mode == _PlanMode.general)
            ..._generalCards(rows)
          else
            ..._sectorModeCards(rows),
        ],
      ),
    );
  }

  // ── Configuración ────────────────────────────────────────────────────────
  Widget _configCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_PlanMode>(
          segments: const [
            ButtonSegment(
              value: _PlanMode.general,
              label: Text('General'),
              icon: Icon(Icons.grid_view, size: 18),
            ),
            ButtonSegment(
              value: _PlanMode.sector,
              label: Text('Por sector'),
              icon: Icon(Icons.tune, size: 18),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? kBlue : kText2),
            backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? kBlue.withValues(alpha: 0.15)
                    : kCardHi),
            side: WidgetStateProperty.all(BorderSide(color: kBorder)),
          ),
          onSelectionChanged: (sel) => setState(() => _mode = sel.first),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('Mes', style: TextStyle(fontSize: 13, color: kText2)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<int>(
                value: _month,
                isExpanded: true,
                dropdownColor: kCard,
                style: const TextStyle(color: kText, fontSize: 14),
                underline: Container(height: 1, color: kBorder),
                items: [
                  for (var i = 0; i < IrrigationPlan.monthNames.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(IrrigationPlan.monthNames[i]),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _month = v!;
                  _eto = IrrigationPlan.typicalEtoMmDay[_month];
                  final sel = _selectedSector;
                  if (_mode == _PlanMode.sector && sel != null) _loadEdit(sel.id);
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
          onChanged: (v) => setState(() {
            _eto = v;
            final sel = _selectedSector;
            if (_mode == _PlanMode.sector && sel != null) _loadEdit(sel.id);
          }),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.eco, size: 15, color: kGreen),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'La demanda (ETc = ETP × Kc) y la frecuencia se calculan por '
                'cultivo y por sector.',
                style: TextStyle(fontSize: 12, color: kText2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Modo General ─────────────────────────────────────────────────────────
  List<Widget> _generalCards(List<PlanRow> rows) {
    final weekM3 = rows.fold<double>(0, (a, r) => a + r.weeklyM3);
    final weekH = rows.fold<double>(0, (a, r) => a + r.weeklyHours);
    final monthM3 = rows.fold<double>(0, (a, r) => a + r.monthlyM3);
    final monthH = rows.fold<double>(0, (a, r) => a + r.monthlyHours);

    return [
      _card(
        'Totales del predio',
        Column(
          children: [
            _totalRow('Por semana', '$weekH h', '$weekM3 m³'),
            _totalRow('Por mes', '$monthH h', '$monthM3 m³'),
            const Divider(color: kBorder, height: 16),
            Text(
              'Lámina semanal equivalente: '
              '${weekM3 > 0 && rows.isNotEmpty ? _weekMm(rows).toStringAsFixed(1) : '—'} mm',
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card('Recomendaciones', _recommendations(rows)),
      const SizedBox(height: 12),
      _card('Detalle por sector', _sectorRows(rows)),
    ];
  }

  // ── Modo Por sector ──────────────────────────────────────────────────────
  List<Widget> _sectorModeCards(List<PlanRow> rows) {
    if (_sectors.isEmpty) {
      return [
        _card('Sectores',
            const Text('No hay sectores cargados.', style: TextStyle(fontSize: 13))),
      ];
    }

    final sel = _selectedSector;
    final preview = sel != null
        ? IrrigationPlan
            .plan([_buildEditedSector(sel)], widget.crops, etoMmDay: _eto)
            .first
        : null;

    return [
      _card(
        'Sector a ajustar',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _sectors)
              ChoiceChip(
                label: Text('Sector ${s.number}'),
                selected: s.id == _selectedSectorId,
                selectedColor: kBlue.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: s.id == _selectedSectorId ? kBlue : kText2,
                ),
                side: BorderSide(color: kBorder),
                onSelected: (_) => _selectSector(s.id),
              ),
          ],
        ),
      ),
      if (sel != null) ...[
        const SizedBox(height: 12),
        _card('Ajustes de ${sel.name}', _editCard(sel)),
        const SizedBox(height: 12),
        if (preview != null) ...[
          _card('Resultado', _previewCard(preview)),
        ],
      ],
    ];
  }

  Widget _editCard(Sector s) {
    final crop = _cropFor(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cultivo (variedad ${s.variety})',
            style: const TextStyle(fontSize: 12, color: kText2)),
        const SizedBox(height: 6),
        DropdownButton<String?>(
          value: _editCropId,
          isExpanded: true,
          dropdownColor: kCard,
          style: const TextStyle(color: kText, fontSize: 14),
          underline: Container(height: 1, color: kBorder),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin cultivo'),
            ),
            for (final c in widget.crops.values)
              DropdownMenuItem<String?>(
                value: c.id,
                child: Text(c.name),
              ),
          ],
          onChanged: (v) => setState(() {
            _editCropId = v;
            final crop2 = v != null ? widget.crops[v] : null;
            _editLamina = s.planLaminaMmDay ?? IrrigationPlan.laminaFor(crop2);
            _editEff = s.planEfficiencyPct ?? IrrigationPlan.efficiencyFor(crop2);
            _editDays = s.planDaysPerWeek ??
                IrrigationPlan.daysPerWeekFor(
                    _eto * IrrigationPlan.kcFor(crop2));
          }),
        ),
        const SizedBox(height: 12),
        _sliderField(
          label: 'Lámina bruta',
          value: _editLamina,
          min: 1,
          max: 25,
          divisions: 48,
          format: (v) => '${v.toStringAsFixed(1)} mm/día',
          onChanged: (v) => setState(() => _editLamina = v),
        ),
        _sliderField(
          label: 'Frecuencia',
          value: _editDays.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          format: (v) => '${v.round()} días/sem',
          onChanged: (v) => setState(() => _editDays = v.round()),
        ),
        _sliderField(
          label: 'Eficiencia del sistema',
          value: _editEff,
          min: 50,
          max: 100,
          divisions: 50,
          format: (v) => '${v.round()} %',
          onChanged: (v) => setState(() => _editEff = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Turnos de riego',
                style: TextStyle(fontSize: 12, color: kText2)),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {_editTurns},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith((st) =>
                    st.contains(WidgetState.selected) ? kBlue : kText2),
                backgroundColor: WidgetStateProperty.resolveWith(
                    (st) => st.contains(WidgetState.selected)
                        ? kBlue.withValues(alpha: 0.15)
                        : kCardHi),
                side: WidgetStateProperty.all(BorderSide(color: kBorder)),
              ),
              onSelectionChanged: (sel) =>
                  setState(() => _editTurns = sel.first),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Kc = ${IrrigationPlan.kcFor(crop).toStringAsFixed(1)} · '
          'reposición sugerida ${IrrigationPlan.laminaFor(crop).toStringAsFixed(1)} mm/día',
          style: const TextStyle(fontSize: 11, color: kText2),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar ajustes'),
                style: FilledButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _saving ? null : () => _save(clearPlan: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: kOrange,
                side: BorderSide(color: kOrange.withValues(alpha: 0.5)),
              ),
              child: const Text('Restablecer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewCard(PlanRow r) {
    final estado = IrrigationPlan.checkLamina(r);
    final estadoColor = estado == 'coherente'
        ? kGreen
        : estado == 'bajo'
            ? kOrange
            : Colors.redAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _miniStat('Demanda del cultivo (ETc)',
                  '${r.etcMmDay.toStringAsFixed(1)} mm/día', ''),
            ),
            _badge(
                estado == 'coherente'
                    ? 'Lámina OK'
                    : estado == 'bajo'
                        ? 'Lámina baja'
                        : 'Lámina alta',
                estadoColor),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _miniStat('Lámina bruta a aplicar',
                  '${r.dailyLaminaMm.toStringAsFixed(1)} mm/día', ''),
            ),
            Expanded(
              child: _miniStat('Tiempo por turno',
                  '${r.timePerTurnH.toStringAsFixed(1)} h', ''),
            ),
            Expanded(
              child: _miniStat('Total / día', '${r.timePerDayH.toStringAsFixed(1)} h', ''),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _miniStat(
                  'Semana (${r.daysPerWeek} d)',
                  '${r.weeklyHours.toStringAsFixed(1)} h',
                  '${r.weeklyM3.toStringAsFixed(0)} m³'),
            ),
            Expanded(
              child: _miniStat('Mes',
                  '${r.monthlyHours.toStringAsFixed(1)} h',
                  '${r.monthlyM3.toStringAsFixed(0)} m³'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────────────
  Widget _sliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: kText2)),
            ),
            Text(format(value),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kText)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: kBlue,
          inactiveColor: kBorder,
          label: format(value),
          onChanged: onChanged,
        ),
      ],
    );
  }

  double _weekMm(List<PlanRow> rows) {
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
                      _badge('${r.daysPerWeek} d/sem',
                          r.daysPerWeek >= 6 ? kOrange : kGreen),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.sector.variety} · ${r.sector.areaHa.toStringAsFixed(1)} ha · '
                    'ETc ${r.etcMmDay.toStringAsFixed(1)} mm/día · '
                    '${r.dailyLaminaMm.toStringAsFixed(1)} mm/día',
                    style: const TextStyle(fontSize: 11, color: kText2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat('Semana',
                            '${r.weeklyHours.toStringAsFixed(1)} h',
                            '${r.weeklyM3.toStringAsFixed(0)} m³'),
                      ),
                      Expanded(
                        child: _miniStat('Mes',
                            '${r.monthlyHours.toStringAsFixed(1)} h',
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
        Text(label, style: const TextStyle(fontSize: 11, color: kText2)),
        Text(hours,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kYellow)),
        if (volume.isNotEmpty)
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
