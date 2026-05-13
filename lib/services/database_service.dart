import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';
import '../models/occurrence_model.dart';

/// Centraliza todas as operações de leitura e escrita no Firestore.
///
/// Coleções utilizadas:
///   - `properties`  → dados das propriedades rurais
///   - `occurrences` → registros de pragas do Radar Colaborativo
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────
  // PROPRIEDADES
  // ──────────────────────────────────────────────

  /// Salva (cria ou atualiza) os dados da propriedade do usuário.
  /// Se for uma nova propriedade, gera um ID automático.
  /// Se for atualização, usa o ID existente.
  Future<void> saveProperty(PropertyModel property) async {
    if (property.id.isEmpty) {
      // Nova propriedade - gera ID automático
      await _db.collection('properties').add(property.toMap());
    } else {
      // Atualização - usa ID existente
      await _db.collection('properties').doc(property.id).set(property.toMap());
    }
  }

  /// Busca os dados da propriedade de um usuário específico.
  /// Retorna null se o usuário ainda não cadastrou sua propriedade.
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

  // ──────────────────────────────────────────────
  // OCORRÊNCIAS DE PRAGA
  // ──────────────────────────────────────────────

  /// Registra uma nova ocorrência de praga no Firestore.
  /// O ID do documento é gerado automaticamente pelo Firestore.
  Future<void> saveOccurrence(OccurrenceModel occurrence) async {
    await _db.collection('occurrences').add(occurrence.toMap());
  }

  /// Retorna um stream com todas as ocorrências em tempo real,
  /// ordenadas da mais recente para a mais antiga.
  Stream<List<OccurrenceModel>> getOccurrencesStream() {
    return _db
        .collection('occurrences')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OccurrenceModel.fromMap(doc.id, doc.data()))
            .toList());
  }
}
