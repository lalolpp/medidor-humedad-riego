# NOTA DE ESTADO — leer antes de continuar

_Escrita el 2026-08-22 desde el PC de lalo (el que tiene el ESP32 conectado por USB)._
_Sirve para retomar el trabajo desde cualquier máquina._

---

## En qué etapa estamos

La app ya tiene **riego manual**, **selector de conexión Bluetooth/WiFi** y **configuración
del WiFi del nodo desde la app** (sección nueva en Ajustes). El firmware del ESP32 recibió
un "buzón" BLE nuevo para recibir `{ssid, pass, id}` y guardarlos en su memoria NVS.

### Compilado y verificado en este PC
- `flutter analyze`: **sin problemas**
- `pio run -e esp32dev_ota`: **compila OK** (firmware con WiFi + deviceId por BLE)
- Windows build OK, APK OK (pero **ojo**: los binarios actuales son de ANTES del último
  ajuste del sheet de vinculación → recompilar, ver pendientes)

## Qué se hizo hoy (resumen)

| # | Avance | Archivos clave |
|---|--------|----------------|
| 1 | Tarjeta **Riego manual** (switch ON/OFF) en detalle de sonda | `app/lib/screens/cloud_device_detail_screen.dart` |
| 2 | Ajustes → **Conexión del nodo**: selector Bluetooth / WiFi-Internet | `settings_screen.dart`, `app_settings.dart`, `home_screen.dart` |
| 3 | Ajustes → **Configurar WiFi del nodo**: escanea BLE, envía SSID/pass/vínculo nube | `settings_screen.dart` (`_NodeWifiSheet`) |
| 4 | Envío BLE de credenciales (+ID de nube) | `ble_device_service.dart`, `cloud_service.dart` |
| 5 | Firmware: característica BLE `c1a5f0d2-77e8-4b39-9a44-52f10de91b63` que guarda WiFi e ID | `firmware/src/ble_service.cpp`, `storage.h/.cpp` |
| 6 | Driver CP210x instalado en este PC → el nodo es **COM3** | — |
| 7 | Nodo flasheado con `esp32dev_ota` (particiones OTA) | — |

## ⚠️ Estado actual del nodo (importante)

El flasheo cambió el esquema de particiones y **borró su memoria interna**:
- Perdió las credenciales WiFi y su ID de nube (`demo-001`)
- **Falta reflashear UNA vez más**: el fix que restaura el ID vía BLE se compiló DESPUÉS
  del flasheo. Sin él, publicaría como `dev0001`.

⚠️ Además quedó escrito `valveState = "ON"` en Firestore (`devices/demo-001/config/current`,
motivo: prueba de relé). Cuando el nodo recupere internet, **abrirá el relé automáticamente**.
Era la prueba pendiente del usuario (relé en GPIO26 + GND + 5V, bomba en COM/NO).

## Pendientes (en orden sugerido)

1. **Reflashear el nodo** (con USB, puerto COM3 en el PC de lalo):
   ```
   pio run -e esp32dev_ota -t upload --upload-port COM3
   ```
   (PIO: `C:\Users\lalo\AppData\Local\Programs\Python\Python312\Scripts\pio.exe`)
2. **Configurar WiFi desde la app**: Ajustes → Configurar WiFi del nodo → elegir
   "MedidorHumedad" → red de la oficina → vincular a **Medidor Humedad Demo**.
   Verificar en serie que imprime `[WIFI] Credenciales guardadas` y `[NVS] deviceId = demo-001`.
3. **Probar extremo a extremo**: nodo publica lecturas a demo-001 → el relé debe activarse
   (valveState ON sigue en la nube). Cortar con el switch de Riego manual o escribir OFF.
4. **Recompilar apps y desplegar** (los binarios actuales no tienen lo de hoy):
   - APK: `flutter build apk --release` → instalar en celu (adb `-s 101aa0c2`; si falla por
     firma, desinstalar antes) → subir a release v1.0 con `--clobber` en
     `lalolpp/medidor-humedad-apk` como `medidor-humedad.apk`
   - Windows: `flutter build windows --release` → copiar `build\windows\x64\runner\Release\*`
     a `C:\Users\lalo\Documents\medidor-humedad-windows`
   - Actualizar también `D:\medidor-humedad-windows.zip` del pendrive (está viejo)
5. **Features en cola (pedidos por el usuario, aún no hechos)**:
   - Interruptor en Ajustes para activar/desactivar **notificaciones** (y quitar las alarmas
     como push al celular)
   - Datos demo extensos (14 días) para el gráfico **"Evolución de humedad promedio"** del
     Sector 1 (hoy solo hay 48 h)
   - Borrar la rama remota `feat/soil-profile-100cm` (ya integrada en main)

## Notas técnicas útiles

- El nodo anuncia BLE como **"MedidorHumedad"**; ventana de ~30 s tras cada arranque
  (presionar RST). Con batería ≥4,15 V (USB puesto) queda despierto permanentemente.
- Relé: GPIO26, **activo en HIGH**, OFF al arrancar. Auto-cierre de seguridad a 240 min.
- Si la app dice "no soporta configuración WiFi" → el nodo tiene firmware viejo → reflashear.
- Firma de APK: keystore debug local. APKs hechas en PCs distintos no se sobreescriben entre sí.
