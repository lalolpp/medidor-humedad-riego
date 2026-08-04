# Presupuesto de energía

Configuración: batería 18650 + panel solar 6V/2W + carga TP4056 + step-up.

## Consumo por ciclo (cada 30 min)

Ciclo: ~20 s activo (medir + BLE + MQTT) + ~10 s de TX LTE.

| Concepto | Consumo |
|---|---|
| Consumo por ciclo | ~1,7 mAh |
| 48 ciclos/día | ~80 mAh |
| Deep sleep (23,4 h/día a ~30 µA) | ~0,7 mAh |
| **Total por día** | **~85–100 mAh** |

## Autonomía

- Batería 18650 de 2.500 mAh → **~25 días de autonomía sin sol**.
- Panel solar de 2W en campo → recarga de sobra; soporta semanas nubladas.

## Recomendaciones

- Usar deep sleep del ESP32 con wake por temporizador cada 30 min.
- Mantener apagado el módulo LTE la mayor parte del tiempo y encenderlo solo para transmitir.
- Monitorear el voltaje de batería y reportarlo como telemetría (estado de salud del nodo).
