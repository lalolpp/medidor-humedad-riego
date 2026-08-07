import 'dart:convert';

import 'package:http/http.dart' as http;

class DailyForecast {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final double precipitationProbability;
  final double precipitationMm;

  const DailyForecast({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.precipitationProbability,
    required this.precipitationMm,
  });
}

class WeatherInfo {
  final List<DailyForecast> daily;
  final bool forecastRain;

  const WeatherInfo({required this.daily, required this.forecastRain});
}

/// Condiciones ambientales actuales del predio (Open-Meteo).
class CurrentConditions {
  final double temperatureC;
  final double relativeHumidityPct;
  final double precipitationMm;
  final double windSpeedKmh;
  final double solarRadiationWm2;
  final bool rainToday;

  const CurrentConditions({
    required this.temperatureC,
    required this.relativeHumidityPct,
    required this.precipitationMm,
    required this.windSpeedKmh,
    required this.solarRadiationWm2,
    required this.rainToday,
  });
}

class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  static const _base = 'https://api.open-meteo.com/v1/forecast';

  /// Umbral de probabilidad de lluvia (%) para sugerir posponer el riego.
  static const double rainThresholdPct = 50;

  Future<WeatherInfo> forecast(double lat, double lon, {int days = 5}) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': '$lat',
      'longitude': '$lon',
      'daily': 'temperature_2m_min,temperature_2m_max,precipitation_probability_max,precipitation_sum',
      'timezone': 'auto',
      'forecast_days': '$days',
    });

    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Clima: error HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final daily = (json['daily'] as Map<String, dynamic>? ?? {});
    final times = (daily['time'] as List?)?.cast<String>() ?? [];
    final tMin = (daily['temperature_2m_min'] as List?)?.cast<num>() ?? [];
    final tMax = (daily['temperature_2m_max'] as List?)?.cast<num>() ?? [];
    final pop = (daily['precipitation_probability_max'] as List?)?.cast<num>() ?? [];
    final pSum = (daily['precipitation_sum'] as List?)?.cast<num>() ?? [];

    final list = <DailyForecast>[
      for (int i = 0; i < times.length; i++)
        DailyForecast(
          date: DateTime.tryParse(times[i]) ?? DateTime.now(),
          minTemp: (i < tMin.length ? tMin[i] : 0).toDouble(),
          maxTemp: (i < tMax.length ? tMax[i] : 0).toDouble(),
          precipitationProbability:
              (i < pop.length ? pop[i] : 0).toDouble(),
          precipitationMm: (i < pSum.length ? pSum[i] : 0).toDouble(),
        ),
    ];

    final forecastRain = list
        .any((d) => d.precipitationProbability >= rainThresholdPct);
    return WeatherInfo(daily: list, forecastRain: forecastRain);
  }

  /// Condiciones actuales + si hoy hay lluvia prevista (≥ umbral).
  Future<CurrentConditions> current(double lat, double lon) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,shortwave_radiation',
      'daily': 'precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '1',
    });

    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Clima: error HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final cur = json['current'] as Map<String, dynamic>? ?? {};
    final pops = (json['daily'] as Map<String, dynamic>? ?? {})[
            'precipitation_probability_max']
        as List?;
    final popToday =
        (pops != null && pops.isNotEmpty ? (pops.first as num).toDouble() : 0.0);

    return CurrentConditions(
      temperatureC: (cur['temperature_2m'] as num?)?.toDouble() ?? double.nan,
      relativeHumidityPct:
          (cur['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
      precipitationMm: (cur['precipitation'] as num?)?.toDouble() ?? 0,
      windSpeedKmh: (cur['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      solarRadiationWm2:
          (cur['shortwave_radiation'] as num?)?.toDouble() ?? 0,
      rainToday: popToday >= rainThresholdPct,
    );
  }
}
