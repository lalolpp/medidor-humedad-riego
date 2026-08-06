import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'metrics_chart.dart';

/// Superpone humedad (%) y temperatura en un mismo plano temporal
/// usando ejes Y independientes (izquierda: humedad, derecha: temperatura).
class DualAxisChart extends StatelessWidget {
  final List<MetricPoint> humidity;
  final List<MetricPoint> temp;
  final String tempUnit;

  const DualAxisChart({
    super.key,
    required this.humidity,
    required this.temp,
    required this.tempUnit,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...humidity, ...temp];
    if (all.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text('Sin datos', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    final minTs = all.map((p) => p.x).reduce((a, b) => a.isBefore(b) ? a : b);
    final maxTs = all.map((p) => p.x).reduce((a, b) => a.isAfter(b) ? a : b);
    final xSpan = maxTs.millisecondsSinceEpoch - minTs.millisecondsSinceEpoch;
    final step = xSpan <= 0 ? 1 : xSpan;
    double xOf(MetricPoint p) =>
        (p.x.millisecondsSinceEpoch - minTs.millisecondsSinceEpoch) / step;

    double tLo() {
      var m = double.infinity;
      for (final p in temp) {
        if (p.y < m) m = p.y;
      }
      return m;
    }

    double tHi() {
      var m = -double.infinity;
      for (final p in temp) {
        if (p.y > m) m = p.y;
      }
      return m;
    }

    final tLoV = temp.isEmpty ? 0 : tLo();
    final tHiV = temp.isEmpty ? 1 : tHi();
    final tSpan = (tHiV - tLoV).abs() < 0.001 ? 1.0 : tHiV - tLoV;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 1,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final p in humidity) FlSpot(xOf(p), p.y.clamp(0, 100)),
              ],
              isCurved: true,
              color: Colors.blue,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withValues(alpha: 0.08),
              ),
            ),
            if (temp.isNotEmpty)
              LineChartBarData(
                spots: [
                  for (final p in temp)
                    FlSpot(xOf(p), (p.y - tLoV) / tSpan * 100),
                ],
                isCurved: true,
                color: Colors.orange,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                ),
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: temp.isNotEmpty,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${(value / 100 * tSpan + tLoV).toStringAsFixed(0)}$tempUnit',
                  style: const TextStyle(fontSize: 10, color: Colors.brown),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 0.25,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value > 1) return const SizedBox.shrink();
                  final ts = minTs.millisecondsSinceEpoch + value * step;
                  final dt = DateTime.fromMillisecondsSinceEpoch(ts.round());
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
