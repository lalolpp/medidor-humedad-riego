/**
 * Envio automatico de alertas de riego por FCM.
 *
 * Lee Firestore (usuarios, campos, sectores, cultivos y dispositivos), calcula
 * la humedad promedio por sector y envia un push cuando un sector baja del
 * umbral de riego (el del sector o el del cultivo) y tiene las alertas
 * habilitadas. Evita repetir avisos: notifica en la transicion a "bajo" y
 * re-avisa solo si sigue bajo despues de 24 h.
 *
 * La app muestra el push gracias a los handlers de firebase_messaging:
 * data: { sectorName, humidity, threshold }.
 *
 * Credenciales: service account con rol "Editor" o "Cloud Messaging Admin"
 * pasado en la variable de entorno FCM_SERVICE_ACCOUNT (secreto de GitHub).
 *
 * Ejecutar:
 *   FCM_SERVICE_ACCOUNT='{"type":"service_account",...}' node fcm_alerts.js
 */
const admin = require('firebase-admin');

const secret = process.env.FCM_SERVICE_ACCOUNT;
if (!secret) {
  console.error(
    '[FCM] Falta el secreto FCM_SERVICE_ACCOUNT (service account JSON).');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(secret)),
});

const db = admin.firestore();
const RE_NOTIFY_MS = 24 * 60 * 60 * 1000; // re-avisar cada 24 h si sigue bajo

function avg(values) {
  return values.reduce((a, b) => a + b, 0) / values.length;
}

async function sectorState(sectorId) {
  const ref = db.collection('alerts').doc(`fcm_${sectorId}`);
  const snap = await ref.get();
  const data = snap.exists ? snap.data() : {};
  return { ref, low: data.low === true, sentAt: data.sentAt || 0 };
}

async function main() {
  const users = await db.collection('users').get();
  const targets = users.docs
    .filter((d) => typeof d.data().fcmToken === 'string' && d.data().fcmToken)
    .map((d) => ({ uid: d.id, token: d.data().fcmToken }));
  if (targets.length === 0) {
    console.log('[FCM] No hay tokens de usuario registrados.');
    return;
  }
  const tokensByUid = new Map(targets.map((t) => [t.uid, t.token]));

  let sent = 0;
  let pending = 0;

  // Campos/sectores/cultivos de cada usuario con token (evita cruzar owners).
  for (const target of targets) {
    const uid = target.uid;
    const fields = await db
      .collection('fields').where('owner', '==', uid).get();
    const crops = await db
      .collection('crops').where('owner', '==', uid).get();
    const devices = await db
      .collection('devices').where('owner', '==', uid).get();

    const cropsById = new Map();
    crops.docs.forEach((d) => cropsById.set(d.id, d.data()));

    const devicesBySector = new Map();
    devices.docs.forEach((d) => {
      const sid = d.data().sectorId;
      if (sid) {
        if (!devicesBySector.has(sid)) devicesBySector.set(sid, []);
        devicesBySector.get(sid).push(d.data());
      }
    });

    for (const field of fields.docs) {
      const sectors = await db
        .collection('fields').doc(field.id).collection('sectors').get();
      for (const sector of sectors.docs) {
        const s = sector.data();
        const crop = s.cropId ? cropsById.get(s.cropId) : null;
        const threshold = s.irrigateBelow ?? crop?.irrigateBelow ?? null;
        if (threshold == null) continue;
        if (s.alertsEnabled === false) continue;

        const hums = (devicesBySector.get(sector.id) || [])
          .map((d) => d.humidity)
          .filter((h) => typeof h === 'number');
        if (hums.length === 0) continue;
        const avgHum = avg(hums);
        const lowNow = avgHum < threshold;

        const state = await sectorState(sector.id);
        const wasLow = state.low === true;
        const shouldSend =
          lowNow && (!wasLow || Date.now() - state.sentAt >= RE_NOTIFY_MS);

        if (lowNow) {
          if (shouldSend) {
            const label = s.name || sector.id;
            try {
              await admin.messaging().send({
                token: target.token,
                data: {
                  sectorName: label,
                  humidity: avgHum.toFixed(1),
                  threshold: threshold.toFixed(0),
                },
              });
              sent++;
              console.log(`[FCM] Enviado a ${uid} · ${label} (${avgHum.toFixed(1)}% < ${threshold.toFixed(0)}%)`);
              // Solo se avanza sentAt cuando el envío tuvo éxito; si falla, la
              // próxima corrida reintenta (sin esperar las 24 h).
              await state.ref.set({ low: true, sentAt: Date.now() }, { merge: true });
            } catch (e) {
              console.error(`[FCM] Error enviando a ${uid} · ${label}: ${e.message}`);
              await state.ref.set({ low: true }, { merge: true });
            }
          }
          if (!wasLow) pending++;
        } else {
          await state.ref.set({ low: false, sentAt: 0 }, { merge: true });
        }
      }
    }
  }

  console.log(`[FCM] Listo. Enviados: ${sent}, sectores bajos: ${pending}.`);
}

main().then(() => process.exit(0)).catch((e) => {
  console.error('[FCM] Error fatal:', e);
  process.exit(1);
});
