import 'package:flutter/foundation.dart';

enum TempUnit { celsius, fahrenheit }

class AppSettings {
  AppSettings._();

  static final ValueNotifier<TempUnit> tempUnit = ValueNotifier(TempUnit.celsius);

  static double toDisplay(double celsius) {
    if (celsius.isNaN || celsius <= -100) return celsius;
    return tempUnit.value == TempUnit.fahrenheit ? celsius * 9 / 5 + 32 : celsius;
  }

  static String unitSuffix() =>
      tempUnit.value == TempUnit.fahrenheit ? '°F' : '°C';
}
