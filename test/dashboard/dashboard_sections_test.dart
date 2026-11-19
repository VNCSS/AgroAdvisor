import 'package:agro_advisor/core/theme/app_theme.dart';
import 'package:agro_advisor/features/dashboard/domain/regional_summary.dart';
import 'package:agro_advisor/features/dashboard/presentation/widgets/regional_section.dart';
import 'package:agro_advisor/features/dashboard/presentation/widgets/weather_section.dart';
import 'package:agro_advisor/features/occurrence/domain/diagnosis_model.dart';
import 'package:agro_advisor/features/occurrence/domain/occurrence_model.dart';
import 'package:agro_advisor/features/weather/domain/weather_forecast.dart';
import 'package:agro_advisor/features/weather/domain/weather_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../weather/weather_fixtures.dart';

final now = DateTime(2026, 10, 2, 12);

// PNG 1×1 válido — evita erro de decodificação no OccurrenceCard.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Widget wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

WeatherForecast forecast({bool withCurrent = true}) {
  final map = validResponse();
  if (!withCurrent) map.remove('current');
  return WeatherForecast.fromMap(map, fetchedAt: DateTime(2026, 10, 2, 10, 5));
}

void main() {
  group('WeatherSection', () {
    testWidgets('carregando', (tester) async {
      await tester.pumpWidget(
        wrap(WeatherSection(result: null, onRetry: () {}, now: now)),
      );
      expect(find.text('Carregando previsão do tempo...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('previsão disponível exibe clima atual e dias', (tester) async {
      await tester.pumpWidget(
        wrap(
          WeatherSection(
            result: WeatherSuccess(forecast()),
            onRetry: () {},
            now: now,
          ),
        ),
      );

      expect(find.text('21,3 °C'), findsOneWidget);
      expect(find.text('82 %'), findsOneWidget);
      expect(find.text('0,1 mm'), findsOneWidget);
      expect(find.text('6,3 km/h'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Amanhã'), findsOneWidget);
      expect(find.text('17,2 mm'), findsOneWidget);
      expect(find.text('94% chance'), findsOneWidget);
      expect(find.textContaining('Open-Meteo.com'), findsOneWidget);
      expect(find.text('Exibindo última previsão obtida'), findsNothing);
    });

    testWidgets('previsão antiga (stale) mostra aviso com horário', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WeatherSection(
            result: WeatherSuccess(forecast(), isStale: true),
            onRetry: () {},
            now: now,
          ),
        ),
      );

      expect(find.text('Exibindo última previsão obtida'), findsOneWidget);
      expect(find.textContaining('02/10 às 10:05'), findsOneWidget);
      expect(find.text('21,3 °C'), findsOneWidget);
    });

    testWidgets('sem bloco current mantém a previsão diária', (tester) async {
      await tester.pumpWidget(
        wrap(
          WeatherSection(
            result: WeatherSuccess(forecast(withCurrent: false)),
            onRetry: () {},
            now: now,
          ),
        ),
      );

      expect(find.text('Condições atuais indisponíveis.'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
    });

    testWidgets('previsão indisponível oferece nova tentativa', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        wrap(
          WeatherSection(
            result: const WeatherFailure(
              WeatherFailureReason.noConnection,
              'Sem conexão',
            ),
            onRetry: () => retries++,
            now: now,
          ),
        ),
      );

      expect(find.text('Previsão indisponível'), findsOneWidget);
      expect(find.text('Sem conexão'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      expect(retries, 1);
    });

    testWidgets('localização ausente não oferece nova tentativa', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WeatherSection(
            result: const WeatherFailure(
              WeatherFailureReason.invalidLocation,
              'Coordenadas inválidas',
            ),
            onRetry: () {},
            now: now,
          ),
        ),
      );

      expect(find.text('Localização ausente'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
    });
  });

  group('RegionalSection', () {
    RegionalSummary summaryOf(List<OccurrenceModel> list) =>
        RegionalSummary.build(
          occurrences: list,
          latitude: -22.73,
          longitude: -47.65,
          radiusKm: 20,
          windowDays: 28,
          now: now,
          userId: 'eu',
          distanceKm: (a, b, c, d) => (d - b).abs(),
        );

    OccurrenceModel occ(String id, double km, int daysAgo, String? pest) =>
        OccurrenceModel(
          id: id,
          imageBase64: _png,
          latitude: -22.73,
          longitude: -47.65 + km,
          timestamp: now.subtract(Duration(days: daysAgo)),
          reportedBy: 'outro',
          diagnosis: pest == null
              ? null
              : DiagnosisModel(
                  pestName: pest,
                  riskLevel: 'alto',
                  description: '',
                  recommendation: '',
                  confidenceScore: 0.9,
                  detectedIssues: const [],
                  analyzedAt: now,
                ),
        );

    testWidgets('sem ocorrências mostra estado vazio', (tester) async {
      await tester.pumpWidget(
        wrap(RegionalSection(summary: summaryOf([]), now: now)),
      );

      expect(
        find.text('Nenhuma ocorrência registrada na região'),
        findsOneWidget,
      );
      expect(find.text('Raio de 20 km · últimos 28 dias'), findsOneWidget);
      expect(find.text('Organismos identificados'), findsNothing);
    });

    testWidgets(
      'com ocorrências mostra indicadores, organismos, tendência e recentes',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RegionalSection(
              summary: summaryOf([
                occ('a', 2, 1, 'Ferrugem asiática'),
                occ('b', 0.5, 3, 'Ferrugem asiática'),
                occ('c', 4, 9, 'Lagarta-do-cartucho'),
                occ('p', 1, 0, null),
              ]),
              now: now,
            ),
          ),
        );

        expect(find.text('Ocorrências registradas'), findsOneWidget);
        expect(find.text('4'), findsOneWidget); // total
        expect(find.text('3'), findsOneWidget); // com problema
        expect(find.text('500 m'), findsOneWidget); // mais próxima
        expect(find.text('Ferrugem asiática'), findsWidgets);
        expect(find.text('2×'), findsOneWidget);
        expect(find.text('Tendência'), findsOneWidget);
        expect(find.text('Ocorrências recentes'), findsOneWidget);
        expect(find.text('a 2,0 km da propriedade'), findsOneWidget);
      },
    );

    testWidgets('só ocorrências pendentes: sem organismos e sem tendência', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          RegionalSection(summary: summaryOf([occ('p', 1, 0, null)]), now: now),
        ),
      );

      expect(
        find.text('Nenhum organismo identificado no período'),
        findsOneWidget,
      );
      expect(find.text('Tendência'), findsNothing);
      expect(find.text('Ocorrências recentes'), findsNothing);
    });
  });

  testWidgets('fonte ampliada (1,6×) em tela estreita não causa overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final summary = RegionalSummary.build(
      occurrences: [
        OccurrenceModel(
          id: 'a',
          imageBase64: _png,
          latitude: -22.73,
          longitude: -47.64,
          timestamp: now.subtract(const Duration(days: 1)),
          reportedBy: 'outro',
          diagnosis: DiagnosisModel(
            pestName: 'Lagarta-do-cartucho com nome bem comprido',
            riskLevel: 'alto',
            description: '',
            recommendation: '',
            confidenceScore: 0.9,
            detectedIssues: const [],
            analyzedAt: now,
          ),
        ),
      ],
      latitude: -22.73,
      longitude: -47.65,
      radiusKm: 20,
      windowDays: 28,
      now: now,
      userId: 'eu',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  WeatherSection(
                    result: WeatherSuccess(forecast()),
                    onRetry: () {},
                    now: now,
                  ),
                  RegionalSection(summary: summary, now: now),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
