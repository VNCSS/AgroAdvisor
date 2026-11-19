import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/intelligent_alert.dart';

abstract class IntelligentAlertStore {
  /// Reserva estado e histórico atomicamente; só um dispositivo ganha.
  Future<bool> reserve(String userId, IntelligentAlert alert);
  Future<void> delivery(String userId, IntelligentAlert alert, String status);
  Future<void> evaluation(
    String userId,
    String propertyId,
    Map<String, dynamic> data,
  );
}

class FirestoreIntelligentAlertStore implements IntelligentAlertStore {
  final FirebaseFirestore db;
  FirestoreIntelligentAlertStore({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      db.collection('notifications').doc(uid).collection('items');

  @override
  Future<bool> reserve(String userId, IntelligentAlert alert) async {
    if (alert.simulated) return false;
    // Compatibilidade: IDs aleatórios do serviço antigo também contam.
    if (alert.type == 'nearby' && alert.occurrenceId != null) {
      final legacy = await _items(
        userId,
      ).where('occurrenceId', isEqualTo: alert.occurrenceId).limit(1).get();
      if (legacy.docs.isNotEmpty) return false;
    }
    final state = _items(userId).doc(alert.stateId);
    final history = _items(userId).doc(alert.historyId);
    return db.runTransaction((tx) async {
      final previous = (await tx.get(state)).data();
      final timestamp = previous?['generatedAt'];
      final reservation = timestamp is Timestamp
          ? AlertReservation(timestamp.toDate(), previous?['level'] as String?)
          : null;
      if (!shouldReserve(alert, reservation)) return false;
      tx.set(state, {
        'type': '_internal',
        'read': true,
        'receivedAt': Timestamp.fromDate(alert.generatedAt),
        'generatedAt': Timestamp.fromDate(alert.generatedAt),
        'level': alert.level,
      });
      tx.set(history, {
        ...alert.toMap(),
        'receivedAt': Timestamp.fromDate(alert.generatedAt),
        'deliveryStatus': 'reserved',
        'transport': 'local',
        'recordedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<void> delivery(String userId, IntelligentAlert alert, String status) =>
      _items(userId).doc(alert.historyId).update({
        'deliveryStatus': status,
        'deliveryAttemptAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> evaluation(
    String userId,
    String propertyId,
    Map<String, dynamic> data,
  ) =>
      _items(userId).doc('evaluation_${IntelligentAlert.key(propertyId)}').set({
        ...data,
        'type': '_internal',
        'read': true,
        'receivedAt': FieldValue.serverTimestamp(),
      });
}

/// O envio local ocorre apenas depois da reserva. Não envia FCM.
class AlertDispatcher {
  final IntelligentAlertStore store;
  final Future<String> Function(String userId, IntelligentAlert alert)
  showLocal;
  final String? Function() activeUser;
  AlertDispatcher({
    required this.store,
    required this.showLocal,
    required this.activeUser,
  });

  Future<bool> emit(
    String userId,
    IntelligentAlert alert, {
    bool Function()? stillActive,
  }) async {
    bool active() => activeUser() == userId && (stillActive?.call() ?? true);
    if (alert.simulated || !active() || !await store.reserve(userId, alert)) {
      return false;
    }
    if (!active()) {
      await store.delivery(userId, alert, 'sessionEnded');
      return false;
    }
    String status;
    try {
      status = await showLocal(userId, alert);
    } catch (_) {
      status = 'localFailed';
    }
    await store.delivery(userId, alert, status);
    return true;
  }
}
