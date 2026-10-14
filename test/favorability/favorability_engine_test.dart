import 'package:agro_advisor/features/favorability/data/favorability_service.dart';
import 'package:agro_advisor/features/favorability/data/scientific_rule_repository.dart';
import 'package:agro_advisor/features/favorability/domain/criteria.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_config.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_engine.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_result.dart';
import 'package:agro_advisor/features/favorability/domain/regional_occurrence.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_pest_rule.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_rule_catalog.dart';
import 'package:agro_advisor/features/favorability/domain/weather_factor_evaluator.dart';
import 'package:agro_advisor/features/occurrence/domain/diagnosis_model.dart';
import 'package:agro_advisor/features/occurrence/domain/occurrence_model.dart';
import 'package:agro_advisor/features/property/domain/property_model.dart';
import 'package:agro_advisor/features/weather/domain/weather_forecast.dart';
import 'package:agro_advisor/features/weather/domain/weather_result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'favorability_test_helpers.dart';

final engine = FavorabilityEngine();

FavorabilityReport run({
  required List<ScientificPestRule> rules,
  required List<RegionalOccurrence> occurrences,
  WeatherForecast? weather,
  PropertyContext? property,
  FavorabilityEngine? withEngine,
  bool stale = false,
}) =>
    (withEngine ?? engine).assess(
      property: property ?? testProperty(),
      occurrences: occurrences,
      catalog: ScientificRuleCatalog(rules),
      forecast: weather,
      now: testNow,
      forecastIsStale: stale,
    );

OrganismAssessment single(FavorabilityReport r) {
  expect(r.organisms, hasLength(1));
  return r.organisms.single;
}

FactorEvaluation factor(OrganismAssessment a, FactorKind kind) =>
    a.environmental!.factors.singleWhere((f) => f.kind == kind);

final tempRule = testRule(
  temperature: const TemperatureCriteria(min: 15, max: 25),
);

