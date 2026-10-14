import 'favorability_config.dart';
import 'regional_occurrence.dart';
import 'scientific_pest_rule.dart';

/// Aviso fixo sobre a natureza do índice. Deve acompanhar qualquer exibição
/// do índice de favorabilidade.
const String favorabilityIndexDisclaimer =
    'O índice de favorabilidade (0–100) é uma métrica interna do '
    'AgroAdvisor que combina as condições meteorológicas previstas com as '
    'ocorrências regionais recentes. Não é a probabilidade de o organismo '
    'ocorrer na propriedade.';

const String insufficientScientificDataMessage =
    'Não existem parâmetros científicos suficientes para estimar a '
    'favorabilidade ambiental deste organismo.';

const String insufficientWeatherDataMessage =
    'Dados meteorológicos insuficientes para estimar a favorabilidade '
    'ambiental deste organismo.';

// ── Fatores ambientais ───────────────────────────────────────────────────────

enum FactorStatus {
  favorable('favorável'),
  partiallyFavorable('parcialmente favorável'),
  unfavorable('desfavorável'),

  /// Definido na regra, mas sem dados suficientes para avaliar.
  notEvaluable('não avaliado'),

  /// Calculado e exibido, mas sem base de comparação na regra (não pontua).
  informational('informativo');

  const FactorStatus(this.label);
  final String label;
}

/// Resultado da comparação de UM critério da regra com a previsão.
class FactorEvaluation {
  final FactorKind kind;
  final FactorStatus status;

  /// Pontuação do fator (0–1). null quando não pontua
  /// ([FactorStatus.notEvaluable] / [FactorStatus.informational]).
  final double? score;

  /// Descrição do que foi comparado, em português.
  final String detail;

  /// true quando o valor comparado foi derivado indiretamente (ex.:
  /// molhamento e ponto de orvalho estimados a partir de UR/temperatura).
  final bool estimated;

  const FactorEvaluation({
    required this.kind,
    required this.status,
    required this.detail,
    this.score,
    this.estimated = false,
  });

  bool get isScored => score != null;
}

/// Componente ambiental de um organismo.
class EnvironmentalAssessment {
  /// Um item por critério definido na regra (critérios ausentes da regra
  /// não aparecem — não são avaliados).
  final List<FactorEvaluation> factors;

  /// Média ponderada das pontuações dos fatores avaliados (0–1). null se
  /// a cobertura for insuficiente.
  final double? score;

  /// Fração (por peso) dos fatores meteorológicos da regra efetivamente
  /// avaliados.
  final double coverage;

  const EnvironmentalAssessment({
    required this.factors,
    required this.score,
    required this.coverage,
  });
}

// ── Evidência regional ───────────────────────────────────────────────────────

class OccurrenceEvidence {
  final RegionalOccurrence occurrence;
  final double distanceKm;
  final double ageDays;

  /// Peso desta ocorrência (recência × distância), 0–1.
  final double weight;

  const OccurrenceEvidence({
    required this.occurrence,
    required this.distanceKm,
    required this.ageDays,
    required this.weight,
  });
}

/// Ocorrências recentes de um organismo ao redor da propriedade.
class RegionalEvidence {
  /// Mais recente primeiro.
  final List<OccurrenceEvidence> occurrences;

  /// Soma dos pesos das ocorrências.
  final double weightedCount;

  /// Evidência normalizada (0–1).
  final double score;

  /// Ocorrências a até [OccurrenceEvidenceConfig.concentrationRadiusKm].
  final int withinConcentrationRadius;

  /// Ocorrências sem cultura informada (incluídas, mas sem confirmação de
  /// que foram na mesma cultura).
  final int unknownCropCount;

  const RegionalEvidence({
    required this.occurrences,
    required this.weightedCount,
    required this.score,
    required this.withinConcentrationRadius,
    required this.unknownCropCount,
  });

  int get count => occurrences.length;

  double? get nearestKm => occurrences.isEmpty
      ? null
      : occurrences.map((e) => e.distanceKm).reduce((a, b) => a < b ? a : b);

  OccurrenceEvidence? get mostRecent =>
      occurrences.isEmpty ? null : occurrences.first;
}

