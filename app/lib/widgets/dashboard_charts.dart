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

/// Datos de una diapositiva del carousel de sectores.
class SectorSlide {
  final String name;
  final String variety;
  final String? fieldName;
  final String? cropName;
  final double? humidity;
  final String? tempLabel;
  final int rangeIdx;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onDelete;

  const SectorSlide({
    required this.name,
    required this.variety,
    this.fieldName,
    this.cropName,
    this.humidity,
    this.tempLabel,
    required this.rangeIdx,
    required this.statusText,
    required this.statusColor,
    this.onDelete,
  });
}

/// Carousel (PageView) de sectores de riego, equivalente al carousel de
/// Bootstrap: se desplaza deslizando o con las flechas laterales, muestra
/// indicadores y un mini-donut por sector.
class SectorCarousel extends StatefulWidget {
  final List<SectorSlide> slides;
  final VoidCallback? onAdd;

  const SectorCarousel({super.key, required this.slides, this.onAdd});

  @override
  State<SectorCarousel> createState() => _SectorCarouselState();
}

class _SectorCarouselState extends State<SectorCarousel> {
  final _controller = PageController();
  int _page = 0;

  int get _total =>
      widget.slides.length + (widget.onAdd != null ? 1 : 0);

  @override
  void didUpdateWidget(covariant SectorCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= _total && _total > 0) {
      _page = _total - 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Sin sectores registrados',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _total,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => i < widget.slides.length
                    ? _slide(widget.slides[i])
                    : _addSlide(),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrow(Icons.chevron_left, _page > 0,
                      () => _goTo(_page - 1)),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrow(Icons.chevron_right, _page < _total - 1,
                      () => _goTo(_page + 1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF223050),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _addSlide() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF182744),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4C)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onAdd,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add,
                    color: Color(0xFF22C55E), size: 26),
              ),
              const SizedBox(height: 8),
              const Text(
                'Añadir sector',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Toca para agregar',
                style:
                    TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _slide(SectorSlide s) {
    final subtitle = [
      if (s.variety.isNotEmpty) s.variety,
      if (s.cropName != null && s.cropName!.isNotEmpty) s.cropName!,
      if (s.tempLabel != null) 'Temp: ${s.tempLabel}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF182744),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.statusColor.withValues(alpha: 0.45)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              _gauge(s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.fieldName != null && s.fieldName!.isNotEmpty) ...[
                      Text(
                        s.fieldName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE6EDF7),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: s.statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: s.statusColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (s.onDelete != null)
            Positioned(
              top: 0,
              right: 0,
              child: _deleteButton(s),
            ),
        ],
      ),
    );
  }

  Widget _deleteButton(SectorSlide s) {
    return Material(
      color: const Color(0xFF7F1D1D),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: s.onDelete,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(
            Icons.delete_outline,
            size: 16,
            color: Color(0xFFFCA5A5),
          ),
        ),
      ),
    );
  }

  /// Mini-donut del sector: proporción de humedad con el color de su rango.
  Widget _gauge(SectorSlide s) {
    final h = s.humidity;
    final color = s.rangeIdx >= 0 && s.rangeIdx < HumRanges.colors.length
        ? HumRanges.colors[s.rangeIdx]
        : s.statusColor;
    final idx = s.rangeIdx < 0
        ? 0
        : (s.rangeIdx > HumRanges.labels.length - 1
            ? HumRanges.labels.length - 1
            : s.rangeIdx);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 31,
              sections: [
                if (h != null)
                  PieChartSectionData(
                    value: h.clamp(0, 100).toDouble(),
                    color: color,
                    radius: 39,
                    showTitle: false,
                  ),
                PieChartSectionData(
                  value: h == null
                      ? 1
                      : (100 - h.clamp(0, 100)).clamp(0, 100).toDouble(),
                  color: color.withValues(alpha: 0.12),
                  radius: 39,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                h == null ? '—' : '${h.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE6EDF7),
                ),
              ),
              Text(
                s.rangeIdx >= 0 ? HumRanges.labels[idx] : 'Sin lectura',
                style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1120).withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF223050)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? const Color(0xFF94A3B8)
                : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

/// Gráfico de líneas con la evolución de la humedad promedio diaria, siguiendo
/// el modelo "brush" de ApexCharts: un gráfico principal muestra la ventana
/// seleccionada y un gráfico resumen inferior permite arrastrar o redimensionar
/// dicha ventana. Tiene tooltip al pasar el dedo y selector de rango.
class HistoryLineChart extends StatefulWidget {
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
  State<HistoryLineChart> createState() => _HistoryLineChartState();
}

enum _BrushMode { move, left, right, jump }

class _HistoryLineChartState extends State<HistoryLineChart> {
  static const _green = Color(0xFF22C55E);

  /// Ventana visible como índices (posiblemente fraccionarios) dentro de
  /// [HistoryLineChart.points].
  double _start = 0;
  double _end = 0;
  _BrushMode _mode = _BrushMode.move;

  List<DailyHumidity> get _points => widget.points;

  @override
  void initState() {
    super.initState();
    _resetWindow();
  }

