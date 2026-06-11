/**
 * AgroAdvisor — Cloud Function: notifyNearbyUsers
 *
 * Disparada quando um diagnóstico de praga é adicionado a uma ocorrência.
 * Salva a notificação no Firestore (notifications/{userId}/items) e envia
 * push FCM para os usuários com propriedades dentro do raio configurado.
 *
 * DEPLOY:
 *   1. firebase login
 *   2. firebase init functions  (selecione o projeto agroadvisor-1e11e)
 *   3. npm install no diretório functions/
 *   4. firebase deploy --only functions
 */

const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const PEST_RISK_LEVELS = new Set(['alto', 'médio', 'medio', 'baixo']);

function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Trigger: atualização de ocorrência — dispara apenas quando o diagnóstico
 * de praga real é adicionado pela primeira vez.
 */
exports.notifyNearbyUsers = onDocumentUpdated(
  'occurrences/{occurrenceId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const occurrenceId = event.params.occurrenceId;

    // Só dispara quando o diagnóstico é recém-adicionado
    if (before.diagnosis || !after.diagnosis) return;

    const diagnosis = after.diagnosis;
    const riskLevel = (diagnosis.riskLevel || '').toLowerCase();

    // Ignora plantas saudáveis
    if (!PEST_RISK_LEVELS.has(riskLevel)) {
      console.log(`[notifyNearbyUsers] diagnóstico "${riskLevel}" não é praga — ignorado`);
      return;
    }

    const { latitude: occLat, longitude: occLng, reportedBy } = after;

    if (!occLat || !occLng) {
      console.log(`[notifyNearbyUsers] ocorrência ${occurrenceId} sem coordenadas — ignorada`);
      return;
    }

    console.log(`[notifyNearbyUsers] praga "${diagnosis.pestName}" (${riskLevel}) em (${occLat}, ${occLng})`);

    // Busca todos os usuários com token FCM registrado.
    // Trata ausência do campo notificationsEnabled como true (padrão opt-in).
    const usersSnapshot = await db.collection('users').get();

    if (usersSnapshot.empty) {
      console.log('[notifyNearbyUsers] nenhum usuário cadastrado');
      return;
    }

    const sendPromises = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;

      if (userId === reportedBy) continue;

      // false explícito = usuário desabilitou; ausência do campo = opt-in padrão
      if (userData.notificationsEnabled === false) continue;

      const fcmToken = userData.fcmToken;
      if (!fcmToken) continue;

      const alertRadiusKm = userData.alertRadiusKm ?? 20;

      const propertiesSnapshot = await db
        .collection('properties')
        .where('ownerId', '==', userId)
        .get();

      // Se o usuário tem propriedades, filtra por raio.
      // Se não tem, notifica mesmo assim (optou por alertas mas ainda não cadastrou propriedade).
      let closestDistKm = Infinity;
      if (!propertiesSnapshot.empty) {
        const isNearby = propertiesSnapshot.docs.some((propDoc) => {
          const prop = propDoc.data();
          if (!prop.latitude || !prop.longitude) return false;
          const distKm = haversineDistanceKm(
            prop.latitude, prop.longitude, occLat, occLng,
          );
          if (distKm < closestDistKm) closestDistKm = distKm;
          return distKm <= alertRadiusKm;
        });
        if (!isNearby) continue;
      }

      const distStr = closestDistKm < Infinity
        ? (closestDistKm < 1
            ? `a ${(closestDistKm * 1000).toFixed(0)} m da sua propriedade`
            : `a ${closestDistKm.toFixed(1)} km da sua propriedade`)
        : 'na sua região';

      const title = `⚠️ ${diagnosis.pestName} detectada próximo a você`;
      const body = `Risco ${diagnosis.riskLevel} — ${distStr}.`;

      sendPromises.push(
        Promise.all([
          // Envia push FCM
          messaging
            .send({
              token: fcmToken,
              notification: { title, body },
              data: {
                occurrenceId,
                latitude: String(occLat),
                longitude: String(occLng),
                type: 'pest_alert',
              },
              android: {
                priority: 'high',
                notification: { channelId: 'agro_advisor_pest_alerts' },
              },
              apns: {
                payload: { aps: { sound: 'default', badge: 1 } },
              },
            })
            .then(() => console.log(`[notifyNearbyUsers] push enviado para ${userId}`))
            .catch((err) =>
              console.error(`[notifyNearbyUsers] erro push para ${userId}:`, err.message),
            ),

          // Persiste no histórico do usuário
          db.collection('notifications').doc(userId).collection('items').add({
            title,
            body,
            receivedAt: FieldValue.serverTimestamp(),
            read: false,
            occurrenceId,
            latitude: occLat,
            longitude: occLng,
          }),
        ]),
      );
    }

    await Promise.all(sendPromises);
    console.log(`[notifyNearbyUsers] concluído — ${sendPromises.length} notificação(ões) enviada(s)`);
  },
);
