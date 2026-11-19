// ⚠️ Regras e organismos usados aqui são DADOS DE TESTE fictícios.

import 'dart:convert';

import 'package:agro_advisor/features/favorability/data/favorability_service.dart';
import 'package:agro_advisor/features/favorability/data/preventive_alert_service.dart';
import 'package:agro_advisor/features/favorability/data/scientific_rule_repository.dart';
import 'package:agro_advisor/features/favorability/domain/criteria.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_config.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_engine.dart';
import 'package:agro_advisor/features/favorability/domain/preventive_alert.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_pest_rule.dart';
import 'package:agro_advisor/features/notifications/data/preventive_alert_store.dart';
import 'package:agro_advisor/features/notifications/domain/app_notification_model.dart';
import 'package:agro_advisor/features/occurrence/domain/diagnosis_model.dart';
import 'package:agro_advisor/features/occurrence/domain/occurrence_model.dart';
import 'package:agro_advisor/features/property/domain/property_model.dart';
import 'package:agro_advisor/features/settings/domain/user_settings_model.dart';
import 'package:agro_advisor/features/weather/domain/weather_forecast.dart';
import 'package:agro_advisor/features/weather/domain/weather_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'favorability_test_helpers.dart';

// ── Dublês ───────────────────────────────────────────────────────────────────

class MemoryAlertStore implements PreventiveAlertStore {
  /// userId → alertId → último alerta gravado.
  final Map<String, Map<String, PreventiveAlert>> docs = {};
  int saves = 0;

  @override
  Future<StoredPreventiveAlert?> find(String userId, String alertId) async {
    final a = docs[userId]?[alertId];
    return a == null
        ? null
        : StoredPreventiveAlert(
            fingerprint: a.fingerprint,
            favorabilityIndex: a.favorabilityIndex,
            validUntil: a.validUntil,
          );
  }

  @override
  Future<void> save(String userId, PreventiveAlert alert) async {
    saves++;
    (docs[userId] ??= {})[alert.alertId] = alert;
  }

  List<PreventiveAlert> of(String userId) =>
      docs[userId]?.values.toList() ?? [];
}

class _InlineSource implements ScientificRuleSource {
  final String raw;
  _InlineSource(this.raw);
  @override
  Future<String> loadRaw() async => raw;
}

/// Cenário configurável de um usuário.
class Scenario {
  List<ScientificPestRule> rules;
  List<OccurrenceModel> occurrences;
  List<PropertyModel> properties;
  WeatherForecast? Function(PropertyModel p) weather;
  UserSettingsModel? settings;
  DateTime now;

  Scenario({
    required this.rules,
    required this.occurrences,
    List<PropertyModel>? properties,
    WeatherForecast? Function(PropertyModel p)? weather,
    this.settings,
    DateTime? now,
  })  : properties = properties ?? [farm()],
        weather = weather ?? ((_) => favorableForecast()),
        now = now ?? testNow;

  final store = MemoryAlertStore();

  late final service = PreventiveAlertService(
    favorability: FavorabilityService(
      engine: FavorabilityEngine(),
      rules: ScientificRuleRepository(
        source: _InlineSource(jsonEncode({
          'schemaVersion': 1,
          'rules': [for (final r in rules) r.toJson()],
        })),
      ),
      loadOccurrencesSince: (_) async => occurrences,
      loadForecast: (p) async {
        final f = weather(p);
        return f == null
            ? const WeatherFailure(WeatherFailureReason.noConnection, 'offline')
            : WeatherSuccess(f);
      },
      now: () => now,
    ),
    store: store,
    loadSettings: (_) async => settings,
    loadProperties: (_) async => properties,
  );

  Future<PreventiveAlertRunResult> run({bool force = true}) =>
      service.run('user-1', force: force);
}

// ── Dados de teste ───────────────────────────────────────────────────────────

PropertyModel farm({
  String id = 'farm-1',
  String name = 'Fazenda Teste',
  String crop = 'Soja',
  double kmNorth = 0,
}) =>
    PropertyModel(
      id: id,
      name: name,
      mainCrop: crop,
      latitude: propertyLat + kmNorth / kmPerDegree,
      longitude: propertyLng,
      ownerId: 'user-1',
    );

int _seq = 0;

