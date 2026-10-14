import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/json_utils.dart';
import '../domain/scientific_pest_rule.dart';
import '../domain/scientific_rule_catalog.dart';

/// Caminho do arquivo versionado com as regras científicas.
const String scientificRulesAssetPath = 'assets/scientific_rules/pest_rules.json';

/// Versão do formato do JSON. Incrementar ao fazer mudança incompatível.
const int scientificRulesSchemaVersion = 1;

/// Origem do JSON bruto das regras.
///
/// Hoje a única implementação lê o asset versionado. Uma futura fonte
/// remota (ex.: Firestore) pode implementar esta interface sem alterar o
/// catálogo nem o motor de risco.
abstract class ScientificRuleSource {
  Future<String> loadRaw();
}

class AssetScientificRuleSource implements ScientificRuleSource {
  final AssetBundle _bundle;
  final String path;

  AssetScientificRuleSource({
    AssetBundle? bundle,
    this.path = scientificRulesAssetPath,
  }) : _bundle = bundle ?? rootBundle;

  @override
  Future<String> loadRaw() => _bundle.loadString(path, cache: false);
}

/// Carrega e mantém em memória o [ScientificRuleCatalog].
///
/// Nunca lança exceção: se o arquivo inteiro for inválido devolve um
/// catálogo vazio com o problema em [ScientificRuleCatalog.issues]; regras
/// individuais inválidas são descartadas sem afetar as demais.
class ScientificRuleRepository {
  final ScientificRuleSource _source;
  Future<ScientificRuleCatalog>? _catalog;

  ScientificRuleRepository({ScientificRuleSource? source})
      : _source = source ?? AssetScientificRuleSource();

  Future<ScientificRuleCatalog> loadCatalog() =>
      _catalog ??= _load();

  Future<ScientificRuleCatalog> _load() async {
    try {
      final raw = await _source.loadRaw();
      final catalog = parseScientificRules(raw);
      for (final issue in catalog.issues) {
        debugPrint('[ScientificRules] $issue');
      }
      return catalog;
    } catch (e) {
      debugPrint('[ScientificRules] falha ao carregar: $e');
      return ScientificRuleCatalog(
        const [],
        issues: [RuleLoadIssue(null, 'Falha ao carregar regras: $e')],
      );
    }
  }
}

/// Converte o JSON do arquivo de regras em catálogo.
///
/// Formato:
/// ```json
/// { "schemaVersion": 1, "rules": [ { ...ScientificPestRule... } ] }
/// ```
ScientificRuleCatalog parseScientificRules(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Arquivo de regras deveria ser um objeto');
  }
  final version = readInt(decoded, 'schemaVersion');
  if (version != scientificRulesSchemaVersion) {
    throw FormatException(
      'schemaVersion $version não suportado '
      '(esperado $scientificRulesSchemaVersion)',
    );
  }

  final rules = <ScientificPestRule>[];
  final issues = <RuleLoadIssue>[];
  for (final json in readObjectList(decoded, 'rules')) {
    try {
      rules.add(ScientificPestRule.fromJson(json));
    } on FormatException catch (e) {
      final id = json['id'];
      issues.add(RuleLoadIssue(id is String ? id : null, e.message));
    }
  }
  return ScientificRuleCatalog(rules, issues: issues);
}
