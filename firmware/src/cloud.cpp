#include "cloud.h"
#include "config.h"
#include "storage.h"
#include "readings_store.h"
#include <WiFi.h>
#include <vector>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <string.h>

static WiFiClientSecure client;
static bool connected = false;

static String cachedToken;
static unsigned long tokenExpiresAt = 0;

static String firestoreBase() {
  return String("https://firestore.googleapis.com/v1/projects/medidor-de-humedad") +
         "/databases/(default)/documents";
}

static String isoUtcNow() {
  time_t t = time(nullptr);
  struct tm tm;
  gmtime_r(&t, &tm);
  char buf[32];
  snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d:%02dZ",
           tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
  return String(buf);
}

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
  JsonDocument doc;
  if (deserializeJson(doc, resp)) return false;
  cachedToken = doc["idToken"] | "";
  tokenExpiresAt = millis() + 3300000UL;  // tokens válidos ~1 h; renovar a los 55 min
  return !cachedToken.isEmpty();
}

static String idToken() {
  if (cachedToken.isEmpty() || millis() >= tokenExpiresAt) {
    if (!fetchToken()) return "";
  }
  return cachedToken;
}

static bool tryConnect(const char *ssid, const char *pass, unsigned long timeoutMs) {
  Serial.printf("[NET] conectando a '%s'…\n", ssid);
  WiFi.disconnect();
  WiFi.begin(ssid, pass);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(100);
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[NET] WiFi OK (%s) IP=%s RSSI=%d\n", ssid,
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
    return true;
  }
  Serial.printf("[NET] WiFi FAIL '%s' (status=%d)\n", ssid, WiFi.status());
  return false;
}

