import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MetricPoint {
  final DateTime x;
  final double y;

  const MetricPoint(this.x, this.y);
}

class MetricSeries {
  final String label;
  final Color color;
  final List<MetricPoint> points;

  const MetricSeries({
    required this.label,
    required this.color,
    required this.points,
  });
}

class MetricsChart extends StatelessWidget {
  final List<MetricSeries> series;
  final String unitLabel;
  final double? minY;
  final double? maxY;
  final bool showHour;
  final String emptyLabel;

  const MetricsChart({
    super.key,
    required this.series,
    required this.unitLabel,
    this.minY,
    this.maxY,
    this.showHour = true,
    this.emptyLabel = 'Sin datos',
  });

  @override
  Widget build(BuildContext context) {
    final all = <MetricPoint>[
      for (final s in series) ...s.points,
    ];
    if (all.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    final minTs = all.map((p) => p.x).reduce((a, b) => a.isBefore(b) ? a : b);
    final maxTs = all.map((p) => p.x).reduce((a, b) => a.isAfter(b) ? a : b);

    double computeMinY() {
      if (minY != null) return minY!;
      var m = double.infinity;
      for (final p in all) {
        if (p.y < m) m = p.y;
      }
      return m;
    }

    double computeMaxY() {
      if (maxY != null) return maxY!;
      var m = -double.infinity;
      for (final p in all) {
        if (p.y > m) m = p.y;
      }
      return m;
    }

    final lo = computeMinY();
    final hi = computeMaxY();
    final span = (hi - lo).abs() < 0.001 ? 1.0 : hi - lo;
    final padLo = lo - span * 0.08;
    final padHi = hi + span * 0.08;

    final xSpan = maxTs.millisecondsSinceEpoch - minTs.millisecondsSinceEpoch;
    final step = xSpan <= 0 ? 1 : xSpan;
    double xOf(MetricPoint p) => (p.x.millisecondsSinceEpoch - minTs.millisecondsSinceEpoch) / step;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 1,
          minY: padLo,
          maxY: padHi,
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: [
                  for (final p in s.points) FlSpot(xOf(p), p.y),
                ],
                isCurved: true,
                color: s.color,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: s.color.withValues(alpha: 0.10),
                ),
              ),
          ],
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: ((padHi - padLo) / 5).clamp(0.01, double.infinity),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                  final text = showHour
                      ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                      : '${dt.day}/${dt.month}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      text,
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
