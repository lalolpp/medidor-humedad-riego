# Nube — Firebase

## Justificación

Se necesita multi-tenant (usuarios finales + administrador), por lo que Firebase con Auth, Firestore y Cloud Functions es adecuado y **gratis** a la escala del proyecto.

Firebase no tiene MQTT nativo; el ESP32 publica por **HTTPS a Firestore/Realtime DB**. Opcional: broker MQTT gratuito (EMQX Cloud / HiveMQ Cloud) como capa de ingreso que reenvía a Firebase.

## Planes

| Plan | Costo | Uso |
|---|---|---|
| Spark (gratis) | $0 CLP/mes | Auth (50.000 MAU), Firestore (1 GB), RTDB (1 GB), Hosting (10 GB), Cloud Functions (2M invocaciones/mes) |
| Blaze (por uso) | ~$1.000–3.000 CLP/mes | Solo si se supera la cuota gratis |

## Volumen estimado

- 10 dispositivos × 48 lecturas/día (cada 30 min) = **480 lecturas/día** (~14.400/mes).
- Cada lectura ~150–250 bytes (JSON) → ~100 KB/día ≈ **3 MB/mes** en total.
- Uso del plan gratis: ~2–3 % de la capacidad.

## Roles y permisos

- **Usuario final**: acceso solo a sus dispositivos (ownership por `device_id`).
- **Administrador**: acceso global a usuarios y dispositivos.
- Registro de dispositivos vía "claim": el usuario empareja el nodo por BLE y lo vincula a su cuenta.

## Modelo de datos sugerido (Firestore)

- `users/{userId}` — perfil y rol (`user` / `admin`).
- `devices/{deviceId}` — metadatos: dueño, ubicación, último reporte, versión firmware.
- `devices/{deviceId}/readings/{autoId}` — telemetría: humedad, temperatura, batería, señal LTE, timestamp.
- `alerts/{alertId}` — alertas de riego, batería baja, pérdida de conectividad.

## Notas

- Publicación de la app: Google Play US$25 (única), Apple Developer US$99/año.
- Los datos del nodo se etiquetan con su `device_id`; el backend decide quién puede verlos.
