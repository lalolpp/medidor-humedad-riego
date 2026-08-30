# Nube — Firebase

## Proyecto

- **Nombre**: medidor de humedad
- **ID**: `medidor-de-humedad`
- **Número**: `270536769377`
- Proyecto **independiente** de mantencion-lineas.

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
- `devices/{deviceId}`: claim por el usuario que lo registra (`owner = uid`); solo dueño/admin/manager escribe la config (válvula) y las lecturas. **El claim no puede fijar la cuenta del nodo** (`nodeAccountEmail`), solo un admin.
- `devices/{deviceId}/config/{id}`: aquí vive el comando de válvula; solo dueño/admin/manager escribe; el **nodo vinculado** (`nodeAccountEmail`) solo lee.
- `devices/{deviceId}/readings/{readingId}`: crea/lee solo dueño/admin/manager o el nodo vinculado.
- `alerts/{alertId}`: lectura autenticada; creación solo admin.
- `commands`, `irrigationEvents`: solo dueño/admin/manager del dispositivo.

> **Vínculo de cuenta del nodo (opcional, recomendado)**: para que el firmware
> quede vinculado a sus dispositivos sin depender del dueño, cada documento
> `devices/{deviceId}` puede llevar `nodeAccountEmail` = email de la cuenta del
> nodo (`nodo@medidor.cl`). Es **opcional**: con las reglas actuales el nodo
> funciona sin él (los dueños/admin/manager siguen pudiendo publicar telemetría y
> la lectura de `config` queda abierta a usuarios autenticados). Se recomienda
> fijarlo por el admin para dejar constancia de a qué cuenta pertenece cada nodo.

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

> **Importante**: el firmware autentica con **Firebase Auth** (email/contraseña de
> la cuenta `nodo@medidor.cl`) y publica por la REST API de Firestore con un **ID
> token** — NO usa el token legacy de RTDB. Las credenciales del nodo NO van en el
> repo: van en `firmware/include/secrets.h` (gitignored, copia de
> `secrets.h.template`). La contraseña de esa cuenta quedó expuesta en el historial
> público del repo, por lo que **debe rotarse**: cambiar la contraseña en Firebase
> Console (Authentication → Users → nodo@medidor.cl) y actualizar `secrets.h`.
> A la vez se debe fijar `nodeAccountEmail` en cada `devices/{deviceId}` (ver
> arriba) para que el nodo quede vinculado a sus dispositivos. Pendiente a futuro:
> migrar a una autenticación más fuerte para el nodo (secreto por dispositivo o
> una Cloud Function que firme el ingreso). Ver `firmware/README.md`.

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
