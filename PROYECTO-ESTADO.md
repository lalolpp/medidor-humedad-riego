# Estado del proyecto — Medidor de Humedad

Actualizado: 2026-08-06

## Etapa actual: ✅ Prototipo funcional — app + firmware + nube operativos

El plan inicial (hardware, energía, costos) está en `docs/`. El firmware ESP32 y la
app Flutter existen, compilan y corren. La integración con el **proyecto Firebase
`medidor-de-humedad`** está **completa**: Auth (email/Google), Firestore (reglas
desplegadas), firmware publicando telemetría por Firestore REST con ID token,
dashboard con el diseño real del campo (8 sectores de riego) y APK release generado.

## Lo que ya está hecho ✅

### Nube (proyecto `medidor-de-humedad`, número `270536769377`)
- Auth: email/contraseña (y Google) habilitado. Cuenta de nodo `nodo@medidor.cl` (firmware).
- Firestore en modo producción; reglas en `firestore.rules` **desplegadas** (users, devices,
  readings, config, fields, sectors, crops, alerts; compartir por email con roles).
- RTDB creada con `database.rules.json` (respaldo).
- `edo.electric@gmail.com` con `rol: admin`.
- Deploy de reglas: `firebase deploy --only firestore:rules --project medidor-de-humedad`.
- `firebase.json` y `firestore.indexes.json` en la raíz del repo.

### Firmware ESP32 (`firmware/`)
- Ciclo: despertar → leer sensor → guardar LittleFS → publicar → ventana BLE → deep sleep.
- Sensores: humedad capacitiva (ADC 34) + **DS18B20** temperatura de suelo (pin 27).
- **Firestore REST con Firebase Auth** (`cloud.cpp`): `signInWithPassword` → ID token →
  POST reading + PATCH meta del device (ArduinoJson). Compilado OK (18.9% RAM / 56.6% flash).
- **Intervalo de reporte configurable desde la app** (`cloudFetchInterval`): el nodo lee
  `devices/{id}/config/current` al despertar y ajusta su deep sleep (intervalos 10–720 min).
- **OTA listo para activar**: módulo `ota.cpp` + particiones `partitions_ota.csv` + env
  `esp32dev_ota` (flag `ENABLE_OTA`). El nodo compara `otaVersion` remota con
  `FIRMWARE_VERSION` y descarga el `.bin`. Requiere grabar UNA vez por USB el esquema OTA.
- BLE GATT (humedad en vivo, batería, intervalo, autonomía, historial por chunks).
- Ajustes en NVS, historial con recorte a 30 archivos.

### App Flutter (`app/`)
- Login/registro Firebase Auth; `rol` user/admin; unidad C/F (`AppSettings`).
- **Dashboard "Mi campo"**: diseño real del predio con 8 sectores (manzanos gotero 4.17 L/h,
  kiwis microaspersión 27 L/h), áreas, estado por sector (requiere riego/OK), clima
  Open-Meteo por campo (alertas de lluvia ≥50%).
- **Seed del diseño**: botón "Cargar diseño de mi campo" crea el campo "Nicolini 2"
  (8 sectores) + perfiles Manzano/Kiwi.
- Sector → ficha técnica (área, emisores, caudal, presión, N° líneas) + sondas + comparativa 24 h.
- Detalle de sonda: humedad/temp históricas, **gráfico de cruce temp-vs-humedad (doble eje)**,
  **índice de infiltración/drenaje**, export **CSV** (compartir archivo), **intervalo de
  reporte configurable**, **compartir dispositivo por email** (Solo lectura/Administrador).
- **Roles/compartir**: reglas `shares {email: role}`; viewer lee, manager escribe.
- **Modo oscuro automático** (tema del sistema); **barras de señal RSSI** en BLE.
- BLE real (`flutter_blue_plus`) + modo demo; claim de dispositivo (field/sector/crop).
- APK release generado: `app/build/app/outputs/flutter-apk/app-release.apk` (~52 MB).

## Lo que falta / debemos hacer ahora 🔧 (en orden)

### 1. Enlace de cobertura (RSSI en nube)
- [ ] Mostrar la última RSSI (de readings) en las tarjetas del dashboard y detalle de sonda,
      para diagnóstico de cobertura WiFi/LTE antes de fallas.

### 2. Notificaciones push (alertas)
- [ ] Configurar **FCM** en el proyecto y en la app (`firebase_messaging`).
- [ ] Alertas por umbral (humedad bajo `irrigateBelow` / temp fuera de rango) y por
      helada (clima minTemp < umbral del cultivo). Hook/cloud function que notifique.

### 3. Automatización de riego (válvulas/relé) — **requiere aclaración**
- [ ] Definir cómo se implementa (¿relé en el nodo? ¿IFTTT/webhook a un programador?).
- [ ] Regla en la app: si humedad < umbral y no hay lluvia prevista → sugerir/ejecutar riego.

### 4. Integración LTE (pendiente grande)
- [ ] `cloud.cpp` hoy usa WiFi. Falta integrar el módulo **A7670E** (pin `PIN_LTE_PWR`)
      y publicar por LTE con SIM.

### 5. OTA en terreno
- [ ] Flashear UNA vez por USB el env `esp32dev_ota` (esquema de particiones con 2 slots).
- [ ] Subir el `.bin` a una URL estable y programar la actualización desde la app.

### 6. Widgets de pantalla de inicio (iOS/Android)
- [ ] App Widgets que muestren humedad/temp actual sin abrir la app.

### 7. Calibración en terreno
- [ ] Sensor SEN0193: calibrar ADC → % humedad (seco vs saturado) en `sensor.cpp`.
- [ ] Confirmar divisor de batería y ajustar `BATTERY_DIVIDER_GAIN` en `config.h`.

### 8. Verificación final
- [ ] `pio run` y `flutter analyze`/`flutter test`/`flutter build` antes de cada release.
- [ ] Probar BLE real entre app y nodo; probar compartir entre dos cuentas.
