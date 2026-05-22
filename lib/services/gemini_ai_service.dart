import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../features/occurrence/domain/diagnosis_model.dart';
import 'ai_service.dart';

/// Implementação do AiService usando Google Gemini 2.0 Flash.
///
/// A chave de API é lida de AppConstants — centralize e documente ali.
/// Para trocar de provedor de IA, crie outra classe implementando AiService
/// e atualize apenas a injeção em app.dart.
class GeminiAiService implements AiService {
  static const String _apiKey = AppConstants.geminiApiKey;
  static const String _endpoint = AppConstants.geminiEndpoint;

  // Prompt especializado em fitossanidade, forçando resposta em JSON puro.
  static const String _systemPrompt = '''Você é um especialista em fitossanidade e proteção de lavouras brasileiras.
Analise a imagem enviada e identifique pragas, doenças ou distúrbios fitossanitários visíveis.

Responda SOMENTE com JSON válido, sem markdown, sem texto adicional, exatamente neste formato:
{
  "pestName": "nome da praga ou doença principal",
  "riskLevel": "alto",
  "description": "descrição técnica do problema observado na imagem",
  "recommendation": "ações de manejo e controle recomendadas",
  "confidenceScore": 0.85,
  "detectedIssues": ["problema 1", "problema 2"]
}

Regras:
- riskLevel deve ser exatamente: "alto", "médio" ou "baixo"
- confidenceScore deve ser entre 0.0 e 1.0
- detectedIssues pode ser vazio [] se houver apenas um problema
- Se não houver problema visível ou a imagem não for de lavoura, use pestName: "Não identificado" e confidenceScore: 0.1
- Se não for possível determinar o risco, use riskLevel: "baixo"
''';

  @override
  Future<DiagnosisModel> analyzeImage(String imageBase64) async {
    dev.log('[GeminiAiService] iniciando análise de imagem');

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt},
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': imageBase64,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1024,
        'topP': 0.8,
      },
    });

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(const Duration(seconds: AppConstants.aiTimeoutSeconds));

    if (response.statusCode == 200) {
      dev.log('[GeminiAiService] resposta recebida, processando');
      return _parseResponse(response.body);
    }

    if (response.statusCode == 429) {
      final retryDelaySecs = _parseRetryDelay(response.body);
      dev.log('[GeminiAiService] 429 — retryDelay: ${retryDelaySecs}s');

      // Só tenta novamente se o delay sugerido for curto (limite de RPM).
      // Quota diária esgotada tem delay longo — falha imediatamente.
      if (retryDelaySecs != null && retryDelaySecs <= 60) {
        dev.log('[GeminiAiService] aguardando ${retryDelaySecs}s (sugerido pela API)');
        await Future.delayed(Duration(seconds: retryDelaySecs));
        final retry = await http
            .post(uri, headers: {'Content-Type': 'application/json'}, body: requestBody)
            .timeout(const Duration(seconds: AppConstants.aiTimeoutSeconds));
        if (retry.statusCode == 200) {
          dev.log('[GeminiAiService] retry bem-sucedido');
          return _parseResponse(retry.body);
        }
      }

      throw const AiRateLimitException();
    }

    dev.log('[GeminiAiService] erro HTTP ${response.statusCode} — body: ${response.body}');
    throw Exception('Gemini API retornou ${response.statusCode}');
  }

  DiagnosisModel _parseResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Sem candidatos na resposta');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;

      if (parts == null || parts.isEmpty) {
        throw const FormatException('Sem partes na resposta');
      }

      final rawText = (parts.first['text'] as String? ?? '').trim();

      // Remove blocos markdown caso o modelo os inclua mesmo sendo instruído a não
      final cleanJson = rawText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final diagnosisMap = jsonDecode(cleanJson) as Map<String, dynamic>;

      final result = DiagnosisModel(
        pestName: diagnosisMap['pestName'] ?? 'Não identificado',
        riskLevel: _normalizeRiskLevel(diagnosisMap['riskLevel']),
        description: diagnosisMap['description'] ?? '',
        recommendation: diagnosisMap['recommendation'] ?? '',
        confidenceScore: (diagnosisMap['confidenceScore'] ?? 0.0).toDouble().clamp(0.0, 1.0),
        detectedIssues: List<String>.from(diagnosisMap['detectedIssues'] ?? []),
        analyzedAt: DateTime.now(),
      );

      dev.log('[GeminiAiService] diagnóstico: ${result.pestName} (${(result.confidenceScore * 100).toStringAsFixed(0)}%)');
      return result;
    } catch (e) {
      dev.log('[GeminiAiService] erro no parse: $e — retornando diagnóstico de fallback');
      return DiagnosisModel(
        pestName: 'Análise inconclusiva',
        riskLevel: 'desconhecido',
        description: 'Não foi possível processar o resultado da análise de IA.',
        recommendation: 'Consulte um engenheiro agrônomo para avaliação presencial.',
        confidenceScore: 0.0,
        detectedIssues: const [],
        analyzedAt: DateTime.now(),
      );
    }
  }

  // Extrai o retryDelay em segundos do corpo do erro 429 da Gemini API.
  // Retorna null se não encontrar ou não conseguir parsear.
  int? _parseRetryDelay(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final details = (json['error']?['details'] as List?) ?? [];
      for (final detail in details) {
        final delay = detail['retryDelay'] as String?;
        if (delay != null) {
          return int.tryParse(delay.replaceAll('s', '').trim());
        }
      }
    } catch (_) {}
    return null;
  }

  String _normalizeRiskLevel(dynamic raw) {
    final s = (raw as String? ?? '').toLowerCase().trim();
    if (s == 'alto') return 'alto';
    if (s == 'médio' || s == 'medio') return 'médio';
    if (s == 'baixo') return 'baixo';
    return 'desconhecido';
  }
}
