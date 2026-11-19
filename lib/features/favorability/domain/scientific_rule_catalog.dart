import 'organism_name.dart';
import 'scientific_pest_rule.dart';

/// Resultado da busca de uma regra para um organismo identificado pela IA.
///
/// O futuro motor de risco deve tratar os três casos:
/// - [RuleFound]: calcular favorabilidade com a regra.
/// - [RuleUnavailable]: organismo conhecido, mas sem evidência suficiente —
///   informar "favorabilidade indisponível", nunca estimar.
/// - [RuleNotFound]: organismo sem regra cadastrada.
sealed class RuleLookup {
  const RuleLookup();
}

class RuleFound extends RuleLookup {
  final ScientificPestRule rule;
  const RuleFound(this.rule);
}

class RuleUnavailable extends RuleLookup {
  final ScientificPestRule rule;
  final List<String> reasons;
  const RuleUnavailable(this.rule, this.reasons);
}

class RuleNotFound extends RuleLookup {
  /// Nome como veio da IA.
  final String queriedName;
  const RuleNotFound(this.queriedName);
}

/// Erro ao carregar uma regra específica. A regra é descartada, mas o
/// restante do catálogo continua funcionando.
class RuleLoadIssue {
  /// Id da regra, quando foi possível lê-lo.
  final String? ruleId;
  final String message;
  const RuleLoadIssue(this.ruleId, this.message);

  @override
  String toString() => 'RuleLoadIssue(${ruleId ?? "?"}): $message';
}

/// Conjunto de regras científicas indexado por nome normalizado.
///
/// Imutável e síncrono — a origem dos dados (asset JSON, Firestore) fica em
/// ScientificRuleRepository.
class ScientificRuleCatalog {
  final List<ScientificPestRule> rules;

  /// Problemas encontrados ao montar o catálogo (JSON inválido, nomes
  /// duplicados entre regras…).
  final List<RuleLoadIssue> issues;

  final Map<String, ScientificPestRule> _byName;

  ScientificRuleCatalog._(this.rules, this.issues, this._byName);

  static final ScientificRuleCatalog empty =
      ScientificRuleCatalog._(const [], const [], const {});

  /// Monta o catálogo. Em caso de nome/sinônimo repetido entre regras
  /// diferentes, vale a primeira e o conflito vai para [issues].
  factory ScientificRuleCatalog(
    Iterable<ScientificPestRule> rules, {
    List<RuleLoadIssue> issues = const [],
  }) {
    final accepted = <ScientificPestRule>[];
    final allIssues = [...issues];
    final byName = <String, ScientificPestRule>{};
    final ids = <String>{};

    for (final rule in rules) {
      if (!ids.add(rule.id)) {
        allIssues.add(RuleLoadIssue(rule.id, 'Id de regra duplicado'));
        continue;
      }
      accepted.add(rule);
      for (final name in rule.normalizedNames) {
        final existing = byName[name];
        if (existing != null) {
          allIssues.add(RuleLoadIssue(
            rule.id,
            'Nome "$name" já pertence à regra "${existing.id}"',
          ));
          continue;
        }
        byName[name] = rule;
      }
    }
    return ScientificRuleCatalog._(
      List.unmodifiable(accepted),
      List.unmodifiable(allIssues),
      Map.unmodifiable(byName),
    );
  }

  /// Busca pelo nome que a IA retornou (popular, científico ou sinônimo).
  /// Não usa o tipo de organismo informado pela IA.
  RuleLookup lookup(String organismName) {
    final rule = _byName[normalizeOrganismName(organismName)];
    if (rule == null) return RuleNotFound(organismName);
    final reasons = rule.unusableReasons;
    return reasons.isEmpty ? RuleFound(rule) : RuleUnavailable(rule, reasons);
  }

  /// Regras aplicáveis a uma cultura (inclui as que não restringem cultura).
  List<ScientificPestRule> rulesForCrop(String crop) =>
      rules.where((r) => r.appliesToCrop(crop) ?? true).toList();
}
