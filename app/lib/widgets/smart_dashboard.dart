import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/field.dart';
import 'package:medidor_humedad/models/reading.dart';
import 'package:medidor_humedad/models/sector.dart';
import 'package:medidor_humedad/screens/cloud_device_detail_screen.dart';
import 'package:medidor_humedad/screens/irrigation_plan_screen.dart';
import 'package:medidor_humedad/screens/sector_detail_screen.dart';
import 'package:medidor_humedad/screens/settings_screen.dart';
import 'package:medidor_humedad/services/app_settings.dart';
import 'package:medidor_humedad/services/auth_service.dart';
import 'package:medidor_humedad/services/automation_service.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/local_notifications.dart';
import 'package:medidor_humedad/services/location_service.dart';
import 'package:medidor_humedad/services/offline_cache.dart';
import 'package:medidor_humedad/services/weather_service.dart';
import 'package:medidor_humedad/widgets/dashboard_alerts.dart';
import 'package:medidor_humedad/widgets/dashboard_charts.dart';
import 'package:medidor_humedad/widgets/signal_bars.dart';

// ---- Paleta oscura del dashboard (identidad Gamalier) -----------------------

const kDbg = Color(0xFF0B1220);
const kCard = Color(0xFF131D33);
const kCardHi = Color(0xFF182744);
const kBorder = Color(0xFF223050);
const kText = Color(0xFFE6EDF7);
const kText2 = Color(0xFF94A3B8);
const kText3 = Color(0xFF64748B);
const kGreen = Color(0xFF22C55E);
const kYellow = Color(0xFFFACC15);
const kRed = Color(0xFFEF4444);
const kOrange = Color(0xFFFB923C);
const kBlue = Color(0xFF38BDF8);

class SmartDashboard extends StatefulWidget {
  final String uid;
  final VoidCallback onChanged;

  const SmartDashboard({super.key, required this.uid, required this.onChanged});

  @override
  State<SmartDashboard> createState() => _SmartDashboardState();
}

class _Bundle {
  final Field field;
  final List<Sector> sectors;
  final List<CloudDevice> devices;
  const _Bundle(this.field, this.sectors, this.devices);
}

class _LoadResult {
  final List<Field> fields;
  final Map<String, Crop> cropById;
  final List<_Bundle> bundles;
  final List<CloudDevice> unassigned;
  final String userName;
  final bool fromCache;
  final DateTime? cachedAt;
  const _LoadResult(this.fields, this.cropById, this.bundles, this.unassigned,
      this.userName, {this.fromCache = false, this.cachedAt});
}

class _DevTrend {
  final double lastHum;
  final double? prevHum;
  const _DevTrend(this.lastHum, this.prevHum);
}

class _HistoryResult {
  final List<DailyHumidity> daily;
  final double weeklyAvg;
  final Map<String, double> lastVoltage;
  final Map<String, _DevTrend> trend;
  const _HistoryResult(this.daily, this.weeklyAvg, this.lastVoltage,
      this.trend);
}

class _SectorStat {
  final Sector sector;
  final List<CloudDevice> devices;
  final double? avgHum;
  final double? maxTemp;
  final Crop? crop;
  final int rangeIdx;
  final String statusText;
  final Color statusColor;
  const _SectorStat(this.sector, this.devices, this.avgHum, this.maxTemp,
      this.crop, this.rangeIdx, this.statusText, this.statusColor);
}

class _SmartDashboardState extends State<SmartDashboard> {
  late Future<_LoadResult> _future;
  Future<_HistoryResult>? _historyFuture;
  int _historyDays = 7;
  bool _seeding = false;
  bool _refreshing = false;
  late DateTime _now;
  Timer? _clock;

  final _secDashboard = GlobalKey();
  final _secSectores = GlobalKey();
  final _secEstaciones = GlobalKey();
  final _secHistorial = GlobalKey();
  final _secAlertas = GlobalKey();

