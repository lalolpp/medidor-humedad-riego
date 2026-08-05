#include "cloud.h"
#include "config.h"
#include "storage.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

static WiFiClientSecure client;
static bool connected = false;

static bool connectWiFi() {
  Settings &s = settings();
  if (s.wifiSsid[0] == '\0') return false;
  WiFi.mode(WIFI_STA);
  WiFi.begin(s.wifiSsid, s.wifiPass);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(100);
  }
  return WiFi.status() == WL_CONNECTED;
}

bool cloudLogin() {
  connected = connectWiFi();
  if (connected) {
    configTime(0, 0, "pool.ntp.org");
  }
  return connected;
}

void cloudDisconnect() {
  connected = false;
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
}

bool cloudPublish(const SensorReading &r, uint16_t intervalMin, float daysNoSun) {
  if (!connected && !cloudLogin()) return false;

  String url = String("https://") + FIREBASE_HOST + "/devices/" + settings().deviceId +
               "/readings.json?auth=" + FIREBASE_AUTH_TOKEN;
  String payload = String("{\"humidity\":") + String(r.humidityPercent, 1) +
                   ",\"batteryV\":" + String(r.batteryVoltage, 2) +
                   ",\"batteryLevel\":" + String(r.batteryLevel01, 2) +
                   ",\"rssi\":" + r.rssi +
                   ",\"intervalMin\":" + intervalMin +
                   ",\"autonomyDays\":" + String(daysNoSun, 1) +
                   ",\"ts\":" + (long)r.timestampSec + "}";

  client.setInsecure();
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(payload);
  http.end();
  return code >= 200 && code < 300;
}
