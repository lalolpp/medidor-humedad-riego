#pragma once

#include <Arduino.h>
#include "sensor.h"

void readingsInit();
void readingsAppend(const SensorReading &reading, uint16_t intervalMin);
size_t readingsCount();
size_t readingsSerializeChunk(size_t start, char *buffer, size_t bufferLen);
