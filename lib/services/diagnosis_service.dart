import 'dart:developer' as dev;

import '../features/occurrence/domain/diagnosis_model.dart';
import 'ai_service.dart';
import 'database_service.dart';


/// Orquestra a análise de IA e a persistência do diagnóstico no Firestore.
///
/// Depende de AiService (injetado) — fácil de testar com um mock.
class DiagnosisService {
  final AiService _aiService;
  final DatabaseService _db;

  const DiagnosisService({
    required AiService aiService,
    required DatabaseService db,
  })  : _aiService = aiService,
        _db = db;

  /// Analisa a imagem via IA e persiste o diagnóstico na ocorrência.
  ///
  /// Retorna o [DiagnosisModel] em caso de sucesso, ou null em caso de falha.
  /// Nunca lança exceção — erros são logados e capturados internamente.
  Future<DiagnosisModel?> analyzeAndSave(
    String occurrenceId,
    String imageBase64, {
    void Function(String error)? onError,
  }) async {
    try {
      dev.log('[DiagnosisService] analisando ocorrência $occurrenceId');

      final diagnosis = await _aiService.analyzeImage(imageBase64);

      dev.log(
        '[DiagnosisService] resultado → ${diagnosis.pestName} '
        '| risco: ${diagnosis.riskLevel} '
        '| confiança: ${(diagnosis.confidenceScore * 100).toStringAsFixed(0)}%',
      );

      await _db.updateOccurrenceDiagnosis(occurrenceId, diagnosis);

      dev.log('[DiagnosisService] diagnóstico salvo no Firestore');

      return diagnosis;
    } on AiRateLimitException catch (e) {
      dev.log('[DiagnosisService] limite de requisições da API atingido');
      onError?.call(e.toString());
      return null;
    } catch (e, stack) {
      dev.log('[DiagnosisService] erro na análise', error: e, stackTrace: stack);
      onError?.call('Falha na análise: ${e.toString()}');
      return null;
    }
  }
}
