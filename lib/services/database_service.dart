import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/occurrence/domain/diagnosis_model.dart';
import '../features/occurrence/domain/occurrence_model.dart';
import '../features/property/domain/property_model.dart';
import '../features/settings/domain/user_settings_model.dart';

/// Centraliza todas as operações de leitura e escrita no Firestore.
///
/// Coleções utilizadas:
///   - `properties`  → dados das propriedades rurais
///   - `occurrences` → registros de pragas do Radar Colaborativo
///   - `users`       → configurações e FCM token dos usuários
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────
  // PROPRIEDADES
  // ──────────────────────────────────────────────

  /// Salva (cria ou atualiza) os dados da propriedade do usuário.
  Future<void> saveProperty(PropertyModel property) async {
    if (property.id.isEmpty) {
      await _db.collection('properties').add(property.toMap());
    } else {
      await _db.collection('properties').doc(property.id).set(property.toMap());
    }
  }

  /// @deprecated Use getUserProperties para múltiplas propriedades
  Future<PropertyModel?> getProperty(String userId) async {
    final doc = await _db.collection('properties').doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return PropertyModel.fromMap(doc.id, doc.data()!);
  }

  /// Busca todas as propriedades de um usuário específico.
  Future<List<PropertyModel>> getUserProperties(String userId) async {
    final querySnapshot = await _db
        .collection('properties')
        .where('ownerId', isEqualTo: userId)
        .get();

    return querySnapshot.docs
        .map((doc) => PropertyModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Exclui uma propriedade do Firestore.
  Future<void> deleteProperty(String propertyId) async {
    await _db.collection('properties').doc(propertyId).delete();
  }

  // ──────────────────────────────────────────────
  // OCORRÊNCIAS DE PRAGA
  // ──────────────────────────────────────────────

  /// Registra ou atualiza uma ocorrência.
  /// Retorna o ID do documento criado/atualizado.
  Future<String> saveOccurrence(OccurrenceModel occurrence) async {
    final collection = _db.collection('occurrences');

    if (occurrence.id.isEmpty) {
      final doc = await collection.add(occurrence.toMap());
      return doc.id;
    } else {
      await collection.doc(occurrence.id).set(occurrence.toMap());
      return occurrence.id;
    }
  }

  /// Retorna um stream com todas as ocorrências em tempo real,
  /// ordenadas da mais recente para a mais antiga.
  Stream<List<OccurrenceModel>> getOccurrencesStream() {
    return _db
        .collection('occurrences')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OccurrenceModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Adiciona ou atualiza o diagnóstico de IA em uma ocorrência existente.
  Future<void> updateOccurrenceDiagnosis(
    String occurrenceId,
    DiagnosisModel diagnosis,
  ) async {
    await _db.collection('occurrences').doc(occurrenceId).update({
      'diagnosis': diagnosis.toMap(),
    });
  }

  // ──────────────────────────────────────────────
  // CONFIGURAÇÕES DO USUÁRIO (FCM + Alertas)
  // ──────────────────────────────────────────────

  /// Salva as configurações de notificação do usuário.
  Future<void> saveUserSettings(UserSettingsModel settings) async {
    await _db
        .collection('users')
        .doc(settings.userId)
        .set(settings.toMap(), SetOptions(merge: true));
  }

  /// Carrega as configurações do usuário. Retorna null se não existirem.
  Future<UserSettingsModel?> getUserSettings(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserSettingsModel.fromMap(doc.data()!);
  }

  /// Persiste (ou atualiza) o FCM token do dispositivo do usuário.
  Future<void> saveUserFcmToken(String userId, String token) async {
    await _db.collection('users').doc(userId).set(
      {'userId': userId, 'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  /// Retorna todos os usuários com notificações habilitadas.
  ///
  /// Nota: a filtragem por raio geográfico é feita no cliente
  /// (Firestore não suporta queries geoespaciais nativamente).
  /// Para escala, considere geohash ou a Cloud Function incluída no projeto.
  Future<List<UserSettingsModel>> getActiveNotificationUsers() async {
    final snapshot = await _db
        .collection('users')
        .where('notificationsEnabled', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => UserSettingsModel.fromMap(doc.data()))
        .toList();
  }
}
