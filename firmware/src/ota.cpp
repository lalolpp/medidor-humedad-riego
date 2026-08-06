#include "ota.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <Update.h>

bool performOta(const String &url) {
  HTTPClient http;
  http.setTimeout(30000);
  if (!http.begin(url)) {
    Serial.println(F("[OTA] no se pudo abrir la URL"));
    return false;
  }

  int code = http.GET();
  if (code != HTTP_CODE_OK) {
    Serial.printf("[OTA] HTTP %d\n", code);
    http.end();
    return false;
  }

  int len = http.getSize();
  if (len <= 0) {
    Serial.println(F("[OTA] tamaño desconocido"));
    http.end();
    return false;
  }

  Serial.printf("[OTA] descargando %d bytes...\n", len);
  bool ok = Update.begin(len);
  if (ok) {
    size_t written = Update.writeStream(http.getStream());
    ok = (written == (size_t)len) && Update.end();
    Serial.printf("[OTA] escritos %u bytes, ok=%d\n", written, ok);
  } else {
    Serial.printf("[OTA] Update.begin falló (error %d)\n", Update.getError());
  }
  http.end();

  if (ok) {
    Serial.println(F("[OTA] reiniciando..."));
    ESP.restart();
    return true;
  }
  Serial.printf("[OTA] error %d\n", Update.getError());
  return false;
}
