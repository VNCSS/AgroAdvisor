import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agro_advisor/services/ai_service.dart';
import 'package:agro_advisor/services/gemini_ai_service.dart';

void main() {
  test('503 muda para Flash-Lite e usa o diagnóstico recebido', () async {
    final models = <String>[];
    final client = MockClient((request) async {
      models.add(request.url.pathSegments.last);
      if (models.length == 1) return http.Response('', 503);
      return http.Response(
        '{"candidates":[{"content":{"parts":[{"text":"{\\"pestName\\":\\"Teste\\"}"}]}}]}',
        200,
      );
    });

    final diagnosis = await http.runWithClient(
      () => GeminiAiService().analyzeImage('imagem'),
      () => client,
    );

    expect(diagnosis.pestName, 'Teste');
    expect(models, [
      'gemini-3.8-flash:generateContent',
      'gemini-3.5-flash-lite:generateContent',
    ]);
  });

  test('timeout repetido encerra a análise após duas tentativas', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      throw TimeoutException('simulado');
    });

    await expectLater(
      http.runWithClient(
        () => GeminiAiService().analyzeImage('imagem'),
        () => client,
      ),
      throwsA(AiUnavailableException.timeout),
    );
    expect(calls, 2);
  });
}
