import '../features/occurrence/domain/diagnosis_model.dart';

/// Interface desacoplada para provedores de IA.
///
/// Para trocar o provider de IA (ex: de Gemini para OpenAI):
///   1. Crie uma nova classe que implementa AiService
///   2. Troque a injeção em main.dart
///   Nenhum outro arquivo precisa mudar.
abstract class AiService {
  Future<DiagnosisModel> analyzeImage(String imageBase64);
}
