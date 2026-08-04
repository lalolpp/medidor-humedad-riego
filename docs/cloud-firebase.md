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

### Ajustes por dispositivo

El intervalo de muestreo se guarda como ajuste del dispositivo y es sincronizado en dos sentidos:

- `devices/{deviceId}.settings.sampling_interval_min` — intervalo en minutos (10/15/20/30/60).
- `devices/{deviceId}.settings.updated_at` — cuándo se cambió y quién lo cambió.

Flujo de cambio de intervalo:

1. La app escribe `sampling_interval_min` en Firestore (con reglas que restringen a dueño/admin).
2. El nodo lo lee en el siguiente ciclo (o recibe un push si hay BLE conectado) y lo aplica en NVS.
3. El nodo confirma el cambio en `settings` y reporta autonomía estimada en el siguiente reporte.

## Notas

- Publicación de la app: Google Play US$25 (única), Apple Developer US$99/año.
- Los datos del nodo se etiquetan con su `device_id`; el backend decide quién puede verlos.
