import 'package:flutter/material.dart';

/// Alerta individual del panel de alertas recientes del dashboard.
class DashAlert {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String time;
  final int severity;

  const DashAlert({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.time,
    this.severity = 0,
  });
}

/// Panel "Alertas recientes": lista las alertas más graves primero y permite
/// expandir para ver todas.
class AlertsPanel extends StatefulWidget {
  final List<DashAlert> alerts;
  final VoidCallback? onViewAll;

  const AlertsPanel({super.key, required this.alerts, this.onViewAll});

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.alerts]
      ..sort((a, b) => b.severity.compareTo(a.severity));
    final visible = _expanded ? sorted : sorted.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                Icon(Icons.verified_outlined, color: Color(0xFF22C55E)),
                SizedBox(width: 8),
                Text(
                  'Sin alertas activas. Todo en orden.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        for (final a in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(a.icon, size: 18, color: a.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE6EDF7),
                              ),
                            ),
                          ),
                          Text(
                            a.time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (sorted.length > 4)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _expanded = !_expanded);
                widget.onViewAll?.call();
              },
              child: Text(
                _expanded
                    ? 'Ver menos'
                    : 'Ver todas las alertas (${sorted.length})',
                style: const TextStyle(color: Color(0xFF38BDF8)),
              ),
            ),
          ),
      ],
    );
  }
}
