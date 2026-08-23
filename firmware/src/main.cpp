#include <Arduino.h>
#include <esp_sleep.h>

#include "config.h"
#include "storage.h"
#include "power.h"
#include "sensor.h"
#include "readings_store.h"
#include "cloud.h"
#include "ble_service.h"
#include "valve.h"

#ifdef ENABLE_OTA
#include "ota.h"
#endif

static unsigned long bleWindowEnd = 0;
static unsigned long valveOpenedAt = 0;
static float lastBatteryVoltage = 0.0f;

void setup() {
  Serial.begin(115200);
  sensorInit();
  settingsLoad();
  Serial.printf("[NVS] wifiSsid='%s' deviceId='%s'\n", settings().wifiSsid,
                settings().deviceId);
  readingsInit();
  valveInit();

  SensorReading r = readSensor();
  lastBatteryVoltage = r.batteryVoltage;
  readingsAppend(r, settings().samplingIntervalMin);

  if (settings().cloudEnabled) {
    Serial.println("[CLOUD] habilitado, intentando ciclo de publicación");
    if (cloudLogin()) {
      // Aplica el comando de riego antes de publicar: si la app ordenó abrir
      // la válvula, este ciclo lo deja accionado (y el loop lo mantiene).
      // Safety: no abre válvula si la batería está por debajo del mínimo.
      String valveState;
      if (cloudFetchValve(valveState)) {
        if (valveState == "ON" && r.batteryLevel01 < VALVE_MIN_BATTERY) {
          Serial.printf("[VALVE] Batería baja (%.0f%%), ignorando comando ON\n",
                        r.batteryLevel01 * 100);
        } else {
          valveSet(valveState == "ON");
          if (valveActive()) {
            valveOpenedAt = millis();
          }
        }
      }
      // Ajusta el intervalo de reporte según la configuración remota
      // (configurado desde la app) antes de publicar.
      settingsSetInterval(
          cloudFetchInterval(settings().samplingIntervalMin));
      float days = autonomyDays(settings().samplingIntervalMin,
                                settings().batteryCapacityMah, r.batteryLevel01);
      if (cloudPublish(r, settings().samplingIntervalMin, days)) {
        // Reenvía las lecturas que quedaron pendientes mientras no hubo red.
        cloudBackfill(r.timestampSec);
      }

#ifdef ENABLE_OTA
      String otaUrl, otaVersion;
      if (cloudFetchOta(otaUrl, otaVersion) &&
          otaVersion != FIRMWARE_VERSION) {
        Serial.printf("[OTA] versión remota %s != local %s, actualizando...\n",
                      otaVersion.c_str(), FIRMWARE_VERSION);
        performOta(otaUrl);
      }
#endif

      cloudDisconnect();
    }
  }

#if VALVE_KEEP_AWAKE
  if (valveActive()) {
    // Mientras riega NO se inicia BLE: el stack BLE junto a WiFi+TLS agotan
    // la RAM (fallas "ssl_client ECP - Memory allocation failed") y el nodo
    // se reinicia en bucle, republicando lecturas y quemando la cuota diaria.
    // La nube se sigue re-chequeando cada VALVE_RECHECK_MS desde loop().
    Serial.println("[BLE] omitido: válvula activa (riego en curso)");
    bleWindowEnd = millis() + VALVE_RECHECK_MS;
  } else
#endif
  {
    bleInit();
    bleSetLatestReading(r);
    bleWindowEnd = millis() + BLE_ADV_WINDOW_MS;
  }
}

void loop() {
  bleProcess();
  if (bleClientConnected()) {
    bleWindowEnd = millis() + BLE_KEEP_ALIVE_MS;
  }

#if VALVE_KEEP_AWAKE
  // Mientras la válvula esté abierta el relé debe permanecer alimentado: no se
  // duerme y se re-chequea el comando remoto para detectar el "OFF".
  if (valveActive() && millis() >= bleWindowEnd) {
    // Safety: si la válvula lleva abierta más de VALVE_MAX_OPEN_MIN, cerrar.
#if VALVE_MAX_OPEN_MIN > 0
    if (valveOpenedAt > 0 &&
        (millis() - valveOpenedAt) > (unsigned long)VALVE_MAX_OPEN_MIN * 60000UL) {
      Serial.printf("[VALVE] Safety: máximo %d min alcanzado, cerrando\n",
                    VALVE_MAX_OPEN_MIN);
      valveSet(false);
    } else
#endif
    {
      bleWindowEnd = millis() + VALVE_RECHECK_MS;
      String valveState;
      if (cloudFetchValve(valveState) && valveState != "ON") {
        valveSet(false);
      }
    }
  }
#endif

  // Modo banco/pruebas: USB puesto. Se detecta como batería llena (≥4,15 V,
  // cargando por USB) o sin batería conectada (≈0 V). Solo con una batería
  // real en rango entra el ciclo normal de deep sleep.
  bool benchPower = lastBatteryVoltage >= 4.15f || lastBatteryVoltage < 0.5f;
  if (benchPower && millis() >= bleWindowEnd) {
    bleWindowEnd = millis() + BLE_KEEP_ALIVE_MS;
  }
  if (millis() >= bleWindowEnd
#if VALVE_KEEP_AWAKE
      && !valveActive()
#endif
      && !benchPower
  ) {
    Serial.printf("[PWR] Batería %.2fV, entrando deep sleep\n", lastBatteryVoltage);
    esp_deep_sleep((uint64_t)settings().samplingIntervalMin * 60ULL * 1000000ULL);
  }
  delay(10);
}
