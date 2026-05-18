/**
 * AgroAdvisor — Cloud Function: notifyNearbyUsers
 *
 * Disparada automaticamente quando uma nova ocorrência é criada no Firestore.
 * Consulta todos os usuários com notificações ativas, verifica se alguma
 * propriedade está dentro do raio configurado e envia push via FCM.
 *
 * DEPLOY:
 *   1. firebase login
 *   2. firebase init functions  (selecione o projeto agroadvisor-1e11e)
 *   3. Copie este arquivo para functions/index.js
 *   4. npm install no diretório functions/
 *   5. firebase deploy --only functions
 *
 * DEPENDÊNCIAS (package.json da pasta functions/):
 *   "firebase-admin": "^12.0.0"
 *   "firebase-functions": "^5.0.0"
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Calcula a distância em km entre dois pontos usando a fórmula de Haversine.
 */
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
 * Trigger: criação de documento na coleção `occurrences`.
 *
 * Fluxo:
 *   1. Lê latitude/longitude da nova ocorrência
 *   2. Busca todos os usuários com notificações ativas e FCM token
 *   3. Para cada usuário, verifica se alguma propriedade está dentro do raio
 *   4. Envia push FCM para os usuários elegíveis
 */
exports.notifyNearbyUsers = onDocumentCreated(
  'occurrences/{occurrenceId}',
  async (event) => {
    const occurrence = event.data.data();
    const occurrenceId = event.params.occurrenceId;

    const { latitude: occLat, longitude: occLng, reportedBy } = occurrence;

    if (!occLat || !occLng) {
      console.log(`[notifyNearbyUsers] ocorrência ${occurrenceId} sem coordenadas — ignorada`);
      return;
    }

    console.log(`[notifyNearbyUsers] nova ocorrência ${occurrenceId} em (${occLat}, ${occLng})`);

    // 1. Busca usuários com notificações ativas e token FCM
    const usersSnapshot = await db
      .collection('users')
      .where('notificationsEnabled', '==', true)
      .get();

    if (usersSnapshot.empty) {
      console.log('[notifyNearbyUsers] nenhum usuário com notificações ativas');
      return;
    }

    const sendPromises = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;

      // Não notifica quem registrou a ocorrência
      if (userId === reportedBy) continue;

      const fcmToken = userData.fcmToken;
      if (!fcmToken) continue;

      const alertRadiusKm = userData.alertRadiusKm ?? 20;

      // 2. Verifica se alguma propriedade do usuário está dentro do raio
      const propertiesSnapshot = await db
        .collection('properties')
        .where('ownerId', '==', userId)
        .get();

      if (propertiesSnapshot.empty) continue;

      const isNearby = propertiesSnapshot.docs.some((propDoc) => {
        const prop = propDoc.data();
        if (!prop.latitude || !prop.longitude) return false;
        const distKm = haversineDistanceKm(
          prop.latitude,
          prop.longitude,
          occLat,
          occLng,
        );
        return distKm <= alertRadiusKm;
      });

      if (!isNearby) continue;

      // 3. Monta e envia a notificação
      const message = {
        token: fcmToken,
        notification: {
          title: '⚠️ Alerta: Praga Detectada!',
          body: `Uma ocorrência de praga foi registrada próxima à sua propriedade. Acesse o Radar para detalhes.`,
        },
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
          payload: {
            aps: { sound: 'default', badge: 1 },
          },
        },
      };

      sendPromises.push(
        messaging
          .send(message)
          .then(() => console.log(`[notifyNearbyUsers] notificação enviada para ${userId}`))
          .catch((err) =>
            console.error(`[notifyNearbyUsers] erro ao notificar ${userId}:`, err.message),
          ),
      );
    }

    await Promise.all(sendPromises);
    console.log(`[notifyNearbyUsers] concluído — ${sendPromises.length} notificação(ões) enviada(s)`);
  },
);
