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

void settingsSetLastSyncedTs(uint32_t ts) {
  s.lastSyncedTs = ts;
  prefs.begin("settings", false);
  prefs.putUInt("lastSyncedTs", ts);
  prefs.end();
}
