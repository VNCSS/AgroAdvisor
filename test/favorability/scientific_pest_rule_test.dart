import 'dart:convert';

import 'package:agro_advisor/features/favorability/data/scientific_rule_repository.dart';
import 'package:agro_advisor/features/favorability/domain/criteria.dart';
import 'package:agro_advisor/features/favorability/domain/organism_name.dart';
import 'package:agro_advisor/features/favorability/domain/organism_type.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_pest_rule.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_rule_catalog.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scientific_rule_fixtures.dart';

ScientificPestRule ruleFrom(Map<String, dynamic> literal) =>
    ScientificPestRule.fromJson(decodeFixture(literal));

class _FakeSource implements ScientificRuleSource {
  final Future<String> Function() load;
  int calls = 0;
  _FakeSource(this.load);

  @override
  Future<String> loadRaw() {
    calls++;
    return load();
  }
}

void main() {
  group('regra completa', () {
    final rule = ruleFrom(completeRuleJson);

    test('lê todos os critérios', () {
      expect(rule.organismType, OrganismType.fungus);
      expect(rule.temperature!.optimal, 20.0);
      expect(rule.humidity!.min, 80.0);
      expect(rule.humidity!.max, isNull);
      expect(rule.precipitation!.condition, PrecipitationCondition.favorable);
      expect(rule.leafWetness!.minDurationHours, 6.0);
      expect(rule.dewPoint!.maxDepression, 2.0);
      expect(rule.degreeDays!.thresholds.single.stage, 'estágio de teste');
      expect(rule.wind!.maxSpeed, 40.0);
      expect(rule.phenology!.susceptibleStages, ['R1', 'R5']);
      expect(rule.additionalCriteria, hasLength(1));
      expect(rule.lastReviewedAt, DateTime(2026, 10, 1));
      expect(rule.confidence, EvidenceConfidence.moderate);
    });

    test('é utilizável', () {
      expect(rule.unusableReasons, isEmpty);
      expect(rule.isUsable, isTrue);
    });

    test('nome normalizado ignora acento e caixa', () {
      expect(rule.normalizedName, 'fungo de teste a');
      expect(rule.normalizedNames,
          containsAll(['testus fictitius', 'mancha de teste', 'teste a']));
    });

    test('ida e volta em JSON preserva os dados', () {
      final roundTrip = ScientificPestRule.fromJson(
        jsonDecode(jsonEncode(rule.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), rule.toJson());
    });
  });

  group('múltiplos parâmetros', () {
    final rule = ruleFrom(completeRuleJson);

    test('todos os critérios ambientais são avaliáveis', () {
      // 8 critérios ambientais; o critério adicional é só descritivo.
      expect(rule.criteria, hasLength(9));
      expect(rule.evaluableCriteria, hasLength(8));
      expect(rule.evaluableCriteria, isNot(contains(isA<AdditionalCriterion>())));
    });

    test('critérios inconsistentes tornam a regra inutilizável', () {
      final json = decodeFixture(completeRuleJson)
        ..['temperature'] = {'min': 30.0, 'max': 10.0}
        ..['humidity'] = {'min': 120.0};
      final rule = ScientificPestRule.fromJson(json);
      expect(rule.isUsable, isFalse);
      expect(rule.unusableReasons.join(),
          allOf(contains('Temperatura'), contains('Umidade')));
    });
  });

  group('regra parcial', () {
    final rule = ruleFrom(partialRuleJson);

    test('critérios ausentes ficam null, sem valor padrão', () {
      expect(rule.temperature!.min, 15.0);
      expect(rule.temperature!.max, isNull);
      expect(rule.temperature!.optimal, isNull);
      expect(rule.humidity, isNull);
      expect(rule.precipitation, isNull);
      expect(rule.leafWetness, isNull);
      expect(rule.dewPoint, isNull);
      expect(rule.degreeDays, isNull);
      expect(rule.wind, isNull);
      expect(rule.phenology, isNull);
      expect(rule.affectedCrops, isEmpty);
      expect(rule.lastReviewedAt, isNull);
      expect(rule.confidence, isNull);
    });

    test('é utilizável com um único parâmetro e fonte', () {
      expect(rule.isUsable, isTrue);
      expect(rule.evaluableCriteria, hasLength(1));
    });

    test('tipo em português é aceito', () {
      expect(rule.organismType, OrganismType.insect);
    });
  });

  group('regra sem parâmetros', () {
    test('indisponível explicitamente', () {
      final rule = ruleFrom(noParametersRuleJson);
      expect(rule.available, isFalse);
      expect(rule.criteria, isEmpty);
      expect(rule.isUsable, isFalse);
      expect(rule.unusableReasons, ['Sem evidência (dado de teste)']);
    });

    test('"available" ausente equivale a indisponível', () {
      final rule = ScientificPestRule.fromJson(
          {'id': 'x', 'organismName': 'Organismo de teste'});
      expect(rule.available, isFalse);
      expect(rule.isUsable, isFalse);
    });

    test('marcada como disponível, mas sem parâmetros, não é utilizável', () {
      final rule = ScientificPestRule.fromJson(decodeFixture({
        ...partialRuleJson,
        'temperature': {'note': 'só observação'},
      }));
      expect(rule.isUsable, isFalse);
      expect(rule.unusableReasons,
          contains('Nenhum parâmetro ambiental avaliável'));
    });
  });

  group('fonte científica', () {
    test('lê todos os campos da fonte', () {
      final source = ruleFrom(completeRuleJson).sources.first;
      expect(source.title, 'Fonte fictícia 1 (teste)');
      expect(source.institution, 'Instituição Fictícia');
      expect(source.authors, ['Autor Fictício']);
      expect(source.url, 'https://example.org/test-source-1');
      expect(source.year, 2020);
      expect(source.note, 'Somente para testes');
      expect(source.reviewedAt, DateTime(2026, 10, 1));
      expect(source.isIdentifiable, isTrue);
    });

    test('regra disponível sem fonte não é utilizável', () {
      final json = decodeFixture(partialRuleJson)..remove('sources');
      final rule = ScientificPestRule.fromJson(json);
      expect(rule.unusableReasons,
          contains('Sem fonte científica identificável (título e URL)'));
    });

    test('fonte sem URL não é identificável', () {
      const source = ScientificSource(id: 's', title: 'Título');
      expect(source.isIdentifiable, isFalse);
    });

    test('critério citando fonte inexistente é inconsistente', () {
      final json = decodeFixture(partialRuleJson)
        ..['temperature'] = {
          'min': 15.0,
          'sourceIds': ['nao-existe'],
        };
      final rule = ScientificPestRule.fromJson(json);
      expect(rule.isUsable, isFalse);
      expect(rule.validate().single, contains('nao-existe'));
    });

    test('fonte sem título é rejeitada na leitura', () {
      expect(
        () => ScientificSource.fromJson({'id': 's', 'url': 'https://x'}),
        throwsFormatException,
      );
    });
  });

  group('múltiplas culturas', () {
    final rule = ruleFrom(completeRuleJson);

    test('aplica-se a qualquer cultura listada, ignorando acento/caixa', () {
      expect(rule.appliesToCrop('soja'), isTrue);
      expect(rule.appliesToCrop('MILHO'), isTrue);
      expect(rule.appliesToCrop('feijao'), isTrue);
      expect(rule.appliesToCrop('Café'), isFalse);
    });

    test('sem culturas cadastradas → indeterminado (null)', () {
      expect(ruleFrom(partialRuleJson).appliesToCrop('Soja'), isNull);
    });

    test('catálogo filtra por cultura', () {
      final catalog = ScientificRuleCatalog(
          [ruleFrom(completeRuleJson), ruleFrom(partialRuleJson)]);
      expect(catalog.rulesForCrop('Soja').map((r) => r.id),
          ['test-fungus-a', 'test-insect-b']);
      expect(catalog.rulesForCrop('Café').map((r) => r.id), ['test-insect-b']);
    });
  });

  group('catálogo e organismo inexistente', () {
    final catalog = ScientificRuleCatalog([
      ruleFrom(completeRuleJson),
      ruleFrom(partialRuleJson),
      ruleFrom(noParametersRuleJson),
    ]);

    test('organismo inexistente → RuleNotFound', () {
      final result = catalog.lookup('Organismo que não existe');
      expect(result, isA<RuleNotFound>());
      expect((result as RuleNotFound).queriedName, 'Organismo que não existe');
    });

    test('busca por nome popular, científico ou sinônimo', () {
      for (final name in [
        'fungo de teste a',
        'FUNGO DE TESTE Á',
        'Testus fictitius',
        'teste-a',
      ]) {
        final result = catalog.lookup(name);
        expect(result, isA<RuleFound>(), reason: name);
        expect((result as RuleFound).rule.id, 'test-fungus-a');
      }
    });

    test('organismo sem evidência → RuleUnavailable', () {
      final result = catalog.lookup('Bacteria de teste C');
      expect(result, isA<RuleUnavailable>());
      expect((result as RuleUnavailable).reasons, isNotEmpty);
    });

    test('catálogo vazio não encontra nada', () {
      expect(ScientificRuleCatalog.empty.lookup('Fungo de Teste Á'),
          isA<RuleNotFound>());
    });

    test('nomes duplicados entre regras são reportados', () {
      final dup = ScientificPestRule.fromJson(decodeFixture({
        ...partialRuleJson,
        'id': 'test-dup',
        'aliases': ['Mancha de teste'],
      }));
      final c = ScientificRuleCatalog([ruleFrom(completeRuleJson), dup]);
      expect(c.issues.single.message, contains('mancha de teste'));
      expect((c.lookup('Mancha de teste') as RuleFound).rule.id,
          'test-fungus-a');
    });
  });

  group('tipo de organismo', () {
    test('aceita variações e cai em unknown quando não reconhece', () {
      expect(OrganismType.parse('Fungo'), OrganismType.fungus);
      expect(OrganismType.parse('bactéria'), OrganismType.bacterium);
      expect(OrganismType.parse('outros'), OrganismType.other);
      expect(OrganismType.parse('doença não classificada'),
          OrganismType.unclassifiedDisease);
      expect(OrganismType.parse('alienígena'), OrganismType.unknown);
      expect(OrganismType.parse(null), OrganismType.unknown);
    });

    test('lookup não depende do tipo informado', () {
      // A IA pode classificar errado; a busca usa apenas o nome.
      final catalog = ScientificRuleCatalog([ruleFrom(partialRuleJson)]);
      expect(catalog.lookup('Inseto de Teste B'), isA<RuleFound>());
    });
  });

  group('normalização de nomes', () {
    test('remove acentos, pontuação e espaços extras', () {
      expect(normalizeOrganismName('  Ferrugem   Asiática (Soja) '),
          'ferrugem asiatica soja');
      expect(normalizeOrganismName('Mosca-branca'), 'mosca branca');
    });
  });

  group('arquivo de regras', () {
    test('regra inválida é descartada sem derrubar as demais', () {
      final catalog = parseScientificRules(rulesFile([
        decodeFixture(partialRuleJson),
        {'id': 'quebrada', 'organismName': 'X', 'temperature': {'min': 'dez'}},
      ]));
      expect(catalog.rules.map((r) => r.id), ['test-insect-b']);
      expect(catalog.issues.single.ruleId, 'quebrada');
    });

    test('schemaVersion incompatível é rejeitado', () {
      expect(() => parseScientificRules(rulesFile([], schemaVersion: 99)),
          throwsFormatException);
    });

    test('repositório devolve catálogo vazio se a fonte falhar', () async {
      final repo = ScientificRuleRepository(
        source: _FakeSource(() async => throw Exception('sem arquivo')),
      );
      final catalog = await repo.loadCatalog();
      expect(catalog.rules, isEmpty);
      expect(catalog.issues, hasLength(1));
    });

    test('repositório carrega uma vez e reutiliza', () async {
      final source = _FakeSource(
          () async => rulesFile([decodeFixture(completeRuleJson)]));
      final repo = ScientificRuleRepository(source: source);
      await repo.loadCatalog();
      final catalog = await repo.loadCatalog();
      expect(source.calls, 1);
      expect(catalog.lookup('Testus fictitius'), isA<RuleFound>());
    });
  });

  group('asset versionado', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('existe, é válido e não contém regras inventadas', () async {
      final raw = await rootBundle.loadString(scientificRulesAssetPath);
      final catalog = parseScientificRules(raw);
      expect(catalog.issues, isEmpty);
      // Nenhuma regra real foi cadastrada ainda. Ao cadastrar regras com
      // fontes verificadas, atualize esta expectativa.
      expect(catalog.rules, isEmpty);
    });
  });
}
