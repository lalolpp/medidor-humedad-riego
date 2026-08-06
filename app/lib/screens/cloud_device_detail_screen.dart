import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/services/app_settings.dart';
import 'package:medidor_humedad/services/auth_service.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/csv_export.dart';
import 'package:medidor_humedad/services/infiltration.dart';
import 'package:medidor_humedad/widgets/dual_axis_chart.dart';
import 'package:medidor_humedad/widgets/metrics_chart.dart';
import 'package:medidor_humedad/widgets/signal_bars.dart';

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
  final _otaUrlController = TextEditingController();
  final _otaVersionController = TextEditingController();
  bool _savingOta = false;

  static const _intervals = [15, 30, 60, 120, 360, 720];

  @override
  void initState() {
    super.initState();
    _readingsFuture = _loadReadings();
    _interval = widget.device.intervalMin ?? 30;
  }

  @override
  void dispose() {
    _otaUrlController.dispose();
    _otaVersionController.dispose();
    super.dispose();
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

  Future<void> _saveOta() async {
    final url = _otaUrlController.text.trim();
    final version = _otaVersionController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la URL del firmware .bin')),
      );
      return;
    }
    if (version.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa la versión del firmware')),
      );
      return;
    }
    setState(() => _savingOta = true);
    try {
      await CloudService.instance.setOtaConfig(
        widget.device.deviceId,
        url: url,
        version: version,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Actualización programada para la versión $version')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al programar OTA: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingOta = false);
    }
  }

  bool _canManage(CloudDevice d) {
    final uid = AuthService.instance.currentUser?.uid;
    if (d.owner == uid) return true;
    final email = AuthService.instance.currentUser?.email?.toLowerCase();
    return email != null && d.shares[email] == 'manager';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final suffix = AppSettings.unitSuffix();

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          if (d.owner == AuthService.instance.currentUser?.uid)
            IconButton(
              tooltip: 'Compartir dispositivo',
              onPressed: () => _showShareSheet(),
              icon: const Icon(Icons.people_outline),
            ),
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
          if (_canManage(d)) ...[
            const SizedBox(height: 16),
            _otaCard(d),
          ],
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
            if (d.rssi != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    SignalBars(rssi: d.rssi),
                    const SizedBox(width: 8),
                    Text(
                      '${d.rssi} dBm (último reporte)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _ShareSheet(device: widget.device),
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

  Widget _otaCard(CloudDevice d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actualización de firmware (OTA)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'El nodo descargará el .bin cuando su versión local difiera. '
              'Requiere nodos flasheados con el esquema OTA (2 slots).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _otaUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL del firmware (.bin)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _otaVersionController,
              decoration: const InputDecoration(
                labelText: 'Versión (ej. 1.1.0)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _savingOta ? null : _saveOta,
              icon: _savingOta
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt),
              label: const Text('Programar actualización'),
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

class _ShareSheet extends StatefulWidget {
  final CloudDevice device;

  const _ShareSheet({required this.device});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late Map<String, String> _shares;
  final _emailController = TextEditingController();
  String _role = 'viewer';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shares = Map.of(widget.device.shares);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addShare() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo válido')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await CloudService.instance
          .shareDevice(widget.device.deviceId, email, role: _role);
      if (!mounted) return;
      setState(() {
        _shares[email.toLowerCase()] = _role;
        _emailController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeShare(String email) async {
    setState(() => _busy = true);
    try {
      await CloudService.instance.unshareDevice(widget.device.deviceId, email);
      if (!mounted) return;
      setState(() => _shares.remove(email));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al quitar acceso: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleLabel(String role) =>
      role == 'manager' ? 'Administrador' : 'Solo lectura';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compartir ${widget.device.name}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Solo lectura: ve datos. Administrador: además configura.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_shares.isNotEmpty) ...[
              const Text('Con acceso:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final entry in _shares.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(entry.key),
                  subtitle: Text(_roleLabel(entry.value)),
                  trailing: IconButton(
                    tooltip: 'Quitar acceso',
                    onPressed: _busy ? null : () => _removeShare(entry.key),
                    icon: const Icon(Icons.close),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo del invitado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Ver')),
                    DropdownMenuItem(
                        value: 'manager', child: Text('Admin')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v != null) setState(() => _role = v);
                        },
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _addShare,
                  child: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
