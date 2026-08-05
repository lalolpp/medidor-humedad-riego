#pragma once

#include <stdint.h>

struct SensorReading {
  float humidityPercent;
  float batteryVoltage;
  float batteryLevel01;
  int32_t rssi;
  uint32_t timestampSec;
};

void sensorInit();
SensorReading readSensor();
