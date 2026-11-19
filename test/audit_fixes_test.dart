// Testes das correções da auditoria de integração.

import 'package:agro_advisor/features/dashboard/domain/regional_summary.dart';
import 'package:agro_advisor/features/occurrence/domain/diagnosis_model.dart';
import 'package:agro_advisor/features/occurrence/domain/occurrence_model.dart';
import 'package:agro_advisor/features/occurrence/presentation/widgets/occurrence_card.dart';
import 'package:agro_advisor/features/property/presentation/screens/property_form_screen.dart';
import 'package:agro_advisor/services/auth_service.dart';
import 'package:agro_advisor/services/nearby_alert_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosisModel _diag(String name) => DiagnosisModel(
      pestName: name,
      riskLevel: 'alto',
      description: '',
      recommendation: '',
      confidenceScore: 0.9,
      detectedIssues: const [],
      analyzedAt: DateTime(2026, 10, 1),
    );

OccurrenceModel _occ(String id, {DiagnosisModel? diagnosis, double lat = -22.0}) =>
    OccurrenceModel(
      id: id,
      imageBase64: 'AAAA', // imagem inválida → errorBuilder do card
      latitude: lat,
      longitude: -47.0,
      timestamp: DateTime(2026, 10, 9),
      reportedBy: 'author',
      diagnosis: diagnosis,
    );

void main() {
  group('A5 — botão "Analisar com IA" só para o autor', () {
    Future<void> pump(WidgetTester t, OccurrenceModel o, {bool? canAnalyze}) =>
        t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: canAnalyze == null
                ? OccurrenceCard(occurrence: o)
                : OccurrenceCard(occurrence: o, canAnalyze: canAnalyze),
          ),
        ));

    testWidgets('autor (padrão) vê o botão — comportamento preservado',
        (t) async {
      await pump(t, _occ('a'));
      expect(find.text('Analisar com IA'), findsOneWidget);
    });

    testWidgets('outro usuário vê "Aguardando análise", sem botão', (t) async {
      await pump(t, _occ('a'), canAnalyze: false);
      expect(find.text('Analisar com IA'), findsNothing);
      expect(find.text('Aguardando análise'), findsOneWidget);
    });

    testWidgets('com diagnóstico, exibe o organismo para todos', (t) async {
      await pump(t, _occ('a', diagnosis: _diag('Organismo X')),
          canAnalyze: false);
      expect(find.text('Organismo X'), findsOneWidget);
      expect(find.text('Aguardando análise'), findsNothing);
    });
  });

  group('A2 — alertas de proximidade só para ocorrências recentes', () {
    final now = DateTime(2026, 10, 13, 12);

    test('dentro de 7 dias → alerta', () {
      expect(NearbyAlertService.isRecentForAlert(now, now), isTrue);
      expect(
          NearbyAlertService.isRecentForAlert(
              now.subtract(const Duration(days: 7)), now),
          isTrue);
    });

    test('mais antiga que 7 dias → sem alerta', () {
      expect(
          NearbyAlertService.isRecentForAlert(
              now.subtract(const Duration(days: 7, minutes: 1)), now),
          isFalse);
      expect(
          NearbyAlertService.isRecentForAlert(DateTime(2025, 1, 1), now),
          isFalse);
    });
  });

  group('M4 — mensagens de erro do login', () {
    test('invalid-credential (SDK atual) tem mensagem específica', () {
      expect(AuthService.mapFirebaseAuthError('invalid-credential'),
          'E-mail ou senha incorretos.');
      expect(AuthService.mapFirebaseAuthError('network-request-failed'),
          contains('Sem conexão'));
    });

    test('códigos existentes preservados', () {
      expect(AuthService.mapFirebaseAuthError('wrong-password'),
          'Senha incorreta.');
      expect(AuthService.mapFirebaseAuthError('user-not-found'),
          'Usuário não encontrado.');
      expect(AuthService.mapFirebaseAuthError('email-already-in-use'),
          'Este e-mail já está cadastrado.');
      expect(AuthService.mapFirebaseAuthError('weak-password'),
          'A senha deve ter pelo menos 6 caracteres.');
      expect(AuthService.mapFirebaseAuthError('qualquer-outro'),
          'Ocorreu um erro. Tente novamente.');
    });
  });

  group('B2 — coordenadas da propriedade', () {
    test('aceita ponto e vírgula decimal', () {
      expect(parseCoordinate('-22.9035'), -22.9035);
      expect(parseCoordinate(' -22,9035 '), -22.9035);
      expect(parseCoordinate('abc'), isNull);
    });

    test('valida faixa de latitude e longitude', () {
      expect(validateCoordinate('', limit: 90), 'Campo obrigatório');
      expect(validateCoordinate('x', limit: 90), 'Número inválido');
      expect(validateCoordinate('-22,5', limit: 90), isNull);
      expect(validateCoordinate('95', limit: 90), 'Deve estar entre -90 e 90');
      expect(validateCoordinate('-47,1', limit: 180), isNull);
      expect(validateCoordinate('-181', limit: 180),
          'Deve estar entre -180 e 180');
    });
  });

  group('M9 — Dashboard agrupa nomes como o motor', () {
    test('variações de acento/pontuação viram um só organismo', () {
      final now = DateTime(2026, 10, 10);
      final s = RegionalSummary.build(
        occurrences: [
          _occ('1', diagnosis: _diag('Ferrugem asiática')),
          _occ('2', diagnosis: _diag('Ferrugem Asiatica')),
          _occ('3', diagnosis: _diag('ferrugem-asiática')),
        ],
        latitude: -22.0,
        longitude: -47.0,
        radiusKm: 20,
        windowDays: 28,
        now: now,
        userId: 'u',
        distanceKm: (_, _, _, _) => 1,
      );
      expect(s.organisms, hasLength(1));
      expect(s.organisms.single.count, 3);
      // A grafia exibida continua sendo a mais frequente / primeira.
      expect(s.organisms.single.name, 'Ferrugem asiática');
    });
  });
}
