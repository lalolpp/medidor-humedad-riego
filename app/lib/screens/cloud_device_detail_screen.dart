import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/services/app_settings.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/csv_export.dart';
import 'package:medidor_humedad/services/infiltration.dart';
import 'package:medidor_humedad/widgets/dual_axis_chart.dart';
import 'package:medidor_humedad/widgets/metrics_chart.dart';

class CloudDeviceDetailScreen extends StatefulWidget {
  final CloudDevice device;

  const CloudDeviceDetailScreen({super.key, required this.device});

  @override
  State<CloudDeviceDetailScreen> createState() => _CloudDeviceDetailScreenState();
}

class _CloudDeviceDetailScreenState extends State<CloudDeviceDetailScreen> {
  late Future<List<Reading>> _readingsFuture;
  bool _exporting = false;
  bool _savingInterval = false;
  int? _interval;

  static const _intervals = [15, 30, 60, 120, 360, 720];

  @override
  void initState() {
    super.initState();
    _readingsFuture = _loadReadings();
    _interval = widget.device.intervalMin ?? 30;
  }

  Future<List<Reading>> _loadReadings() {
    final since = DateTime.now().subtract(const Duration(hours: 48));
    return CloudService.instance.readingsFor(
      widget.device.deviceId,
      from: since,
      limit: 4000,
    );
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final readings = await CloudService.instance.readingsFor(
        widget.device.deviceId,
        from: since,
        limit: 20000,
      );
      if (!mounted) return;
      if (readings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin datos para exportar')),
        );
        return;
      }
      final name = widget.device.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await exportReadingsCsv(readings, '${name}_lecturas.csv');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveInterval(int intervalMin) async {
    setState(() {
      _savingInterval = true;
      _interval = intervalMin;
    });
    try {
      await CloudService.instance.setIntervalConfig(
          widget.device.deviceId, intervalMin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intervalo guardado: cada $intervalMin min')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _interval = widget.device.intervalMin ?? 30);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar intervalo: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingInterval = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final suffix = AppSettings.unitSuffix();

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV (7 días)',
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(d, suffix),
          const SizedBox(height: 16),
          _intervalCard(d),
          const SizedBox(height: 16),
          Text('Humedad del suelo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<Reading>>(
            future: _readingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Text('No se pudieron cargar los datos: ${snapshot.error}',
                    style: const TextStyle(color: Colors.orange));
              }
              final readings = snapshot.data ?? [];
              final humidityPoints = [
                for (final r in readings) MetricPoint(r.timestamp, r.humidity),
              ];
              final tempPoints = [
                for (final r in readings)
                  if (!r.soilTemp.isNaN)
                    MetricPoint(r.timestamp, AppSettings.toDisplay(r.soilTemp)),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetricsChart(
                    series: [
                      MetricSeries(
                        label: 'Humedad',
                        color: Colors.blue,
                        points: humidityPoints,
                      ),
                    ],
                    unitLabel: '%',
                    minY: 0,
                    maxY: 100,
                  ),
                  if (tempPoints.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Temperatura del suelo',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    MetricsChart(
                      series: [
                        MetricSeries(
                          label: 'Temp. suelo',
                          color: Colors.orange,
                          points: tempPoints,
                        ),
                      ],
                      unitLabel: suffix,
                    ),
                    const SizedBox(height: 20),
                    Text('Cruce: temperatura vs humedad',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DualAxisChart(
                      humidity: humidityPoints,
                      temp: tempPoints,
                      tempUnit: suffix,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Un pico de temperatura que coincide con una caída de '
                      'humedad indica estrés hídrico de la tierra.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                  if (computeInfiltration(readings) case final info?) ...[
                    const SizedBox(height: 20),
                    Text('Índice de infiltración / drenaje',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _infiltrationCard(info),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statusCard(CloudDevice d, String suffix) {
    final hum = d.humidity;
    final temp = d.soilTemp;
    final last = d.lastReportAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${d.deviceId}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                _metric('Humedad',
                    hum == null ? '—' : '${hum.toStringAsFixed(1)}%'),
                const SizedBox(width: 16),
                _metric('Temp. suelo',
                    temp == null || temp.isNaN
                        ? '—'
                        : '${AppSettings.toDisplay(temp).toStringAsFixed(1)}$suffix'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              last == null
                  ? 'Sin reportes todavía'
                  : 'Último reporte: ${last.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (d.batteryLevel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Batería: ${(d.batteryLevel! * 100).clamp(0, 100).toStringAsFixed(0)}%'
                  '${d.autonomyDays != null ? ' · Autonomía: ${d.autonomyDays!.toStringAsFixed(1)} días' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _intervalCard(CloudDevice d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modo de bajo consumo (deep sleep)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Cada cuánto despierta el sensor para reportar. A mayor '
              'intervalo, mayor duración de la batería.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey(_interval),
              initialValue: _interval,
              decoration: const InputDecoration(
                labelText: 'Intervalo de reporte',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in _intervals)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m < 60
                          ? 'Cada $m minutos'
                          : m == 60
                              ? 'Cada 1 hora'
                              : 'Cada ${m ~/ 60} horas',
                    ),
                  ),
              ],
              onChanged: _savingInterval
                  ? null
                  : (value) {
                      if (value != null) _saveInterval(value);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infiltrationCard(InfiltrationInfo info) {
    final color = info.ratePctPerHour >= 3.0
        ? Colors.red
        : info.ratePctPerHour >= 0.3
            ? Colors.green
            : Colors.orange;
    return Card(
      child: ListTile(
        leading: Icon(Icons.water_drop, color: color),
        title: Text(info.assessment,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Tasa de descenso: ${info.ratePctPerHour.toStringAsFixed(1)} %/h\n'
          '${info.detail}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
