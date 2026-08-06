#pragma once

#include <Arduino.h>

// Descarga y aplica un firmware .bin vía OTA. Debe llamarse con WiFi
// conectado. En caso de éxito reinicia el dispositivo.
bool performOta(const String &url);
