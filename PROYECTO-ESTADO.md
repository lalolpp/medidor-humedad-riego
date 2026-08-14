# Estado del proyecto — Medidor de Humedad

Actualizado: 2026-08-13

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
- **Fingerprints de firma registrados** (Management API) para la app
  `1:270536769377:android:d7021f9bc93066704a0f20` (`cl.riego.medidor_humedad`):
  SHA-1 `146518c4779b736653ba0ab52c361e158068bb6d` y SHA-256
  `80a24f954077911e232bbaf8a43d00a1fa51039dbd20d93eb366226adbc9273a`
  (cert debug que firma el APK actual). Si se pasa a keystore propio o Play
  App Signing, hay que registrar las nuevas huellas.
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
- **Simulador de datos del nodo en la nube**: el detalle del dispositivo demo
  (`isDemo`) tiene el botón "Generar datos de ejemplo" → `CloudService.seedDemoReadings`
  crea 7 días de lecturas horarias realistas (humedad con riegos y drenaje exponencial,
  temp de suelo, batería y RSSI) + telemetría resumida; regenera limpiando lecturas
  previas. Regla Firestore: dueño/admin/manager puede actualizar/borrar lecturas de su
  dispositivo (desplegado). Sin hardware, se exploran gráficos, infiltración y CSV.
- BLE real (`flutter_blue_plus`) + modo demo; claim de dispositivo (field/sector/crop).
- **Automatización de riego (OpenCode, sin Cloud Functions)**: `AutomationScreen` configura
  umbral de humedad, duración, ventana horaria (incluso cruce de medianoche), pausa por
  lluvia (Open-Meteo) y mínimo entre riegos (anti-rebote). El motor
  `AutomationService.check` evalúa al cargar/refrescar el dashboard o el detalle del
  dispositivo y escribe SOLO en cambios de estado: comando `valveState` (ON/OFF) en
  `devices/{id}/config/current` (lo que el ESP32 lee) + `automationStatus` en el doc del
  dispositivo para el indicador ("Esperando…/Regando/Pausado por lluvia/Anti-rebote").
  Reglas validadas en emulador (dueño/manager escriben, viewer denegado, nodo lee).
- **Firmware ejecuta `valveState` (OpenCode)**: nuevo módulo `valve.h/valve.cpp` (relé en
  GPIO 26), `cloudFetchValve()` re-lee `config/current` y el nodo aplica el comando en cada
  ciclo; con `VALVE_KEEP_AWAKE=1` mientras la válvula está abierta no duerme y re-chequea
  la nube cada `VALVE_RECHECK_MS` (60 s) para detectar el apagado. Compila en ambos entornos
  (`pio run` OK). Versión firmware 1.1.0. Falta: hardware real (relé común o biestable).
- APK release generado: `app/build/app/outputs/flutter-apk/app-release.apk` (~52 MB).
- **Dashboard nuevo (OpenCode, "SmartDashboard")**: rediseño completo a tema oscuro tipo SaaS
  con identidad Gamalier — encabezado con reloj/fecha/filtro, menú por secciones, KPIs
  (humedad promedio, temp. suelo, sensores activos, sector más seco), indicadores (mín/máx/
  promedio semanal/riegos sugeridos), resumen por rango 0–100% con donut, tabla de sectores
  con "Ver detalle", gráfico histórico con rango 7/14/30/60 días, condiciones ambientales
  (Open-Meteo actual), estado del cultivo, estado energético (batería/voltaje/autonomía),
  comunicación (RSSI/sincronización/calidad), mapa esquemático de estaciones con colores y
  panel de alertas recientes. `WeatherService.current()` nuevo. `flutter analyze` 0 issues,
  tests OK, APK 54.6 MB instalado.
- **RSSI en tarjetas del dashboard**: la fila "Panel solar: —" ahora muestra **"Señal"** con
  `SignalBars` + valor dBm coloreado por calidad (≤−95 rojo, ≤−75 naranja, sino verde)
  usando el RSSI del último reporte (`devices/{id}.rssi`). El detalle de sonda y la tabla
  de sectores ya lo mostraban. `flutter analyze` 0 issues.
