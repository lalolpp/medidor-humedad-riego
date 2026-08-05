import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/services/autonomy.dart';
import 'package:medidor_humedad/services/device_service.dart';
import 'package:medidor_humedad/services/nodo_connection.dart';
import 'package:medidor_humedad/widgets/humidity_chart.dart';

class DeviceDetailScreen extends StatefulWidget {
  final DeviceService service;
  final DiscoveredDevice device;

  const DeviceDetailScreen({
    super.key,
    required this.service,
    required this.device,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  NodoConnection? _conn;
  StreamSubscription<Reading?>? _liveSub;

  bool _connecting = true;
  bool _busy = false;
  String _error = '';

  Reading? _latest;
  List<Reading> _history = [];
  int? _interval;
  String _autonomy = '—';
  BatteryInfo? _battery;
  int? _historyCount;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _conn?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = '';
    });
    try {
      final conn = await widget.service.connect(widget.device);
      if (!mounted) {
        await conn.close();
        return;
      }
      _conn = conn;
      _liveSub = conn.liveReadingStream.listen((reading) {
        if (reading != null && mounted) {
          setState(() {
            _latest = reading;
            _history.add(reading);
            if (_history.length > 300) _history.removeAt(0);
          });
        }
      });
      await _refreshAll();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar: $e');
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _refreshAll() async {
    final conn = _conn;
    if (conn == null) return;
    final interval = await conn.readInterval();
    final autonomy = await conn.readAutonomy();
    final battery = await conn.readBattery();
    final live = await conn.readLive();
    final count = await conn.readHistoryCount();
    if (!mounted) return;
    setState(() {
      _interval = interval;
      _autonomy = autonomy;
      _battery = battery;
      if (live != null) {
        _latest = live;
        if (_history.isEmpty || _history.last.timestamp != live.timestamp) {
          _history.add(live);
        }
      }
      _historyCount = count;
    });
  }

  Future<void> _selectInterval(int candidate) async {
    if (_interval == candidate) return;
    final capacity = kDefaultBatteryCapacityMah;
    final level = _battery?.level ?? (_latest?.batteryLevel ?? 1.0);
    final days = autonomyDays(candidate, capacity, level);
    final isLow = days < kAutonomyWarningDays;

    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isLow ? Icons.warning_amber_rounded : Icons.battery_charging_full,
          color: isLow ? Colors.orange : Colors.green,
          size: 40,
        ),
        title: Text('Intervalo de $candidate min'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Autonomía estimada de batería sin sol: ~${formatAutonomy(days)}.',
            ),
            const SizedBox(height: 12),
            Text(
              isLow
                  ? 'Con lecturas tan frecuentes el consumo sube bastante. '
                      'Deberás revisar y recargar la batería con más frecuencia, '
                      'y el panel solar será crítico.'
                  : 'Las lecturas más frecuentes aumentan el consumo. '
                      'Revisa la autonomía de la batería según tu configuración.',
              style: TextStyle(
                color: isLow ? Colors.orange.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (apply != true) return;

    setState(() => _busy = true);
    try {
      await _conn?.setInterval(candidate);
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Intervalo actualizado a $candidate min')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar intervalo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadHistory() async {
    final conn = _conn;
    if (conn == null) return;
    setState(() => _busy = true);
    try {
      final history = await conn.readHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyCount = history.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Historial descargado: ${history.length} lecturas')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar historial: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            onPressed: _connecting || _busy ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(_error, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _connect,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _statusCard(context),
                    const SizedBox(height: 16),
                    _autonomyCard(context),
                    const SizedBox(height: 16),
                    _intervalCard(context),
                    const SizedBox(height: 16),
                    _historyCard(context),
                  ],
                ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final latest = _latest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lectura en vivo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        latest == null
                            ? '—'
                            : '${latest.humidity.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
                      ),
                      const Text('Humedad'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        latest == null
                            ? '—'
                            : '${latest.batteryVoltage.toStringAsFixed(2)} V',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        latest == null
                            ? 'Batería'
                            : '${(latest.batteryLevel * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: HumidityChart(readings: _history),
            ),
          ],
        ),
      ),
    );
  }

  Widget _autonomyCard(BuildContext context) {
    final days = _battery?.level != null
        ? autonomyDays(
            _interval ?? 30,
            kDefaultBatteryCapacityMah,
            _battery!.level,
          )
        : null;
    final low = days != null && days < kAutonomyWarningDays;
    return Card(
      child: ListTile(
        leading: Icon(
          low ? Icons.battery_alert : Icons.battery_charging_full,
          color: low ? Colors.orange : Colors.green,
          size: 32,
        ),
        title: const Text('Autonomía de batería'),
        subtitle: Text(
          days != null
              ? '~${formatAutonomy(days)} sin sol a ${_interval ?? 30} min'
              : _autonomy,
        ),
        isThreeLine: false,
      ),
    );
  }

  Widget _intervalCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intervalo de lectura',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Cada cambio muestra la autonomía de batería estimada.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interval in kAllowedIntervals)
                  ChoiceChip(
                    label: Text('$interval min'),
                    selected: _interval == interval,
                    onSelected: _busy ? null : (_) => _selectInterval(interval),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history, size: 32),
        title: const Text('Historial'),
        subtitle: Text(
          _historyCount != null
              ? '$_historyCount lecturas almacenadas en el nodo'
              : 'Descarga el historial local del nodo',
        ),
        trailing: const Icon(Icons.download),
        onTap: _busy ? null : _downloadHistory,
      ),
    );
  }
}
