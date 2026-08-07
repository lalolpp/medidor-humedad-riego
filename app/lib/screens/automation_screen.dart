import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/automation_config.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/services/automation_service.dart';
import 'package:medidor_humedad/services/auth_service.dart';
import 'package:medidor_humedad/services/cloud_service.dart';

/// Pantalla de configuración de automatización de riego de un dispositivo.
///
/// Decide aquí mismo (sin Cloud Functions) cuándo regar según umbral de
/// humedad, duración, ventana horaria, pronóstico de lluvia y anti-rebote,
/// y escribe el comando `valveState` que el nodo lee en su próximo ciclo.
class AutomationScreen extends StatefulWidget {
  final CloudDevice device;

  const AutomationScreen({super.key, required this.device});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  late CloudDevice _device = widget.device;
  late AutomationConfig _cfg = widget.device.automation;
  late bool _canManage = _isManager();
  bool _saving = false;
  bool _checking = false;
  late bool _allDay = _isAllDay(widget.device.automation);
  AutomationResult? _last;

  static const _intervals = [30, 60, 120, 180];

  bool _isManager() {
    final uid = AuthService.instance.currentUser?.uid;
    if (_device.owner == uid) return true;
    final email = AuthService.instance.currentUser?.email?.toLowerCase();
    return email != null && _device.shares[email] == 'manager';
  }

  static bool _isAllDay(AutomationConfig cfg) =>
      cfg.startMin == 0 && cfg.endMin == 1440;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<(double?, double?)> _fieldCoords() async {
    final fieldId = _device.fieldId;
    if (fieldId == null) return (null, null);
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return (null, null);
    try {
      final fields = await CloudService.instance.myFields(uid);
      for (final f in fields) {
        if (f.id == fieldId) return (f.lat, f.lon);
      }
    } catch (_) {}
    return (null, null);
  }

