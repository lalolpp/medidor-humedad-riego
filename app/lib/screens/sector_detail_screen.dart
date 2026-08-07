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

  @override
  void initState() {
    super.initState();
    _comparisonFuture = _loadComparison();
  }

  Future<List<Reading>> _loadComparison() async {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final results = await Future.wait([
      for (final d in widget.devices)
        CloudService.instance.readingsFor(d.deviceId, from: since, limit: 2000),
    ]);
    return results.expand((r) => r).toList();
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
            Text('Comparativa de humedad (últimas 24 h)',
                style: Theme.of(context).textTheme.titleMedium),
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
                return MetricsChart(
                  series: series,
                  unitLabel: '%',
                  minY: 0,
                  maxY: 100,
                );
              },
            ),
          ],
        ],
      ),
    );
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
      if (crop.irrigateBelow > 0)
        ('Riego sugerido bajo', '< ${crop.irrigateBelow.toStringAsFixed(0)}%'),
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
    final crop = widget.crop;
    final hum = d.humidity;
    final soilTemp = d.soilTemp;
    final needsIrrigation = crop != null &&
        hum != null &&
        hum < crop.irrigateBelow;

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
          '${needsIrrigation ? '\nRequiere riego (<${crop.irrigateBelow.toStringAsFixed(0)}%)' : ''}',
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
