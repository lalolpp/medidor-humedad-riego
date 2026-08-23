# Estado del proyecto — Medidor de Humedad

Actualizado: 2026-08-22

## Etapa actual: ✅ Prototipo funcional — app + firmware + nube operativos

El plan inicial (hardware, energía, costos) está en `docs/`. El firmware ESP32 y la
app Flutter existen, compilan y corren. La integración con el **proyecto Firebase
`medidor-de-humedad`** está **completa**: Auth (email/Google), Firestore (reglas
desplegadas), firmware publicando telemetría por Firestore REST con ID token,
dashboard con el diseño real del campo (8 sectores de riego) y APK release generado.

## Sesión 2026-08-22 (PC de lalo) — BLE real probado ✅

- **Conexión BLE real app↔nodo verificada**: celular Android ↔ ESP32 DevKit V1 (CP2102,
  COM3, MAC `b0:3f:d3:5c:51:1c`). El nodo anuncia "MedidorHumedad", la app lo encuentra,
  diálogo de confirmación, badge verde "Conectado por Bluetooth" con ID.
- **Driver CP210x instalado** (el chip del DevKit es CP2102, no CH340).
- **Nodo despierto mientras hay USB**: si la batería lee ≥4,15 V (USB puesto) no entra
  en deep sleep y mantiene la ventana BLE abierta permanentemente (`main.cpp`). Con
  batería duerme normal. Facilita las pruebas en banco.
- **Logs BLE en serial**: `[BLE] Anunciando/Cliente conectado/Cliente desconectado`,
  intervalo configurado por BLE queda registrado.
- **Config WiFi vía BLE** (implementado en paralelo por ambos PCs; quedó la versión
  del otro PC): característica `c1a5f0d2-…` recibe `{ssid, pass, id}` JSON, guarda en
  NVS y responde. App: Ajustes → Configurar WiFi del nodo.
- **Fix de instancia de servicio**: `_service` era un getter que creaba una instancia
  nueva en cada acceso → al conectar decía "dispositivo no encontrado". Ahora se guarda
  la instancia y se recrea solo al cambiar de modo demo/BLE.
- **Sección "Cercanos" subida** en Home: ahora aparece antes que "Mi campo".
- Nodo reflasheado con `esp32dev_ota` (particiones OTA) — borró NVS: reconfigurar WiFi
  e ID desde la app (Ajustes → Configurar WiFi del nodo).
- APK debug instalada en celu (`cl.riego.medidor_humedad`, adb `-s 101aa0c2`) con todo lo anterior.

## Sesión 2026-08-22 (tarde) — Config WiFi desde la app FUNCIONAL ✅

**Ciclo completo verificado: nodo → WiFi → Firebase → app.**

- **Configurar WiFi por BLE funciona de punta a punta**: Ajustes → Configurar WiFi
  del nodo → escanear → "MedidorHumedad" → SSID/pass → vincular dispositivo nube →
  Enviar. Serial confirma `[BLE] Config WiFi recibida` → `[WIFI] Credenciales
  guardadas` → `[NVS] deviceId`. La app ahora lee `OK` del nodo.
- **Fix clave firmware**: característica WiFi `c1a5f0d2-…` no tenía propiedad READ
  y la app fallaba al leer la respuesta ("The READ property is not supported").
  Ahora es `PROPERTY_WRITE | PROPERTY_READ`.
- **Fix clave app** (`ble_device_service.dart`): timeout de conexión BLE (15 s),
  timeouts en write/read (10 s/5 s), lectura de respuesta tolerante (si falla,
  asume guardado porque el write llegó), logs `[WIFI-CFG]` en logcat para
  diagnosticar cada paso.
- **Logs de diagnóstico firmware**: `[NVS] wifiSsid/deviceId` al boot,
  `[CLOUD] habilitado…`, `[NET] conectando a 'ssid'… / WiFi OK IP/RSSI /
  WiFi FAIL status`. Imprescindibles para depurar sin adivinar.
- **Vinculación correcta**: el nodo quedó con `deviceId = B0:3F:D3:5C:51:1E`
  (su MAC), que ES el doc ID del dispositivo "MedidorHumedad" del usuario en
  Firestore (creado por claim previo). Ojo: el desplegable lista TODOS los
  dispositivos propios (MedidorHumedad=MAC, TY=otra MAC, Medidor Humedad
  Demo=demo-001); elegir bien a cuál vincular.
- **Publicación verificada en la app**: detalle de la sonda muestra última
  medición "hace N minutos" tras reiniciar el nodo. Humedad 100% y temp -127 °C
  son valores esperados SIN sensores conectados (pin suelto / DS18B20 ausente).
- **Comportamiento en banco**: con USB puesto el nodo está despierto y publica
  SOLO al arrancar (reiniciar con RST para re-publicar). Con batería publicará
  cada intervalo al despertar.
- **APK debug actualizada** e instalada en el celu con todos estos arreglos.
- Nota operativa: el auto-reset USB falló varias veces al flashear; solución:
  mantener presionado BOOT durante el `pio run -t upload` hasta que empiece a
  escribir.

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
- **Backfill de lecturas pendientes (OpenCode, v1.2.0)**: si no hay red, el nodo acumula
  lecturas en LittleFS; al reconectar `cloudBackfill()` las reenvía en lotes (commit Firestore,
  ≤100 por lote, tope 10 s por ciclo) con doc idempotente `readings/r{ts}` (marca de avance
  `lastSyncedTs` en NVS). Compila en ambos entornos: `esp32dev` y `esp32dev_ota`
  (RAM 19.0% / flash 91.4% — flash quedando justo).

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
  sigue bajo. Fix OpenCode (2026-08-15): handler de background registrado en `main()` antes de
  `runApp` (los push se perdían con la app cerrada) y reintento de envíos fallidos (solo avanza
  `sentAt` cuando el envío tiene éxito). Pendiente de operación: secreto `FCM_SERVICE_ACCOUNT`
  en GitHub.
