import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/services/app_firebase.dart';
import 'package:medidor_humedad/services/auth_service.dart';
import 'package:medidor_humedad/services/ble_device_service.dart';
import 'package:medidor_humedad/services/demo_device_service.dart';
import 'package:medidor_humedad/services/device_service.dart';
import 'package:medidor_humedad/services/push_notifications.dart';
import 'package:medidor_humedad/widgets/smart_dashboard.dart';

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
  int _dashboardVersion = 0;
  DeviceService _service = DemoDeviceService();

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    if (AppFirebase.configured && uid != null) {
      PushService.instance.init(uid);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _discover();
      _loadCloud();
    });
  }

  void _loadCloud() {
    final uid = AuthService.instance.currentUser?.uid;
    if (!AppFirebase.configured || uid == null) {
      return;
    }
    setState(() => _dashboardVersion++);
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
    setState(() {
      _demoMode = demo;
      _service = demo ? DemoDeviceService() : BleDeviceService();
    });
    _discover();
  }

  /// Pull-to-refresh: re-descubre dispositivos cercanos y recarga el
  /// dashboard en la nube (campos, cultivos, sondas e historial).
  Future<void> _handleRefresh() async {
    await _discover();
    _loadCloud();
  }

  void _openDevice(DiscoveredDevice device) async {
    final isBle = _service.isDemo == false;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isBle ? Icons.bluetooth : Icons.phone_android,
          color: isBle ? Colors.blue : Colors.grey,
          size: 40,
        ),
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBle
                  ? '¿Conectar a este dispositivo por Bluetooth?'
                  : '¿Entrar en modo demo (sin hardware real)?',
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${device.id}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (isBle && device.rssi != 0)
              Text(
                'Señal: ${device.rssi} dBm',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            child: Text(isBle ? 'Conectar' : 'Iniciar demo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(service: _service, device: device),
      ),
    );
    _loadCloud();
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
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
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
          if (showCloud) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Mi campo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SmartDashboard(
              key: ValueKey(_dashboardVersion),
              uid: user.uid,
              onChanged: _loadCloud,
            ),
            const Divider(height: 24),
          ],
        ],
        ),
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
