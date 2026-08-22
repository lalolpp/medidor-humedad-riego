import 'package:flutter/foundation.dart';

enum TempUnit { celsius, fahrenheit }

enum ConnectionMode { bluetooth, wifi }

class AppSettings {
  AppSettings._();

  static final ValueNotifier<TempUnit> tempUnit = ValueNotifier(TempUnit.celsius);

  /// Cómo prefiere trabajar con los nodos: Bluetooth directo (al lado del
  /// nodo) o WiFi/nube (monitoreo remoto desde cualquier lugar).
  static final ValueNotifier<ConnectionMode> connectionMode =
      ValueNotifier(ConnectionMode.bluetooth);

  static double toDisplay(double celsius) {
    if (celsius.isNaN || celsius <= -100) return celsius;
    return tempUnit.value == TempUnit.fahrenheit ? celsius * 9 / 5 + 32 : celsius;
  }

  static String unitSuffix() =>
      tempUnit.value == TempUnit.fahrenheit ? '°F' : '°C';
}