void main() {
  group('1. temperatura favorável', () {
    test('todas as horas na faixa → favorável, pontuação 1', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(temperature: 20),
      ));
      final f = factor(a, FactorKind.temperature);
      expect(f.status, FactorStatus.favorable);
      expect(f.score, 1.0);
      expect(f.detail, contains('72 de 72 horas'));
      expect(a.status, AssessmentStatus.assessed);
    });

    test('fora da faixa ótima, mas tolerada → pontuação reduzida', () {
      final rule = testRule(
        temperature: const TemperatureCriteria(
            min: 10, max: 30, optimalMin: 18, optimalMax: 22),
      );
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(temperature: 27),
      ));
      final f = factor(a, FactorKind.temperature);
      expect(f.score, const WeatherEvaluationConfig().suboptimalTemperatureScore);
      expect(f.status, FactorStatus.partiallyFavorable);
    });
  });

  group('2. temperatura desfavorável', () {
    test('todas as horas fora da faixa → desfavorável e índice menor', () {
      final hot = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(temperature: 35),
      ));
      final mild = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(temperature: 20),
      ));
      expect(factor(hot, FactorKind.temperature).status,
          FactorStatus.unfavorable);
      expect(factor(hot, FactorKind.temperature).score, 0.0);
      expect(hot.favorabilityIndex!, lessThan(mild.favorabilityIndex!));
      expect(hot.environmental!.score, 0.0);
    });

    test('regra só com valor ótimo pontual não é avaliada', () {
      final rule = testRule(temperature: const TemperatureCriteria(optimal: 22));
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(),
      ));
      expect(factor(a, FactorKind.temperature).status,
          FactorStatus.notEvaluable);
      expect(a.status, AssessmentStatus.insufficientWeatherData);
      expect(a.favorabilityIndex, isNull);
    });
  });

  group('3. umidade favorável', () {
    final rule = testRule(
      humidity: const HumidityCriteria(min: 85, minDurationHours: 6),
    );

    test('UR alta contínua atende à duração → favorável', () {
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(humidity: 95),
      ));
      final f = factor(a, FactorKind.humidity);
      expect(f.status, FactorStatus.favorable);
      expect(f.detail, contains('72 h'));
    });

    test('sequência menor que a duração → parcial', () {
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(humidity: (h) => h < 3 ? 95 : 60),
      ));
      final f = factor(a, FactorKind.humidity);
      expect(f.score, closeTo(0.5, 1e-9));
      expect(f.status, FactorStatus.partiallyFavorable);
    });

    test('sem duração na regra → fração de horas', () {
      final a = single(run(
        rules: [testRule(humidity: const HumidityCriteria(min: 80))],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(humidity: (h) => h.isEven ? 90 : 50),
      ));
      expect(factor(a, FactorKind.humidity).score, closeTo(0.5, 1e-9));
    });
  });

  group('4. chuva favorável', () {
    final amountRule = testRule(
      precipitation: const PrecipitationCriteria(
        minAmountMm: 5,
        periodHours: 24,
        condition: PrecipitationCondition.favorable,
      ),
    );

    test('acumulado em 24 h atinge o mínimo → favorável', () {
      final a = single(run(
        rules: [amountRule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(precipitation: (h) => h >= 30 && h < 40 ? 1.0 : 0),
      ));
      final f = factor(a, FactorKind.precipitation);
      expect(f.status, FactorStatus.favorable);
      expect(f.detail, contains('10 mm'));
    });

    test('sem chuva → desfavorável', () {
      final a = single(run(
        rules: [amountRule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(precipitation: (_) => 0),
      ));
      expect(factor(a, FactorKind.precipitation).status,
          FactorStatus.unfavorable);
    });

    test('regra só com condição: chuva prevista é favorável', () {
      final rule = testRule(
        precipitation: const PrecipitationCriteria(
            condition: PrecipitationCondition.favorable),
      );
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(precipitation: (h) => h == 10 ? 2.0 : 0),
      ));
      expect(factor(a, FactorKind.precipitation).status,
          FactorStatus.favorable);
    });

    test('chuva desfavorável na regra inverte a avaliação', () {
      final rule = testRule(
        precipitation: const PrecipitationCriteria(
            condition: PrecipitationCondition.unfavorable),
      );
      final rainy = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(precipitation: (_) => 3.0),
      ));
      final dry = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(precipitation: (_) => 0),
      ));
      expect(factor(rainy, FactorKind.precipitation).status,
          FactorStatus.unfavorable);
      expect(factor(dry, FactorKind.precipitation).status,
          FactorStatus.favorable);
    });
  });

  group('5. múltiplos fatores', () {
    final rule = testRule(
      temperature: const TemperatureCriteria(min: 15, max: 25),
      humidity: const HumidityCriteria(min: 85),
      leafWetness: const LeafWetnessCriteria(minDurationHours: 6),
      dewPoint: const DewPointCriteria(maxDepression: 2),
      wind: const WindCriteria(maxSpeed: 20),
    );

    test('cada parâmetro da regra é avaliado e explicado', () {
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(temperature: 20, humidity: 95, wind: 30),
      ));
      final env = a.environmental!;
      expect(env.factors.map((f) => f.kind), [
        FactorKind.temperature,
        FactorKind.humidity,
        FactorKind.leafWetness,
        FactorKind.dewPoint,
        FactorKind.wind,
      ]);
      expect(factor(a, FactorKind.wind).status, FactorStatus.unfavorable);
      // 4 fatores com 1,0 e 1 com 0 (pesos iguais).
      expect(env.score, closeTo(0.8, 1e-9));
      expect(env.coverage, 1.0);
    });

    test('molhamento e orvalho são rotulados como estimados', () {
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(humidity: 95),
      ));
      final wet = factor(a, FactorKind.leafWetness);
      expect(wet.estimated, isTrue);
      expect(wet.kind.label, 'condição estimada de molhamento');
      expect(wet.detail, contains('não é medição'));
      expect(factor(a, FactorKind.dewPoint).estimated, isTrue);
      expect(a.explanation.join('\n'),
          contains('- condição estimada de molhamento: favorável'));
    });

    test('pesos configuráveis alteram o componente ambiental', () {
      final weighted = FavorabilityEngine(
        config: const FavorabilityConfig(
          scoring: ScoringConfig(factorWeights: {FactorKind.wind: 4}),
        ),
      );
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(temperature: 20, humidity: 95, wind: 30),
        withEngine: weighted,
      ));
      expect(a.environmental!.score, closeTo(4 / 8, 1e-9));
    });

    test('ponto de orvalho pela fórmula de Magnus', () {
      // UR 100% → ponto de orvalho = temperatura.
      expect(WeatherFactorEvaluator.dewPointMagnus(20, 100), closeTo(20, 1e-9));
      expect(WeatherFactorEvaluator.dewPointMagnus(25, 50),
          closeTo(13.85, 0.05));
      expect(WeatherFactorEvaluator.dewPointMagnus(20, 0), isNull);
    });

    test('explicação traz índice como métrica do sistema, sem prever ocorrência',
        () {
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste', km: 6.2, daysAgo: 2)],
        weather: mildForecast(humidity: 95),
      ));
      final text = a.explanation.join('\n');
      expect(text, contains('Organismo: Organismo de Teste'));
      expect(text, contains('Índice de favorabilidade: ${a.favorabilityIndex}/100'));
      expect(text, contains('ocorrência mais próxima: 6,2 km'));
      expect(text, contains('ocorrência mais recente: há 2 dias'));
      expect(text, contains('Resultado: ${a.level!.headline}'));
      expect(text, contains(favorabilityIndexDisclaimer));
      expect(text, contains('Fonte: Fonte fictícia (teste)'));
      expect(text, isNot(contains('chance')));
      expect(text, isNot(contains('irá ocorrer')));
    });
  });

  group('6. regra parcial', () {
    test('só os parâmetros da regra são avaliados', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(),
      ));
      expect(a.environmental!.factors, hasLength(1));
    });

    test('parâmetro sem dado na previsão fica "não avaliado"', () {
      final rule = testRule(
        temperature: const TemperatureCriteria(min: 15, max: 25),
        humidity: const HumidityCriteria(min: 85),
      );
      // Previsão sem umidade.
      final weather = forecast(temperature: (_) => 20);
      final a = single(run(
          rules: [rule], occurrences: [occ('Organismo de Teste')], weather: weather));
      expect(factor(a, FactorKind.humidity).status, FactorStatus.notEvaluable);
      expect(a.environmental!.coverage, 0.5);
      // Cobertura 50% atinge o mínimo padrão (50%): índice só com temperatura.
      expect(a.status, AssessmentStatus.assessed);
      expect(a.environmental!.score, 1.0);

      final strict = FavorabilityEngine(
        config: const FavorabilityConfig(
          weather: WeatherEvaluationConfig(minEnvironmentalCoverage: 0.75),
        ),
      );
      final b = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: weather,
        withEngine: strict,
      ));
      expect(b.status, AssessmentStatus.insufficientWeatherData);
      expect(b.favorabilityIndex, isNull);
      expect(b.reasons.single, contains('umidade relativa'));
    });

    test('fenologia sem estádio informado não pontua nem bloqueia', () {
      final rule = testRule(
        temperature: const TemperatureCriteria(min: 15, max: 25),
        phenology: const PhenologyCriteria(susceptibleStages: ['R1', 'R2']),
      );
      final a = single(run(
          rules: [rule],
          occurrences: [occ('Organismo de Teste')],
          weather: mildForecast()));
      expect(factor(a, FactorKind.phenology).status, FactorStatus.notEvaluable);
      expect(a.status, AssessmentStatus.assessed);

      final b = single(run(
          rules: [rule],
          occurrences: [occ('Organismo de Teste')],
          weather: mildForecast(),
          property: testProperty(cropStage: 'v4')));
      expect(factor(b, FactorKind.phenology).status, FactorStatus.unfavorable);
      expect(b.environmental!.score, 0.5);
    });
  });

  group('7. ausência de regra', () {
    test('sem regra → sem índice, mensagem padrão, ocorrências mantidas', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo Desconhecido', km: 3),
          occ('organismo desconhecido', km: 8),
        ],
        weather: mildForecast(),
      ));
      expect(a.status, AssessmentStatus.insufficientScientificData);
      expect(a.message,
          'Não existem parâmetros científicos suficientes para estimar a '
          'favorabilidade ambiental deste organismo.');
      expect(a.favorabilityIndex, isNull);
      expect(a.level, isNull);
      expect(a.environmental, isNull);
      expect(a.regional.count, 2);
      expect(a.explanation.join('\n'), isNot(contains('Índice')));
    });

    test('regra indisponível → mesmo estado, com o motivo', () {
      final rule = ScientificPestRule(
        id: 'test-unavailable',
        organismName: 'Organismo Sem Evidência',
        unavailabilityReason: 'Evidência insuficiente (teste)',
      );
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo Sem Evidência')],
        weather: mildForecast(),
      ));
      expect(a.status, AssessmentStatus.insufficientScientificData);
      expect(a.rule, isNotNull);
      expect(a.reasons, ['Evidência insuficiente (teste)']);
    });
  });

  group('8. ausência de ocorrências', () {
    test('nenhuma ocorrência → noRecentOccurrences', () {
      final r = run(rules: [tempRule], occurrences: [], weather: mildForecast());
      expect(r.status, ReportStatus.noRecentOccurrences);
      expect(r.organisms, isEmpty);
    });

    test('só ocorrências fora do raio/período → noRecentOccurrences', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', km: 80),
          occ('Organismo de Teste', daysAgo: 40),
        ],
        weather: mildForecast(),
      );
      expect(r.status, ReportStatus.noRecentOccurrences);
      expect(r.screening.outsideRadius, 1);
      expect(r.screening.outsideWindow, 1);
    });

    test('ocorrências saudáveis/sem diagnóstico não viram evidência', () {
      OccurrenceModel model(String id, DiagnosisModel? d) => OccurrenceModel(
            id: id,
            imageBase64: '',
            latitude: propertyLat,
            longitude: propertyLng,
            timestamp: testNow,
            reportedBy: 'u',
            diagnosis: d,
          );
      DiagnosisModel diag(String name, String risk) => DiagnosisModel(
            pestName: name,
            riskLevel: risk,
            description: '',
            recommendation: '',
            confidenceScore: 0.9,
            detectedIssues: const [],
            analyzedAt: testNow,
          );
      expect(RegionalOccurrence.fromOccurrence(model('a', null)), isNull);
      expect(
          RegionalOccurrence.fromOccurrence(
              model('b', diag('Nenhuma praga', 'baixo'))),
          isNull);
      final ok = RegionalOccurrence.fromOccurrence(
          model('c', diag('Organismo de Teste', 'alto')))!;
      expect(ok.organismName, 'Organismo de Teste');
      expect(ok.diagnosisConfidence, 0.9);
      expect(ok.crop, isNull);
    });
  });

  group('9. múltiplas ocorrências', () {
    test('mais ocorrências → maior evidência regional, limitada a 1', () {
      RegionalEvidence evidence(int n) => single(run(
            rules: [tempRule],
            occurrences: [
              for (var i = 0; i < n; i++)
                occ('Organismo de Teste', km: 2, reportedBy: 'user-$i'),
            ],
            weather: mildForecast(),
          )).regional;

      final one = evidence(1), three = evidence(3), many = evidence(30);
      expect(three.count, 3);
      expect(three.score, greaterThan(one.score));
      expect(many.score, 1.0);
      expect(three.withinConcentrationRadius, 3);
    });

    test('mais evidência com o mesmo clima → índice maior ou igual', () {
      int index(int n) => single(run(
            rules: [tempRule],
            occurrences: [
              for (var i = 0; i < n; i++)
                occ('Organismo de Teste', reportedBy: 'user-$i'),
            ],
            weather: mildForecast(),
          )).favorabilityIndex!;
      expect(index(5), greaterThan(index(1)));
    });
  });

  group('10. diferentes distâncias', () {
    test('ocorrência próxima pesa mais que distante', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', km: 2, reportedBy: 'a'),
          occ('Organismo de Teste', km: 40, reportedBy: 'b'),
        ],
        weather: mildForecast(),
      ));
      final byDist = {
        for (final e in a.regional.occurrences) e.distanceKm.round(): e.weight,
      };
      expect(byDist[2]!, greaterThan(byDist[40]!));
      expect(a.regional.nearestKm, closeTo(2, 0.01));
      expect(a.regional.withinConcentrationRadius, 1);
    });

    test('raio configurável', () {
      final r = run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste', km: 30)],
        weather: mildForecast(),
        withEngine: FavorabilityEngine(
          config: const FavorabilityConfig(
            occurrences: OccurrenceEvidenceConfig(radiusKm: 20),
          ),
        ),
      );
      expect(r.status, ReportStatus.noRecentOccurrences);
    });

    test('localização inválida da propriedade → locationUnavailable', () {
      final r = engine.assess(
        property: const PropertyContext(id: 'p', latitude: 0, longitude: 0),
        occurrences: [occ('Organismo de Teste')],
        catalog: ScientificRuleCatalog([tempRule]),
        forecast: mildForecast(),
        now: testNow,
      );
      expect(r.status, ReportStatus.locationUnavailable);
      expect(r.organisms, isEmpty);
    });

    test('ocorrência com coordenada inválida é descartada', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          RegionalOccurrence(
            id: 'bad',
            organismName: 'Organismo de Teste',
            latitude: 0,
            longitude: 0,
            timestamp: testNow,
          ),
        ],
        weather: mildForecast(),
      );
      expect(r.screening.invalidLocation, 1);
      expect(r.status, ReportStatus.noRecentOccurrences);
    });
  });

  group('11. diferentes datas', () {
    test('ocorrência recente pesa mais que antiga; mais recente primeiro', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', daysAgo: 20, reportedBy: 'a'),
          occ('Organismo de Teste', daysAgo: 1, reportedBy: 'b'),
        ],
        weather: mildForecast(),
      ));
      final items = a.regional.occurrences;
      expect(items.first.ageDays, closeTo(1, 1e-9));
      expect(items.first.weight, greaterThan(items.last.weight));
    });

    test('fora da janela ou no futuro é ignorada', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', daysAgo: 29),
          occ('Organismo de Teste', daysAgo: -1),
          occ('Organismo de Teste', daysAgo: 27),
        ],
        weather: mildForecast(),
      );
      expect(r.screening.outsideWindow, 2);
      expect(single(r).regional.count, 1);
    });

    test('"hoje" e "ontem" na explicação', () {
      final today = single(run(
          rules: [tempRule],
          occurrences: [occ('Organismo de Teste', daysAgo: 0)],
          weather: mildForecast()));
      expect(today.explanation.join('\n'),
          contains('ocorrência mais recente: hoje'));
    });
  });

  group('12. diferentes culturas', () {
    final soyRule = testRule(
      crops: ['Soja', 'Feijão'],
      temperature: const TemperatureCriteria(min: 15, max: 25),
    );

    test('cultura não listada na regra → cropNotAffected, sem índice', () {
      final a = single(run(
        rules: [soyRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(),
        property: testProperty(crop: 'Milho'),
      ));
      expect(a.status, AssessmentStatus.cropNotAffected);
      expect(a.favorabilityIndex, isNull);
      expect(a.regional.count, 1);
    });

    test('cultura listada (sem acento/caixa) → avaliado', () {
      final a = single(run(
        rules: [soyRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(),
        property: testProperty(crop: 'feijao'),
      ));
      expect(a.status, AssessmentStatus.assessed);
    });

    test('cultura ausente ou "Outro" → avaliado, com aviso', () {
      for (final crop in [null, '', 'Outro']) {
        final r = run(
          rules: [soyRule],
          occurrences: [occ('Organismo de Teste')],
          weather: mildForecast(),
          property: testProperty(crop: crop),
        );
        expect(r.crop, isNull, reason: '$crop');
        expect(r.warnings, contains(ReportWarning.cropMissing));
        expect(single(r).status, AssessmentStatus.assessed);
      }
    });

    test('ocorrência em outra cultura é descartada; sem cultura é mantida',
        () {
      final r = run(
        rules: [soyRule],
        occurrences: [
          occ('Organismo de Teste', crop: 'Milho', reportedBy: 'a'),
          occ('Organismo de Teste', crop: 'soja', reportedBy: 'b'),
          occ('Organismo de Teste', reportedBy: 'c'),
        ],
        weather: mildForecast(),
      );
      expect(r.screening.otherCrop, 1);
      expect(single(r).regional.count, 2);
      expect(single(r).regional.unknownCropCount, 1);
      expect(r.warnings, contains(ReportWarning.occurrenceCropUnknown));
    });
  });

  group('13. múltiplos organismos', () {
    test('cada organismo é avaliado pela própria regra', () {
      final fungus = testRule(
        id: 'test-fungus',
        name: 'Fungo de Teste',
        scientificName: 'Fungus fictitius',
        temperature: const TemperatureCriteria(min: 15, max: 25),
      );
      final insect = testRule(
        id: 'test-insect',
        name: 'Inseto de Teste',
        temperature: const TemperatureCriteria(min: 28, max: 35),
      );
      final r = run(
        rules: [fungus, insect],
        occurrences: [
          occ('Fungo de Teste', reportedBy: 'a'),
          occ('Fungus fictitius', reportedBy: 'b'),
          occ('Inseto de Teste', reportedBy: 'c'),
          occ('Organismo Sem Regra', reportedBy: 'd'),
        ],
        weather: mildForecast(temperature: 20),
      );
      expect(r.status, ReportStatus.ok);
      expect(r.organisms, hasLength(3));
      final byName = {for (final a in r.organisms) a.organismName: a};

      final f = byName['Fungo de Teste']!;
      expect(f.regional.count, 2, reason: 'nome científico agrupa no mesmo');
      expect(f.reportedNames, {'Fungo de Teste', 'Fungus fictitius'});
      expect(factor(f, FactorKind.temperature).status, FactorStatus.favorable);

      final i = byName['Inseto de Teste']!;
      expect(factor(i, FactorKind.temperature).status, FactorStatus.unfavorable);

      expect(byName['Organismo Sem Regra']!.status,
          AssessmentStatus.insufficientScientificData);

      // Com índice primeiro, maior índice primeiro.
      expect(r.organisms.map((a) => a.organismName).toList(),
          ['Fungo de Teste', 'Inseto de Teste', 'Organismo Sem Regra']);
    });
  });

  group('14. graus-dia', () {
    ScientificPestRule ddRule(DegreeDayCriteria c) => testRule(degreeDays: c);

    FactorEvaluation dd(DegreeDayCriteria c, WeatherForecast w) =>
        factor(single(run(rules: [ddRule(c)], occurrences: [occ('Organismo de Teste')], weather: w)),
            FactorKind.degreeDays);

    test('acumulado projetado atinge a referência → favorável', () {
      // 20 °C, base 10 → 10 GD/dia × 7 dias = 70.
      final f = dd(
        const DegreeDayCriteria(
            baseTemperature: 10,
            thresholds: [DegreeDayThreshold(accumulated: 50, stage: 'geração (teste)')]),
        mildForecast(temperature: 20),
      );
      expect(f.status, FactorStatus.favorable);
      expect(f.detail, contains('70 graus-dia projetados em 7 dias'));
      expect(f.detail, contains('geração (teste)'));
    });

    test('acumulado parcial → pontuação proporcional', () {
      final f = dd(
        const DegreeDayCriteria(
            baseTemperature: 10,
            thresholds: [DegreeDayThreshold(accumulated: 140)]),
        mildForecast(temperature: 20),
      );
      expect(f.score, closeTo(0.5, 1e-9));
    });

    test('limite superior corta a temperatura', () {
      final f = dd(
        const DegreeDayCriteria(
            baseTemperature: 10,
            upperThreshold: 25,
            thresholds: [DegreeDayThreshold(accumulated: 1000)]),
        mildForecast(temperature: 30),
      );
      // (25 − 10) × 7 = 105.
      expect(f.detail, contains('105 graus-dia'));
    });

    test('sem temperatura-base → não avaliado (nunca inventada)', () {
      final f = dd(
        const DegreeDayCriteria(upperThreshold: 30),
        mildForecast(),
      );
      expect(f.status, FactorStatus.notEvaluable);
      expect(f.detail, contains('temperatura-base'));
    });

    test('sem acumulado de referência → informativo, não pontua', () {
      final f = dd(const DegreeDayCriteria(baseTemperature: 10), mildForecast());
      expect(f.status, FactorStatus.informational);
      expect(f.score, isNull);
    });

    test('poucos dias completos → não avaliado', () {
      final f = dd(
        const DegreeDayCriteria(
            baseTemperature: 10, thresholds: [DegreeDayThreshold(accumulated: 10)]),
        forecast(hours: 48, temperature: (_) => 20),
      );
      expect(f.status, FactorStatus.notEvaluable);
      expect(f.detail, contains('disponíveis: 2'));
    });

    test('dia com hora sem temperatura é descartado, não extrapolado', () {
      final f = dd(
        const DegreeDayCriteria(
            baseTemperature: 10, thresholds: [DegreeDayThreshold(accumulated: 1000)]),
        forecast(temperature: (h) => h == 30 ? null : 20),
      );
      expect(f.detail, contains('60 graus-dia projetados em 6 dias'));
    });
  });

  group('15. ausência de dados meteorológicos', () {
    test('sem previsão → sem índice, ocorrências e aviso presentes', () {
      final r = run(
          rules: [tempRule], occurrences: [occ('Organismo de Teste')], weather: null);
      final a = single(r);
      expect(r.warnings, contains(ReportWarning.forecastUnavailable));
      expect(a.status, AssessmentStatus.insufficientWeatherData);
      expect(a.message, insufficientWeatherDataMessage);
      expect(a.favorabilityIndex, isNull);
      expect(a.regional.count, 1);
      expect(factor(a, FactorKind.temperature).detail, 'previsão indisponível');
    });

    test('previsão desatualizada gera aviso', () {
      final r = run(
          rules: [tempRule],
          occurrences: [occ('Organismo de Teste')],
          weather: mildForecast(),
          stale: true);
      expect(r.warnings, contains(ReportWarning.forecastStale));
    });

    test('cobertura horária baixa → não avaliado', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(temperature: (h) => h < 20 ? 20 : null),
      ));
      expect(factor(a, FactorKind.temperature).status, FactorStatus.notEvaluable);
      expect(factor(a, FactorKind.temperature).detail, contains('20 de 72'));
    });

    test('hora sem chuva informada não é tratada como 0 mm', () {
      final rule = testRule(
        precipitation: const PrecipitationCriteria(maxAmountMm: 1, periodHours: 24),
      );
      // Uma hora ausente em cada bloco de 24 h → nenhum período completo.
      final a = single(run(
        rules: [rule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(precipitation: (h) => h % 20 == 0 ? null : 0),
      ));
      expect(factor(a, FactorKind.precipitation).status,
          FactorStatus.notEvaluable);
    });

    test('previsão sem horários no período → não avaliado', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: forecast(hours: 0, temperature: (_) => 20),
      ));
      expect(a.status, AssessmentStatus.insufficientWeatherData);
    });
  });

  group('16. duplicidade', () {
    test('mesmo id repetido conta uma vez', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', id: 'x'),
          occ('Organismo de Teste', id: 'x'),
        ],
        weather: mildForecast(),
      );
      expect(r.screening.duplicates, 1);
      expect(single(r).regional.count, 1);
    });

    test('mesmo autor, organismo, local e horário próximos → uma só', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', daysAgo: 1.0),
          occ('ORGANISMO de teste', daysAgo: 1.02), // ~30 min depois
        ],
        weather: mildForecast(),
      );
      expect(r.screening.duplicates, 1);
      expect(single(r).regional.count, 1);
    });

    test('autores diferentes no mesmo local não são duplicatas', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', reportedBy: 'a'),
          occ('Organismo de Teste', reportedBy: 'b'),
        ],
        weather: mildForecast(),
      );
      expect(r.screening.duplicates, 0);
      expect(single(r).regional.count, 2);
    });

    test('mesmo autor, local e horário, mas organismos diferentes → ambos',
        () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste'),
          occ('Outro Organismo'),
          occ('organismo de teste'), // duplicata da primeira
        ],
        weather: mildForecast(),
      );
      expect(r.screening.duplicates, 1);
      expect(r.organisms, hasLength(2));
    });

    test('mesmo autor em dias diferentes não é duplicata', () {
      final r = run(
        rules: [tempRule],
        occurrences: [
          occ('Organismo de Teste', daysAgo: 1),
          occ('Organismo de Teste', daysAgo: 3),
        ],
        weather: mildForecast(),
      );
      expect(r.screening.duplicates, 0);
    });
  });

  group('níveis e índice', () {
    test('limites configuráveis', () {
      const levels = AttentionLevelThresholds();
      expect(levels.levelFor(0), AttentionLevel.low);
      expect(levels.levelFor(30), AttentionLevel.moderate);
      expect(levels.levelFor(55), AttentionLevel.high);
      expect(levels.levelFor(75), AttentionLevel.veryHigh);
      expect(const AttentionLevelThresholds(moderate: 10, high: 20, veryHigh: 90)
          .levelFor(50), AttentionLevel.high);
    });

    test('índice combina componentes pelos pesos configurados', () {
      final a = single(run(
        rules: [tempRule],
        occurrences: [occ('Organismo de Teste')],
        weather: mildForecast(),
      ));
      final expected =
          ((0.6 * 1.0 + 0.4 * a.regional.score) / 1.0 * 100).round();
      expect(a.favorabilityIndex, expected);
      expect(a.level, const AttentionLevelThresholds().levelFor(expected));
      expect(a.message, a.level!.headline);
    });
  });

  group('FavorabilityService', () {
    PropertyModel property() => const PropertyModel(
          id: 'p',
          name: 'Fazenda Teste',
          mainCrop: 'Soja',
          latitude: propertyLat,
          longitude: propertyLng,
          ownerId: 'u',
        );

    ScientificRuleRepository repo() => ScientificRuleRepository(
          source: _InlineSource('{"schemaVersion":1,"rules":[]}'),
        );

    test('falha de previsão vira relatório sem clima', () async {
      DateTime? since;
      final service = FavorabilityService(
        engine: engine,
        rules: repo(),
        loadOccurrencesSince: (s) async {
          since = s;
          return [];
        },
        loadForecast: (_) async =>
            const WeatherFailure(WeatherFailureReason.timeout, 'timeout'),
        now: () => testNow,
      );
      final r = await service.assess(property());
      expect(since, testNow.subtract(const Duration(days: 28)));
      expect(r.warnings, contains(ReportWarning.forecastUnavailable));
      expect(r.status, ReportStatus.noRecentOccurrences);
    });

    test('erro ao carregar ocorrências é repassado', () async {
      final service = FavorabilityService(
        engine: engine,
        rules: repo(),
        loadOccurrencesSince: (_) async => throw StateError('firestore'),
        loadForecast: (_) async => WeatherSuccess(mildForecast()),
        now: () => testNow,
      );
      expect(service.assess(property()), throwsStateError);
    });
  });
}

class _InlineSource implements ScientificRuleSource {
  final String raw;
  _InlineSource(this.raw);
  @override
  Future<String> loadRaw() async => raw;
}