// Multi-WiFi: escanea el entorno, elige la red conocida con mejor señal y
// conecta. Si el escaneo no encuentra ninguna, intenta una por una.
static bool connectWiFi() {
  const int n = wifiCount();
  if (n == 0) {
    Serial.println("[NET] sin redes WiFi guardadas");
    return false;
  }
  WiFi.mode(WIFI_STA);

  int bestIdx = -1;
  int bestRssi = -127;
  Serial.println("[NET] escaneando redes conocidas…");
  const int found = WiFi.scanNetworks();
  for (int f = 0; f < found; f++) {
    String seen = WiFi.SSID(f);
    for (int i = 0; i < n; i++) {
      char ssid[33], pass[65];
      if (!wifiGet(i, ssid, sizeof(ssid), pass, sizeof(pass))) continue;
      if (seen == ssid && (int)WiFi.RSSI(f) > bestRssi) {
        bestRssi = (int)WiFi.RSSI(f);
        bestIdx = i;
      }
    }
  }
  WiFi.scanDelete();

  char ssid[33] = {0}, pass[65] = {0};
  if (bestIdx >= 0 && wifiGet(bestIdx, ssid, sizeof(ssid), pass, sizeof(pass))) {
    if (tryConnect(ssid, pass, 12000)) return true;
    Serial.println("[NET] falló la red con mejor señal; probando las demás…");
  }

  for (int i = 0; i < n; i++) {
    if (i == bestIdx) continue;
    if (!wifiGet(i, ssid, sizeof(ssid), pass, sizeof(pass))) continue;
    if (tryConnect(ssid, pass, 8000)) return true;
  }

  Serial.println("[NET] sin conexión a ninguna red conocida");
  return false;
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

static bool postReading(const String &token, const SensorReading &r,
                        uint16_t intervalMin, float daysNoSun) {
  String url = firestoreBase() + "/devices/" + settings().deviceId + "/readings";
  JsonDocument doc;
  JsonObject f = doc["fields"].to<JsonObject>();
  f["humidity"]["doubleValue"] = r.humidityPercent;
  f["soilTemp"]["doubleValue"] = isnan(r.soilTempC) ? -127.0 : r.soilTempC;
  f["batteryV"]["doubleValue"] = r.batteryVoltage;
  f["batteryLevel"]["doubleValue"] = r.batteryLevel01;
  f["rssi"]["integerValue"] = String(r.rssi);
  f["intervalMin"]["integerValue"] = String(intervalMin);
  f["autonomyDays"]["doubleValue"] = daysNoSun;
  f["ts"]["integerValue"] = String((long)r.timestampSec);

  String payload;
  serializeJson(doc, payload);

  client.setInsecure();
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.addHeader("Authorization", String("Bearer ") + token);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(payload);
  http.end();
  return code >= 200 && code < 300;
}

static bool updateDeviceMeta(const String &token, const SensorReading &r,
                             uint16_t intervalMin, float daysNoSun) {
  String url = firestoreBase() + "/devices/" + settings().deviceId;
  url += "?updateMask.fieldPaths=humidity&updateMask.fieldPaths=soilTemp";
  url += "&updateMask.fieldPaths=batteryLevel&updateMask.fieldPaths=rssi";
  url += "&updateMask.fieldPaths=intervalMin&updateMask.fieldPaths=autonomyDays";
  url += "&updateMask.fieldPaths=lastReportAt";

  JsonDocument doc;
  JsonObject f = doc["fields"].to<JsonObject>();
  f["humidity"]["doubleValue"] = r.humidityPercent;
  f["soilTemp"]["doubleValue"] = isnan(r.soilTempC) ? -127.0 : r.soilTempC;
  f["batteryLevel"]["doubleValue"] = r.batteryLevel01;
  f["rssi"]["integerValue"] = String(r.rssi);
  f["intervalMin"]["integerValue"] = String(intervalMin);
  f["autonomyDays"]["doubleValue"] = daysNoSun;
  f["lastReportAt"]["stringValue"] = isoUtcNow();

  String payload;
  serializeJson(doc, payload);

  client.setInsecure();
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.addHeader("Authorization", String("Bearer ") + token);
  http.addHeader("Content-Type", "application/json");
  int code = http.sendRequest("PATCH", (uint8_t *)payload.c_str(), payload.length());
  http.end();
  return code >= 200 && code < 300;
}

bool cloudPublish(const SensorReading &r, uint16_t intervalMin, float daysNoSun) {
  if (!connected && !cloudLogin()) return false;

  String token = idToken();
  if (token.isEmpty()) return false;

  return postReading(token, r, intervalMin, daysNoSun) &&
         updateDeviceMeta(token, r, intervalMin, daysNoSun);
}

// Descarga devices/{id}/config/current y lo deserializa en `doc`.
// Devuelve false si no hay red, error HTTP o JSON inválido.
static bool fetchConfigDoc(JsonDocument &doc) {
  if (!connected && !cloudLogin()) return false;

  String token = idToken();
  if (token.isEmpty()) return false;

  String url = firestoreBase() + "/devices/" + settings().deviceId +
               "/config/current";
  client.setInsecure();
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.addHeader("Authorization", String("Bearer ") + token);
  int code = http.GET();
  String resp = http.getString();
  http.end();
  if (code != 200) return false;

  return !deserializeJson(doc, resp);
}

uint16_t cloudFetchInterval(uint16_t fallback) {
  JsonDocument doc;
  if (!fetchConfigDoc(doc)) return fallback;

  const char *s = doc["fields"]["intervalMin"]["integerValue"] | "";
  if (s[0] == '\0') return fallback;
  uint16_t v = (uint16_t)strtoul(s, nullptr, 10);
  return v > 0 ? v : fallback;
}

bool cloudFetchOta(String &url, String &version) {
  JsonDocument doc;
  if (!fetchConfigDoc(doc)) return false;

  url = doc["fields"]["otaUrl"]["stringValue"] | "";
  version = doc["fields"]["otaVersion"]["stringValue"] | "";
  return !url.isEmpty();
}

bool cloudFetchValve(String &state) {
  JsonDocument doc;
  if (!fetchConfigDoc(doc)) return false;

  state = doc["fields"]["valveState"]["stringValue"] | "";
  return !state.isEmpty();
}

// Envía un lote de lecturas como un commit atómico de Firestore. Cada lectura
// va a `readings/r{ts}` (sobrescribe), por lo que reenviar es idempotente.
static bool commitReadings(const String &token,
                           const std::vector<StoredReading> &batch) {
  String url = firestoreBase() + ":commit";
  JsonDocument doc;
  JsonArray writes = doc["writes"].to<JsonArray>();
  for (const auto &sr : batch) {
    char name[96];
    snprintf(name, sizeof(name),
             "projects/medidor-de-humedad/databases/(default)/documents/"
             "devices/%s/readings/r%lu",
             settings().deviceId, (unsigned long)sr.r.timestampSec);
    JsonObject update = writes.add<JsonObject>();
    update["name"] = name;
    JsonObject f = update["fields"].to<JsonObject>();
    f["humidity"]["doubleValue"] = sr.r.humidityPercent;
    f["soilTemp"]["doubleValue"] = isnan(sr.r.soilTempC) ? -127.0 : sr.r.soilTempC;
    f["batteryV"]["doubleValue"] = sr.r.batteryVoltage;
    f["batteryLevel"]["doubleValue"] = sr.r.batteryLevel01;
    f["rssi"]["integerValue"] = String(sr.r.rssi);
    f["intervalMin"]["integerValue"] = String(sr.intervalMin);
    f["ts"]["integerValue"] = String((long)sr.r.timestampSec);
  }

  String payload;
  serializeJson(doc, payload);

  client.setInsecure();
  HTTPClient http;
  if (!http.begin(client, url)) return false;
  http.addHeader("Authorization", String("Bearer ") + token);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(payload);
  http.end();
  return code >= 200 && code < 300;
}

bool cloudBackfill(uint32_t currentTs) {
  if (!connected && !cloudLogin()) return false;

  // Transición desde firmware sin backfill: asumimos que el historial previo
  // ya fue publicado y no se reenvía (evita duplicar lecturas ya subidas).
  if (settings().lastSyncedTs == 0) {
    settingsSetLastSyncedTs(currentTs);
    return true;
  }

  String token = idToken();
  if (token.isEmpty()) return false;

  unsigned long deadline = millis() + BACKFILL_BUDGET_MS;
  std::vector<StoredReading> batch;
  batch.reserve(BACKFILL_BATCH_SIZE);

  while (millis() < deadline) {
    batch.clear();
    readingsVisitRange(
        settings().lastSyncedTs, currentTs,
        [&batch](const StoredReading &sr) -> bool {
          if (batch.size() < BACKFILL_BATCH_SIZE) batch.push_back(sr);
          return batch.size() < BACKFILL_BATCH_SIZE;
        });

    if (batch.empty()) break;

    if (!commitReadings(token, batch)) return false;

    uint32_t last = 0;
    for (const auto &sr : batch) {
      if (sr.r.timestampSec > last) last = sr.r.timestampSec;
    }
    settingsSetLastSyncedTs(last);
  }
  return true;
}
