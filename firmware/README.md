# Firmware ESP32 — Medidor de Humedad

Firmware del nodo todo-en-uno (ESP32 + LTE + sensor capacitivo), PlatformIO con framework Arduino.

## Estructura

```
firmware/
├── platformio.ini
├── include/
│   ├── config.h          # pines, batería, energía, BLE, Firebase, válvula
│   ├── storage.h         # ajustes en NVS
│   ├── power.h           # autonomía por intervalo
│   ├── sensor.h          # lectura del sensor y batería
│   ├── readings_store.h  # historial local (LittleFS)
│   ├── cloud.h           # publicación a Firebase (HTTPS)
│   ├── valve.h           # relé de riego accionado por nube
│   └── ble_service.h     # servicio GATT para la app
└── src/
    ├── main.cpp          # ciclo: medir → guardar → publicar → ventana BLE → deep sleep
    ├── storage.cpp
    ├── power.cpp
    ├── sensor.cpp
    ├── readings_store.cpp
    ├── cloud.cpp
    ├── valve.cpp
    └── ble_service.cpp
```

## Credenciales del nodo (secrets.h)

Las credenciales de la cuenta con la que el nodo publica (`nodo@medidor.cl`)
**no van en el repo**:

1. Copiar `include/secrets.h.template` a `include/secrets.h` (ya está en `.gitignore`).
2. Rellenar con las credenciales reales. Sin el archivo, el firmware compila pero
   **no publica** en runtime (se queda sin ID token).
3. La contraseña quedó expuesta en el historial público del repo → **rotar** en
   Firebase Console (Authentication → Users → nodo@medidor.cl) y actualizar
   `secrets.h`.

Además, opcionalmente, cada `devices/{deviceId}` puede llevar el campo
`nodeAccountEmail` con el email de la cuenta del nodo (ver `docs/cloud-firebase.md`);
es recomendable pero no obligatorio con las reglas actuales.

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

## Riego automático (válvula)

La app escribe el comando `valveState` ("ON"/"OFF") en `devices/{id}/config/current`.
En cada ciclo el nodo lee ese comando y acciona el relé en `PIN_VALVE_RELAY` (GPIO 26):

- `ON` → abre la válvula; `OFF` → la cierra.
- Con `VALVE_KEEP_AWAKE=1` (por defecto) mientras la válvula esté abierta el nodo
  **no duerme**: el relé queda alimentado y cada `VALVE_RECHECK_MS` (60 s) re-lee la
  nube para detectar el apagado. Es lo correcto para un relé común (no biestable).
- Si se usa un **relé biestable** (latch), poner `VALVE_KEEP_AWAKE=0` en `config.h`:
  el nodo duerme normalmente y re-aplica el comando en cada despertar.

> **Hardware sugerido**: relé de módulo (canal con optoacoplador) alimentado a la
> misma fuente del nodo. Para no energizar el relé desde el pin del ESP32, usar un
> transistor/ULN2003 o un módulo de relé de 3.3 V activo ALTO. Confirmar en terreno
> el consumo del relé mientras riega (impacta la autonomía).


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
