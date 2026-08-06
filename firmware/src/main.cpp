#include <Arduino.h>
#include <esp_sleep.h>

#include "config.h"
#include "storage.h"
#include "power.h"
#include "sensor.h"
#include "readings_store.h"
#include "cloud.h"
#include "ble_service.h"

#ifdef ENABLE_OTA
#include "ota.h"
#endif

static unsigned long bleWindowEnd = 0;

void setup() {
  Serial.begin(115200);
  sensorInit();
  settingsLoad();
  readingsInit();

  SensorReading r = readSensor();
  readingsAppend(r, settings().samplingIntervalMin);

  if (settings().cloudEnabled) {
    if (cloudLogin()) {
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
  if (millis() >= bleWindowEnd) {
    esp_deep_sleep((uint64_t)settings().samplingIntervalMin * 60ULL * 1000000ULL);
  }
  delay(10);
}
