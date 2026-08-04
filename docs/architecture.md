# Arquitectura del sistema

## Topología

Cada nodo de campo es un dispositivo **todo-en-uno**: ESP32 (WiFi + BLE) + módulo LTE con SIM propia + sensor de humedad capacitivo.

```
[ Nodo de campo ]
  ESP32 + LTE + Sensor de humedad
     |
     |--- WiFi/LTE (cada 30 min) ---> [ Firebase ]
     |                                     |
     |--- BLE (app cercana)                |--- API/Dashboard
     |                                     |
  [ App móvil ] <---------- nube --------->|   [ Panel admin ]
```

## Flujo de datos

El sensor de humedad está conectado **físicamente** al ESP32 (lectura analógica). El celular nunca lee el sensor directamente; lo hace a través del nodo.

### Camino 1 — Nube (automático, cada 30 min)

1. El ESP32 despierta del deep sleep y lee el sensor.
2. Guarda la lectura en memoria local (historial/respaldo).
3. Publica la lectura en Firebase vía WiFi o LTE.
4. Vuelve a dormir.

### Camino 2 — BLE (local, cuando hay app cerca)

1. La app se empareja con el nodo por BLE.
2. Muestra la humedad **en tiempo real** (el nodo lee el sensor al momento).
3. Permite descargar el **historial local** (datos acumulados sin red).
4. Permite configurar el dispositivo y hacer diagnóstico.

## Roles

- **Usuario final**: ve sus dispositivos, datos en tiempo real, históricos, alertas de riego y descarga de datos (BLE y nube).
- **Administrador**: ve todos los usuarios y dispositivos, provisiona equipos, gestiona cuentas, monitoreo global y estado de salud de cada nodo (batería, señal LTE).

## Intervalo de muestreo configurable

El nodo no lee ni registra siempre cada 30 min: el intervalo es **configurable por dispositivo**.

- Opciones: **10, 15, 20, 30 y 60 minutos** (configurables vía BLE con la app, o por el administrador).
- El intervalo se guarda en **NVS** del ESP32 (persiste ante cortes de energía y resets) y se replica en la nube (`devices/{deviceId}.settings.sampling_interval_min`).
- El deep sleep del nodo usa el intervalo configurado como wake por temporizador.

### Aviso de autonomía al cambiar el intervalo

Cada cambio de intervalo debe mostrar al usuario la **autonomía aproximada de la batería**
según la configuración (ver `power-budget.md`), para que sepa que lecturas más frecuentes
significan más consumo y por lo tanto **más revisión/mantenimiento de la batería**:

- Al seleccionar el intervalo, la app calcula y muestra: *"10 min → ~9–10 días de batería sin sol"*.
- Si la autonomía estimada baja de un umbral (p. ej. 15 días), se muestra un aviso
  destacado y la app solicita confirmación antes de aplicar el cambio.
- El nodo reporta el voltaje real de batería como telemetría; la app puede recalcular
  la autonomía real en vez de usar solo el valor teórico.

## Almacenamiento local del nodo

Respaldo de lecturas en Flash/SD del ESP32. Si el campo no tiene red, el nodo acumula datos y los sube (o se entregan por BLE) cuando haya cobertura.
