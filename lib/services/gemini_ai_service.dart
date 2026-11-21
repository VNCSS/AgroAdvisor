import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../features/occurrence/domain/diagnosis_model.dart';
import 'ai_service.dart';

/// Implementação do AiService usando os modelos Gemini Flash e Flash-Lite.
class GeminiAiService implements AiService {
  static const String _apiKey = AppConstants.geminiApiKey;
  static const String _endpoint = AppConstants.geminiEndpoint;

  static const String _systemPrompt =
      '''Especialista em fitossanidade. Analise a imagem e responda APENAS com JSON, sem texto extra.

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
    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _systemPrompt},
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': imageBase64},
            },
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 4096,
        'responseMimeType': 'application/json',
        'thinkingConfig': {'thinkingLevel': 'low'},
      },
    });

    final response = await _request(uri, requestBody, allowRetry: true);
    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }

    if (response.statusCode == 400) {
      final message = _extractApiError(response.body);
      throw Exception('Gemini: requisição inválida — $message');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Gemini: chave de API inválida ou sem permissão (${response.statusCode}). '
        'Gere uma nova em aistudio.google.com/apikey',
      );
    }

    if (response.statusCode == 429) {
      throw const AiRateLimitException();
    }

    throw Exception(
      'Gemini API [${response.statusCode}]: ${_extractApiError(response.body)}',
    );
  }

  Future<http.Response> _request(
    Uri uri,
    String body, {
    required bool allowRetry,
  }) async {
    final http.Response response;
    final client = http.Client();
    final elapsed = Stopwatch()..start();
    final model = uri.pathSegments.last.split(':').first;
    try {
      response = await client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(
            Duration(
              seconds: allowRetry
                  ? AppConstants.aiPrimaryTimeoutSeconds
                  : AppConstants.aiTimeoutSeconds,
            ),
          );
    } on TimeoutException {
      dev.log(
        '[GeminiAiService] $model: timeout após ${elapsed.elapsedMilliseconds} ms',
      );
      if (!allowRetry) throw AiUnavailableException.timeout;
      return _retryWithFallback(body);
    } finally {
      client.close();
    }

    final status = response.statusCode;
    dev.log(
      '[GeminiAiService] $model: HTTP $status em ${elapsed.elapsedMilliseconds} ms',
    );
    if (status == 503 || status == 502 || status == 504) {
      if (!allowRetry) throw AiUnavailableException.serviceUnavailable;
      return _retryWithFallback(body);
    }
    if (status == 429 && allowRetry) {
      final delay = _parseRetryDelay(response.body);
      if (delay != null && delay >= 0 && delay <= 60) {
        return _retry(uri, body, Duration(seconds: delay));
      }
    }
    return response;
  }

  Future<http.Response> _retryWithFallback(String body) => _retry(
    Uri.parse('${AppConstants.geminiFallbackEndpoint}?key=$_apiKey'),
    body,
    const Duration(seconds: 2),
  );

  Future<http.Response> _retry(Uri uri, String body, Duration delay) async {
    await Future<void>.delayed(delay);
    return _request(uri, body, allowRetry: false);
  }

  DiagnosisModel _parseResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Sem candidatos na resposta');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts =
          (content?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (parts.isEmpty) {
        throw const FormatException('Sem partes na resposta');
      }

      final rawText = (parts.first['text'] as String? ?? '').trim();
      dev.log(
        '[GeminiAiService] rawText recebido: ${rawText.length > 300 ? rawText.substring(0, 300) : rawText}',
      );

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
        confidenceScore: (diagnosisMap['confidenceScore'] ?? 0.0)
            .toDouble()
            .clamp(0.0, 1.0),
        detectedIssues: List<String>.from(diagnosisMap['detectedIssues'] ?? []),
        analyzedAt: DateTime.now(),
      );

      dev.log(
        '[GeminiAiService] diagnóstico: ${result.pestName} (${(result.confidenceScore * 100).toStringAsFixed(0)}%)',
      );
      return result;
    } catch (e) {
      dev.log(
        '[GeminiAiService] erro no parse: $e — retornando diagnóstico de fallback',
      );
      return DiagnosisModel(
        pestName: 'Análise inconclusiva',
        riskLevel: 'desconhecido',
        description: 'Não foi possível processar o resultado da análise de IA.',
        recommendation:
            'Consulte um engenheiro agrônomo para avaliação presencial.',
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
