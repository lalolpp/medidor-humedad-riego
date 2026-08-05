#include "sensor.h"
#include "config.h"
#include <Arduino.h>
#include <WiFi.h>

static float readBatteryVoltage() {
  uint32_t raw = 0;
  for (uint8_t i = 0; i < 8; i++) raw += analogRead(PIN_BATTERY_ADC);
  raw /= 8;
  return (float)raw * BATTERY_REF_VOLTAGE / 4095.0f * BATTERY_DIVIDER_GAIN;
}

static float batteryLevel(float voltage) {
  float full = BATTERY_FULL_VOLTAGE_MV / 1000.0f;
  float empty = BATTERY_EMPTY_VOLTAGE_MV / 1000.0f;
  if (voltage >= full) return 1.0f;
  if (voltage <= empty) return 0.0f;
  return (voltage - empty) / (full - empty);
}

void sensorInit() {
  analogSetPinAttenuation(PIN_SOIL_SENSOR, ADC_11db);
  analogSetPinAttenuation(PIN_BATTERY_ADC, ADC_11db);
  pinMode(PIN_LTE_PWR, OUTPUT);
  digitalWrite(PIN_LTE_PWR, LOW);
}

SensorReading readSensor() {
  SensorReading r = {};
  uint32_t raw = 0;
  for (uint8_t i = 0; i < 8; i++) raw += analogRead(PIN_SOIL_SENSOR);
  raw /= 8;
  r.humidityPercent = 100.0f * (1.0f - (float)raw / 4095.0f);
  r.batteryVoltage = readBatteryVoltage();
  r.batteryLevel01 = batteryLevel(r.batteryVoltage);
  r.rssi = (WiFi.status() == WL_CONNECTED) ? WiFi.RSSI() : -127;
  r.timestampSec = (uint32_t)time(nullptr);
  return r;
}
