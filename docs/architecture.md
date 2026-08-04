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

## Almacenamiento local del nodo

Respaldo de lecturas en Flash/SD del ESP32. Si el campo no tiene red, el nodo acumula datos y los sube (o se entregan por BLE) cuando haya cobertura.