  Future<void> _refresh() async {
    try {
      final fresh = await CloudService.instance.deviceFor(_device.deviceId);
      if (mounted && fresh != null) {
        setState(() {
          _device = fresh;
          _cfg = fresh.automation;
          _canManage = _isManager();
        });
      }
    } catch (_) {}
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      final coords = await _fieldCoords();
      final result = await AutomationService.instance
          .checkDevice(_device.deviceId, lat: coords.$1, lon: coords.$2);
      await _refresh();
      if (!mounted) return;
      setState(() => _last = result);
      _showResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al comprobar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await CloudService.instance.saveAutomation(_device.deviceId, _cfg);
      await _checkNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cfg.enabled
              ? 'Automatización activada y evaluada'
              : 'Automatización desactivada'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showResult(AutomationResult r) {
    if (!r.changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.valveState == 'ON'
              ? '🚰 Riego iniciado automáticamente'
              : 'Válvula cerrada · ${r.reason}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _cfg.startMin ~/ 60, minute: _cfg.startMin % 60),
    );
    if (t == null) return;
    setState(() {
      _allDay = false;
      _cfg = AutomationConfig(
        enabled: _cfg.enabled,
        threshold: _cfg.threshold,
        durationMin: _cfg.durationMin,
        startMin: t.hour * 60 + t.minute,
        endMin: _cfg.endMin,
        rainPause: _cfg.rainPause,
        minIntervalMin: _cfg.minIntervalMin,
      );
    });
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _cfg.endMin ~/ 60, minute: _cfg.endMin % 60),
    );
    if (t == null) return;
    setState(() {
      _allDay = false;
      _cfg = AutomationConfig(
        enabled: _cfg.enabled,
        threshold: _cfg.threshold,
        durationMin: _cfg.durationMin,
        startMin: _cfg.startMin,
        endMin: t.hour * 60 + t.minute,
        rainPause: _cfg.rainPause,
        minIntervalMin: _cfg.minIntervalMin,
      );
    });
  }

  AutomationConfig _copy({
    bool? enabled,
    int? threshold,
    int? durationMin,
    int? startMin,
    int? endMin,
    bool? rainPause,
    int? minIntervalMin,
  }) {
    return AutomationConfig(
      enabled: enabled ?? _cfg.enabled,
      threshold: threshold ?? _cfg.threshold,
      durationMin: durationMin ?? _cfg.durationMin,
      startMin: startMin ?? _cfg.startMin,
      endMin: endMin ?? _cfg.endMin,
      rainPause: rainPause ?? _cfg.rainPause,
      minIntervalMin: minIntervalMin ?? _cfg.minIntervalMin,
    );
  }

  String _fmt(int min) {
    final h = (min ~/ 60).toString().padLeft(2, '0');
    final m = (min % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Automatización · ${_device.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(),
          const SizedBox(height: 16),
          if (_canManage) ...[
            _configCard(),
            const SizedBox(height: 16),
            _actionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    final state = _device.automationState ?? _last?.state;
    final reason = _device.automationReason ?? _last?.reason;
    final valve = _device.valveState ?? _last?.valveState;
    final (label, icon, color) = _statusInfo(state, valve);

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (valve != null) ...[
                  const Spacer(),
                  Chip(
                    label: Text(valve == 'ON' ? 'VÁLVULA ON' : 'VÁLVULA OFF'),
                    backgroundColor: valve == 'ON'
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.grey.shade300,
                    labelStyle: TextStyle(
                        color: valve == 'ON' ? Colors.green.shade800 : Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(reason, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }

  (String, IconData, Color) _statusInfo(String? state, String? valve) {
    if (valve == 'ON') {
      return ('Regando', Icons.water_drop, Colors.green);
    }
    switch (state) {
      case AutomationService.stateIrrigating:
        return ('Regando', Icons.water_drop, Colors.green);
      case AutomationService.stateRainPaused:
        return ('Pausado por lluvia', Icons.beach_access_outlined, Colors.blue);
      case AutomationService.stateOutsideWindow:
        return ('Fuera del horario', Icons.schedule, Colors.orange);
      case AutomationService.stateCooldown:
        return ('Anti-rebote activo', Icons.timer_outlined, Colors.orange);
      case AutomationService.stateDisabled:
        return ('Desactivada', Icons.power_settings_new, Colors.grey);
      case AutomationService.stateIdle:
        return ('Esperando…', Icons.pause_circle_outline, Colors.teal);
      default:
        return ('Sin estado', Icons.help_outline, Colors.grey);
    }
  }

  Widget _configCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatización de riego',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Enciende la válvula cuando la humedad baja del umbral, '
                  'respetando horario, lluvia y anti-rebote.'),
              value: _cfg.enabled,
              onChanged: (v) => setState(() => _cfg = _copy(enabled: v)),
            ),
            const Divider(),
            Text('Umbral de humedad',
                style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _cfg.threshold.toDouble(),
                    min: 20,
                    max: 80,
                    divisions: 60,
                    label: '${_cfg.threshold}%',
                    onChanged: (v) =>
                        setState(() => _cfg = _copy(threshold: v.round())),
                  ),
                ),
                Text('${_cfg.threshold}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Duración del riego',
                style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _cfg.durationMin.toDouble(),
                    min: 15,
                    max: 240,
                    divisions: 15,
                    label: '${_cfg.durationMin} min',
                    onChanged: (v) =>
                        setState(() => _cfg = _copy(durationMin: v.round())),
                  ),
                ),
                Text('${_cfg.durationMin} min',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Ventana de riego',
                style: Theme.of(context).textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Todo el día'),
              value: _allDay,
              onChanged: (v) => setState(() {
                _allDay = v;
                _cfg = _copy(startMin: 0, endMin: 1440);
              }),
            ),
            if (!_allDay)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickStart,
                      child: Text('Inicio: ${_fmt(_cfg.startMin)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEnd,
                      child: Text('Fin: ${_fmt(_cfg.endMin)}'),
                    ),
                  ),
                ],
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pausar si hay lluvia prevista'),
              subtitle: const Text(
                  'No riega cuando el pronóstico supera 50% de probabilidad.'),
              value: _cfg.rainPause,
              onChanged: (v) => setState(() => _cfg = _copy(rainPause: v)),
            ),
            const SizedBox(height: 8),
            Text('Mínimo entre riegos (anti-rebote)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _cfg.minIntervalMin,
              decoration: const InputDecoration(
                labelText: 'Evita ciclos cortos de la válvula',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in _intervals)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m < 60 ? '$m minutos' : '${m ~/ 60} hora(s)'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _cfg = _copy(minIntervalMin: v));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: (_saving || _checking) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Guardar y evaluar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (_saving || _checking) ? null : _checkNow,
            icon: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Comprobar ahora'),
          ),
        ),
      ],
    );
  }
}
