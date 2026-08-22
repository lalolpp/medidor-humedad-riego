#include "ble_service.h"
#include "config.h"
#include "storage.h"
#include "power.h"
#include "readings_store.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

#define UUID_SERVICE "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define UUID_CHR_INTERVAL "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define UUID_CHR_AUTONOMY "6e6b9d01-1e0a-4f1e-b8e0-3f1a3f0c4a01"
#define UUID_CHR_LIVE "3c8a2d6f-5b2a-4e3a-8f6d-9c1d0e2f3a4b"
#define UUID_CHR_BATTERY "5a5b6c7d-8e9f-4a5b-8c7d-9e0f1a2b3c4d"
#define UUID_CHR_HIST_COUNT "7d7e8f90-1234-4a5b-9c8d-1e2f3a4b5c6d"
#define UUID_CHR_HIST_NEXT "8e8f9a0b-1234-4a5b-8c7d-9e0f1a2b3c4d"

static BLECharacteristic *intervalChr = nullptr;
static BLECharacteristic *autonomyChr = nullptr;
static BLECharacteristic *liveChr = nullptr;
static BLECharacteristic *batteryChr = nullptr;
static BLECharacteristic *histCountChr = nullptr;
static BLECharacteristic *histNextChr = nullptr;

static bool clientConnected = false;
static size_t histCursor = 0;
static SensorReading latest = {};
static char autonomyBuf[32];

static void updateAutonomyText() {
  Settings &s = settings();
  float level = latest.batteryLevel01 > 0.0f ? latest.batteryLevel01 : 1.0f;
  float days = autonomyDays(s.samplingIntervalMin, s.batteryCapacityMah, level);
  snprintf(autonomyBuf, sizeof(autonomyBuf), "%.0f dias", days);
  if (autonomyChr) autonomyChr->setValue(autonomyBuf);
  if (intervalChr) intervalChr->setValue(String(s.samplingIntervalMin).c_str());
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    clientConnected = true;
    histCursor = 0;
    Serial.println("[BLE] Cliente conectado");
  }
  void onDisconnect(BLEServer *server) override {
    clientConnected = false;
    server->getAdvertising()->start();
    Serial.println("[BLE] Cliente desconectado, reanunciando...");
  }
};

class IntervalCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *chr) override {
    String value = String(chr->getValue().c_str());
    uint16_t interval = (uint16_t)value.toInt();
    Serial.printf("[BLE] Intervalo configurado: %u min\n", interval);
    settingsSetInterval(interval);
    updateAutonomyText();
  }
  void onRead(BLECharacteristic *chr) override {
    chr->setValue(String(settings().samplingIntervalMin).c_str());
  }
};

class HistNextCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic *chr) override {
    static char buf[1536];
    size_t n = readingsSerializeChunk(histCursor, buf, sizeof(buf));
    if (n > 2) {
      chr->setValue((uint8_t *)buf, n);
      histCursor += HISTORY_CHUNK_RECORDS;
    } else {
      histCursor = 0;
      chr->setValue((uint8_t *)"", 0);
    }
  }
};

void bleInit() {
  BLEDevice::init(BLE_DEVICE_NAME);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(UUID_SERVICE);

  intervalChr = service->createCharacteristic(UUID_CHR_INTERVAL,
                                              BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  intervalChr->setCallbacks(new IntervalCallbacks());

  autonomyChr = service->createCharacteristic(UUID_CHR_AUTONOMY, BLECharacteristic::PROPERTY_READ);
  liveChr = service->createCharacteristic(UUID_CHR_LIVE,
                                          BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  batteryChr = service->createCharacteristic(UUID_CHR_BATTERY, BLECharacteristic::PROPERTY_READ);
  histCountChr = service->createCharacteristic(UUID_CHR_HIST_COUNT, BLECharacteristic::PROPERTY_READ);
  histNextChr = service->createCharacteristic(UUID_CHR_HIST_NEXT, BLECharacteristic::PROPERTY_READ);
  histNextChr->setCallbacks(new HistNextCallbacks());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(UUID_SERVICE);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] Anunciando como " BLE_DEVICE_NAME);

  updateAutonomyText();
}

bool bleClientConnected() {
  return clientConnected;
}

void bleProcess() {
}

void bleSetLatestReading(const SensorReading &reading) {
  latest = reading;
  char buf[128];
  float st = isnan(reading.soilTempC) ? -127.0f : reading.soilTempC;
  snprintf(buf, sizeof(buf), "{\"h\":%.1f,\"st\":%.1f,\"bV\":%.2f,\"ts\":%lu}",
           reading.humidityPercent, st, reading.batteryVoltage, (unsigned long)reading.timestampSec);
  if (liveChr) liveChr->setValue(buf);
  snprintf(buf, sizeof(buf), "%.2fV (%.0f%%)", reading.batteryVoltage, reading.batteryLevel01 * 100.0f);
  if (batteryChr) batteryChr->setValue(buf);
  snprintf(buf, sizeof(buf), "%u", (unsigned)readingsCount());
  if (histCountChr) histCountChr->setValue(buf);
  updateAutonomyText();
  if (clientConnected && liveChr) {
    liveChr->notify();
  }
}
