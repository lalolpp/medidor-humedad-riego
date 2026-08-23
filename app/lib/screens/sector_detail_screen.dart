import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/models/sector.dart';
import 'package:medidor_humedad/services/app_settings.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/widgets/metrics_chart.dart';
import 'package:medidor_humedad/widgets/signal_bars.dart';

import 'cloud_device_detail_screen.dart';

class SectorDetailScreen extends StatefulWidget {
  final Sector sector;
  final List<CloudDevice> devices;
  final Crop? crop;

  const SectorDetailScreen({
    super.key,
    required this.sector,
    required this.devices,
    this.crop,
  });

  @override
  State<SectorDetailScreen> createState() => _SectorDetailScreenState();
}

class _SectorDetailScreenState extends State<SectorDetailScreen> {
  late Future<List<Reading>> _comparisonFuture;
  int _rangeHours = 24;
  bool _sendingValve = false;

  /// Override local tras enviar un comando (la lista de dispositivos viene del
  /// widget padre y no se refresca sola); null = usar el estado en la nube.
  bool? _valveOverride;

  /// true si alguna sonda del sector está regando según la nube.
  bool get _cloudIrrigating =>
      widget.devices.any((d) => d.valveState == 'ON');

  bool get _irrigating => _valveOverride ?? _cloudIrrigating;

  /// Umbral de riego: el propio del sector si está definido, si no el del cultivo.
  double? get _threshold {
    final own = widget.sector.irrigateBelow;
    if (own != null) return own;
    final crop = widget.crop?.irrigateBelow;
    return (crop ?? 0) > 0 ? crop : null;
  }

  static const _ranges = [
    (hours: 24, label: '24 h'),
    (hours: 168, label: '7 días'),
    (hours: 720, label: '30 días'),
  ];

  @override
  void initState() {
    super.initState();
    _comparisonFuture = _loadComparison();
  }

  Future<List<Reading>> _loadComparison() async {
    final since = DateTime.now().subtract(Duration(hours: _rangeHours));
    final results = await Future.wait([
      for (final d in widget.devices)
        CloudService.instance.readingsFor(d.deviceId,
            from: since, limit: 1000),
    ]);
    return results.expand((r) => r).toList();
  }

  void _setRange(int hours) {
    if (_rangeHours == hours) return;
    setState(() {
      _rangeHours = hours;
      _comparisonFuture = _loadComparison();
    });
  }

