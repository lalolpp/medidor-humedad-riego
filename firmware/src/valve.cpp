#include "valve.h"
#include "config.h"

static bool active = false;

void valveInit() {
  pinMode(PIN_VALVE_RELAY, OUTPUT);
  digitalWrite(PIN_VALVE_RELAY, LOW);
  active = false;
  Serial.println("[VALVE] relé inicializado (OFF)");
}

void valveSet(bool on) {
  if (on == active) return;
  active = on;
  digitalWrite(PIN_VALVE_RELAY, on ? HIGH : LOW);
  Serial.printf("[VALVE] %s\n", on ? "ON (riego)" : "OFF");
}

bool valveActive() {
  return active;
}
