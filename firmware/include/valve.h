#pragma once

#include <Arduino.h>

// Inicializa el pin del relé de riego (salida LOW / relé abierto).
void valveInit();
// Abre (true) o cierra (false) la válvula accionando el relé.
void valveSet(bool on);
// Estado actual del relé (válvula abierta = true).
bool valveActive();
