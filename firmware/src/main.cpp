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

void setup() {
  Serial.begin(115200);
  sensorInit();
  settingsLoad();
  readingsInit();
  valveInit();

  SensorReading r = readSensor();
  readingsAppend(r, settings().samplingIntervalMin);

  if (settings().cloudEnabled) {
    if (cloudLogin()) {
      // Aplica el comando de riego antes de publicar: si la app ordenó abrir
      // la válvula, este ciclo lo deja accionado (y el loop lo mantiene).
      String valveState;
      if (cloudFetchValve(valveState)) {
        valveSet(valveState == "ON");
      }
      // Ajusta el intervalo de reporte según la configuración remota
      // (configurado desde la app) antes de publicar.
      settingsSetInterval(
          cloudFetchInterval(settings().samplingIntervalMin));
      float days = autonomyDays(settings().samplingIntervalMin,
                                settings().batteryCapacityMah, r.batteryLevel01);
      cloudPublish(r, settings().samplingIntervalMin, days);

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

  bleInit();
  bleSetLatestReading(r);
  bleWindowEnd = millis() + BLE_ADV_WINDOW_MS;
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
    bleWindowEnd = millis() + VALVE_RECHECK_MS;
    String valveState;
    if (cloudFetchValve(valveState) && valveState != "ON") {
      valveSet(false);
    }
  }
#endif

  if (millis() >= bleWindowEnd
#if VALVE_KEEP_AWAKE
      && !valveActive()
#endif
  ) {
    esp_deep_sleep((uint64_t)settings().samplingIntervalMin * 60ULL * 1000000ULL);
  }
  delay(10);
}
