#include "storage.h"
#include "config.h"
#include "power.h"

static Preferences prefs;
static Settings s;

Settings &settings() {
  return s;
}

void settingsLoad() {
  prefs.begin("settings", false);
  s.samplingIntervalMin = prefs.getUShort("intervalMin", DEFAULT_INTERVAL_MIN);
  s.batteryCapacityMah = prefs.getUShort("batteryMah", DEFAULT_BATTERY_CAPACITY_MAH);
  s.cloudEnabled = prefs.getBool("cloudEnabled", true);
  prefs.getString("deviceId", s.deviceId, sizeof(s.deviceId));
  s.updatedAtSec = prefs.getUInt("updatedAt", 0);
  s.lastSyncedTs = prefs.getUInt("lastSyncedTs", 0);

  // Migración: credenciales planas del firmware antiguo -> slot multi-WiFi.
  if (!prefs.isKey("wN") && prefs.isKey("wifiSsid")) {
    char ssid[33] = {0}, pass[65] = {0};
    prefs.getString("wifiSsid", ssid, sizeof(ssid));
    prefs.getString("wifiPass", pass, sizeof(pass));
    if (ssid[0] != '\0') {
      prefs.putUChar("wN", 1);
      prefs.putString("w0s", ssid);
      prefs.putString("w0p", pass);
      Serial.printf("[WIFI] migrada red '%s' al almacenamiento multi-WiFi\n", ssid);
    }
    prefs.remove("wifiSsid");
    prefs.remove("wifiPass");
  }
  prefs.end();

  if (s.deviceId[0] == '\0') {
    strncpy(s.deviceId, DEFAULT_DEVICE_ID, sizeof(s.deviceId) - 1);
  }
}

void settingsSave() {
  prefs.begin("settings", false);
  prefs.putUShort("intervalMin", s.samplingIntervalMin);
  prefs.putUShort("batteryMah", s.batteryCapacityMah);
  prefs.putBool("cloudEnabled", s.cloudEnabled);
  prefs.putString("deviceId", s.deviceId);
  s.updatedAtSec = (uint32_t)time(nullptr);
  prefs.putUInt("updatedAt", s.updatedAtSec);
  prefs.end();
}

bool settingsSetInterval(uint16_t intervalMin) {
  if (!isValidInterval(intervalMin)) return false;
  s.samplingIntervalMin = intervalMin;
  settingsSave();
  return true;
}

// Guarda el ID con el que el nodo se identifica en la nube (devices/{id}).
bool settingsSetDeviceId(const char *id) {
  if (!id || id[0] == '\0') return false;
  if (strlen(id) >= sizeof(s.deviceId)) return false;
  memset(s.deviceId, 0, sizeof(s.deviceId));
  strncpy(s.deviceId, id, sizeof(s.deviceId) - 1);
  settingsSave();
  Serial.printf("[NVS] deviceId = \"%s\"\n", s.deviceId);
  return true;
}

// --- Multi-WiFi -----------------------------------------------------------

static void wifiSlotKeys(int idx, char *ks, size_t ksCap, char *kp, size_t kpCap) {
  snprintf(ks, ksCap, "w%ds", idx);
  snprintf(kp, kpCap, "w%dp", idx);
}

int wifiCount() {
  prefs.begin("settings", true);
  uint8_t n = prefs.getUChar("wN", 0);
  prefs.end();
  return n;
}

bool wifiGet(int idx, char *ssid, size_t ssidCap, char *pass, size_t passCap) {
  if (idx < 0 || idx >= MAX_WIFI_NETWORKS) return false;
  prefs.begin("settings", true);
  char ks[8], kp[8];
  wifiSlotKeys(idx, ks, sizeof(ks), kp, sizeof(kp));
  bool ok = prefs.isKey(ks);
  if (ok && ssid != nullptr) prefs.getString(ks, ssid, ssidCap);
  if (ok && pass != nullptr) prefs.getString(kp, pass, passCap);
  prefs.end();
  return ok;
}

WifiAddResult wifiAdd(const char *ssid, const char *pass) {
  if (!ssid || ssid[0] == '\0' || strlen(ssid) >= 33) return WifiAddResult::Invalid;
  if (pass && strlen(pass) >= 65) return WifiAddResult::Invalid;

  prefs.begin("settings", false);
  uint8_t n = prefs.getUChar("wN", 0);

  // Si la red ya está guardada, solo actualiza su contraseña.
  for (uint8_t i = 0; i < n; i++) {
    char ks[8], kp[8], cur[33] = {0};
    wifiSlotKeys(i, ks, sizeof(ks), kp, sizeof(kp));
    prefs.getString(ks, cur, sizeof(cur));
    if (strcmp(cur, ssid) == 0) {
      prefs.putString(kp, pass ? pass : "");
      prefs.end();
      Serial.printf("[WIFI] contraseña actualizada para '%s'\n", ssid);
      return WifiAddResult::Ok;
    }
  }

  if (n >= MAX_WIFI_NETWORKS) {
    prefs.end();
    Serial.println("[WIFI] memoria llena (5 redes); elimina una primero");
    return WifiAddResult::Full;
  }

  char ks[8], kp[8];
  wifiSlotKeys(n, ks, sizeof(ks), kp, sizeof(kp));
  prefs.putString(ks, ssid);
  prefs.putString(kp, pass ? pass : "");
  prefs.putUChar("wN", static_cast<uint8_t>(n + 1));
  prefs.end();
  Serial.printf("[WIFI] red agregada '%s' (%d/%d)\n", ssid, n + 1, MAX_WIFI_NETWORKS);
  return WifiAddResult::Ok;
}

bool wifiRemove(const char *ssid) {
  if (!ssid || ssid[0] == '\0') return false;
  prefs.begin("settings", false);
  uint8_t n = prefs.getUChar("wN", 0);

  int found = -1;
  for (uint8_t i = 0; i < n; i++) {
    char ks[8], cur[33] = {0};
    char kpTmp[8];
    wifiSlotKeys(i, ks, sizeof(ks), kpTmp, sizeof(kpTmp));
    prefs.getString(ks, cur, sizeof(cur));
    if (strcmp(cur, ssid) == 0) {
      found = i;
      break;
    }
  }
  if (found < 0) {
    prefs.end();
    return false;
  }

  // Compacta: mueve los slots siguientes hacia arriba.
  for (int i = found; i < n - 1; i++) {
    char srcS[8], srcP[8], dstS[8], dstP[8];
    char ssidBuf[33] = {0}, passBuf[65] = {0};
    wifiSlotKeys(i + 1, srcS, sizeof(srcS), srcP, sizeof(srcP));
    wifiSlotKeys(i, dstS, sizeof(dstS), dstP, sizeof(dstP));
    prefs.getString(srcS, ssidBuf, sizeof(ssidBuf));
    prefs.getString(srcP, passBuf, sizeof(passBuf));
    prefs.putString(dstS, ssidBuf);
    prefs.putString(dstP, passBuf);
  }
  char lastS[8], lastP[8];
  wifiSlotKeys(n - 1, lastS, sizeof(lastS), lastP, sizeof(lastP));
  prefs.remove(lastS);
  prefs.remove(lastP);
  prefs.putUChar("wN", static_cast<uint8_t>(n - 1));
  prefs.end();
  Serial.printf("[WIFI] red eliminada '%s' (%d restantes)\n", ssid, n - 1);
  return true;
}

void settingsSetLastSyncedTs(uint32_t ts) {
  s.lastSyncedTs = ts;
  prefs.begin("settings", false);
  prefs.putUInt("lastSyncedTs", ts);
  prefs.end();
}
