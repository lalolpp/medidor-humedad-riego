# Firmware ESP32 — Medidor de Humedad

Firmware del nodo todo-en-uno (ESP32 + LTE + sensor capacitivo), PlatformIO con framework Arduino.

## Estructura

```
firmware/
├── platformio.ini
├── include/
│   ├── config.h          # pines, batería, energía, BLE, Firebase
│   ├── storage.h         # ajustes en NVS
│   ├── power.h           # autonomía por intervalo
│   ├── sensor.h          # lectura del sensor y batería
│   ├── readings_store.h  # historial local (LittleFS)
│   ├── cloud.h           # publicación a Firebase (HTTPS)
│   └── ble_service.h     # servicio GATT para la app
└── src/
    ├── main.cpp          # ciclo: medir → guardar → publicar → ventana BLE → deep sleep
    ├── storage.cpp
    ├── power.cpp
    ├── sensor.cpp
    ├── readings_store.cpp
    ├── cloud.cpp
    └── ble_service.cpp
```

## Compilar y subir

```
pio run
pio run -t upload
pio device monitor
```

## Ciclo de vida del nodo

1. Despierta del deep sleep (wake por temporizador con el intervalo configurado).
2. Lee sensor de humedad y voltaje de batería.
3. Guarda la lectura en el historial local (LittleFS, archivo por día).
4. Publica a Firebase por HTTPS (WiFi o LTE) si está habilitado.
5. Abre una ventana BLE (~30 s) para que la app lea en vivo, cambie el intervalo o descargue el historial.
6. Duerme hasta el siguiente intervalo.

## Intervalo y autonomía

El intervalo se configura por BLE (o por el administrador vía nube) y persiste en NVS.
Valores permitidos: 10, 15, 20, 30 y 60 minutos. El nodo expone la autonomía estimada
de batería calculada con la fórmula de `power.cpp`:

```
ciclos/día = 1440 / intervalo_min
consumo/día = ciclos * ~2,1 mAh (por ciclo, incluye TX LTE) + ~0,7 mAh (deep sleep)
autonomía_días = batería_mAh * nivel_batería / consumo/día
```

Ver `docs/power-budget.md` para la tabla completa por intervalo.

## Pendientes de calibración

- **Sensor SEN0193**: la conversión ADC → % de humedad es lineal e invertida por defecto.
  Calibrar en terreno con suelo seco y saturado y ajustar `sensor.cpp`.
- **Divisor de batería**: confirmar las resistencias reales del divisor y ajustar
  `BATTERY_DIVIDER_GAIN` en `config.h`.
- **LTE**: el módulo A7670E aún no está integrado (ver `cloud.cpp`); la publicación usa WiFi.
