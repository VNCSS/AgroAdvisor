import 'favorability_config.dart';
import 'favorability_result.dart';
import 'pt_format.dart';

/// Mensagem exibida (sem criar alerta) para organismos sem base científica.
const String noScientificBasisAlertMessage =
    'Não há parâmetros científicos suficientes para estimar a '
    'favorabilidade deste organismo.';

/// Critérios para transformar uma avaliação de favorabilidade em alerta.
///
/// Parâmetros de projeto (não científicos), ajustáveis aqui.
class PreventiveAlertPolicy {
  /// Nível de atenção mínimo para alertar.
  final AttentionLevel minLevel;

  /// Componente ambiental mínimo (0–1). Garante que o alerta reflita
  /// condições compatíveis com a regra, não apenas muitas ocorrências.
  final double minEnvironmentalScore;

  /// Mínimo de ocorrências regionais do organismo.
  final int minOccurrences;

  /// Variação do índice (pontos) considerada mudança significativa, mesmo
  /// sem mudança de nível ou de fatores favoráveis.
  final int significantIndexChange;

  /// Validade do alerta. Dentro dela, condições equivalentes não geram novo
  /// alerta; depois dela, se as condições persistirem, um novo é emitido.
  final Duration validity;

  const PreventiveAlertPolicy({
    this.minLevel = AttentionLevel.high,
    this.minEnvironmentalScore = 0.6,
    this.minOccurrences = 1,
    this.significantIndexChange = 15,
    this.validity = const Duration(hours: 72),
  });
}

/// Por que um organismo não gerou alerta.
enum AlertSkipReason {
  noScientificBasis,
  cropNotAffected,
  insufficientWeather,
  conditionsNotFavorable,
  notEnoughOccurrences,
}

class SkippedOrganism {
  final String propertyId;
  final String organismName;
  final AlertSkipReason reason;
  final String message;

  const SkippedOrganism({
    required this.propertyId,
    required this.organismName,
    required this.reason,
    required this.message,
  });
}

/// Alerta preventivo pronto para ser gravado no sistema de notificações.
class PreventiveAlert {
  /// Id determinístico (propriedade + regra): é a chave de deduplicação.
  final String alertId;
  final String propertyId;
  final String ruleId;
  final String organismName;
  final String title;
  final String body;

  /// Resumo das condições relevantes. Mudou = mudança significativa.
  final String fingerprint;

  final int favorabilityIndex;
  final AttentionLevel level;
  final DateTime validFrom;
  final DateTime validUntil;

  const PreventiveAlert({
    required this.alertId,
    required this.propertyId,
    required this.ruleId,
    required this.organismName,
    required this.title,
    required this.body,
    required this.fingerprint,
    required this.favorabilityIndex,
    required this.level,
    required this.validFrom,
    required this.validUntil,
  });

  /// Mesmo alerta com título marcado como atualização.
  PreventiveAlert asUpdate() => PreventiveAlert(
        alertId: alertId,
        propertyId: propertyId,
        ruleId: ruleId,
        organismName: organismName,
        title: 'Atualização: $title',
        body: body,
        fingerprint: fingerprint,
        favorabilityIndex: favorabilityIndex,
        level: level,
        validFrom: validFrom,
        validUntil: validUntil,
      );
}

/// Estado de um alerta já gravado, usado na deduplicação.
class StoredPreventiveAlert {
  final String fingerprint;
  final int favorabilityIndex;
  final DateTime validUntil;

  const StoredPreventiveAlert({
    required this.fingerprint,
    required this.favorabilityIndex,
    required this.validUntil,
  });
}

enum AlertAction {
  /// Não havia alerta vigente: criar.
  create,

  /// Havia alerta vigente, mas as condições mudaram significativamente.
  update,

  /// Alerta vigente equivalente: não fazer nada.
  skip,
}

/// Decide o que fazer com um alerta candidato, dado o que já foi gravado.
AlertAction decideAlertAction({
  required StoredPreventiveAlert? existing,
  required PreventiveAlert candidate,
  required DateTime now,
  PreventiveAlertPolicy policy = const PreventiveAlertPolicy(),
}) {
  if (existing == null || !existing.validUntil.isAfter(now)) {
    return AlertAction.create;
  }
  final indexDelta =
      (candidate.favorabilityIndex - existing.favorabilityIndex).abs();
  if (existing.fingerprint != candidate.fingerprint ||
      indexDelta >= policy.significantIndexChange) {
    return AlertAction.update;
  }
  return AlertAction.skip;
}

class PreventiveAlertEvaluation {
  final List<PreventiveAlert> alerts;
  final List<SkippedOrganism> skipped;
  const PreventiveAlertEvaluation(this.alerts, this.skipped);
}

/// Converte um [FavorabilityReport] em alertas preventivos.
///
/// Só gera alerta quando: há ocorrência regional, regra científica
/// aplicável, previsão suficiente, cultura compatível (quando conhecida) e
/// condições compatíveis com a regra (nível e componente ambiental mínimos).
/// Os textos descrevem condições e recomendam monitoramento — nunca afirmam
/// que o organismo vai ocorrer.
class PreventiveAlertBuilder {
  final PreventiveAlertPolicy policy;

  const PreventiveAlertBuilder([this.policy = const PreventiveAlertPolicy()]);

