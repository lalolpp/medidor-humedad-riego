# Presupuesto de energía

Configuración: batería 18650 + panel solar 6V/2W + carga TP4056 + step-up.

## Consumo por ciclo

Ciclo: ~20 s activo (medir + BLE + MQTT) + ~10 s de TX LTE.

| Concepto | Consumo |
|---|---|
| Consumo por ciclo | ~1,7–2,1 mAh |
| Deep sleep (a ~30 µA) | ~0,7 mAh/día |

El total diario depende directamente del **intervalo de muestreo configurado** (ver tabla abajo).

## Intervalo de muestreo configurable y autonomía

El intervalo de lectura/registro es configurable por dispositivo (vía app BLE o admin).
Cada cambio de intervalo debe mostrar al usuario la **autonomía aproximada de la batería**,
para que entienda el impacto de elegir lecturas más frecuentes.

Valores de referencia con batería 18650 **sin sol**:

| Intervalo | Ciclos/día | Consumo/día | Autonomía (2.500 mAh) | Autonomía (3.000 mAh) |
|---|---|---|---|---|
| 10 min | 144 | ~240–290 mAh | **~9–10 días** | ~10–12 días |
| 15 min | 96 | ~160–195 mAh | ~13–15 días | ~15–18 días |
| 20 min | 72 | ~120–145 mAh | ~17–20 días | ~21–25 días |
| 30 min | 48 | ~85–100 mAh | **~25–29 días** | ~30–35 días |
| 60 min | 24 | ~42–50 mAh | ~50–59 días | ~60–71 días |

Regla de oro: **duplicar la frecuencia ≈ duplicar el consumo**. Cada ciclo activo
cuesta ~2 mAh de batería.

## Autonomía

- Batería 18650 de 2.500 mAh → **~9 a ~60 días** según el intervalo elegido (sin sol).
- Panel solar de 2W en campo → recarga de sobra; soporta semanas nubladas en intervalos de 30 min o más.
- Con intervalos cortos (10 min), el solar es importante: si falla, la batería dura ~10 días.

## Recomendaciones

- Usar deep sleep del ESP32 con wake por temporizador según el intervalo configurado.
- Mantener apagado el módulo LTE la mayor parte del tiempo y encenderlo solo para transmitir.
- Monitorear el voltaje de batería y reportarlo como telemetría (estado de salud del nodo).
- En la app, al cambiar el intervalo, mostrar la autonomía estimada y un aviso cuando baje de un umbral (p. ej. < 15 días).