- **Alertas push automáticas por umbral (GitHub Actions, sin Cloud Functions)**: script Node
  `firebase/fcm_alerts.js` + workflow `.github/workflows/fcm-alerts.yml` (cron cada 30 min +
  manual). Lee users/campos/sectores/cultivos/dispositivos, calcula la humedad promedio por
  sector y envía push FCM con `data: {sectorName, humidity, threshold}` (lo que
  `push_notifications.dart` ya muestra con el canal "Alertas de riego"). Umbral
  `sector.irrigateBelow ?? crop.irrigateBelow`, respeta `alertsEnabled` y el doc
  `alerts/fcm_{sectorId}` (solo admin). Sin spam: notifica al bajar y re-avisa cada 24 h si
  sigue bajo. Pendiente de operación: push al repo y secreto `FCM_SERVICE_ACCOUNT` en GitHub.

## Lo que falta / debemos hacer ahora 🔧 (en orden)

> División de trabajo: **Qwen Coder** → revisión de código, testing.
> **OpenCode** → RSSI en nube ✅, FCM/alertas por umbral ✅, LTE A7670E, OTA en terreno,
> automatización de riego, widgets de pantalla de inicio.

### 1. Enlace de cobertura (RSSI en nube) — ✅ hecho por OpenCode
- [x] Mostrar la última RSSI (de readings) en las tarjetas del dashboard y detalle de sonda,
      para diagnóstico de cobertura WiFi/LTE antes de fallas. El RSSI del último reporte llega
      como `devices/{id}.rssi` (lo actualiza el nodo con cada lectura); ya se ve en tarjetas
      del dashboard ("Señal" + SignalBars), detalle de sonda y tabla de sectores.

### 2. Notificaciones push (alertas) — ⚠️ casi listo, falta operación en GitHub
- [x] Fingerprints SHA-1/SHA-256 registrados en Firebase (FCM ya puede autenticar la app).
- [x] Configurar **FCM** en la app (`firebase_messaging`) + token y canal de notificación.
- [x] Alertas por umbral (humedad bajo `irrigateBelow`): **hook por GitHub Actions**
      (`firebase/fcm_alerts.js` + `.github/workflows/fcm-alerts.yml`, cada 30 min + manual).
      Pendiente del usuario: hacer push al repo y crear el secreto
      **`FCM_SERVICE_ACCOUNT`** (JSON de service account con rol Editor/Cloud Messaging Admin)
      en Settings → Secrets → Actions; luego Run workflow para probar.
- [ ] (opcional) Alertas por temp fuera de rango y por helada (minTemp del clima < umbral
      del cultivo) en el mismo script.

### 3. Automatización de riego (válvulas/relé) — *OpenCode* — ✅ app + firmware
- [x] Motor de reglas en la app (`AutomationService` + `AutomationScreen`): umbral, duración,
      ventana horaria, pausa por lluvia, anti-rebote; escribe `valveState` en `config/current`.
- [x] **Firmware** lee `devices/{id}/config/current.valveState` en cada ciclo y acciona el
      relé (GPIO 26), con keep-awake mientras riega. Compila (`pio run`), sin hardware aún.
- [ ] Probar en terreno: conectar relé (común activo ALTO o biestable con `VALVE_KEEP_AWAKE=0`)
      y verificar cierre/apertura ante comando de la app; confirmar si el relé va en el nodo
      o hay módulo de 8 salidas por sector (en ese caso ajustar `valve.cpp` a 8 pines).

### 4. Integración LTE A7670E — *OpenCode* (pendiente grande)
- [ ] `cloud.cpp` hoy usa WiFi. Falta integrar el módulo **A7670E** (pin `PIN_LTE_PWR`)
      y publicar por LTE con SIM.

### 5. OTA en terreno — *OpenCode*
- [ ] Flashear UNA vez por USB el env `esp32dev_ota` (esquema de particiones con 2 slots).
- [ ] Subir el `.bin` a una URL estable y programar la actualización desde la app.

### 6. Widgets de pantalla de inicio (iOS/Android) — *OpenCode*
- [ ] App Widgets que muestren humedad/temp actual sin abrir la app.

### 7. Calibración en terreno
- [ ] Sensor SEN0193: calibrar ADC → % humedad (seco vs saturado) en `sensor.cpp`.
- [ ] Confirmar divisor de batería y ajustar `BATTERY_DIVIDER_GAIN` en `config.h`.

### 8. Verificación final
- [ ] `pio run` y `flutter analyze`/`flutter test`/`flutter build` antes de cada release.
- [ ] Probar BLE real entre app y nodo; probar compartir entre dos cuentas.