- **Expansión del modelo de datos (OpenCode, 2026-08-19)**: nuevos campos `depthCm`
  en devices, `targetMin`/`targetMax`/`stressMin` en sectores (bandas de gestión);
  nuevas colecciones top-level `commands/{id}` (audit trail de comandos con
  requestedAt/acknowledgedAt/startedAt/endedAt/status), `irrigationEvents/{id}`
  (historial de riegos con deviceId/source/duration/humidityBefore/After),
  `sectorClimate/{sectorId_date}` (agregados diarios: avg/min/max humedad y temp,
  precipitación, ETP). Modelos Dart: `Command`, `IrrigationEvent`, `SectorClimate`.
  Reglas Firestore desplegadas para las 3 colecciones + `depthCm` en update mask.
  `flutter analyze` 0 errors, 0 issues en widgets.
- **Resumen ejecutivo en dashboard (OpenCode, 2026-08-19)**: tarjeta con score de
  salud del predio (0–100): humedad promedio 40%, batería 25%, conectividad 25% +
  penalización por sectores críticos. Indicadores visuales OK/Alerta/Crítico.
- **Seguridad de firmware v1.3.0 (OpenCode, 2026-08-19)**: `VALVE_MAX_OPEN_MIN`
  (240 min) cierra automáticamente la válvula si lleva abierta demasiado tiempo;
  `VALVE_MIN_BATTERY` (10%) impide abrir válvula con batería crítica; timestamp
  `valveOpenedAt` para el timeout. Compila OK (verificar con `pio run`).

## Lo que falta / debemos hacer ahora 🔧 (en orden)

> Detalle operativo del día a día en `NOTA-ESTADO-Y-PENDIENTES.md` (2026-08-22).

### 0. Inmediato (tras reflasheo con particiones OTA)
- [x] Configurar WiFi desde la app — ✅ hecho y verificado (ver sesión de la tarde).
      El nodo quedó vinculado al dispositivo "MedidorHumedad" (`B0:3F:D3:5C:51:1E`).
- [x] Riego falso en banco probado — ✅ relé acciona con `valveState=ON` desde
      "Riego manual" de la app y el nuevo botón por sector. Se detecta OFF en ≤60 s.
      ⚠️ **PENDIENTE CRÍTICO**: `VALVE_MIN_BATTERY` quedó en `0.0` para poder probar
      sin batería. RESTAURAR A `0.10` en `config.h` antes de usar con batería real.
- [ ] Recompilar y desplegar: APK release + Windows release + release v1.0 GitHub
      (`lalolpp/medidor-humedad-apk`, `--clobber`) + actualizar pendrive `D:\medidor-humedad-windows.zip`.
      Nota: build Windows falla por rutas >260 car.; usar junction corta (`C:\mh`) ya creada.
- [x] Incidente de cuota Firestore (2026-08-22): el nodo crash-loopiaba durante el
      riego (BLE+TLS agotaban RAM) republicando lecturas cada ~100 s, y la app
      cargaba hasta 3000 lecturas/dispositivo por refresh. Fixes: BLE omitido
      mientras riega (`main.cpp`), historial limitado a 600/1000 puntos, workflow
      FCM desactivado (solo manual). Vigilar uso en consola los próximos días.

### 1. Enlace de cobertura (RSSI en nube) — ✅ hecho por OpenCode
- [x] Mostrar la última RSSI (de readings) en las tarjetas del dashboard y detalle de sonda,
      para diagnóstico de cobertura WiFi/LTE antes de fallas. El RSSI del último reporte llega
      como `devices/{id}.rssi` (lo actualiza el nodo con cada lectura); ya se ve en tarjetas
      del dashboard ("Señal" + SignalBars), detalle de sonda y tabla de sectores.

### 2. Notificaciones push (alertas) — ⚠️ solo falta el secreto en GitHub
- [x] Fingerprints SHA-1/SHA-256 registrados en Firebase (FCM ya puede autenticar la app).
- [x] Configurar **FCM** en la app (`firebase_messaging`) + token y canal de notificación.
- [x] Alertas por umbral (humedad bajo `irrigateBelow`): **hook por GitHub Actions**
      (`firebase/fcm_alerts.js` + `.github/workflows/fcm-alerts.yml`, cada 30 min + manual).
      Handler de background en `main()` + reintento de envíos fallidos (ya subido).
      Pendiente del usuario: crear el secreto **`FCM_SERVICE_ACCOUNT`** (JSON de service
      account con rol Editor/Cloud Messaging Admin) en Settings → Secrets → Actions;
      luego Run workflow para probar.
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

### 8. Features en cola (pedidos por el usuario)
- [ ] Interruptor en Ajustes para activar/desactivar notificaciones.
- [ ] Datos demo extensos (14 días) para el gráfico "Evolución de humedad promedio" del Sector 1.
- [ ] Borrar rama remota `feat/soil-profile-100cm` (ya integrada).

### 9. Verificación final
- [ ] `pio run` y `flutter analyze`/`flutter test`/`flutter build` antes de cada release.
- [x] Probar BLE real entre app y nodo — ✅ verificado 2026-08-22.
- [ ] Probar compartir entre dos cuentas.
