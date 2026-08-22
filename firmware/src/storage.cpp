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
  prefs.getString("wifiSsid", s.wifiSsid, sizeof(s.wifiSsid));
  prefs.getString("wifiPass", s.wifiPass, sizeof(s.wifiPass));
  prefs.getString("deviceId", s.deviceId, sizeof(s.deviceId));
  s.updatedAtSec = prefs.getUInt("updatedAt", 0);
  s.lastSyncedTs = prefs.getUInt("lastSyncedTs", 0);
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
  prefs.putString("wifiSsid", s.wifiSsid);
  prefs.putString("wifiPass", s.wifiPass);
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

// Guarda las credenciales WiFi recibidas por BLE. Devuelve false si no caben
// en los buffers (SSID máx. 32, contraseña máx. 64 caracteres).
bool settingsSetWifi(const char *ssid, const char *pass) {
  if (!ssid || ssid[0] == '\0') return false;
  if (strlen(ssid) >= sizeof(s.wifiSsid)) return false;
  if (pass && strlen(pass) >= sizeof(s.wifiPass)) return false;
  memset(s.wifiSsid, 0, sizeof(s.wifiSsid));
  memset(s.wifiPass, 0, sizeof(s.wifiPass));
  strncpy(s.wifiSsid, ssid, sizeof(s.wifiSsid) - 1);
  if (pass) strncpy(s.wifiPass, pass, sizeof(s.wifiPass) - 1);
  settingsSave();
  Serial.printf("[WIFI] Credenciales guardadas para \"%s\"\n", s.wifiSsid);
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

void settingsSetLastSyncedTs(uint32_t ts) {
  s.lastSyncedTs = ts;
  prefs.begin("settings", false);
  prefs.putUInt("lastSyncedTs", ts);
  prefs.end();
}
