import 'package:flutter/material.dart';

/// Muestra la intensidad de señal WiFi/BLE (dBm) como barras de nivel.
class SignalBars extends StatelessWidget {
  final int? rssi;
  final double size;

  const SignalBars({super.key, this.rssi, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final value = rssi;
    if (value == null) {
      return Icon(Icons.signal_cellular_off, size: size, color: Colors.grey);
    }
    final level = value <= -95
        ? 0
        : value <= -85
            ? 1
            : value <= -70
                ? 2
                : value <= -55
                    ? 3
                    : 4;
    final color = level <= 1
        ? Colors.red
        : level == 2
            ? Colors.orange
            : Colors.green;
    final w = size / 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: w,
            height: size * i / 4,
            margin: const EdgeInsets.symmetric(horizontal: 0.75),
            decoration: BoxDecoration(
              color: i <= level ? color : Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
