#pragma once

#include <Arduino.h>
#include "sensor.h"

bool cloudLogin();
void cloudDisconnect();
bool cloudPublish(const SensorReading &reading, uint16_t intervalMin, float daysNoSun);
