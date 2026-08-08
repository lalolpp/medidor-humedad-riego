#pragma once

#include <Arduino.h>
#include <functional>
#include "sensor.h"

struct StoredReading {
  SensorReading r;
  uint16_t intervalMin;
};

void readingsInit();
void readingsAppend(const SensorReading &reading, uint16_t intervalMin);
size_t readingsCount();
size_t readingsSerializeChunk(size_t start, char *buffer, size_t bufferLen);

// Itera las lecturas guardadas en LittleFS con `lowerTs < t < upperTs`, en
// orden cronológico, llamando a `cb` por cada una. Si `cb` devuelve false la
// iteración se detiene. Devuelve cuántas lecturas visitó (las filtradas no se
// cuentan).
size_t readingsVisitRange(uint32_t lowerTs, uint32_t upperTs,
                          const std::function<bool(const StoredReading &)> &cb);
