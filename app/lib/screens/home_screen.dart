import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/device.dart';
import 'package:medidor_humedad/services/ble_device_service.dart';
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

  DeviceService get _service => _demoMode ? DemoDeviceService() : BleDeviceService();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Dispositivos')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Modo demo (sin hardware)'),
            subtitle: const Text('Simula un nodo para probar la app'),
            value: _demoMode,
            onChanged: _onModeChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _devices.isEmpty
                ? const Center(child: Text('No se encontraron dispositivos'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.sensors, size: 32),
                          title: Text(device.name),
                          subtitle: Text('RSSI: ${device.rssi} dBm'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDevice(device),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
