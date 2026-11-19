import 'package:cloud_firestore/cloud_firestore.dart';

import '../../favorability/domain/preventive_alert.dart';
import '../domain/app_notification_model.dart';

/// Onde os alertas preventivos são gravados e consultados.
abstract class PreventiveAlertStore {
  Future<StoredPreventiveAlert?> find(String userId, String alertId);
  Future<void> save(String userId, PreventiveAlert alert);
}

/// Grava alertas preventivos na MESMA coleção das notificações existentes
/// (`notifications/{userId}/items`), para que apareçam na tela e no
/// contador de não lidas sem um segundo sistema de notificações.
///
/// Diferenças em relação aos alertas de proximidade:
/// - documento com id determinístico ([PreventiveAlert.alertId]) → um
///   alerta por propriedade + organismo, atualizado no lugar;
/// - campo `type: 'preventive'`;
/// - SEM `occurrenceId`: o NearbyAlertService usa esse campo para saber
///   quais ocorrências já notificou, e um alerta preventivo não pode
///   interferir nisso.
class FirestorePreventiveAlertStore implements PreventiveAlertStore {
  final FirebaseFirestore _db;

  FirestorePreventiveAlertStore({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String userId, String id) =>
      _db.collection('notifications').doc(userId).collection('items').doc(id);

  @override
  Future<StoredPreventiveAlert?> find(String userId, String alertId) async {
    final snap = await _doc(userId, alertId).get();
    final data = snap.data();
    return data == null ? null : storedAlertFromMap(data);
  }

  @override
  Future<void> save(String userId, PreventiveAlert alert) =>
      _doc(userId, alert.alertId).set({
        ...preventiveAlertToMap(alert),
        'receivedAt': FieldValue.serverTimestamp(),
      });
}

/// Campos gravados (exceto `receivedAt`, que usa o horário do servidor).
/// Regravar marca o alerta como não lido.
Map<String, dynamic> preventiveAlertToMap(PreventiveAlert alert) => {
      'type': AppNotificationModel.typePreventive,
      'title': alert.title,
      'body': alert.body,
      'read': false,
      'propertyId': alert.propertyId,
      'ruleId': alert.ruleId,
      'organismName': alert.organismName,
      'fingerprint': alert.fingerprint,
      'favorabilityIndex': alert.favorabilityIndex,
      'level': alert.level.name,
      'validFrom': Timestamp.fromDate(alert.validFrom),
      'validUntil': Timestamp.fromDate(alert.validUntil),
    };

/// Lê o estado de deduplicação. Documento incompleto → null (tratado como
/// inexistente, o que gera um alerta novo em vez de falhar).
StoredPreventiveAlert? storedAlertFromMap(Map<String, dynamic> map) {
  final fingerprint = map['fingerprint'];
  final index = map['favorabilityIndex'];
  final validUntil = map['validUntil'];
  if (fingerprint is! String || index is! num || validUntil is! Timestamp) {
    return null;
  }
  return StoredPreventiveAlert(
    fingerprint: fingerprint,
    favorabilityIndex: index.toInt(),
    validUntil: validUntil.toDate(),
  );
}
