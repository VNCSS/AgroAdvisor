import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/diagnosis_model.dart';
import '../domain/occurrence_model.dart';

/// Repositório de ocorrências de pragas.
///
/// Centraliza as operações Firestore da feature occurrence,
/// impedindo que telas ou widgets acessem o Firestore diretamente.
class OccurrenceRepository {
  final FirebaseFirestore _db;

  OccurrenceRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.colOccurrences);

  /// Persiste uma ocorrência e retorna o ID gerado.
  Future<String> save(OccurrenceModel occurrence) async {
    if (occurrence.id.isEmpty) {
      final doc = await _col.add(occurrence.toMap());
      return doc.id;
    } else {
      await _col.doc(occurrence.id).set(occurrence.toMap());
      return occurrence.id;
    }
  }

  /// Stream em tempo real de todas as ocorrências (mais recentes primeiro).
  Stream<List<OccurrenceModel>> watchAll() {
    return _col
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OccurrenceModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Atualiza o diagnóstico de IA de uma ocorrência existente.
  Future<void> updateDiagnosis(
    String occurrenceId,
    DiagnosisModel diagnosis,
  ) async {
    await _col.doc(occurrenceId).update({'diagnosis': diagnosis.toMap()});
  }
}
