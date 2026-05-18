import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/user_settings_model.dart';

/// Repositório de configurações do usuário (FCM token + raio de alerta).
class SettingsRepository {
  final FirebaseFirestore _db;

  SettingsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _db.collection(AppConstants.colUsers).doc(userId);

  Future<UserSettingsModel?> get(String userId) async {
    final snap = await _doc(userId).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserSettingsModel.fromMap(snap.data()!);
  }

  Future<void> save(UserSettingsModel settings) async {
    await _doc(settings.userId).set(settings.toMap(), SetOptions(merge: true));
  }

  Future<void> saveFcmToken(String userId, String token) async {
    await _doc(userId).set(
      {'userId': userId, 'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  Future<List<UserSettingsModel>> getActiveUsers() async {
    final snap = await _db
        .collection(AppConstants.colUsers)
        .where('notificationsEnabled', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => UserSettingsModel.fromMap(d.data()))
        .toList();
  }
}