OccurrenceModel sighting(
  String organism, {
  double km = 2,
  double daysAgo = 1,
  String? reportedBy,
}) =>
    OccurrenceModel(
      id: 'o-${_seq++}',
      imageBase64: '',
      latitude: propertyLat + km / kmPerDegree,
      longitude: propertyLng,
      timestamp:
          testNow.subtract(Duration(minutes: (daysAgo * 24 * 60).round())),
      reportedBy: reportedBy ?? 'reporter-${_seq++}',
      diagnosis: DiagnosisModel(
        pestName: organism,
        riskLevel: 'alto',
        description: '',
        recommendation: '',
        confidenceScore: 0.9,
        detectedIssues: const [],
        analyzedAt: testNow,
      ),
    );

List<OccurrenceModel> sightings(String organism, int n, {double km = 2}) =>
    [for (var i = 0; i < n; i++) sighting(organism, km: km)];

ScientificPestRule ruleA({List<String> crops = const ['Soja']}) => testRule(
      id: 'test-fungus-a',
      name: 'Fungo de Teste A',
      scientificName: 'Fungus testae',
      crops: crops,
      temperature: const TemperatureCriteria(min: 15, max: 25),
      humidity: const HumidityCriteria(min: 85),
      precipitation: const PrecipitationCriteria(
          condition: PrecipitationCondition.favorable),
      wind: const WindCriteria(maxSpeed: 20),
    );

ScientificPestRule ruleB() => testRule(
      id: 'test-insect-b',
      name: 'Inseto de Teste B',
      temperature: const TemperatureCriteria(min: 18, max: 30),
    );

WeatherForecast favorableForecast({double wind = 10, double humidity = 95}) =>
    forecast(
      temperature: (_) => 20,
      humidity: (_) => humidity,
      precipitation: (h) => h == 5 ? 2.0 : 0,
      wind: (_) => wind,
    );

final forbidden = RegExp(
  r'você terá|vai aparecer|irá ocorrer|vai ocorrer|certo que|chance|'
  r'\d+\s*%\s*de',
  caseSensitive: false,
);

