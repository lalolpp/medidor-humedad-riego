const List<int> kAllowedIntervals = [10, 15, 20, 30, 60];
const int kDefaultBatteryCapacityMah = 2500;
const double kActiveMahPerCycle = 2.1;
const double kSleepMahPerDay = 0.7;

const int kAutonomyWarningDays = 15;

bool isValidInterval(int intervalMin) => kAllowedIntervals.contains(intervalMin);

double totalMahPerDay(int intervalMin) {
  final safe = isValidInterval(intervalMin) ? intervalMin : 30;
  final cyclesPerDay = 1440 / safe;
  return cyclesPerDay * kActiveMahPerCycle + kSleepMahPerDay;
}

double autonomyDays(int intervalMin, int capacityMah, double batteryLevel01) {
  final usable = capacityMah * batteryLevel01.clamp(0.0, 1.0);
  if (usable <= 0) return 0;
  return usable / totalMahPerDay(intervalMin);
}

String formatAutonomy(double days) {
  return '${days.round()} días';
}