  /// Sectores que ya avisaron "Requiere riego" en esta sesión (evita spamear
  /// con cada refresco; se limpia cuando el sector vuelve sobre el umbral).
  final Set<String> _notifiedLow = {};

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
    _future = _load();
    _future.then((r) {
      if (!mounted) return;
      setState(() {
        _historyFuture = _loadHistory(r, _historyDays);
      });
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<_LoadResult> _load() async {
    try {
      final r = await _loadFromCloud();
      unawaited(OfflineCache.instance.save(widget.uid, _resultToJson(r)));
      unawaited(_notifyLowHumidity(r));
      return r;
    } catch (e) {
      debugPrint('[Dashboard] Error de carga, intentando caché offline: $e');
      final payload = await OfflineCache.instance.load(widget.uid);
      if (payload != null) {
        final cachedAt = await OfflineCache.instance.savedAt(widget.uid);
        return _resultFromJson(payload, cachedAt);
      }
      rethrow;
    }
  }

  Future<_LoadResult> _loadFromCloud() async {
    final fields = await CloudService.instance.myFields(widget.uid);
    final crops = await CloudService.instance.myCrops(widget.uid);
    var devices = await CloudService.instance.myDevices(widget.uid);
    final email = AuthService.instance.currentUser?.email;
    if (email != null) {
      final shared =
          await CloudService.instance.devicesSharedWithEmail(email);
      final ids = devices.map((d) => d.deviceId).toSet();
      devices = [
        ...devices,
        ...shared.where((d) => !ids.contains(d.deviceId)),
      ];
    }
    final cropById = {for (final c in crops) c.id: c};

    final bundles = <_Bundle>[];
    for (final f in fields) {
      final sectors = await CloudService.instance.sectorsFor(f.id);
      final fieldDevices =
          devices.where((d) => d.fieldId == f.id).toList();
      bundles.add(_Bundle(f, sectors, fieldDevices));
    }
    final unassigned = devices.where((d) => d.fieldId == null).toList();
    _runAutomation(bundles);

    final u = AuthService.instance.currentUser;
    final userName = (u?.displayName?.isNotEmpty == true)
        ? u!.displayName!
        : (u?.email?.split('@').first ?? 'Agricultor');
    return _LoadResult(fields, cropById, bundles, unassigned, userName);
  }

  Map<String, dynamic> _resultToJson(_LoadResult r) {
    return {
      'fields': [
        for (final f in r.fields) {'id': f.id, ...f.toMap()},
      ],
      'crops': [
        for (final c in r.cropById.values) {'id': c.id, ...c.toMap()},
      ],
      'sectors': [
        for (final b in r.bundles)
          for (final s in b.sectors) {'id': s.id, ...s.toMap()},
      ],
      'devices': [
        for (final b in r.bundles)
          for (final d in b.devices) {'id': d.deviceId, ...d.toMap()},
        for (final d in r.unassigned) {'id': d.deviceId, ...d.toMap()},
      ],
      'userName': r.userName,
    };
  }

  _LoadResult _resultFromJson(Map<String, dynamic> json, DateTime? cachedAt) {
    final fields = <Field>[
      for (final m in json['fields'] as List? ?? [])
        Field.fromMap(m['id'] as String,
            (m as Map).cast<String, dynamic>()..remove('id')),
    ];
    final crops = <Crop>[
      for (final m in json['crops'] as List? ?? [])
        Crop.fromMap(m['id'] as String,
            (m as Map).cast<String, dynamic>()..remove('id')),
    ];
    final sectors = <String, List<Sector>>{};
    for (final m in json['sectors'] as List? ?? []) {
      final map = (m as Map).cast<String, dynamic>();
      final id = map.remove('id') as String;
      final fieldId = map['fieldId'] as String? ?? '';
      sectors.putIfAbsent(fieldId, () => []).add(Sector.fromMap(id, fieldId, map));
    }
    final devices = <CloudDevice>[
      for (final m in json['devices'] as List? ?? [])
        CloudDevice.fromMap(m['id'] as String,
            (m as Map).cast<String, dynamic>()..remove('id')),
    ];
    final cropById = {for (final c in crops) c.id: c};
    final bundles = <_Bundle>[
      for (final f in fields)
        _Bundle(f, sectors[f.id] ?? const [], devices.where((d) => d.fieldId == f.id).toList()),
    ];
    final unassigned = devices.where((d) => d.fieldId == null).toList();
    final userName = json['userName'] as String? ?? 'Agricultor';
    return _LoadResult(fields, cropById, bundles, unassigned, userName,
        fromCache: true, cachedAt: cachedAt);
  }

  /// Recarga todos los datos del dashboard (campos, cultivos, dispositivos,
  /// historial) para ver las últimas actualizaciones.
  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final r = await _load();
      if (!mounted) return;
      setState(() {
        _future = Future.value(r);
        _historyFuture = _loadHistory(r, _historyDays);
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Evalúa la automatización de cada sonda al cargar el dashboard (trigger
  /// `onDeviceUpdate` equivalente, ejecutado desde la app).
  void _runAutomation(List<_Bundle> bundles) {
    for (final b in bundles) {
      for (final d in b.devices) {
        unawaited(
          AutomationService.instance
              .checkDevice(d.deviceId, lat: b.field.lat, lon: b.field.lon)
              .catchError((_) => const AutomationResult(
                  state: 'unknown', reason: 'Error de red')),
        );
      }
    }
  }

  /// Umbral de riego de un sector: el propio si está definido, si no el del cultivo.
  double _irrigateBelow(Sector s, Crop? crop) =>
      s.irrigateBelow ?? crop?.irrigateBelow ?? 35.0;

  /// Si el sector tiene desactivadas las alertas de riego (default: activas).
  bool _alertsEnabled(Sector s) => s.alertsEnabled ?? true;

  /// Dispara notificaciones locales cuando un sector cae bajo el umbral de
  /// riego (el del sector o el del cultivo). Solo avisa una vez por sector
  /// hasta que se recupere.
  Future<void> _notifyLowHumidity(_LoadResult r) async {
    try {
      final stats = _computeStats(r);
      final lowNow = <String>{};
      for (final st in stats.sectorStats) {
        if (st.avgHum == null || !_alertsEnabled(st.sector)) continue;
        final id = st.sector.id;
        final threshold = _irrigateBelow(st.sector, st.crop);
        if (st.avgHum! < threshold) {
          lowNow.add(id);
          if (!_notifiedLow.contains(id)) {
            _notifiedLow.add(id);
            await LocalNotificationsService.instance.showLowHumidity(
              sectorName: st.sector.name,
              humidity: st.avgHum!,
              threshold: threshold,
            );
          }
        }
      }
      _notifiedLow.removeWhere((id) => !lowNow.contains(id));
    } catch (e) {
      debugPrint('[Notif] Error al evaluar alertas locales: $e');
    }
  }

  Future<_HistoryResult> _loadHistory(_LoadResult r, int days) async {
    final all =
        [...r.bundles.expand((b) => b.devices), ...r.unassigned];
    if (all.isEmpty) {
      return const _HistoryResult([], double.nan, {}, {});
    }
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    final perDevice = await Future.wait([
      for (final d in all)
        CloudService.instance
            .readingsFor(d.deviceId, from: from, to: now, limit: 3000)
            .then<List<Reading>>((list) => list)
            .catchError((_) => <Reading>[]),
    ]);

    // Promedio diario por dispositivo y luego promedio global por día.
    final dayTotals = <DateTime, List<double>>{};
    final lastVoltage = <String, double>{};
    final trend = <String, _DevTrend>{};
    for (int i = 0; i < all.length; i++) {
      final dev = all[i];
      final rs = perDevice[i];
      if (rs.isEmpty) continue;
      lastVoltage[dev.deviceId] = rs.last.batteryVoltage;
      final byDay = <DateTime, List<double>>{};
      for (final rd in rs) {
        final day = DateTime(rd.timestamp.year, rd.timestamp.month,
            rd.timestamp.day);
        byDay.putIfAbsent(day, () => []).add(rd.humidity);
      }
      final sortedDays = byDay.keys.toList()..sort();
      if (sortedDays.length >= 2) {
        final last = sortedDays.last;
        final prev = sortedDays[sortedDays.length - 2];
        final lastAvg = _mean(byDay[last]!);
        final prevAvg = _mean(byDay[prev]!);
        trend[dev.deviceId] = _DevTrend(lastAvg, prevAvg);
      } else if (sortedDays.length == 1) {
        trend[dev.deviceId] =
            _DevTrend(_mean(byDay[sortedDays.first]!), null);
      }
      byDay.forEach((day, list) {
        dayTotals.putIfAbsent(day, () => []).add(_mean(list));
      });
    }

    final daysSorted = dayTotals.keys.toList()..sort();
    final daily = <DailyHumidity>[
      for (final d in daysSorted) DailyHumidity(d, _mean(dayTotals[d]!)),
    ];
    final week = daily.length > 7
        ? daily.sublist(daily.length - 7)
        : daily;
    final weeklyAvg = week.isEmpty ? double.nan : _mean(week.map((e) => e.avg));
    return _HistoryResult(daily, weeklyAvg, lastVoltage, trend);
  }

  static double _mean(Iterable<double> v) {
    final l = v.toList();
    if (l.isEmpty) return double.nan;
    return l.reduce((a, b) => a + b) / l.length;
  }

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await CloudService.instance.seedFieldLayout(widget.uid);
      if (!mounted) return;
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el diseño: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  void _pickRange() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar gráfico histórico',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kText,
                ),
              ),
              const SizedBox(height: 8),
              for (final d in const [7, 14, 30, 60])
                ListTile(
                  title: Text(
                    'Últimos $d días',
                    style: TextStyle(
                      color: _historyDays == d ? kGreen : kText2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: _historyDays == d
                      ? const Icon(Icons.check, color: kGreen)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (mounted) {
                      setState(() => _historyDays = d);
                      _future.then((r) {
                        if (mounted) {
                          setState(() =>
                              _historyFuture = _loadHistory(r, d));
                        }
                      });
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1220), Color(0xFF0E1524)],
        ),
      ),
      child: FutureBuilder<_LoadResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No se pudo cargar el campo: ${snapshot.error}',
                style: const TextStyle(color: kOrange),
              ),
            );
          }
          final result = snapshot.data!;
          if (result.fields.isEmpty) {
            return _emptyState();
          }
          return _dashboard(result);
        },
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aún no has configurado tu campo. Carga el diseño con sus '
            '8 sectores de riego (manzanos y kiwis):',
            style: TextStyle(color: kText2),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _seeding ? null : _seed,
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            icon: _seeding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.agriculture_outlined),
            label: const Text('Cargar diseño de mi campo'),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(_LoadResult result) {
    final stats = _computeStats(result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.fromCache) _offlineBanner(result),
        _header(result),
        _menuChips(result),
        if (result.unassigned.isNotEmpty) _unassignedStrip(result),
        const SizedBox(height: 8),
        _sectionLabel('Panel general', Icons.dashboard_outlined, _secDashboard),
        _kpiRow(stats),
        _bottomStats(stats),
        _rangeRow(stats),
        _sectionLabel('Resumen por sector', Icons.grid_view_outlined, _secSectores),
        _sectorTable(result, stats),
        _sectionLabel('Historial de humedad', Icons.show_chart, _secHistorial),
        _historyCard(result),
        _sectionLabel('Ambiente y cultivo', Icons.eco_outlined, null),
        _ambientAndCrop(result),
        _sectionLabel('Estado del sistema', Icons.monitor_heart_outlined, null),
        _systemStatus(result),
        _sectionLabel('Estaciones del predio', Icons.sensors, _secEstaciones),
        _stationsGrid(result),
        _sectionLabel('Alertas recientes', Icons.notifications_outlined, _secAlertas),
        _alertsCard(result),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Encabezado -----------------------------------------------------------

  Widget _offlineBanner(_LoadResult result) {
    final when = result.cachedAt;
    final whenText = when != null
        ? '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')} '
            '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'
        : 'fecha desconocida';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kOrange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: kOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión · mostrando datos guardados del $whenText. '
              'Los valores pueden estar desactualizados.',
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(_LoadResult result) {
    final u = AuthService.instance.currentUser;
    final initials = _initials(result.userName);
    final dateStr =
        '${_now.day.toString().padLeft(2, '0')}/${_now.month.toString().padLeft(2, '0')}/${_now.year}';
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 640;
          final welcome = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, ${result.userName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kText,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Resumen general del predio · riego tecnificado inteligente',
                style: TextStyle(fontSize: 13, color: kText2),
              ),
            ],
          );
          final brand = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Nicolini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
                  Text(
                    'Riego tecnificado',
                    style: TextStyle(fontSize: 11, color: kText2),
                  ),
                ],
              ),
            ],
          );

          if (wide) {
            return Row(
              children: [
                brand,
                const Spacer(),
                welcome,
                const SizedBox(width: 16),
                _clockChip(dateStr, timeStr),
                const SizedBox(width: 8),
                _userChip(u?.email, initials),
                const SizedBox(width: 8),
                _filterButton(),
                const SizedBox(width: 8),
                _settingsButton(),
                const SizedBox(width: 8),
                _refreshButton(),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  brand,
                  const Spacer(),
                  _userChip(u?.email, initials),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: welcome),
                  _clockChip(dateStr, timeStr),
                  const SizedBox(width: 8),
                  _filterButton(),
                  const SizedBox(width: 8),
                  _settingsButton(),
                  const SizedBox(width: 8),
                  _refreshButton(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _clockChip(String date, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          Text(
            date,
            style: const TextStyle(fontSize: 11, color: kText2),
          ),
        ],
      ),
    );
  }

  Widget _userChip(String? email, String initials) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: kGreen.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              email ?? resultUserNameFallback,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
          ),
        ],
      ),
    );
  }

  String get resultUserNameFallback => 'usuario@predio.cl';

  Widget _filterButton() {
    return IconButton.filled(
      onPressed: _pickRange,
      style: IconButton.styleFrom(
        backgroundColor: kCard,
        foregroundColor: kText,
        side: const BorderSide(color: kBorder),
      ),
      icon: const Icon(Icons.filter_list),
      tooltip: 'Filtrar',
    );
  }

  Widget _refreshButton() {
    return IconButton.filled(
      onPressed: _refreshing ? null : _refreshAll,
      style: IconButton.styleFrom(
        backgroundColor: kCard,
        foregroundColor: kBlue,
        side: const BorderSide(color: kBorder),
      ),
      icon: _refreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: kBlue),
            )
          : const Icon(Icons.refresh),
      tooltip: 'Actualizar datos',
    );
  }

  Widget _settingsButton() {
    return IconButton.filled(
      onPressed: _openSettings,
      style: IconButton.styleFrom(
        backgroundColor: kCard,
        foregroundColor: kText2,
        side: const BorderSide(color: kBorder),
      ),
      icon: const Icon(Icons.tune),
      tooltip: 'Configuración',
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(uid: widget.uid),
      ),
    );
    if (mounted) _refreshAll();
  }

  Widget _menuChips(_LoadResult result) {
    const labels = <String>[
      'Dashboard',
      'Sectores',
      'Estaciones',
      'Historial',
      'Alertas',
    ];
    const icons = <IconData>[
      Icons.dashboard_outlined,
      Icons.grid_view_outlined,
      Icons.sensors,
      Icons.show_chart,
      Icons.notifications_outlined,
    ];
    final keys = [
      _secDashboard,
      _secSectores,
      _secEstaciones,
      _secHistorial,
      _secAlertas,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(icons[i], size: 16, color: kText2),
                  label: Text(
                    labels[i],
                    style: const TextStyle(color: kText2, fontSize: 12),
                  ),
                  backgroundColor: kCard,
                  side: const BorderSide(color: kBorder),
                  onPressed: () => _scrollTo(keys[i]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined,
                    size: 16, color: kGreen),
                label: const Text(
                  'Plan de riego',
                  style: TextStyle(color: kText2, fontSize: 12),
                ),
                backgroundColor: kCard,
                side: const BorderSide(color: kBorder),
                onPressed: () => _openPlan(result),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlan(_LoadResult result) {
    final sectors = [
      ...result.bundles.expand((b) => b.sectors),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IrrigationPlanScreen(
          sectors: sectors,
          crops: result.cropById,
        ),
      ),
    );
  }

  // ---- Estadísticas computadas ---------------------------------------------

  _Stats _computeStats(_LoadResult r) {
    final all = [...r.bundles.expand((b) => b.devices), ...r.unassigned];
    final hums = all.map((d) => d.humidity).whereType<double>().toList();
    final temps = all
        .where((d) => d.soilTemp != null && !d.soilTemp!.isNaN)
        .map((d) => d.soilTemp!)
        .toList();
    final avgHum = hums.isEmpty ? double.nan : _mean(hums);
    final avgTemp = temps.isEmpty ? double.nan : _mean(temps);
    final now = DateTime.now();
    final active = all
        .where((d) =>
            d.isDemo ||
            (d.lastReportAt != null &&
                now.difference(d.lastReportAt!) < const Duration(hours: 6)))
        .length;
    final batts = all
        .map((d) => d.batteryLevel)
        .whereType<double>()
        .toList();
    final avgBatt = batts.isEmpty ? double.nan : _mean(batts) * 100;

    final sectorStats = <_SectorStat>[];
    for (final b in r.bundles) {
      for (final s in b.sectors) {
        final devices =
            b.devices.where((d) => d.sectorId == s.id).toList();
        final crop = s.cropId != null ? r.cropById[s.cropId] : null;
        final humsS =
            devices.map((d) => d.humidity).whereType<double>().toList();
        final avgS = humsS.isEmpty ? null : _mean(humsS);
        final tempsS = devices
            .where((d) => d.soilTemp != null && !d.soilTemp!.isNaN)
            .map((d) => d.soilTemp!)
            .toList();
        final maxT =
            tempsS.isEmpty ? null : tempsS.reduce((a, b) => a > b ? a : b);

        Color sc = kGreen;
        String st = 'OK';
        if (devices.isEmpty) {
          sc = kText3;
          st = 'Sin sondas';
        } else if (avgS == null) {
          sc = kOrange;
          st = 'Sin lecturas';
        } else if (avgS < _irrigateBelow(s, crop)) {
          sc = kRed;
          st = 'Requiere riego';
        } else if (crop != null && avgS < crop.minHumidity) {          sc = kOrange;
          st = 'Bajo óptimo';
        } else if (maxT != null && crop != null && maxT > crop.maxTemp) {
          sc = kOrange;
          st = 'Temp. alta';
        }
        sectorStats.add(_SectorStat(
            s, devices, avgS, maxT, crop,
            avgS == null ? -1 : HumRanges.indexOf(avgS), st, sc));
      }
    }

    _SectorStat? driest;
    for (final st in sectorStats) {
      if (st.avgHum == null) continue;
      if (driest == null || st.avgHum! < driest.avgHum!) driest = st;
    }
    return _Stats(avgHum, avgTemp, all.length, active, avgBatt, sectorStats,
        driest, all);
  }

  // ---- KPIs -----------------------------------------------------------------

  Widget _kpiRow(_Stats s) {
    final maxTemp = s.all
        .where((d) => d.soilTemp != null && !d.soilTemp!.isNaN)
        .map((d) => d.soilTemp!)
        .toList();
    final avgAmbient = double.nan; // se rellena con clima en tarjeta ambiente
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 16 - 24) / 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpiCard(w, Icons.water_drop_outlined, kBlue, 'Humedad promedio',
                  s.avgHum.isNaN ? '—' : '${s.avgHum.toStringAsFixed(1)}%',
                  child: _progressBar(
                      s.avgHum.isNaN ? 0 : s.avgHum / 100,
                      kBlue,
                      _capacityLabel(s.avgHum))),
              _kpiCard(w, Icons.thermostat_outlined, kOrange,
                  'Temperatura del suelo',
                  maxTemp.isEmpty
                      ? '—'
                      : '${AppSettings.toDisplay(_mean(maxTemp)).toStringAsFixed(1)}${AppSettings.unitSuffix()}',
                  child: Text(
                    'Ambiente: ${avgAmbient.isNaN ? '—' : '${AppSettings.toDisplay(avgAmbient).toStringAsFixed(0)}${AppSettings.unitSuffix()}'}',
                    style: const TextStyle(fontSize: 11, color: kText2),
                  )),
              _kpiCard(
                  w, Icons.sensors, kGreen, 'Sensores activos',
                  '${s.active}/${s.total}',
                  child: _progressBar(
                      s.total == 0 ? 0 : s.active / s.total, kGreen,
                      '${s.total == 0 ? 0 : (s.active * 100 / s.total).round()}% operativo')),
              _kpiCard(
                  w,
                  Icons.emergency,
                  kRed,
                  'Sector más seco',
                  s.driest == null ? '—' : s.driest!.sector.name,
                  child: s.driest == null
                      ? const Text('Sin datos',
                          style: TextStyle(fontSize: 11, color: kText2))
                      : Row(
                          children: [
                            Text(
                              '${s.driest!.avgHum!.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.warning_amber_rounded,
                                color: kRed, size: 18),
                          ],
                        )),
            ],
          ),
        );
      },
    );
  }

  String _capacityLabel(double? avgHum) {
    if (avgHum == null || avgHum.isNaN) return 'Cap. de campo —';
    final cap = 70.0;
    return 'Cap. de campo ${cap.toStringAsFixed(0)}% · uso ${min(100.0, avgHum * 100 / cap).toStringAsFixed(0)}%';
  }

  Widget _progressBar(double v, Color color, String label) {
    final clamped = v.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 6,
            backgroundColor: kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: kText2),
        ),
      ],
    );
  }

  Widget _kpiCard(
      double w, IconData icon, Color color, String label, String value,
      {Widget? child}) {
    return Container(
      width: w,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kCard, kCardHi],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: kText2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          ?child,
        ],
      ),
    );
  }

  // ---- Indicadores inferiores ----------------------------------------------

  Widget _bottomStats(_Stats s) {
    final sectorHums =
        s.sectorStats.where((e) => e.avgHum != null).map((e) => e.avgHum!);
    final minH = sectorHums.isEmpty
        ? double.nan
        : sectorHums.reduce((a, b) => a < b ? a : b);
    final maxH = sectorHums.isEmpty
        ? double.nan
        : sectorHums.reduce((a, b) => a > b ? a : b);
    final needsWater =
        s.sectorStats.where((e) => e.statusColor == kRed).length;
    final lowest = _driestSector(s);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _miniStat(Icons.arrow_downward, kRed, 'Humedad mín',
                    minH.isNaN ? '—' : '${minH.toStringAsFixed(1)}%'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(Icons.arrow_upward, kGreen, 'Humedad máxima',
                    maxH.isNaN ? '—' : '${maxH.toStringAsFixed(1)}%'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<_HistoryResult>(
                  future: _historyFuture,
                  builder: (context, snap) {
                    final weekly = snap.data?.weeklyAvg ?? double.nan;
                    return _miniStat(Icons.calendar_view_week, kBlue,
                        'Promedio semanal',
                        weekly.isNaN ? '—' : '${weekly.toStringAsFixed(1)}%');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(Icons.opacity, kBlue,
                    'Riegos sugeridos hoy', '$needsWater'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<_HistoryResult>(
            future: _historyFuture,
            builder: (context, snap) {
              final h = snap.data;
              return _nextRiegoCard(_computeRiego(lowest, h));
            },
          ),
        ],
      ),
    );
  }

  _SectorStat? _driestSector(_Stats s) {
    _SectorStat? lowest;
    for (final st in s.sectorStats) {
      if (st.avgHum == null) continue;
      if (lowest == null || st.avgHum! < lowest.avgHum!) lowest = st;
    }
    return lowest;
  }

  _NextRiego _computeRiego(_SectorStat? st, _HistoryResult? h) {
    if (st == null || st.avgHum == null) return const _NextRiego(null, null);
    final crop = st.crop;
    final threshold = _irrigateBelow(st.sector, crop);
    if (st.avgHum! < threshold) {
      return _NextRiego(st.sector.name, null, needNow: true);
    }
    if (h == null) return _NextRiego(st.sector.name, null);
    final target = threshold;
    double? minHours;
    for (final d in st.devices) {
      final t = h.trend[d.deviceId];
      if (t == null || t.prevHum == null) continue;
      final slope = t.lastHum - t.prevHum!; // % por día
      if (slope >= -0.001) continue; // no se está secando
      final hours = ((t.lastHum - target) / (-slope)) * 24;
      if (hours >= 0 && (minHours == null || hours < minHours)) {
        minHours = hours;
      }
    }
    return _NextRiego(st.sector.name, minHours);
  }

  Widget _miniStat(IconData icon, Color color, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextRiegoCard(_NextRiego riego) {
    final when = riego.needNow
        ? 'ahora'
        : riego.hours == null
            ? 'según tendencia'
            : 'en ${riego.hours!.toStringAsFixed(1)} h';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kBlue, Color(0xFF2563EB)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x5538BDF8), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próximo riego sugerido',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE0F2FE)),
                ),
                const SizedBox(height: 2),
                Text(
                  riego.sector ?? '—',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            when,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Rangos ---------------------------------------------------------------

  Widget _rangeRow(_Stats s) {
    final counts = List.filled(5, 0);
    for (final st in s.sectorStats) {
      if (st.rangeIdx >= 0) counts[st.rangeIdx]++;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen por rango de humedad',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < 5; i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HumRanges.colors[i].withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: HumRanges.colors[i].withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        HumRanges.labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: HumRanges.colors[i],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${counts[i]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _dashCard(
            title: 'Distribución de sectores',
            child: RangeDonut(counts: counts),
          ),
        ],
      ),
    );
  }

  // ---- Tabla de sectores ----------------------------------------------------

  Widget _sectorTable(_LoadResult r, _Stats s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: _dashCard(
        title: 'Sectores de riego',
        child: Column(
          children: [
            for (final st in s.sectorStats)
              _sectorRow(st),
          ],
        ),
      ),
    );
  }

  Widget _sectorRow(_SectorStat st) {
    final suffix = AppSettings.unitSuffix();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kCardHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: st.statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: st.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.grass, color: st.statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.sector.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kText,
                  ),
                ),
                Text(
                  st.sector.variety,
                  style: const TextStyle(fontSize: 11, color: kText2),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.avgHum == null
                      ? 'Humedad: —'
                      : '${st.avgHum!.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 13, color: kText),
                ),
                Text(
                  st.maxTemp == null
                      ? 'Temp: —'
                      : 'Temp: ${AppSettings.toDisplay(st.maxTemp!).toStringAsFixed(1)}$suffix',
                  style: const TextStyle(fontSize: 11, color: kText2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: st.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              st.statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: st.statusColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _openSector(st),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Ver detalle',
              style: TextStyle(fontSize: 11, color: kBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _openSector(_SectorStat st) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SectorDetailScreen(
          sector: st.sector,
          devices: st.devices,
          crop: st.crop,
        ),
      ),
    );
  }

  // ---- Historial ------------------------------------------------------------

  Widget _historyCard(_LoadResult r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: _dashCard(
        title: 'Evolución de humedad promedio',
        child: FutureBuilder<_HistoryResult>(
          future: _historyFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final h = snap.data ?? const _HistoryResult([], double.nan, {}, {});
            return HistoryLineChart(
              points: h.daily,
              days: _historyDays,
              onDaysChanged: (d) {
                if (mounted) {
                  setState(() => _historyDays = d);
                  _future.then((r) {
                    if (mounted) {
                      setState(() =>
                          _historyFuture = _loadHistory(r, d));
                    }
                  });
                }
              },
            );
          },
        ),
      ),
    );
  }

  // ---- Ambiente y cultivo ---------------------------------------------------

  Widget _ambientAndCrop(_LoadResult r) {
    final firstField = r.bundles.isNotEmpty ? r.bundles.first.field : null;
    final crops = r.cropById.values.toList();
    final crop = crops.isNotEmpty ? crops.first : null;
    final stats = _computeStats(r);
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 16 - 24) / 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: w,
                child: _dashCard(
                  title: 'Condiciones ambientales',
                  child: _AmbientCard(
                    fieldLat: firstField?.lat, fieldLon: firstField?.lon),
                ),
              ),
              SizedBox(
                width: w,
                child: _dashCard(
                  title: 'Estado del cultivo',
                  child: _CropStatusCard(stats: stats, crop: crop),
                ),
              ),
              SizedBox(
                width: c.maxWidth - 32,
                child: _dashCard(
                  title: 'Equipamiento de riego',
                  child: _EquipCard(field: firstField),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Estado del sistema ---------------------------------------------------

  Widget _systemStatus(_LoadResult r) {
    final stats = _computeStats(r);
    final auts = stats.all
        .map((d) => d.autonomyDays)
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    final avgAutonomy =
        auts.isEmpty ? double.nan : _mean(auts);
    final rssis =
        stats.all.map((d) => d.rssi).whereType<int>().toList();
    final avgRssi =
        rssis.isEmpty ? null : (rssis.reduce((a, b) => a + b) / rssis.length);
    final lastSync = stats.all
        .map((d) => d.lastReportAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null,
            (acc, t) => acc == null || t.isAfter(acc) ? t : acc);

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 16 - 24) / 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: w,
                child: _dashCard(
                  title: 'Estado energético',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _energyRow(
                          Icons.battery_std, kGreen,
                          'Batería promedio',
                          stats.avgBatt.isNaN
                              ? '—'
                              : '${stats.avgBatt.toStringAsFixed(0)}%'),
                      FutureBuilder<_HistoryResult>(
                        future: _historyFuture,
                        builder: (context, snap) {
                          final values = snap.data?.lastVoltage.values;
                          final txt = (snap.connectionState ==
                                          ConnectionState.done &&
                                      values != null &&
                                      values.isNotEmpty)
                              ? '${values.first.toStringAsFixed(2)} V'
                              : '—';
                          return _energyRow(Icons.bolt, kYellow,
                              'Voltaje (última lectura)', txt);
                        },
                      ),
                      _energyRow(
                          Icons.wb_sunny_outlined, kOrange,
                          'Carga solar',
                          '— (sin medidor)'),
                      _energyRow(
                          Icons.timer_outlined, kBlue,
                          'Autonomía estimada',
                          avgAutonomy.isNaN
                              ? '—'
                              : '${avgAutonomy.toStringAsFixed(0)} días'),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: w,
                child: _dashCard(
                  title: 'Comunicación',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Señal (RSSI promedio)',
                                style: TextStyle(fontSize: 12, color: kText2)),
                          ),
                          if (avgRssi != null) ...[
                            SignalBars(rssi: avgRssi.round()),
                            const SizedBox(width: 6),
                            Text(
                              '$avgRssi dBm',
                              style: const TextStyle(
                                  fontSize: 12, color: kText),
                            ),
                          ] else
                            const Text('—',
                                style: TextStyle(color: kText2)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _energyRow(
                          Icons.sync, kGreen,
                          'Última sincronización',
                          lastSync == null ? '—' : _timeAgo(lastSync)),
                      const SizedBox(height: 6),
                      _energyRow(
                          Icons.signal_cellular_alt, avgRssi == null
                              ? kText3
                              : (avgRssi <= -95
                                  ? kRed
                                  : avgRssi <= -85
                                      ? kOrange
                                      : kGreen),
                          'Calidad de conexión',
                          avgRssi == null
                              ? '—'
                              : avgRssi <= -95
                                  ? 'Pésima'
                                  : avgRssi <= -85
                                      ? 'Débil'
                                      : avgRssi <= -70
                                          ? 'Regular'
                                          : 'Buena'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _energyRow(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Estaciones -----------------------------------------------------------

  Widget _stationsGrid(_LoadResult r) {
    final all = [...r.bundles.expand((b) => b.devices), ...r.unassigned];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: _dashCard(
        title: 'Mapa esquemático · cada estación cambia de color según su estado',
        child: all.isEmpty
            ? const Text('Sin estaciones',
                style: TextStyle(fontSize: 12, color: kText2))
            : LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in all) _stationCard(d, w),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _stationCard(CloudDevice d, double w) {
    final now = DateTime.now();
    final disconnected = !d.isDemo &&
        (d.lastReportAt == null ||
            now.difference(d.lastReportAt!) > const Duration(hours: 6));
    final lowBatt = d.batteryLevel != null && d.batteryLevel! < 0.25;
    final irrigating = d.valveState == 'ON';
    final Color border = disconnected
        ? kRed
        : lowBatt
            ? kOrange
            : irrigating
                ? kBlue
                : kGreen;
    final Color dot = disconnected
        ? kRed
        : lowBatt
            ? kOrange
            : irrigating
                ? kBlue
                : kGreen;

    return Container(
      width: w,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kCardHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, size: 18, color: dot),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kText,
                  ),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: dot, blurRadius: 6)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _kv('Batería',
                    d.batteryLevel == null
                        ? '—'
                        : '${(d.batteryLevel! * 100).round()}%',
                    color: lowBatt ? kRed : null),
              ),
              Expanded(
                child: _kv('Última lectura',
                    _lastReportLabel(d),
                    color: disconnected ? kRed : null),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _kv('Panel solar', '—')),
              Expanded(child: _kv('N° serie', d.deviceId)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _kv('Firmware', '—')),
              if (irrigating)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop, size: 10, color: kBlue),
                      SizedBox(width: 3),
                      Text('VÁLVULA ON',
                          style: TextStyle(fontSize: 9, color: kBlue)),
                    ],
                  ),
                )
              else
                Text('HW: —',
                    style: const TextStyle(fontSize: 11, color: kText3)),
            ],
          ),
        ],
      ),
    );
  }

  String _lastReportLabel(CloudDevice d) {
    final t = d.lastReportAt;
    return t == null ? '—' : _timeAgo(t);
  }

  Widget _kv(String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            '$label: ',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: kText3),
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color ?? kText2,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Alertas --------------------------------------------------------------

  Widget _alertsCard(_LoadResult r) {
    final alerts = _buildAlerts(r);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: _dashCard(
        title: 'Alertas recientes',
        child: AlertsPanel(alerts: alerts),
      ),
    );
  }

  List<DashAlert> _buildAlerts(_LoadResult r) {
    final alerts = <DashAlert>[];
    final stats = _computeStats(r);
    final now = DateTime.now();
    for (final st in stats.sectorStats) {
      if (st.avgHum == null) continue;
      final threshold = _irrigateBelow(st.sector, st.crop);
      if (_alertsEnabled(st.sector) &&
          st.avgHum! < threshold) {
        alerts.add(DashAlert(
          icon: Icons.water_drop,
          color: kRed,
          title: 'Humedad baja en ${st.sector.name}',
          detail:
              'La humedad promedio es ${st.avgHum!.toStringAsFixed(1)}% (límite de riego ${threshold.toStringAsFixed(0)}%).',
          time: _timeAgo(now),
          severity: 3,
        ));
      }
      if (st.maxTemp != null && st.crop != null && st.maxTemp! > st.crop!.maxTemp) {
        alerts.add(DashAlert(
          icon: Icons.thermostat,
          color: kOrange,
          title: 'Temperatura alta en ${st.sector.name}',
          detail:
              'Máxima de ${AppSettings.toDisplay(st.maxTemp!).toStringAsFixed(1)}${AppSettings.unitSuffix()} (límite ${AppSettings.toDisplay(st.crop!.maxTemp).toStringAsFixed(0)}${AppSettings.unitSuffix()}).',
          time: _timeAgo(now),
          severity: 2,
        ));
      }
    }
    for (final d in stats.all) {
      if (d.batteryLevel != null && d.batteryLevel! < 0.25) {
        alerts.add(DashAlert(
          icon: Icons.battery_alert,
          color: kOrange,
          title: 'Batería baja · ${d.name}',
          detail: 'Queda un ${(d.batteryLevel! * 100).round()}% de batería.',
          time: d.lastReportAt == null ? _timeAgo(now) : _timeAgo(d.lastReportAt!),
          severity: 2,
        ));
      }
      if (!d.isDemo &&
          (d.lastReportAt == null ||
              now.difference(d.lastReportAt!) > const Duration(hours: 6))) {
        alerts.add(DashAlert(
          icon: Icons.sensors_off,
          color: kRed,
          title: 'Sensor desconectado · ${d.name}',
          detail: d.lastReportAt == null
              ? 'Sin reportes desde que se registró.'
              : 'Sin reportes desde hace ${_timeAgo(d.lastReportAt!)}.',
          time: _timeAgo(now),
          severity: 3,
        ));
      }
      if (d.valveState == 'ON') {
        alerts.add(DashAlert(
          icon: Icons.water,
          color: kBlue,
          title: 'Riego activo · ${d.name}',
          detail: 'La válvula está abierta. Estado: ${d.automationReason ?? '—'}.',
          time: d.automationStartedAt == null
              ? _timeAgo(now)
              : _timeAgo(d.automationStartedAt!),
          severity: 1,
        ));
      }
      if (d.rssi != null && d.rssi! <= -95) {
        alerts.add(DashAlert(
          icon: Icons.wifi_off,
          color: kRed,
          title: 'Pérdida de comunicación · ${d.name}',
          detail: 'RSSI de ${d.rssi} dBm (fuera de cobertura útil).',
          time: _timeAgo(now),
          severity: 1,
        ));
      }
    }
    return alerts;
  }

  // ---- Utilidades -----------------------------------------------------------

  Widget _sectionLabel(String text, IconData icon, GlobalKey? key) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Container(
        key: key,
        child: Row(
          children: [
            Icon(icon, size: 18, color: kGreen),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kText2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _unassignedStrip(_LoadResult r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: kBlue),
            const SizedBox(width: 6),
            Text(
              '${r.unassigned.length} sonda(s) sin sector asignado.',
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () => _showUnassigned(r.unassigned),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Ver',
                  style: TextStyle(fontSize: 12, color: kBlue)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnassigned(List<CloudDevice> devices) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sondas sin sector asignado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kText,
                ),
              ),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.sensors, color: kBlue),
                title: Text(d.name,
                    style: const TextStyle(color: kText)),
                subtitle: Text(
                  d.location ?? d.deviceId,
                  style: const TextStyle(color: kText2),
                ),
                trailing: const Icon(Icons.chevron_right, color: kText3),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CloudDeviceDetailScreen(device: d),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }
}

