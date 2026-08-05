import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/cloud_device.dart';
import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/services/app_firebase.dart';
import 'package:medidor_humedad/services/auth_service.dart';
import 'package:medidor_humedad/services/ble_device_service.dart';
import 'package:medidor_humedad/services/cloud_service.dart';
import 'package:medidor_humedad/services/demo_device_service.dart';
import 'package:medidor_humedad/services/device_service.dart';

import 'device_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _demoMode = true;
  bool _scanning = false;
  List<DiscoveredDevice> _devices = [];

  DeviceService get _service => _demoMode
      ? DemoDeviceService()
      : BleDeviceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _discover());
  }

  Future<void> _discover() async {
    setState(() {
      _scanning = true;
      _devices = [];
    });
    try {
      final found = await _service.discover();
      if (mounted) setState(() => _devices = found);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de escaneo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _onModeChanged(bool demo) {
    setState(() => _demoMode = demo);
    _discover();
  }

  void _openDevice(DiscoveredDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(service: _service, device: device),
      ),
    );
  }

  void _onLogout() {
    AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final showCloud = AppFirebase.configured && user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Dispositivos'),
        actions: [
          if (showCloud)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') _onLogout();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    user.email ?? 'Usuario',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: const Text('Modo demo (sin hardware)'),
            subtitle: const Text('Simula un nodo para probar la app'),
            value: _demoMode,
            onChanged: _onModeChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton.icon(
              onPressed: _scanning ? null : _discover,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_demoMode ? 'Recargar demo' : 'Buscar dispositivos'),
            ),
          ),
          if (showCloud) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'En la nube',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _cloudDevices(),
            const Divider(height: 24),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Cercanos (BLE / demo)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_devices.isEmpty && !_scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No se encontraron dispositivos cercanos',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final device in _devices) _deviceCard(device),
        ],
      ),
    );
  }

  Widget _cloudDevices() {
    final uid = AuthService.instance.currentUser!.uid;
    return FutureBuilder<List<CloudDevice>>(
      future: CloudService.instance.myDevices(uid),
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
              'No se pudo cargar la nube: ${snapshot.error}',
              style: const TextStyle(color: Colors.orange),
            ),
          );
        }
        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aún no tienes dispositivos vinculados en la nube.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: [for (final device in devices) _cloudCard(device)],
        );
      },
    );
  }

  Widget _cloudCard(CloudDevice device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.cloud_outlined, size: 28),
        title: Text(device.name),
        subtitle: Text(
          device.lastReportAt == null
              ? 'Sin reportes'
              : 'Último reporte: ${device.lastReportAt!.toLocal()}'
                  '${device.humidity != null ? '\nHumedad: ${device.humidity!.toStringAsFixed(1)}%' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _deviceCard(DiscoveredDevice device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.sensors, size: 32),
        title: Text(device.name),
        subtitle: Text('RSSI: ${device.rssi} dBm'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openDevice(device),
      ),
    );
  }
}
