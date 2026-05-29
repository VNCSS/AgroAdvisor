import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../features/occurrence/domain/diagnosis_model.dart';
import 'ai_service.dart';

/// Implementação do AiService usando Google Gemini 2.5 Flash.
///
/// Tier gratuito: 1.500 req/dia — ideal para desenvolvimento e testes.
/// Para trocar de provedor, altere AppConstants.geminiEndpoint em app_constants.dart.
class GeminiAiService implements AiService {
  static const String _apiKey = AppConstants.geminiApiKey;
  static const String _endpoint = AppConstants.geminiEndpoint;

  static const String _systemPrompt = '''Especialista em fitossanidade. Analise a imagem e responda APENAS com JSON, sem texto extra.

Formato obrigatório:
{"pestName":"<máx 40 chars>","riskLevel":"alto","description":"<máx 120 chars>","recommendation":"<máx 120 chars>","confidenceScore":0.85,"detectedIssues":["<máx 30 chars>"]}

Regras:
- riskLevel: exatamente "alto", "médio" ou "baixo"
- confidenceScore: entre 0.0 e 1.0
- detectedIssues: [] se apenas um problema
- Sem imagem de lavoura: pestName "Não identificado", confidenceScore 0.1
- Risco incerto: "baixo"
- Seja breve: respeite os limites de caracteres acima''';

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
        'responseMimeType': 'application/json',
        // Desativa o raciocínio interno (thinking) do gemini-2.5-flash.
        // Sem isso, o modelo consome tokens "pensando" antes de responder,
        // deixando poucos tokens para o JSON e causando resposta truncada.
        'thinkingConfig': {
          'thinkingBudget': 0,
        },
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

    // Loga sempre o corpo completo para facilitar diagnóstico
    dev.log(
      '[GeminiAiService] erro HTTP ${response.statusCode}\n'
      'body: ${response.body}',
    );

    if (response.statusCode == 400) {
      // 400 normalmente significa chave inválida ou payload malformado.
      // Extrai a mensagem da API para exibir algo útil.
      final msg = _extractApiError(response.body);
      throw Exception('Gemini: requisição inválida — $msg');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Gemini: chave de API inválida ou sem permissão (${response.statusCode}). '
        'Gere uma nova em aistudio.google.com/apikey',
      );
    }

    if (response.statusCode == 429) {
      final retryDelaySecs = _parseRetryDelay(response.body);
      dev.log('[GeminiAiService] 429 — retryDelay: ${retryDelaySecs}s');

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
        dev.log('[GeminiAiService] retry também falhou — body: ${retry.body}');
      }

      throw const AiRateLimitException();
    }

    throw Exception('Gemini API [${response.statusCode}]: ${_extractApiError(response.body)}');
  }

  DiagnosisModel _parseResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Sem candidatos na resposta');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = (content?['parts'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];

      if (parts.isEmpty) {
        throw const FormatException('Sem partes na resposta');
      }

      final rawText = (parts.first['text'] as String? ?? '').trim();
      dev.log('[GeminiAiService] rawText recebido: ${rawText.length > 300 ? rawText.substring(0, 300) : rawText}');

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

  String _extractApiError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      if (message != null) return message;
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  String _normalizeRiskLevel(dynamic raw) {
    final s = (raw as String? ?? '').toLowerCase().trim();
    if (s == 'alto') return 'alto';
    if (s == 'médio' || s == 'medio') return 'médio';
    if (s == 'baixo') return 'baixo';
    return 'desconhecido';
  }
}
