#pragma once

#include <Arduino.h>
#include <Preferences.h>

struct Settings {
  uint16_t samplingIntervalMin;
  uint16_t batteryCapacityMah;
  bool cloudEnabled;
  char deviceId[24];
  uint32_t updatedAtSec;
  uint32_t lastSyncedTs;  // ts de la última lectura confirmada en la nube (backfill)
};

// Resultado de guardar una red WiFi.
enum class WifiAddResult { Ok, Full, Invalid };

Settings &settings();

void settingsLoad();
void settingsSave();
bool settingsSetInterval(uint16_t intervalMin);
bool settingsSetDeviceId(const char *id);
void settingsSetLastSyncedTs(uint32_t ts);

// --- Multi-WiFi (hasta MAX_WIFI_NETWORKS redes recordadas en NVS) ---
int wifiCount();
bool wifiGet(int idx, char *ssid, size_t ssidCap, char *pass, size_t passCap);
WifiAddResult wifiAdd(const char *ssid, const char *pass);
bool wifiRemove(const char *ssid);
