#pragma once

#include <Arduino.h>
#include "sensor.h"

void bleInit();
bool bleClientConnected();
void bleProcess();
void bleSetLatestReading(const SensorReading &reading);
