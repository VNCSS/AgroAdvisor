import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _db;

  NotificationRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('notifications').doc(userId).collection('items');

  /// Stream em tempo real das notificações do usuário (mais recentes primeiro).
  Stream<List<AppNotificationModel>> watchForUser(String userId) {
    return _col(userId)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotificationModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Stream com a contagem de notificações não lidas.
  Stream<int> watchUnreadCount(String userId) {
    return _col(userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String userId, String notifId) async {
    await _col(userId).doc(notifId).update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    final unread = await _col(userId).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
