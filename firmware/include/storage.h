#pragma once

#include <Arduino.h>
#include <Preferences.h>

struct Settings {
  uint16_t samplingIntervalMin;
  uint16_t batteryCapacityMah;
  bool cloudEnabled;
  char wifiSsid[33];
  char wifiPass[65];
  char deviceId[24];
  uint32_t updatedAtSec;
};

Settings &settings();

void settingsLoad();
void settingsSave();
bool settingsSetInterval(uint16_t intervalMin);