void main() {
  group('alerta válido', () {
    test('cria um alerta explicativo no sistema de notificações', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: [
          sighting('Fungo de Teste A', km: 6.2, daysAgo: 2),
          ...sightings('Fungus testae', 4, km: 3),
        ],
      );
      final r = await s.run();
      expect(r.ran, isTrue);
      expect(r.created, hasLength(1));
      expect(r.errors, isEmpty);

      final alert = s.store.of('user-1').single;
      expect(alert.alertId, 'preventive_farm-1_test-fungus-a');
      expect(alert.title, startsWith('🔴 Condições muito favoráveis para monitoramento'));
      expect(alert.title, contains('Fungo de Teste A (Fazenda Teste)'));

      final body = alert.body;
      expect(body, contains('Foram identificadas ocorrências recentes de '
          'Fungo de Teste A na região e as condições meteorológicas previstas '
          'apresentam fatores compatíveis com condições associadas ao seu '
          'desenvolvimento.'));
      expect(body, contains('Recomenda-se intensificar o monitoramento.'));
      expect(body, contains('Organismo: Fungo de Teste A (Fungus testae)'));
      expect(body, contains('Cultura: Soja'));
      expect(body, contains('Período analisado: 10/10 a 13/10'));
      expect(body, contains('Temperatura: favorável'));
      expect(body, contains('Umidade relativa: favorável'));
      expect(body, contains('Precipitação: favorável'));
      expect(body, contains('Vento: favorável'));
      expect(body, contains('Ocorrências: 5 nos últimos 28 dias (raio de 20 km)'));
      expect(body, contains('Ocorrência mais próxima: 3,0 km'));
      expect(body, contains('Ocorrência mais recente: 09/10/2026 (ontem)'));
      expect(body, contains('Fonte científica: Fonte fictícia (teste)'));
      expect(body, contains('índice de favorabilidade ${alert.favorabilityIndex}/100'));
      expect(body, contains('não representa probabilidade'));
      expect('${alert.title}\n$body', isNot(matches(forbidden)));
    });

    test('nível "alto" usa 🟠 e "Condições favoráveis"', () async {
      final s = Scenario(
        rules: [ruleB()],
        // Evidência regional fraca (longe e antiga, dentro do raio padrão de
        // 20 km) com clima favorável → nível alto, não muito alto.
        occurrences: [sighting('Inseto de Teste B', km: 15, daysAgo: 10)],
      );
      await s.run();
      final alert = s.store.of('user-1').single;
      expect(alert.level, AttentionLevel.high);
      expect(alert.title,
          startsWith('🟠 Condições favoráveis para monitoramento'));
    });

    test('condições abaixo do limite não geram alerta', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: [sighting('Fungo de Teste A')],
        weather: (_) => favorableForecast(humidity: 50, wind: 40),
      );
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(r.skipped.single.reason, AlertSkipReason.conditionsNotFavorable);
      expect(r.skipped.single.message, isNot(matches(forbidden)));
    });

    test('notificações desativadas → nada é verificado', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 3),
        settings: const UserSettingsModel(
            userId: 'user-1', notificationsEnabled: false),
      );
      final r = await s.run();
      expect(r.ran, isFalse);
      expect(s.store.saves, 0);
    });

    test('raio de alerta do usuário é respeitado', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 3, km: 30),
        settings: const UserSettingsModel(userId: 'user-1', alertRadiusKm: 20),
      );
      expect((await s.run()).created, isEmpty);
      s.settings = const UserSettingsModel(userId: 'user-1', alertRadiusKm: 50);
      expect((await s.run()).created, hasLength(1));
    });
  });

  group('ausência de ocorrência', () {
    test('sem ocorrências → nenhum alerta', () async {
      final s = Scenario(rules: [ruleA()], occurrences: []);
      final r = await s.run();
      expect(r.ran, isTrue);
      expect(r.created, isEmpty);
      expect(r.skipped, isEmpty);
      expect(s.store.saves, 0);
    });

    test('ocorrência só de outro organismo → sem alerta para A', () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: [sighting('Organismo Diferente')]);
      final r = await s.run();
      expect(r.created, isEmpty);
    });
  });

  group('ausência de regra', () {
    test('sem regra → sem alerta, apenas a mensagem informativa', () async {
      final s = Scenario(
          rules: [], occurrences: sightings('Organismo Sem Regra', 5));
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(s.store.saves, 0);
      final skip = r.skipped.single;
      expect(skip.reason, AlertSkipReason.noScientificBasis);
      expect(skip.message,
          'Não há parâmetros científicos suficientes para estimar a '
          'favorabilidade deste organismo.');
    });

    test('regra indisponível também não gera alerta', () async {
      final s = Scenario(
        rules: [testRule(id: 'x', name: 'Organismo X', available: false)],
        occurrences: sightings('Organismo X', 5),
      );
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(r.skipped.single.reason, AlertSkipReason.noScientificBasis);
    });
  });

  group('previsão indisponível', () {
    test('sem previsão → sem alerta', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 5),
        weather: (_) => null,
      );
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(r.skipped.single.reason, AlertSkipReason.insufficientWeather);
    });

    test('previsão incompleta (sem variáveis da regra) → sem alerta', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 5),
        weather: (_) => forecast(precipitation: (_) => 0),
      );
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(r.skipped.single.reason, AlertSkipReason.insufficientWeather);
    });

    test('falha em uma propriedade não impede as outras', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 5),
        properties: [farm(id: 'ok'), farm(id: 'broken', name: 'Quebrada')],
        weather: (p) => p.id == 'broken'
            ? throw StateError('erro inesperado')
            : favorableForecast(),
      );
      final r = await s.run();
      expect(r.created.single.propertyId, 'ok');
      expect(r.errors.single, contains('Quebrada'));
    });
  });

  group('duplicidade', () {
    test('mesma condição em execuções seguidas → um único alerta', () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      final first = await s.run();
      final second = await s.run();
      final third = await s.run();
      expect(first.created, hasLength(1));
      expect(second.created, isEmpty);
      expect(second.unchanged, hasLength(1));
      expect(third.unchanged, hasLength(1));
      expect(s.store.saves, 1);
    });

    test('atualizações de tela seguidas não reexecutam a verificação',
        () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      expect((await s.run(force: false)).ran, isTrue);
      final again = await s.run(force: false);
      expect(again.ran, isFalse);
      expect(s.store.saves, 1);
    });

    test('chamadas simultâneas compartilham a mesma execução', () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      final a = s.service.run('user-1');
      final b = s.service.run('user-1');
      expect(identical(a, b), isTrue);
      await Future.wait([a, b]);
      expect(s.store.saves, 1);
    });

    test('nova ocorrência com variação pequena do índice → sem novo alerta',
        () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      await s.run();
      s.occurrences = [...s.occurrences, sighting('Fungo de Teste A', km: 2)];
      final r = await s.run();
      expect(r.unchanged, hasLength(1));
      expect(s.store.saves, 1);
    });

    test('ocorrências repetidas (mesmo id) não inflam o alerta', () async {
      final o = sighting('Fungo de Teste A');
      final s = Scenario(rules: [ruleA()], occurrences: [o, o, o]);
      await s.run();
      expect(s.store.of('user-1').single.body,
          contains('Ocorrências: 1 nos últimos'));
    });
  });

  group('múltiplos organismos', () {
    test('um alerta por organismo com regra; sem regra só informa', () async {
      final s = Scenario(
        rules: [ruleA(), ruleB()],
        occurrences: [
          ...sightings('Fungo de Teste A', 3),
          ...sightings('Inseto de Teste B', 3),
          ...sightings('Organismo Sem Regra', 3),
        ],
      );
      final r = await s.run();
      expect(r.created.map((a) => a.ruleId).toSet(),
          {'test-fungus-a', 'test-insect-b'});
      expect(s.store.of('user-1').map((a) => a.alertId).toSet(), {
        'preventive_farm-1_test-fungus-a',
        'preventive_farm-1_test-insect-b',
      });
      expect(r.skipped.single.organismName, 'Organismo Sem Regra');
      expect(r.skipped.single.reason, AlertSkipReason.noScientificBasis);
    });
  });

  group('mudança de condição', () {
    test('fator favorável deixa de ser → alerta atualizado no lugar', () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      await s.run();
      final before = s.store.of('user-1').single;

      s.weather = (_) => favorableForecast(wind: 40); // vento desfavorável
      final r = await s.run();
      expect(r.updated, hasLength(1));
      final after = s.store.of('user-1').single;
      expect(after.alertId, before.alertId);
      expect(after.title, startsWith('Atualização: '));
      expect(after.fingerprint, isNot(before.fingerprint));
      expect(after.body, contains('Vento: desfavorável'));
      expect(s.store.saves, 2);
    });

    test('alerta vencido e condições mantidas → novo alerta', () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      await s.run();
      s.now = testNow.add(const Duration(hours: 73));
      final r = await s.run();
      expect(r.created, hasLength(1));
      expect(r.updated, isEmpty);
      expect(s.store.saves, 2);
    });

    test('condições deixam de ser favoráveis → nenhum alerta novo', () async {
      final s = Scenario(
          rules: [ruleA()], occurrences: sightings('Fungo de Teste A', 5));
      await s.run();
      s.weather = (_) => favorableForecast(humidity: 40, wind: 40);
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(r.updated, isEmpty);
      expect(s.store.saves, 1);
    });

    test('decideAlertAction', () {
      PreventiveAlert alert({String fp = 'a', int index = 80}) =>
          PreventiveAlert(
            alertId: 'id',
            propertyId: 'p',
            ruleId: 'r',
            organismName: 'o',
            title: 't',
            body: 'b',
            fingerprint: fp,
            favorabilityIndex: index,
            level: AttentionLevel.veryHigh,
            validFrom: testNow,
            validUntil: testNow.add(const Duration(hours: 72)),
          );
      StoredPreventiveAlert stored({String fp = 'a', int index = 80, int hours = 10}) =>
          StoredPreventiveAlert(
            fingerprint: fp,
            favorabilityIndex: index,
            validUntil: testNow.add(Duration(hours: hours)),
          );

      AlertAction decide(StoredPreventiveAlert? e, PreventiveAlert c) =>
          decideAlertAction(existing: e, candidate: c, now: testNow);

      expect(decide(null, alert()), AlertAction.create);
      expect(decide(stored(), alert()), AlertAction.skip);
      expect(decide(stored(index: 70), alert()), AlertAction.skip);
      expect(decide(stored(index: 60), alert()), AlertAction.update);
      expect(decide(stored(fp: 'b'), alert()), AlertAction.update);
      expect(decide(stored(hours: -1), alert()), AlertAction.create);
    });
  });

  group('propriedade diferente', () {
    test('cada propriedade tem seu próprio alerta', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 5),
        properties: [
          farm(id: 'farm-1', name: 'Fazenda Um'),
          farm(id: 'farm-2', name: 'Fazenda Dois', kmNorth: 4),
        ],
      );
      final r = await s.run();
      expect(r.created.map((a) => a.alertId).toSet(), {
        'preventive_farm-1_test-fungus-a',
        'preventive_farm-2_test-fungus-a',
      });
      expect(r.created.map((a) => a.title).join(),
          allOf(contains('Fazenda Um'), contains('Fazenda Dois')));
    });

    test('propriedade distante das ocorrências não recebe alerta', () async {
      final s = Scenario(
        rules: [ruleA()],
        occurrences: sightings('Fungo de Teste A', 5),
        properties: [farm(id: 'near'), farm(id: 'far', kmNorth: 200)],
      );
      final r = await s.run();
      expect(r.created.map((a) => a.propertyId), ['near']);
    });
  });

  group('cultura diferente', () {
    test('cultura fora da regra → sem alerta', () async {
      final s = Scenario(
        rules: [ruleA(crops: ['Soja'])],
        occurrences: sightings('Fungo de Teste A', 5),
        properties: [farm(crop: 'Milho')],
      );
      final r = await s.run();
      expect(r.created, isEmpty);
      expect(r.skipped.single.reason, AlertSkipReason.cropNotAffected);
    });

    test('mesma regra, cultura compatível → alerta', () async {
      final s = Scenario(
        rules: [ruleA(crops: ['Soja'])],
        occurrences: sightings('Fungo de Teste A', 5),
        properties: [
          farm(id: 'milho', crop: 'Milho'),
          farm(id: 'soja', crop: 'Soja'),
        ],
      );
      final r = await s.run();
      expect(r.created.single.propertyId, 'soja');
    });

    test('cultura não informada → alerta, com cultura "não informada"',
        () async {
      final s = Scenario(
        rules: [ruleA(crops: ['Soja'])],
        occurrences: sightings('Fungo de Teste A', 5),
        properties: [farm(crop: 'Outro')],
      );
      final r = await s.run();
      expect(r.created.single.body, contains('Cultura: não informada'));
    });
  });

  group('compatibilidade com o sistema de notificações existente', () {
    test('documento gravado não tem occurrenceId e tem type', () {
      final alert = PreventiveAlertBuilder.alertIdFor('farm/1', 'rule.x');
      expect(alert, 'preventive_farm_1_rule_x');

      final map = preventiveAlertToMap(PreventiveAlert(
        alertId: 'id',
        propertyId: 'p',
        ruleId: 'r',
        organismName: 'o',
        title: 't',
        body: 'b',
        fingerprint: 'f',
        favorabilityIndex: 70,
        level: AttentionLevel.high,
        validFrom: testNow,
        validUntil: testNow.add(const Duration(hours: 72)),
      ));
      // O NearbyAlertService usa occurrenceId para saber o que já notificou.
      expect(map.containsKey('occurrenceId'), isFalse);
      expect(map['type'], AppNotificationModel.typePreventive);
      expect(map['read'], isFalse);

      final stored = storedAlertFromMap(map)!;
      expect(stored.fingerprint, 'f');
      expect(stored.favorabilityIndex, 70);
      expect(stored.validUntil, testNow.add(const Duration(hours: 72)));
      expect(storedAlertFromMap({'title': 'antigo'}), isNull);

      final notif = AppNotificationModel.fromMap(
          {...map, 'receivedAt': Timestamp.fromDate(testNow)}, 'id');
      expect(notif.isPreventive, isTrue);
      expect(notif.title, 't');
    });

    test('alertas de proximidade antigos continuam sendo lidos igual', () {
      final legacy = AppNotificationModel.fromMap({
        'title': 'Praga detectada próximo a você',
        'body': 'Risco alto — a 3,0 km da sua propriedade.',
        'read': false,
        'occurrenceId': 'occ-1',
        'latitude': -22.0,
        'longitude': -47.0,
      }, 'n1');
      expect(legacy.type, isNull);
      expect(legacy.isPreventive, isFalse);
      expect(legacy.occurrenceId, 'occ-1');
    });
  });
}
