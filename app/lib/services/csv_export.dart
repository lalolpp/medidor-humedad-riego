import 'package:medidor_humedad/models/reading.dart';

import 'csv_exporter_stub.dart'
    if (dart.library.io) 'csv_exporter_io.dart'
    if (dart.library.html) 'csv_exporter_web.dart' as impl;

String buildReadingsCsv(List<Reading> readings) {
  final buf = StringBuffer();
  buf.writeln('timestamp,humidity_pct,soil_temp_c,battery_v,battery_level,rssi');
  for (final r in readings) {
    final t = r.timestamp.toUtc().toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');
    final st = r.soilTemp.isNaN || r.soilTemp <= -100 ? '' : r.soilTemp.toStringAsFixed(2);
    buf.writeln(
      '$t,${r.humidity.toStringAsFixed(2)},$st,'
      '${r.batteryVoltage.toStringAsFixed(2)},${r.batteryLevel.toStringAsFixed(2)},${r.rssi}',
    );
  }
  return buf.toString();
}

Future<void> exportReadingsCsv(List<Reading> readings, String fileName) {
  return impl.saveCsv(buildReadingsCsv(readings), fileName);
}
