# Estado del proyecto — Medidor de Humedad

Actualizado: 2026-08-05

## Etapa actual: 🚧 Prototipo funcional (app + firmware) con nube en configuración

El plan inicial (hardware, energía, costos) está completo en `docs/`. El firmware
ESP32 y la app Flutter ya existen y corren (firmware sin probar en hardware real,
app con modo demo funcional). La integración con el **nuevo proyecto Firebase**
`medidor-de-humedad` está **en curso**: se creó el proyecto y se dejaron las reglas
y el host del firmware listos, pero falta la reconfiguración de la app.

## Lo que ya está hecho ✅

### Planeación (`docs/`)
- `architecture.md` — flujo de datos: sensor → nodo → (WiFi/LTE) → Firebase → app; y BLE local.
- `hardware.md` — BOM <$50 USD/nodo (ESP32 + A7670E LTE + sensor capacitivo + solar).
- `power-budget.md` — ~85–100 mAh/día; batería 18650 → ~25 días sin sol.
- `costs.md` — nube ~$0–1.200 CLP/mes; SIM a cargo del cliente.
- `cloud-firebase.md` — proyecto nuevo, reglas, roles.

### Firmware ESP32 (`firmware/`)
- Ciclo de vida: despertar → leer sensor → guardar en LittleFS (historial por día) → publicar → ventana BLE (~30 s) → deep sleep.
- Servicio BLE GATT (UUIDs compartidos con la app): humedad en vivo, batería, intervalo configurable, autonomía, historial por chunks.
- Ajustes en NVS, historial con recorte a 30 archivos.
- `config.h` ya apunta a `medidor-de-humedad-default-rtdb.firebaseio.com`.

### App Flutter (`app/`)
- Login/registro con Firebase Auth; campo de rol **`rol`** (`user` / `admin`).
- Pantallas: login, lista de dispositivos, detalle del nodo (en vivo, batería, autonomía, intervalo, historial descargable, gráfico).
- BLE real (`flutter_blue_plus`) + **modo demo** sin hardware.
- Claim de dispositivo ("Vincular a mi cuenta" → Firestore `devices/{id}`).
- Firestore: `users/{uid}` (rol), `devices/{id}` (owner), `alerts`.

### Nube
- Reglas Firestore solo-medidor en `firestore.rules` (rol `user`/`admin`, sin auto-promoción).
- Reglas RTDB en `database.rules.json`.
- **Proyecto Firebase**: `medidor-de-humedad` (ID) / número `270536769377`.

## Lo que falta / debemos hacer ahora 🔧 (en orden)

### 1. Reconfigurar la app Flutter con el nuevo proyecto (bloqueante para nube) ✅
- [x] Registrar la app Android (`cl.riego.medidor_humedad`) en el nuevo proyecto y descargar `google-services.json`.
- [x] **Reemplazar** `app/android/app/google-services.json` (ahora apunta a `medidor-de-humedad`).
- [x] En `app/`: ejecutar `flutterfire configure --project=medidor-de-humedad` (regenera `firebase_options.dart`).

### 2. Pegar reglas en la consola del proyecto nuevo
- [ ] **Firestore → Rules**: pegar contenido de `firestore.rules` → Publish.
- [ ] **Realtime Database → Rules**: pegar contenido de `database.rules.json` → Publish.

### 3. Firmware: token de la base de datos
- [ ] Completar `FIREBASE_AUTH_TOKEN` en `firmware/include/config.h` (RTDB → Configuración → *Database secrets*). Sin esto el nodo no puede publicar.

### 4. Crear tu usuario admin
- [ ] Registrarte en la app (queda `rol: user`) y en Firestore cambiar `users/{tuUid}.rol` a `"admin"`.

### 5. Bug de compilación en la app ✅ (descartado)
- [x] `app/lib/services/ble_device_service.dart`: el switch sin `break` **no es un error**. Desde Dart 3.0 el fall-through se eliminó y el linter `unnecessary_breaks` recomienda omitir `break` al final de un case no vacío. Verificado con `dart analyze` y ejecución: compila y no cae al siguiente case. No requiere cambios.

### 6. Integración LTE (pendiente grande)
- [ ] `cloud.cpp` hoy solo usa WiFi. Falta integrar el módulo **A7670E** (pin `PIN_LTE_PWR` sin uso) y la publicación por LTE con SIM.

### 7. Decidir dónde vive la telemetría
- [ ] La app lee **Firestore** (`devices/{id}`) pero el firmware escribe **Realtime DB** (`devices/{id}/readings.json`). Unificar (recomendado: migrar el firmware a Firestore REST, o la app a RTDB).

### 8. Calibración en terreno
- [ ] Sensor SEN0193: calibrar ADC → % humedad (seco vs saturado) en `sensor.cpp`.
- [ ] Confirmar divisor de batería y ajustar `BATTERY_DIVIDER_GAIN` en `config.h`.

### 9. Compilar y probar
- [ ] `pio run` (firmware) y `flutter analyze` / `flutter build` (app) para verificar.
- [ ] Probar BLE real entre app y nodo.
