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

## Reglas de seguridad

### Firestore (la app)

El proyecto Firebase del medidor es **independiente** (no comparte base con
mantencion-lineas). Pegar **todo el contenido** de `firestore.rules` en
**Firestore → Rules** (RULES tab) → *Publish*.

Las reglas usan el campo **`rol`** (`user` / `admin`) y cubren:
- `users/{userId}`: alta de cuenta propia con rol `user`; el usuario NO puede auto-promoverse a `admin`.
- `devices/{deviceId}`: claim por cualquier usuario autenticado; solo dueño/admin lee, actualiza o borra.
- `devices/{deviceId}/readings/{readingId}`: lectura solo dueño/admin.
- `alerts/{alertId}`: lectura autenticada; creación solo admin.

Para crear tu usuario admin: regístrate en la app (queda `rol: user`) y luego en
Firestore cambia manualmente `users/{tuUid}.rol` a `"admin"`.

### Realtime Database (el nodo ESP32)

Pegar en **Realtime Database → Rules** (RULES tab). Archivo fuente: `database.rules.json`.

```json
{
  "rules": {
    "devices": {
      "$deviceId": {
        ".read": "auth != null",
        ".write": "auth != null",
        "readings": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    }
  }
}
```

> **Importante**: el firmware publica hoy con token legacy en la URL
> (`?auth=FIREBASE_AUTH_TOKEN`). Ese mecanismo da acceso de administrador y
> **salta las reglas** (está deprecado por Google). Para el prototipo hay que
> completar `FIREBASE_AUTH_TOKEN` en `firmware/include/config.h`; a futuro se
> debe migrar a una autenticación real (Firebase Auth para el nodo o una Cloud
> Function que firme el ingreso). Ver pendientes en `firmware/README.md`.

## Claim de dispositivos

El botón "Vincular a mi cuenta" en la app crea el documento `devices/{deviceId}`
con `owner = uid` del usuario. El `allow create` abierto a cualquier usuario
autenticado es suficiente para esta etapa; el `allow update` impide que otro
usuario se apodere de un dispositivo ya asignado. Si se quiere mayor rigor, se
puede validar el `deviceId` contra un patrón o requerir que el nodo haya sido
pre-registrado por un admin.

## Notas

- Publicación de la app: Google Play US$25 (única), Apple Developer US$99/año.
- Los datos del nodo se etiquetan con su `device_id`; el backend decide quién puede verlos.