  /// Envía el comando de válvula a TODAS las sondas del sector.
  Future<void> _setSectorIrrigation(bool on) async {
    if (widget.devices.isEmpty || _sendingValve) return;
    if (on) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.water_drop, color: Colors.blue, size: 40),
          title: Text('Iniciar riego · ${widget.sector.name}'),
          content: Text(
            'Se enviará el comando de apertura a ${widget.devices.length} '
            '${widget.devices.length == 1 ? 'sonda' : 'sondas'}. El nodo la '
            'aplicará en su próximo ciclo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Regar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _sendingValve = true);
    try {
      for (final d in widget.devices) {
        await CloudService.instance
            .setValveCommand(d.deviceId, on ? 'ON' : 'OFF', 'manual');
      }
      if (!mounted) return;
      setState(() => _valveOverride = on);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(on
              ? 'Riego iniciado en ${widget.sector.name}'
              : 'Riego detenido en ${widget.sector.name}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingValve = false);
    }
  }

  Widget _irrigationControlCard() {
    final irrigating = _irrigating;
    final hasDevices = widget.devices.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop,
                  size: 18,
                  color: irrigating ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Riego del sector',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  _sendingValve
                      ? 'Enviando…'
                      : irrigating
                          ? 'Regando'
                          : 'Detenido',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: irrigating ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          irrigating ? Colors.green.shade700 : null,
                      foregroundColor: irrigating ? Colors.white : null,
                    ),
                    onPressed: hasDevices && !_sendingValve && !irrigating
                        ? () => _setSectorIrrigation(true)
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar riego'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          irrigating ? Colors.red.shade700 : null,
                      foregroundColor: irrigating ? Colors.white : null,
                    ),
                    onPressed: hasDevices && !_sendingValve && irrigating
                        ? () => _setSectorIrrigation(false)
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
                ),
              ],
            ),
            if (!hasDevices)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Asigna una sonda al sector para poder regar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sector;
    final suffix = AppSettings.unitSuffix();

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.name} · ${s.variety}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(s),
          const SizedBox(height: 16),
          _irrigationControlCard(),
          if (widget.crop != null) ...[
            const SizedBox(height: 16),
            _cropCard(widget.crop!),
          ],
          const SizedBox(height: 16),
          Text('Sondas del sector (${widget.devices.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Aún no hay sondas asignadas a este sector.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            for (final d in widget.devices) _deviceCard(d, suffix),
          const SizedBox(height: 16),
          if (widget.devices.length > 1) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Comparativa de humedad (últimas $_rangeLabel())',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final r in _ranges)
                  ButtonSegment(value: r.hours, label: Text(r.label)),
              ],
              selected: {_rangeHours},
              onSelectionChanged: (s) => _setRange(s.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Reading>>(
              future: _comparisonFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final all = snapshot.data ?? [];
                if (all.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin datos para comparar.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                final colors = [
                  Colors.blue,
                  Colors.green,
                  Colors.purple,
                  Colors.teal,
                  Colors.indigo,
                  Colors.orange,
                  Colors.pink,
                  Colors.brown,
                ];
                final series = <MetricSeries>[
                  for (var i = 0; i < widget.devices.length; i++)
                    MetricSeries(
                      label: widget.devices[i].name,
                      color: colors[i % colors.length],
                      points: [
                        for (final r in all)
                          if (r.humidity > 0) MetricPoint(r.timestamp, r.humidity),
                      ],
                    ),
                ];
                final threshold = _threshold;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetricsChart(
                      series: series,
                      unitLabel: '%',
                      minY: 0,
                      maxY: 100,
                      showHour: _rangeHours <= 24,
                      thresholdY: threshold,
                      thresholdLabel: threshold == null
                          ? null
                          : 'Umbral riego <${threshold.toStringAsFixed(0)}%',
                    ),
                    if (threshold != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Línea roja: umbral de riego sugerido del cultivo.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _rangeLabel() {
    for (final r in _ranges) {
      if (r.hours == _rangeHours) return r.label;
    }
    return '$_rangeHours h';
  }

  Widget _infoCard(Sector s) {
    final rows = <(String, String)>[
      if (s.blocks != null) ('Bloques', s.blocks!),
      ('Superficie', '${s.areaHa.toStringAsFixed(2)} Ha'),
      ('Emisor', s.emitterType),
      if (s.emitterFlowLh != null)
        ('Caudal emisor', '${s.emitterFlowLh!.toStringAsFixed(2)} L/h'),
      if (s.irrigationTimeH != null)
        ('Tiempo riego', '${s.irrigationTimeH!.toStringAsFixed(2)} h'),
      if (s.numLines != null) ('N° líneas', '${s.numLines}'),
      if (s.rowSpacing != null)
        ('Entre hilera', '${s.rowSpacing!.toStringAsFixed(2)} m'),
      if (s.inRowSpacing != null)
        ('Sobre hilera', '${s.inRowSpacing!.toStringAsFixed(1)} m'),
      if (s.emitterSpacing != null)
        ('Sep. emisor', '${s.emitterSpacing!.toStringAsFixed(2)} m'),
      if (s.totalFlowM3h != null)
        ('Caudal total', '${s.totalFlowM3h!.toStringAsFixed(1)} m³/h'),
      if (s.pressureMca != null)
        ('Presión', '${s.pressureMca!.toStringAsFixed(1)} m.c.a.'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cropCard(Crop crop) {
    final rows = <(String, String)>[
      ('Especie/Variedad', crop.name),
      if (crop.kc != null) ('Coef. cultivo (Kc)', '${crop.kc}'),
      if (crop.etpMmDay != null)
        ('ET potencial', '${crop.etpMmDay!.toStringAsFixed(1)} mm/día'),
      if (crop.etActualMmDay != null)
        ('ET actual', '${crop.etActualMmDay!.toStringAsFixed(2)} mm/día'),
      if (crop.efficiencyPct != null)
        ('Eficiencia aplicación', '${crop.efficiencyPct!.toStringAsFixed(0)}%'),
      if (crop.laminaBrutaMmDay != null)
        ('Lámina bruta a reponer',
            '${crop.laminaBrutaMmDay!.toStringAsFixed(1)} mm/día'),
      if (_threshold != null)
        ('Riego sugerido bajo', '< ${_threshold!.toStringAsFixed(0)}%'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco_outlined, color: Colors.green),
                const SizedBox(width: 8),
                Text('Datos del cultivo',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(CloudDevice d, String suffix) {
    final threshold = _threshold;
    final hum = d.humidity;
    final soilTemp = d.soilTemp;
    final needsIrrigation =
        threshold != null && hum != null && hum < threshold;

    final tempText = (soilTemp == null || soilTemp.isNaN)
        ? ''
        : ' · Temp: ${AppSettings.toDisplay(soilTemp).toStringAsFixed(1)}$suffix';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: Icon(
          Icons.sensors,
          color: needsIrrigation ? Colors.red : Colors.green,
        ),
        title: Text(d.name),
        subtitle: Text(
          'Humedad: ${hum == null ? '—' : '${hum.toStringAsFixed(1)}%'}'
          '$tempText'
          '${needsIrrigation ? '\nRequiere riego (<${threshold.toStringAsFixed(0)}%)' : ''}',
        ),
        isThreeLine: needsIrrigation,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SignalBars(rssi: d.rssi, size: 14),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CloudDeviceDetailScreen(device: d),
          ),
        ),
      ),
    );
  }
}
