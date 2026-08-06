import 'package:medidor_humedad/models/reading.dart';

class InfiltrationInfo {
  final double ratePctPerHour;
  final String assessment;
  final String detail;

  const InfiltrationInfo(this.ratePctPerHour, this.assessment, this.detail);
}

/// Analiza la velocidad a la que baja la humedad después de un riego
/// (regresión lineal sobre el tramo de descenso tras el pico máximo).
/// Devuelve null si no hay datos suficientes.
InfiltrationInfo? computeInfiltration(List<Reading> readings) {
  final data = readings.where((r) => r.humidity > 0).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (data.length < 10) return null;

  var peakIdx = 0;
  for (var i = 1; i < data.length; i++) {
    if (data[i].humidity > data[peakIdx].humidity) peakIdx = i;
  }
  final peak = data[peakIdx];

  double sx = 0, sy = 0, sxx = 0, sxy = 0;
  var n = 0;
  for (final p in data.sublist(peakIdx)) {
    final hours = p.timestamp.difference(peak.timestamp).inMinutes / 60.0;
    if (hours <= 0) continue;
    final dy = p.humidity - peak.humidity;
    if (dy > 0) continue;
    sx += hours;
    sy += dy;
    sxx += hours * hours;
    sxy += hours * dy;
    n++;
  }
  if (n < 4) return null;

  final denom = n * sxx - sx * sx;
  if (denom.abs() < 1e-9) return null;
  final slope = (n * sxy - sx * sy) / denom; // %/h (negativo al descender)
  final rate = -slope;

  final String assessment;
  final String detail;
  if (rate >= 3.0) {
    assessment = 'Drenaje rápido';
    detail = 'La humedad baja muy rápido: suelo muy arenoso o alta infiltración.';
  } else if (rate >= 1.0) {
    assessment = 'Drenaje normal';
    detail = 'El suelo drena a un ritmo adecuado.';
  } else if (rate >= 0.3) {
    assessment = 'Drenaje lento';
    detail = 'El suelo retiene mucha humedad: vigila riesgo de asfixia radicular.';
  } else {
    assessment = 'Retención alta';
    detail = 'La humedad casi no baja: posible exceso de riego o suelo compactado.';
  }
  return InfiltrationInfo(rate, assessment, detail);
}
