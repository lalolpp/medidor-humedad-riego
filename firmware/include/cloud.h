#pragma once

#include <Arduino.h>
#include "sensor.h"

bool cloudLogin();
void cloudDisconnect();
bool cloudPublish(const SensorReading &reading, uint16_t intervalMin, float daysNoSun);
// Lee la configuración remota (devices/{id}/config/current). Devuelve el
// intervalo de reporte en minutos configurado desde la app, o `fallback`
// si no existe o hay error.
uint16_t cloudFetchInterval(uint16_t fallback);