// ---- Tipos auxiliares -------------------------------------------------------

class _Stats {
  final double avgHum;
  final double avgTemp;
  final int total;
  final int active;
  final double avgBatt;
  final List<_SectorStat> sectorStats;
  final _SectorStat? driest;
  final List<CloudDevice> all;
  const _Stats(this.avgHum, this.avgTemp, this.total, this.active,
      this.avgBatt, this.sectorStats, this.driest, this.all);
}

class _NextRiego {
  final String? sector;
  final double? hours;
  final bool needNow;
  const _NextRiego(this.sector, this.hours, {this.needNow = false});
}

// ---- Tarjeta de condiciones ambientales (Open-Meteo) ------------------------

class _AmbientCard extends StatefulWidget {
  final double? fieldLat;
  final double? fieldLon;
  const _AmbientCard({this.fieldLat, this.fieldLon});

  /// Resuelve las coordenadas: GPS del dispositivo si está disponible,
  /// en caso contrario las coordenadas guardadas del predio.
  static Future<({double lat, double lon, bool fromGps})?> _resolve(
      double? fieldLat, double? fieldLon) async {
    final gps = await LocationService.instance.getPosition();
    if (gps != null) return (lat: gps.lat, lon: gps.lon, fromGps: true);
    if (fieldLat != null && fieldLon != null) {
      return (lat: fieldLat, lon: fieldLon, fromGps: false);
    }
    return null;
  }