  static String alertIdFor(String propertyId, String ruleId) {
    String safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'preventive_${safe(propertyId)}_${safe(ruleId)}';
  }

  PreventiveAlertEvaluation build({
    required FavorabilityReport report,
    required String propertyName,
    required double radiusKm,
    required int windowDays,
    required int horizonHours,
  }) {
    final alerts = <PreventiveAlert>[];
    final skipped = <SkippedOrganism>[];
    if (report.status != ReportStatus.ok) {
      return PreventiveAlertEvaluation(alerts, skipped);
    }

    void skip(OrganismAssessment a, AlertSkipReason reason, String message) =>
        skipped.add(SkippedOrganism(
          propertyId: report.propertyId,
          organismName: a.organismName,
          reason: reason,
          message: message,
        ));

    for (final a in report.organisms) {
      switch (a.status) {
        case AssessmentStatus.insufficientScientificData:
          skip(a, AlertSkipReason.noScientificBasis,
              noScientificBasisAlertMessage);
          continue;
        case AssessmentStatus.cropNotAffected:
          skip(a, AlertSkipReason.cropNotAffected, a.message);
          continue;
        case AssessmentStatus.insufficientWeatherData:
          skip(a, AlertSkipReason.insufficientWeather, a.message);
          continue;
        case AssessmentStatus.assessed:
          break;
      }
      if (a.regional.count < policy.minOccurrences) {
        skip(a, AlertSkipReason.notEnoughOccurrences,
            'Ocorrências regionais insuficientes para alerta.');
        continue;
      }
      final level = a.level!;
      final envScore = a.environmental!.score!;
      if (level.index < policy.minLevel.index ||
          envScore < policy.minEnvironmentalScore) {
        skip(a, AlertSkipReason.conditionsNotFavorable,
            'Condições previstas abaixo do limite de alerta '
            '(${level.headline.toLowerCase()}).');
        continue;
      }
      alerts.add(_alertFor(a, report, propertyName, radiusKm, windowDays,
          horizonHours));
    }
    return PreventiveAlertEvaluation(alerts, skipped);
  }

  PreventiveAlert _alertFor(
    OrganismAssessment a,
    FavorabilityReport report,
    String propertyName,
    double radiusKm,
    int windowDays,
    int horizonHours,
  ) {
    final rule = a.rule!;
    final level = a.level!;
    final now = report.generatedAt;
    final periodEnd = now.add(Duration(hours: horizonHours));
    final validUntil = now.add(policy.validity);

    final favorableKinds = a.environmental!.factors
        .where((f) => f.status == FactorStatus.favorable)
        .map((f) => f.kind.name)
        .toList()
      ..sort();
    final fingerprint = [
      level.name,
      favorableKinds.join(','),
      rule.id,
      rule.lastReviewedAt?.toIso8601String() ?? '-',
    ].join('|');

    final title = '${_emoji(level)} ${level.headline} para monitoramento: '
        '${a.organismName} ($propertyName)';

    final regional = a.regional;
    final mostRecent = regional.mostRecent?.occurrence.timestamp;
    final lines = <String>[
      'Foram identificadas ocorrências recentes de ${a.organismName} na '
          'região e as condições meteorológicas previstas apresentam fatores '
          'compatíveis com condições associadas ao seu desenvolvimento. '
          'Recomenda-se intensificar o monitoramento.',
      '',
      'Organismo: ${a.organismName}'
          '${rule.scientificName == null ? '' : ' (${rule.scientificName})'}',
      'Propriedade: $propertyName',
      'Cultura: ${report.crop ?? 'não informada'}',
      'Período analisado: ${_dayMonth(now)} a ${_dayMonth(periodEnd)} '
          '(próximas $horizonHours h)',
      for (final f in a.environmental!.factors)
        '${_capitalize(f.kind.label)}: ${f.status.label} — ${f.detail}',
      'Ocorrências: ${regional.count} nos últimos $windowDays dias '
          '(raio de ${fmtNum(radiusKm)} km)',
      if (regional.nearestKm != null)
        'Ocorrência mais próxima: ${fmtKm(regional.nearestKm!)}',
      if (mostRecent != null)
        'Ocorrência mais recente: ${fmtDate(mostRecent)} '
            '(${fmtDaysAgo(mostRecent, now)})',
      'Favorabilidade: ${level.headline} — índice de favorabilidade '
          '${a.favorabilityIndex}/100. O índice é uma métrica interna do '
          'sistema e não representa probabilidade de ocorrência.',
      for (final s in rule.sources)
        'Fonte científica: ${s.title}'
            '${s.institution == null ? '' : ' — ${s.institution}'}'
            '${s.url == null ? '' : ' (${s.url})'}',
    ];

    return PreventiveAlert(
      alertId: alertIdFor(report.propertyId, rule.id),
      propertyId: report.propertyId,
      ruleId: rule.id,
      organismName: a.organismName,
      title: title,
      body: lines.join('\n'),
      fingerprint: fingerprint,
      favorabilityIndex: a.favorabilityIndex!,
      level: level,
      validFrom: now,
      validUntil: validUntil,
    );
  }

  static String _emoji(AttentionLevel level) => switch (level) {
        AttentionLevel.low => '🟢',
        AttentionLevel.moderate => '🟡',
        AttentionLevel.high => '🟠',
        AttentionLevel.veryHigh => '🔴',
      };

  static String _dayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
