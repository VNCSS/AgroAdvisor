import 'dart:async';

import 'package:agro_advisor/features/favorability/data/favorability_service.dart';
import 'package:agro_advisor/features/favorability/data/scientific_rule_repository.dart';
import 'package:agro_advisor/features/favorability/domain/experimental_profile.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_config.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_engine.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_rule_catalog.dart';
import 'package:agro_advisor/features/favorability/presentation/favorability_screen.dart';
import 'package:agro_advisor/features/property/domain/property_model.dart';
import 'package:agro_advisor/features/weather/domain/weather_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'favorability_test_helpers.dart';

void main() {
  final engine = FavorabilityEngine();
  const property = PropertyModel(
    id: 'real',
    name: 'Propriedade real',
    mainCrop: 'Soja',
    latitude: propertyLat,
    longitude: propertyLng,
    ownerId: 'owner',
  );

  test(
    'Serviço operacional distingue falha regional de consulta vazia',
    () async {
      var failed = true;
      final service = FavorabilityService(
        engine: engine,
        rules: ScientificRuleRepository(),
        now: () => testNow,
        loadOccurrencesSince: (since) async {
          expect(since, testNow.subtract(const Duration(days: 28)));
          if (failed) throw StateError('offline');
          return [];
        },
        loadForecast: (p) async {
          expect(p.id, 'real');
          return WeatherSuccess(
            DemonstrationInput.presets[AttentionLevel.high]!.forecast(testNow),
          );
        },
      );
      final unavailable = await service.assessExperimental(property);
      expect(unavailable.index, isNull);
      expect(unavailable.regional, isNull);
      failed = false;
      final empty = await service.assessExperimental(property);
      expect(empty.simulated, isFalse);
      expect(empty.index, 60);
      expect(empty.regional!.count, 0);
    },
  );

  test(
    'Falha meteorológica operacional e cache antigo ficam explícitos',
    () async {
      var offline = true;
      final service = FavorabilityService(
        engine: engine,
        rules: ScientificRuleRepository(),
        now: () => testNow,
        loadOccurrencesSince: (_) async => [],
        loadForecast: (_) async {
          if (offline) throw StateError('offline');
          return WeatherSuccess(
            DemonstrationInput.presets[AttentionLevel.high]!.forecast(testNow),
            isStale: true,
          );
        },
      );
      expect((await service.assessExperimental(property)).index, isNull);
      offline = false;
      expect(
        (await service.assessExperimental(property)).warnings.join(),
        contains('cache'),
      );
    },
  );
  for (final entry in DemonstrationInput.presets.entries) {
    test('Cenário ${entry.key.label} usa a fórmula do motor', () {
      final result = engine.demonstrate(entry.value, testNow);
      expect(result.level, entry.key);
      expect(result.index, [0, 40, 60, 100][entry.key.index]);
      expect(result.simulated, isTrue);
    });
  }

  test('Clima ausente, parcial ou regional indisponível não gera índice', () {
    for (final weather in [
      null,
      forecast(
        hours: 71,
        temperature: (_) => 26,
        humidity: (_) => 85,
        precipitation: (_) => 0,
      ),
    ]) {
      expect(
        engine
            .assessExperimental(
              property: testProperty(),
              occurrences: [],
              forecast: weather,
              now: testNow,
            )
            .index,
        isNull,
      );
    }
    expect(
      engine
          .assessExperimental(
            property: testProperty(),
            occurrences: null,
            forecast: DemonstrationInput.presets[AttentionLevel.high]!.forecast(
              testNow,
            ),
            now: testNow,
          )
          .index,
      isNull,
    );
  });

  test('Valores não finitos e fora dos limites físicos são insuficientes', () {
    for (final input in [
      const DemonstrationInput(-91, 85, 12, false),
      const DemonstrationInput(61, 85, 12, false),
      const DemonstrationInput(26, -1, 12, false),
      const DemonstrationInput(26, 101, 12, false),
      const DemonstrationInput(26, 85, -1, false),
      const DemonstrationInput(double.nan, 85, 12, false),
      const DemonstrationInput(26, double.infinity, 12, false),
    ]) {
      expect(engine.demonstrate(input, testNow).index, isNull);
    }
  });

  test(
    'Zero registros não significa ausência de risco e permite clima alto',
    () {
      final result = engine.demonstrate(
        DemonstrationInput.presets[AttentionLevel.high]!,
        testNow,
      );
      expect(result.regional!.count, 0);
      expect(result.index, 60);
      expect(
        result.warnings.join(),
        contains('não significa ausência de risco'),
      );
    },
  );

  test('Limites inclusivos experimentais e precipitação total de 72 h', () {
    for (final temperature in [22.0, 30.0]) {
      for (final rain in [5.0, 30.0]) {
        expect(
          engine
              .demonstrate(
                DemonstrationInput(temperature, 80, rain, false),
                testNow,
              )
              .index,
          60,
        );
      }
    }
    expect(
      engine
          .demonstrate(
            const DemonstrationInput(21.9, 79.9, 4.9, false),
            testNow,
          )
          .index,
      0,
    );
    expect(
      engine
          .demonstrate(const DemonstrationInput(30.1, 85, 30.1, false), testNow)
          .index,
      20,
    );
  });

  test('Limites das quatro classificações', () {
    const levels = AttentionLevelThresholds();
    for (final entry in {
      0: AttentionLevel.low,
      29: AttentionLevel.low,
      30: AttentionLevel.moderate,
      54: AttentionLevel.moderate,
      55: AttentionLevel.high,
      74: AttentionLevel.high,
      75: AttentionLevel.veryHigh,
      100: AttentionLevel.veryHigh,
    }.entries) {
      expect(levels.levelFor(entry.key), entry.value);
    }
  });

  test('Triagem regional real mantém raio, janela e deduplicação', () {
    final result = engine.assessExperimental(
      property: testProperty(),
      occurrences: [
        occ('A', km: 51),
        occ('B', daysAgo: 29),
        occ('C', id: 'same'),
        occ('C', id: 'same'),
      ],
      forecast: DemonstrationInput.presets[AttentionLevel.high]!.forecast(
        testNow,
      ),
      now: testNow,
    );
    expect(result.regional!.count, 1);
  });

  test('Demonstração não modifica entradas reais nem catálogo científico', () {
    final occurrences = [occ('Real')];
    final weather = mildForecast();
    final before = engine.assessExperimental(
      property: testProperty(),
      occurrences: occurrences,
      forecast: weather,
      now: testNow,
    );
    engine.demonstrate(
      DemonstrationInput.presets[AttentionLevel.veryHigh]!,
      testNow,
    );
    final after = engine.assessExperimental(
      property: testProperty(),
      occurrences: occurrences,
      forecast: weather,
      now: testNow,
    );
    expect(after.index, before.index);
    expect(occurrences.single.organismName, 'Real');
    expect(
      engine
          .assess(
            property: testProperty(),
            occurrences: occurrences,
            catalog: ScientificRuleCatalog.empty,
            forecast: weather,
            now: testNow,
          )
          .organisms
          .single
          .hasIndex,
      isFalse,
    );
  });

  testWidgets(
    'Demo não chama fontes reais; desativar apaga resultado e entradas',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: FavorabilityScreen(
            loadOperational: () async {
              loads++;
              return engine.assessExperimental(
                property: testProperty(),
                occurrences: [],
                forecast: null,
                now: testNow,
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '26');
      await tester.scrollUntilVisible(
        find.text('Executar avaliação').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Executar avaliação'));
      await tester.pumpAndSettle();
      expect(loads, 0);
      await tester.scrollUntilVisible(
        find.text('Resultado simulado e experimental').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Resultado simulado e experimental'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Resultado simulado e experimental'), findsNothing);
      expect(find.text('MODO DEMONSTRAÇÃO — DADOS SIMULADOS'), findsNothing);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '15.0',
      );
      expect(loads, 0);
    },
  );

  testWidgets('Resposta operacional atrasada não invade demonstração', (
    tester,
  ) async {
    final pending = Completer<ExperimentalAssessment>();
    await tester.pumpWidget(
      MaterialApp(
        home: FavorabilityScreen(loadOperational: () => pending.future),
      ),
    );
    await tester.tap(find.text('Executar avaliação'));
    await tester.pump();
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    pending.complete(
      engine.assessExperimental(
        property: testProperty(),
        occurrences: [],
        forecast: null,
        now: testNow,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resultado experimental com dados reais'), findsNothing);
    expect(find.text('MODO DEMONSTRAÇÃO — DADOS SIMULADOS'), findsOneWidget);
  });
}
