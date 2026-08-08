#include "readings_store.h"
#include "config.h"
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <algorithm>
#include <vector>

static bool ready = false;

static String todayFile() {
  time_t t = time(nullptr);
  struct tm tm;
  localtime_r(&t, &tm);
  char name[40];
  snprintf(name, sizeof(name), "%s/h-%04d%02d%02d.jsonl",
           HISTORY_DIR, tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
  return String(name);
}

static void trimOldFiles() {
  File dir = LittleFS.open(HISTORY_DIR);
  if (!dir) return;
  std::vector<String> files;
  File f = dir.openNextFile();
  while (f) {
    if (!f.isDirectory()) files.push_back(String(f.name()));
    f.close();
    f = dir.openNextFile();
  }
  dir.close();
  std::sort(files.begin(), files.end());
  while ((int)files.size() > HISTORY_MAX_FILES) {
    LittleFS.remove(files[0]);
    files.erase(files.begin());
  }
}

void readingsInit() {
  if (!LittleFS.begin(true)) return;
  if (!LittleFS.exists(HISTORY_DIR)) LittleFS.mkdir(HISTORY_DIR);
  ready = true;
}

void readingsAppend(const SensorReading &r, uint16_t intervalMin) {
  if (!ready) return;
  File file = LittleFS.open(todayFile(), "a");
  if (!file) return;
  float st = isnan(r.soilTempC) ? -127.0f : r.soilTempC;
  file.printf("{\"t\":%lu,\"h\":%.1f,\"st\":%.1f,\"bV\":%.2f,\"bL\":%.2f,\"rssi\":%d,\"int\":%u}\n",
              (unsigned long)r.timestampSec, r.humidityPercent, st,
              r.batteryVoltage, r.batteryLevel01, r.rssi, intervalMin);
  file.close();
  trimOldFiles();
}

size_t readingsCount() {
  if (!ready) return 0;
  size_t n = 0;
  File dir = LittleFS.open(HISTORY_DIR);
  if (!dir) return 0;
  File f = dir.openNextFile();
  while (f) {
    if (!f.isDirectory()) {
      while (f.available()) {
        if (f.read() == '\n') n++;
      }
    }
    f.close();
    f = dir.openNextFile();
  }
  dir.close();
  return n;
}

size_t readingsSerializeChunk(size_t start, char *buffer, size_t bufferLen) {
  if (!ready || bufferLen < 4) return 0;
  buffer[0] = '[';
  size_t written = 1;
  size_t idx = 0;
  size_t emitted = 0;
  File dir = LittleFS.open(HISTORY_DIR);
  if (!dir) return 0;
  File f = dir.openNextFile();
  while (f && emitted < HISTORY_CHUNK_RECORDS) {
    if (!f.isDirectory()) {
      String line;
      while (f.available() && emitted < HISTORY_CHUNK_RECORDS) {
        char c = (char)f.read();
        if (c == '\n') {
          if (idx >= start) {
            if (written + line.length() + 3 < bufferLen) {
              if (emitted > 0) buffer[written++] = ',';
              memcpy(buffer + written, line.c_str(), line.length());
              written += line.length();
              emitted++;
            }
          }
          idx++;
          line = "";
        } else {
          line += c;
        }
      }
    }
    f.close();
    f = dir.openNextFile();
  }
  dir.close();
  buffer[written++] = ']';
  buffer[written] = '\0';
  return written;
}

size_t readingsVisitRange(uint32_t lowerTs, uint32_t upperTs,
                          const std::function<bool(const StoredReading &)> &cb) {
  if (!ready || !cb) return 0;
  size_t visited = 0;

  std::vector<String> files;
  File dir = LittleFS.open(HISTORY_DIR);
  if (!dir) return 0;
  File f = dir.openNextFile();
  while (f) {
    if (!f.isDirectory()) files.push_back(String(f.name()));
    f.close();
    f = dir.openNextFile();
  }
  dir.close();
  std::sort(files.begin(), files.end());

  for (const String &name : files) {
    File file = LittleFS.open(name, "r");
    if (!file) continue;
    String line;
    while (file.available()) {
      char c = (char)file.read();
      if (c == '\n') {
        if (line.length() > 4) {
          JsonDocument doc;
          if (!deserializeJson(doc, line)) {
            StoredReading sr;
            sr.r.timestampSec = doc["t"].as<uint32_t>();
            sr.r.humidityPercent = doc["h"].as<float>();
            sr.r.soilTempC = doc["st"].as<float>();
            sr.r.batteryVoltage = doc["bV"].as<float>();
            sr.r.batteryLevel01 = doc["bL"].as<float>();
            sr.r.rssi = doc["rssi"].as<int32_t>();
            sr.intervalMin = (uint16_t)doc["int"].as<uint32_t>();
            if (sr.r.timestampSec > lowerTs && sr.r.timestampSec < upperTs) {
              visited++;
              if (!cb(sr)) {
                file.close();
                return visited;
              }
            }
          }
        }
        line = "";
      } else {
        line += c;
      }
    }
    file.close();
  }
  return visited;
}