  @override
  State<_AmbientCard> createState() => _AmbientCardState();
}

class _ClimaData {
  final double lat;
  final double lon;
  final bool fromGps;
  final CurrentConditions w;
  _ClimaData(this.lat, this.lon, this.fromGps, this.w);
}

class _AmbientCardState extends State<_AmbientCard> {
  late Future<_ClimaData?> _future;

  Future<_ClimaData?> _load() async {
    final ({double lat, double lon, bool fromGps})? coords;
    try {
      coords = await _AmbientCard._resolve(widget.fieldLat, widget.fieldLon);
    } catch (e) {
      debugPrint('[Clima] Error de coordenadas: $e');
      return null;
    }
    if (coords == null) return null;
    final w = await WeatherService.instance.current(coords.lat, coords.lon);
    return _ClimaData(coords.lat, coords.lon, coords.fromGps, w);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClimaData?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError) {
          debugPrint('[Clima] Error al consultar: ${snap.error}');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 18, color: kBlue),
                  tooltip: 'Actualizar',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                ),
              ),
              const Text(
                'No se pudo consultar el clima.',
                style: TextStyle(fontSize: 12, color: kText2),
              ),
            ],
          );
        }
        final data = snap.data;
        if (data == null) {
          debugPrint('[Clima] Sin coordenadas (GPS ni predio)');
          return const Text(
            'Sin coordenadas (activa el GPS o configura el predio).',
            style: TextStyle(fontSize: 12, color: kText2),
          );
        }
        final w = data.w;
        debugPrint('[Clima] OK: T=${w.temperatureC} hum='
            '${w.relativeHumidityPct}% lluvia=${w.precipitationMm}mm');
        final t = AppSettings.toDisplay(w.temperatureC);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18, color: kBlue),
                tooltip: 'Actualizar',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ),
            _ambRow(Icons.thermostat, kOrange,
                '${t.toStringAsFixed(1)}${AppSettings.unitSuffix()}',
                'Temperatura ambiente'),
            _ambRow(Icons.water_drop_outlined, kBlue,
                '${w.relativeHumidityPct.toStringAsFixed(0)}%',
                'Humedad relativa'),
            _ambRow(Icons.umbrella_outlined, kBlue,
                '${w.precipitationMm.toStringAsFixed(1)} mm'
                    '${w.rainToday ? ' · lluvia' : ''}',
                'Lluvia (hoy)'),
            _ambRow(Icons.wb_sunny_outlined, kYellow,
                '${w.solarRadiationWm2.toStringAsFixed(0)} W/m²',
                'Radiación solar'),
            _ambRow(Icons.air, kText2,
                '${w.windSpeedKmh.toStringAsFixed(0)} km/h', 'Viento'),
            _ambRow(Icons.location_on_outlined, kText3,
                data.fromGps ? 'GPS del teléfono' : 'Coordenadas predio',
                'Ubicación'),
          ],
        );
      },
    );
  }

  Widget _ambRow(IconData icon, Color color, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: kText2),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Equipamiento de riego --------------------------------------------------

