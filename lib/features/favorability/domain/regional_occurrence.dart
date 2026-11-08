import '../../occurrence/domain/occurrence_model.dart';

/// Ocorrência regional no formato consumido pelo motor de favorabilidade.
///
/// Independe do Firestore: qualquer fonte de ocorrências pode ser
/// convertida para este formato.
class RegionalOccurrence {
  final String id;

  /// Nome do organismo como veio da IA (texto livre).
  final String organismName;

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String reportedBy;

  /// Cultura onde a ocorrência foi registrada. null = desconhecida (o app
  /// ainda não registra a cultura nas ocorrências).
  final String? crop;

  /// Confiança do diagnóstico da IA (0–1), quando disponível.
  final double? diagnosisConfidence;

  const RegionalOccurrence({
    required this.id,
    required this.organismName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.reportedBy = '',
    this.crop,
    this.diagnosisConfidence,
  });

  /// Converte uma ocorrência do app. Retorna null quando ela não indica um
  /// organismo (sem diagnóstico, saudável ou sem nome) — essas ocorrências
  /// não são evidência de nenhum organismo.
  static RegionalOccurrence? fromOccurrence(OccurrenceModel o) {
    final diagnosis = o.diagnosis;
    if (diagnosis == null || diagnosis.isHealthy) return null;
    final name = diagnosis.pestName.trim();
    if (name.isEmpty) return null;
    return RegionalOccurrence(
      id: o.id,
      organismName: name,
      latitude: o.latitude,
      longitude: o.longitude,
      timestamp: o.timestamp,
      reportedBy: o.reportedBy,
      diagnosisConfidence: diagnosis.confidenceScore,
    );
  }
}
