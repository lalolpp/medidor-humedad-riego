import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/crop.dart';
import 'package:medidor_humedad/models/field.dart';
import 'package:medidor_humedad/models/sector.dart';
import 'package:medidor_humedad/services/app_settings.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/weather_service.dart';
import 'package:medidor_humedad/screens/sector_detail_screen.dart';

class FieldDashboard extends StatefulWidget {
  final String uid;
  final VoidCallback onChanged;

  const FieldDashboard({super.key, required this.uid, required this.onChanged});

  @override
  State<FieldDashboard> createState() => _FieldDashboardState();
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
  const _LoadResult(this.fields, this.cropById, this.bundles, this.unassigned);
}

class _FieldDashboardState extends State<FieldDashboard> {
  late Future<_LoadResult> _future;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LoadResult> _load() async {
    final fields = await CloudService.instance.myFields(widget.uid);
    final crops = await CloudService.instance.myCrops(widget.uid);
    final devices = await CloudService.instance.myDevices(widget.uid);
    final cropById = {for (final c in crops) c.id: c};

    final bundles = <_Bundle>[];
    for (final f in fields) {
      final sectors = await CloudService.instance.sectorsFor(f.id);
      final fieldDevices =
          devices.where((d) => d.fieldId == f.id).toList();
      bundles.add(_Bundle(f, sectors, fieldDevices));
    }
    final unassigned = devices.where((d) => d.fieldId == null).toList();
    return _LoadResult(fields, cropById, bundles, unassigned);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No se pudo cargar el campo: ${snapshot.error}',
              style: const TextStyle(color: Colors.orange),
            ),
          );
        }
        final result = snapshot.data!;
        if (result.fields.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aún no has configurado tu campo. Carga el diseño con sus '
                  '8 sectores de riego (manzanos y kiwis):',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _seeding ? null : _seed,
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final bundle in result.bundles) ...[
              _fieldHeader(bundle, result),
              _sectorsGrid(bundle, result),
              const SizedBox(height: 8),
            ],
            if (result.unassigned.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Sondas sin sector asignado (${result.unassigned.length})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              for (final d in result.unassigned) _unassignedCard(d),
            ],
          ],
        );
      },
    );
  }

  Widget _fieldHeader(_Bundle bundle, _LoadResult result) {
    final field = bundle.field;
    final totalHa =
        bundle.sectors.fold<double>(0, (acc, s) => acc + s.areaHa);
    final totalDevices = bundle.devices.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.agriculture, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${field.name} · ${totalHa.toStringAsFixed(2)} Ha · $totalDevices sondas',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (field.lat != null && field.lon != null)
            WeatherChip(lat: field.lat!, lon: field.lon!),
        ],
      ),
    );
  }

  Widget _sectorsGrid(_Bundle bundle, _LoadResult result) {
    final width = (MediaQuery.of(context).size.width - 48) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in bundle.sectors)
            _sectorCard(s, bundle.devices, result.cropById[s.cropId], width),
        ],
      ),
    );
  }

  Widget _sectorCard(
      Sector s, List<CloudDevice> fieldDevices, Crop? crop, double width) {
    final devices =
        fieldDevices.where((d) => d.sectorId == s.id).toList();
    final values = devices
        .where((d) => d.humidity != null)
        .map((d) => d.humidity!)
        .toList();
    final avgHum =
        values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    final temps = devices
        .where((d) => d.soilTemp != null && !d.soilTemp!.isNaN)
        .map((d) => d.soilTemp!)
        .toList();
    final minTemp =
        temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b);

    final Color statusColor;
    final String statusText;
    if (devices.isEmpty) {
      statusColor = Colors.grey;
      statusText = 'Sin sondas';
    } else if (crop != null && avgHum != null && avgHum < crop.irrigateBelow) {
      statusColor = Colors.red;
      statusText = 'Requiere riego';
    } else if (avgHum == null) {
      statusColor = Colors.orange;
      statusText = 'Sin lecturas';
    } else {
      statusColor = Colors.green;
      statusText = 'OK';
    }

    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openSector(s, devices, crop),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                                fontSize: 10, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s.variety,
                  style: TextStyle(
                      color: s.variety == 'Manzanos'
                          ? Colors.red.shade400
                          : Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s.areaHa.toStringAsFixed(2)} Ha · ${devices.length} sondas',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (avgHum != null)
                  Text(
                    'Humedad media: ${avgHum.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  )
                else
                  const Text('Humedad: —',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                if (minTemp != null)
                  Text(
                    'Temp. mín: ${AppSettings.toDisplay(minTemp).toStringAsFixed(1)}${AppSettings.unitSuffix()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unassignedCard(CloudDevice d) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.sensors),
        title: Text(d.name),
        subtitle: Text('Sin campo ni sector asignado'),
      ),
    );
  }

  void _openSector(Sector s, List<CloudDevice> devices, Crop? crop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SectorDetailScreen(sector: s, devices: devices, crop: crop),
      ),
    );
  }
}

class WeatherChip extends StatefulWidget {
  final double lat;
  final double lon;

  const WeatherChip({super.key, required this.lat, required this.lon});

  @override
  State<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends State<WeatherChip> {
  late Future<WeatherInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = WeatherService.instance.forecast(widget.lat, widget.lon, days: 1);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherInfo>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Icon(Icons.wb_cloudy_outlined, color: Colors.grey);
        }
        final info = snapshot.data!;
        final today = info.daily.isNotEmpty ? info.daily.first : null;
        final icon = info.forecastRain
            ? Icons.water_drop
            : Icons.wb_sunny_outlined;
        return Tooltip(
          message: info.forecastRain
              ? 'Lluvia prevista (≥50%). Considera posponer el riego.'
              : 'Sin lluvia prevista en los próximos días.',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: info.forecastRain ? Colors.blue : Colors.orange),
              if (today != null) ...[
                const SizedBox(width: 4),
                Text(
                  '${AppSettings.toDisplay(today.maxTemp).toStringAsFixed(0)}${AppSettings.unitSuffix()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