class _EquipCard extends StatelessWidget {
  final Field? field;
  const _EquipCard({required this.field});

  @override
  Widget build(BuildContext context) {
    final f = field;
    final rows = <(IconData, Color, String, String)>[
      if (f?.pumpModel != null)
        (Icons.settings_backup_restore, kBlue, 'Bomba', f!.pumpModel!),
      if (f?.pumpHp != null)
        (Icons.flash_on_outlined, kYellow, 'Potencia', '${f!.pumpHp}'),
      if (f?.filterType != null)
        (Icons.filter_alt_outlined, kGreen, 'Filtro', f!.filterType!),
      if (f?.filterInches != null)
        (Icons.straighten, kOrange, 'Entrada', '${f!.filterInches}'),
      if (f?.filterModel != null)
        (Icons.qr_code_2, kText2, 'Modelo filtro', f!.filterModel!),
    ];
    if (rows.isEmpty) {
      return const Text(
        'Sin datos de equipamiento.',
        style: TextStyle(fontSize: 12, color: kText2),
      );
    }
    return Column(
      children: [
        for (final (icon, color, label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: kText2),
                  ),
                ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
          ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---- Estado del cultivo -----------------------------------------------------

class _CropStatusCard extends StatelessWidget {
  final _Stats stats;
  final Crop? crop;
  const _CropStatusCard({required this.stats, required this.crop});

  @override
  Widget build(BuildContext context) {
    final level = _cropLevel();
    final (label, color, icon) = switch (level) {
      3 => ('Excelente', kGreen, Icons.verified_outlined),
      2 => ('Bueno', kBlue, Icons.thumb_up_alt_outlined),
      1 => ('Precaución', kYellow, Icons.error_outline),
      _ => ('Crítico', kRed, Icons.warning_amber_rounded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  crop?.name ?? 'Cultivo',
                  style: const TextStyle(fontSize: 12, color: kText2),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _seg(Icons.water_drop_outlined, kBlue, 'Humedad',
                  _humScore()),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _seg(Icons.energy_savings_leaf_outlined, kGreen, 'Batería',
                  stats.avgBatt.isNaN ? 0 : stats.avgBatt.clamp(0, 100)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _seg(Icons.sensors, kOrange, 'Conectividad',
                  stats.total == 0
                      ? 0
                      : (stats.active * 100 / stats.total).toDouble()),
            ),
          ],
        ),
      ],
    );
  }

  int _cropLevel() {
    final h = _humScore();
    final b = stats.avgBatt.isNaN ? 0.0 : stats.avgBatt.clamp(0.0, 100.0);
    final c = stats.total == 0
        ? 0.0
        : (stats.active * 100 / stats.total).clamp(0.0, 100.0);
    final score = h * 0.5 + b * 0.25 + c * 0.25;
    if (score >= 80) return 3;
    if (score >= 60) return 2;
    if (score >= 40) return 1;
    return 0;
  }

  double _humScore() {
    if (stats.avgHum.isNaN) return 0;
    final minH = crop?.minHumidity ?? 30;
    final maxH = crop?.maxHumidity ?? 70;
    final h = stats.avgHum;
    if (h >= minH && h <= maxH) return 100;
    final ideal = (minH + maxH) / 2;
    return (100 - ((h - ideal).abs() / ideal) * 100).clamp(0.0, 100.0);
  }

  Widget _seg(IconData icon, Color color, String label, double v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: kText2),
              ),
            ),
            Text(
              '${v.round()}',
              style: const TextStyle(fontSize: 10, color: kText),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: v / 100,
            minHeight: 5,
            backgroundColor: kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
