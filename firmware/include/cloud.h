#pragma once

#include <Arduino.h>
#include "sensor.h"

bool cloudLogin();
void cloudDisconnect();
bool cloudPublish(const SensorReading &reading, uint16_t intervalMin, float daysNoSun);
// Reenvía a la nube las lecturas acumuladas en LittleFS que quedaron sin
// publicar (t en (lastSyncedTs, currentTs)) usando commits en lote de
// Firestore, con documento determinista readings/r{ts} (idempotente).
// Devuelve false solo si no hay red o un commit falla.
bool cloudBackfill(uint32_t currentTs);
// Lee la configuración remota (devices/{id}/config/current). Devuelve el
// intervalo de reporte en minutos configurado desde la app, o `fallback`
// si no existe o hay error.
uint16_t cloudFetchInterval(uint16_t fallback);
// Lee la configuración OTA (otaUrl/otaVersion). Devuelve false si no hay
// actualización configurada o hay error.
bool cloudFetchOta(String &url, String &version);
// Lee el comando de riego (valveState: "ON"/"OFF") desde config/current.
// Devuelve false si no hay comando o hay error.
bool cloudFetchValve(String &state);