/// Contagens da triagem das ocorrências (antes do agrupamento).
class OccurrenceScreening {
  final int received;
  final int accepted;
  final int outsideWindow;
  final int invalidLocation;
  final int outsideRadius;
  final int lowConfidence;
  final int otherCrop;
  final int duplicates;

  const OccurrenceScreening({
    required this.received,
    required this.accepted,
    required this.outsideWindow,
    required this.invalidLocation,
    required this.outsideRadius,
    required this.lowConfidence,
    required this.otherCrop,
    required this.duplicates,
  });

  static const empty = OccurrenceScreening(
    received: 0,
    accepted: 0,
    outsideWindow: 0,
    invalidLocation: 0,
    outsideRadius: 0,
    lowConfidence: 0,
    otherCrop: 0,
    duplicates: 0,
  );
}

// ── Resultado por organismo ──────────────────────────────────────────────────

enum AssessmentStatus {
  /// Índice calculado.
  assessed,

  /// Sem regra científica, ou regra indisponível/incompleta.
  insufficientScientificData,

  /// A regra científica não lista a cultura da propriedade.
  cropNotAffected,

  /// Regra existe, mas a previsão não cobre os parâmetros dela.
  insufficientWeatherData,
}

class OrganismAssessment {
  /// Nome para exibição (nome da regra, ou grafia mais frequente da IA).
  final String organismName;

  /// Grafias recebidas da IA que foram agrupadas aqui.
  final Set<String> reportedNames;

  /// Regra encontrada (pode existir mesmo sem índice, ex.: indisponível).
  final ScientificPestRule? rule;

  final AssessmentStatus status;

  /// Mensagem principal para o usuário.
  final String message;

  /// Motivos detalhados quando não há índice.
  final List<String> reasons;

  /// null quando a regra não permitiu avaliar o ambiente.
  final EnvironmentalAssessment? environmental;

  /// Sempre presente: as ocorrências podem ser exibidas mesmo sem índice.
  final RegionalEvidence regional;

  /// Índice interno 0–100. null quando [status] ≠ assessed.
  final int? favorabilityIndex;

  final AttentionLevel? level;

  /// Explicação completa, linha a linha, em português.
  final List<String> explanation;

  const OrganismAssessment({
    required this.organismName,
    required this.reportedNames,
    required this.rule,
    required this.status,
    required this.message,
    required this.reasons,
    required this.environmental,
    required this.regional,
    required this.favorabilityIndex,
    required this.level,
    required this.explanation,
  });

  bool get hasIndex => favorabilityIndex != null;
}

// ── Resultado da propriedade ─────────────────────────────────────────────────

enum ReportStatus {
  ok,

  /// Coordenadas da propriedade inválidas — sem distância nem previsão.
  locationUnavailable,

  /// Nenhuma ocorrência relevante na região/período.
  noRecentOccurrences,
}

enum ReportWarning {
  cropMissing(
    'Cultura da propriedade não informada: a aplicabilidade das regras à '
    'cultura não foi verificada.',
  ),
  forecastUnavailable(
    'Previsão meteorológica indisponível: nenhuma condição ambiental foi '
    'avaliada.',
  ),
  forecastStale(
    'Previsão meteorológica desatualizada (cache): as condições podem ter '
    'mudado.',
  ),
  occurrenceCropUnknown(
    'As ocorrências não informam a cultura em que foram registradas; foram '
    'consideradas todas as ocorrências da região.',
  );

  const ReportWarning(this.message);
  final String message;
}

class FavorabilityReport {
  final String propertyId;

  /// null quando a cultura não foi informada.
  final String? crop;

  final DateTime generatedAt;
  final ReportStatus status;
  final List<ReportWarning> warnings;
  final OccurrenceScreening screening;

  /// Ordenado: com índice primeiro (maior índice primeiro), depois os
  /// demais por evidência regional.
  final List<OrganismAssessment> organisms;

  const FavorabilityReport({
    required this.propertyId,
    required this.crop,
    required this.generatedAt,
    required this.status,
    required this.warnings,
    required this.screening,
    required this.organisms,
  });

  String get disclaimer => favorabilityIndexDisclaimer;
}
