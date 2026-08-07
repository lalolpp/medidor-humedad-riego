import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Punto diario de humedad promedio para el gráfico histórico.
class DailyHumidity {
  final DateTime day;
  final double avg;

  const DailyHumidity(this.day, this.avg);
}

/// Paleta y rangos de humedad compartidos por el dashboard.
class HumRanges {
  static const colors = <Color>[
    Color(0xFFEF4444), // 0-20 crítico
    Color(0xFFFB923C), // 20-40 bajo
    Color(0xFF22C55E), // 40-60 óptimo
    Color(0xFF38BDF8), // 60-80 alto
    Color(0xFF8B5CF6), // 80-100 saturado
  ];

  static const labels = <String>[
    '0–20%',
    '20–40%',
    '40–60%',
    '60–80%',
    '80–100%',
  ];

  static const status = <String>[
    'Crítico',
    'Bajo',
    'Óptimo',
    'Alto',
    'Saturado',
  ];

  static int indexOf(double h) {
    if (h < 20) return 0;
    if (h < 40) return 1;
    if (h < 60) return 2;
    if (h < 80) return 3;
    return 4;
  }
}

/// Gráfico circular de distribución de sectores por rango de humedad.
class RangeDonut extends StatelessWidget {
  final List<int> counts;

  const RangeDonut({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = counts.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[
      for (int i = 0; i < HumRanges.colors.length; i++)
        if (counts[i] > 0)
          PieChartSectionData(
            value: counts[i].toDouble(),
            color: HumRanges.colors[i],
            radius: 42,
            showTitle: false,
          ),
    ];

    if (total == 0) {
      return const Center(
        child: Text(
          'Sin datos de sectores',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    sections: sections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE6EDF7),
                      ),
                    ),
                    const Text(
                      'sectores',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < HumRanges.colors.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: HumRanges.colors[i],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${HumRanges.labels[i]} · ${HumRanges.status[i]}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Text(
                          '${counts[i]}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE6EDF7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de líneas con la evolución de la humedad promedio diaria.
/// Tiene tooltip al pasar el dedo y un selector de rango de fechas.
class HistoryLineChart extends StatelessWidget {
  final List<DailyHumidity> points;
  final int days;
  final ValueChanged<int> onDaysChanged;

  const HistoryLineChart({
    super.key,
    required this.points,
    required this.days,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].avg),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final d in const [7, 14, 30])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    '$d días',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: days == d,
                  onSelected: (_) => onDaysChanged(d),
                  selectedColor: const Color(0xFF22C55E),
                  backgroundColor: const Color(0xFF16203A),
                  side: BorderSide(
                    color: days == d
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF223050),
                  ),
                  labelStyle: TextStyle(
                    color: days == d
                        ? const Color(0xFF06110B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: spots.isEmpty
              ? const Center(
                  child: Text(
                    'Sin datos históricos en el rango',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touched) => [
                          for (final t in touched)
                            LineTooltipItem(
                              '${t.y.toStringAsFixed(1)}%',
                              const TextStyle(
                                color: Color(0xFF06110B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFF22C55E),
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF22C55E).withValues(alpha: 0.3),
                              const Color(0xFF22C55E).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ],
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: const Color(0xFF223050),
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: 25,
                          getTitlesWidget: (value, meta) => Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval:
                              (points.length / 4).ceilToDouble().clamp(1, 99),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final d = points[idx].day;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${d.day}/${d.month}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
