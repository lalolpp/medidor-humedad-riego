#include "power.h"
#include "config.h"

static const uint16_t kAllowedIntervals[] = {10, 15, 20, 30, 60, 120, 360, 720};

bool isValidInterval(uint16_t intervalMin) {
  for (uint8_t i = 0; i < sizeof(kAllowedIntervals) / sizeof(kAllowedIntervals[0]); i++) {
    if (kAllowedIntervals[i] == intervalMin) return true;
  }
  return false;
}

float autonomyDays(uint16_t intervalMin, uint16_t capacityMah, float batteryLevel01) {
  if (!isValidInterval(intervalMin)) intervalMin = DEFAULT_INTERVAL_MIN;
  uint16_t cyclesPerDay = 1440 / intervalMin;
  float totalMahPerDay = cyclesPerDay * ACTIVE_MAH_PER_CYCLE + SLEEP_CURRENT_MAH_PER_DAY;
  float usableMah = (float)capacityMah * batteryLevel01;
  if (usableMah <= 0.0f) return 0.0f;
  return usableMah / totalMahPerDay;
}
