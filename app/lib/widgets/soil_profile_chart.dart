import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:medidor_humedad/models/reading.dart';

class SoilProfileChart extends StatelessWidget {
  final Reading reading;
  final double irrigateBelow;
  final double optimalMin;
  final double optimalMax;
  final double excessAbove;

  const SoilProfileChart({
    super.key,
    required this.reading,
    required this.irrigateBelow,
    required this.optimalMin,
    required this.optimalMax,
    required this.excessAbove,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reading.humidityByDepth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Sin perfil de humedad disponible')),
      );
    }

    final spots = [
      for (final entry in entries)
        FlSpot(entry.value.clamp(0, 100).toDouble(), 110 - entry.key.toDouble()),
    ];

    return SizedBox(
      height: 270,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 100,
          minY: 0,
          maxY: 110,
          clipData: const FlClipData.all(),
          rangeAnnotations: RangeAnnotations(
            verticalRangeAnnotations: [
              VerticalRangeAnnotation(
                x1: 0,
                x2: irrigateBelow.clamp(0, 100).toDouble(),
                color: Colors.orange.withValues(alpha: 0.12),
              ),
              VerticalRangeAnnotation(
                x1: optimalMin.clamp(0, 100).toDouble(),
                x2: optimalMax.clamp(0, 100).toDouble(),
                color: Colors.green.withValues(alpha: 0.15),
              ),
              VerticalRangeAnnotation(
                x1: excessAbove.clamp(0, 100).toDouble(),
                x2: 100,
                color: Colors.red.withValues(alpha: 0.10),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (items) => [
                for (final item in items)
                  LineTooltipItem(
                    '${(110 - item.y).round()} cm\n'
                    '${item.x.toStringAsFixed(1)}% humedad',
                    const TextStyle(
                      color: Color(0xFFE8E8F0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF00E5FF),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: const Color(0xFF1C1C2E),
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF00E5FF),
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          gridData: FlGridData(
            drawVerticalLine: true,
            verticalInterval: 20,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Humedad (%)'),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 20,
                getTitlesWidget: (value, meta) => Text(
                  '${value.round()}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9E9EB8)),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text('Profundidad (cm)'),
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  final depth = 110 - value;
                  if (depth <= 0 || depth > 100) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${depth.round()}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9E9EB8)),
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