  @override
  void didUpdateWidget(covariant HistoryLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points || oldWidget.days != widget.days) {
      _resetWindow();
    }
  }

  void _resetWindow() {
    final n = _points.length;
    if (n == 0) {
      _start = 0;
      _end = 0;
      return;
    }
    final days = widget.days < 1 ? 1 : (widget.days > n ? n : widget.days);
    _start = (n - days).toDouble();
    _end = (n - 1).toDouble();
  }

  double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  int _idx(double v, int lo, int hi) {
    var i = v.round();
    if (i < lo) i = lo;
    if (i > hi) i = hi;
    return i;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rangeChips(),
        const SizedBox(height: 12),
        if (_points.isEmpty)
          const SizedBox(
            height: 230,
            child: Center(
              child: Text(
                'Sin datos históricos en el rango',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else ...[
          SizedBox(height: 230, child: _mainChart()),
          const SizedBox(height: 14),
          SizedBox(height: 60, child: _brushChart()),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 13, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Text(
                  'Arrastra o redimensiona la ventana inferior para explorar',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _rangeChips() {
    return Row(
      children: [
        for (final d in const [7, 14, 30])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$d días', style: const TextStyle(fontSize: 12)),
              selected: widget.days == d,
              onSelected: (_) => widget.onDaysChanged(d),
              selectedColor: _green,
              backgroundColor: const Color(0xFF16203A),
              side: BorderSide(
                color: widget.days == d ? _green : const Color(0xFF223050),
              ),
              labelStyle: TextStyle(
                color: widget.days == d
                    ? const Color(0xFF06110B)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
      ],
    );
  }

  /// Gráfico principal limitado a la ventana [_start, _end].
  Widget _mainChart() {
    final n = _points.length;
    final s = _idx(_start, 0, n - 1);
    final e = _idx(_end, s, n - 1);
    final spots = <FlSpot>[
      for (int i = s; i <= e; i++) FlSpot(i.toDouble(), _points[i].avg),
    ];
    final interval = ((e - s + 1) / 3).ceil().clamp(1, 99).toDouble();

    return LineChart(
      LineChartData(
        minX: s.toDouble(),
        maxX: e.toDouble(),
        minY: 0,
        maxY: 100,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  _tooltipFor(t.x),
                  const TextStyle(
                    color: Color(0xFF06110B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _green,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _green.withValues(alpha: 0.3),
                  _green.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Color(0xFF223050),
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
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _points.length) {
                  return const SizedBox.shrink();
                }
                final d = _points[idx].day;
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
    );
  }

  String _tooltipFor(double x) {
    final idx = x.round();
    if (idx < 0 || idx >= _points.length) {
      return '${x.toStringAsFixed(1)}%';
    }
    final d = _points[idx].day;
    return '${d.day}/${d.month}\n${_points[idx].avg.toStringAsFixed(1)}%';
  }

  /// Gráfico resumen (overview) con la ventana de selección arrastrable.
  Widget _brushChart() {
    final n = _points.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (n <= 1) {
          return _brushLine();
        }
        final l = (_start / (n - 1)) * width;
        final r = (_end / (n - 1)) * width;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onBrushStart(d, width, n),
          onPanUpdate: (d) => _onBrushUpdate(d, width, n),
          onPanEnd: (_) => _mode = _BrushMode.move,
          child: Stack(
            children: [
              Positioned.fill(child: _brushLine()),
              Positioned(
                left: l,
                right: width - r,
                top: 0,
                bottom: 0,
                child: _brushBand(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// La línea del gráfico resumen, con todos los puntos cargados.
  Widget _brushLine() {
    final spots = <FlSpot>[
      for (int i = 0; i < _points.length; i++)
        FlSpot(i.toDouble(), _points[i].avg),
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_points.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _green.withValues(alpha: 0.55),
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _green.withValues(alpha: 0.18),
                  _green.withValues(alpha: 0.01),
                ],
              ),
            ),
          ),
        ],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          show: false,
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _brushBand() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              border: Border(
                left: const BorderSide(color: _green, width: 1),
                right: const BorderSide(color: _green, width: 1),
              ),
            ),
          ),
        ),
        Positioned(left: 0, top: 0, bottom: 0, child: _brushHandle()),
        Positioned(right: 0, top: 0, bottom: 0, child: _brushHandle()),
      ],
    );
  }

  Widget _brushHandle() {
    return Container(
      width: 6,
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  void _onBrushStart(DragStartDetails d, double width, int n) {
    final l = (_start / (n - 1)) * width;
    final r = (_end / (n - 1)) * width;
    final x = d.localPosition.dx;
    final len = _end - _start;
    if ((x - l).abs() <= 12) {
      _mode = _BrushMode.left;
    } else if ((x - r).abs() <= 12) {
      _mode = _BrushMode.right;
    } else if (x >= l && x <= r) {
      _mode = _BrushMode.move;
    } else {
      // Tocar fuera de la ventana la centra en ese punto.
      _mode = _BrushMode.jump;
      final v = (x / width) * (n - 1);
      final ns = _clamp(v - len / 2, 0, (n - 1) - len);
      setState(() {
        _start = ns;
        _end = ns + len;
      });
    }
  }

  void _onBrushUpdate(DragUpdateDetails d, double width, int n) {
    final dIdx = d.delta.dx / width * (n - 1);
    final maxIdx = (n - 1).toDouble();
    setState(() {
      switch (_mode) {
        case _BrushMode.move:
        case _BrushMode.jump:
          final len = _end - _start;
          final ns = _clamp(_start + dIdx, 0, maxIdx - len);
          _start = ns;
          _end = ns + len;
          break;
        case _BrushMode.left:
          _start = _clamp(_start + dIdx, 0, _end - 1);
          break;
        case _BrushMode.right:
          _end = _clamp(_end + dIdx, _start + 1, maxIdx);
          break;
      }
    });
  }
}
