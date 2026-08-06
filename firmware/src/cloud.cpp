#include "cloud.h"
#include "config.h"
#include "storage.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <string.h>

static WiFiClientSecure client;
static bool connected = false;

static String cachedToken;
static unsigned long tokenExpiresAt = 0;

static bool fetchToken() {
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") +
               FIREBASE_API_KEY;
  String body = String("{\"email\":\"") + FIREBASE_AUTH_EMAIL +
                "\",\"password\":\"" + FIREBASE_AUTH_PASSWORD +
                "\",\"returnSecureToken\":true}";

  client.setInsecure();
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);
  String resp = http.getString();
  http.end();

  if (code != 200) return false;
  const char *marker = "\"idToken\":\"";
  int start = resp.indexOf(marker);
  if (start < 0) return false;
  start += strlen(marker);
  int end = resp.indexOf('"', start);
  if (end < 0) return false;
  cachedToken = resp.substring(start, end);
  tokenExpiresAt = millis() + 3300000UL;  // tokens válidos ~1 h; renovar a los 55 min
  return !cachedToken.isEmpty();
}

static String idToken() {
  if (cachedToken.isEmpty() || millis() >= tokenExpiresAt) {
    if (!fetchToken()) return "";
  }
  return cachedToken;
}

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

  String token = idToken();
  if (token.isEmpty()) return false;

  String url = String("https://") + FIREBASE_HOST + "/devices/" + settings().deviceId +
               "/readings.json?auth=" + token;
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
