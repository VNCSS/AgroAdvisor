import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/occurrence/domain/diagnosis_model.dart';
import '../features/property/domain/property_model.dart';
import 'database_service.dart';

/// Escuta novas ocorrências em tempo real e grava notificações no Firestore
/// quando uma praga é detectada dentro do raio configurado pelo usuário.
///
/// Substitui a Cloud Function para o plano Spark (sem Cloud Functions).
/// Funciona enquanto o app está aberto em foreground ou background recente.
class NearbyAlertService {
  final DatabaseService _db;
  final FirebaseFirestore _firestore;

  String? _currentUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Set<String> _notified = {};

  NearbyAlertService({DatabaseService? db, FirebaseFirestore? firestore})
      : _db = db ?? DatabaseService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Inicia (ou reinicia) a escuta para [userId].
  /// Idempotente: não faz nada se o mesmo userId já estiver ativo.
  Future<void> initialize(String userId) async {
    if (_currentUserId == userId && _sub != null) return;
    await stop();
    _currentUserId = userId;

    try {
      final settings = await _db.getUserSettings(userId);
      if (settings?.notificationsEnabled == false) {
        dev.log('[NearbyAlert] notificações desabilitadas para $userId');
        return;
      }

      final alertRadiusKm = settings?.alertRadiusKm ?? 20.0;

      final properties = await _db.getUserProperties(userId);
      dev.log('[NearbyAlert] ${properties.length} propriedade(s) carregada(s)');

      // Carrega IDs já notificados para não reenviar após reinício do app.
      final existing = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .get();
      for (final doc in existing.docs) {
        final id = doc.data()['occurrenceId'] as String?;
        if (id != null) _notified.add(id);
      }
      dev.log('[NearbyAlert] ${_notified.length} ocorrência(s) já notificada(s)');

      _sub = _firestore
          .collection('occurrences')
          .snapshots()
          .listen(
            (snap) => _onSnapshot(snap, userId, properties, alertRadiusKm),
            onError: (e) => dev.log('[NearbyAlert] erro stream: $e'),
          );

      dev.log('[NearbyAlert] iniciado — userId=$userId raio=${alertRadiusKm}km');
    } catch (e, st) {
      dev.log('[NearbyAlert] falha ao inicializar: $e', stackTrace: st);
    }
  }

  /// Para a escuta e limpa o estado.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _currentUserId = null;
    _notified.clear();
  }

  // ── Processamento do snapshot ─────────────────────────────────────────────

  void _onSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    String userId,
    List<PropertyModel> properties,
    double alertRadiusKm,
  ) {
    dev.log('[NearbyAlert] snapshot: ${snap.docChanges.length} mudança(s)');

    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;

      final data = change.doc.data();
      if (data == null) continue;

      final occId = change.doc.id;
      if (_notified.contains(occId)) continue;

      final reportedBy = data['reportedBy'] as String? ?? '';
      if (reportedBy == userId) {
        dev.log('[NearbyAlert] ignorado (própria ocorrência): $occId');
        continue;
      }

      final rawDiag = data['diagnosis'];
      if (rawDiag == null) continue;

      DiagnosisModel diagnosis;
      try {
        diagnosis =
            DiagnosisModel.fromMap(Map<String, dynamic>.from(rawDiag as Map));
      } catch (_) {
        continue;
      }
      if (diagnosis.isHealthy) continue;

      final occLat = (data['latitude'] as num?)?.toDouble();
      final occLng = (data['longitude'] as num?)?.toDouble();
      if (occLat == null || occLng == null) continue;

      // Verifica raio. Se o usuário não tem propriedades, notifica mesmo assim.
      double? closestKm;
      if (properties.isNotEmpty) {
        for (final prop in properties) {
          final d = _haversineKm(prop.latitude, prop.longitude, occLat, occLng);
          if (closestKm == null || d < closestKm) closestKm = d;
        }
        if (closestKm == null || closestKm > alertRadiusKm) continue;
      }

      _notified.add(occId);

      final distStr = closestKm == null
          ? 'na sua região'
          : closestKm < 1
              ? 'a ${(closestKm * 1000).toStringAsFixed(0)} m da sua propriedade'
              : 'a ${closestKm.toStringAsFixed(1)} km da sua propriedade';

      _saveNotification(
        userId: userId,
        occId: occId,
        title: '${diagnosis.pestName} detectada próximo a você',
        body: 'Risco ${diagnosis.riskLevel} — $distStr.',
        occLat: occLat,
        occLng: occLng,
      );
    }
  }

  Future<void> _saveNotification({
    required String userId,
    required String occId,
    required String title,
    required String body,
    required double occLat,
    required double occLng,
  }) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .add({
        'title': title,
        'body': body,
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'occurrenceId': occId,
        'latitude': occLat,
        'longitude': occLng,
      });
      dev.log('[NearbyAlert] notificação salva: $title');
    } catch (e) {
      dev.log('[NearbyAlert] erro ao salvar: $e');
      _notified.remove(occId); // permite nova tentativa
    }
  }

  // ── Haversine ─────────────────────────────────────────────────────────────

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}
