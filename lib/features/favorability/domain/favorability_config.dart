// Parâmetros do motor de favorabilidade.
//
// ⚠️ TODOS os valores padrão deste arquivo são PARÂMETROS DE PROJETO do
// AgroAdvisor — escolhas de engenharia para ponderar e resumir dados —, e
// NÃO conhecimento científico sobre os organismos. O conhecimento científico
// vem exclusivamente das regras em assets/scientific_rules/.
//
// Ajuste-os aqui (ou injete outra configuração no FavorabilityEngine); o
// motor não contém nenhum limite fixo fora destas classes.

/// Fatores ambientais que o motor sabe avaliar.
enum FactorKind {
  temperature('temperatura', meteorological: true),
  humidity('umidade relativa', meteorological: true),
  precipitation('precipitação', meteorological: true),
  leafWetness('condição estimada de molhamento', meteorological: true),
  dewPoint('ponto de orvalho estimado', meteorological: true),
  degreeDays('graus-dia', meteorological: true),
  wind('vento', meteorological: true),
  phenology('estádio fenológico', meteorological: false);

  const FactorKind(this.label, {required this.meteorological});

  /// Nome em português para a explicação.
  final String label;

  /// true se depende da previsão do tempo (entra na cobertura
  /// meteorológica).
  final bool meteorological;
}

/// Como as ocorrências regionais viram evidência.
class OccurrenceEvidenceConfig {
  /// Raio em torno da propriedade (km).
  final double radiusKm;

  /// Ocorrências mais antigas que isso são ignoradas (dias).
  final int windowDays;

  /// Idade em que o peso de uma ocorrência cai pela metade (dias).
  final double recencyHalfLifeDays;

  /// Distância em que o peso de uma ocorrência cai pela metade (km).
  final double distanceHalfLifeKm;

  /// Soma de pesos (ocorrências ponderadas) que corresponde à evidência
  /// regional máxima (1,0).
  final double saturationWeightedCount;

  /// Raio usado para medir concentração ("N ocorrências a até X km").
  final double concentrationRadiusKm;

  /// Mínimo de ocorrências para um organismo ser analisado.
  final int minOccurrencesPerOrganism;

  /// Confiança mínima do diagnóstico da IA (0–1). null = sem filtro.
  final double? minDiagnosisConfidence;

  /// Se true, ocorrências com cultura CONHECIDA e diferente da cultura da
  /// propriedade são descartadas. Ocorrências sem cultura são mantidas.
  final bool excludeOtherCropOccurrences;

  /// Duas ocorrências do mesmo autor e organismo, a até esta distância
  /// (km) e [duplicateTimeWindow] uma da outra, contam como uma só.
  final double duplicateDistanceKm;
  final Duration duplicateTimeWindow;

  const OccurrenceEvidenceConfig({
    this.radiusKm = 50,
    this.windowDays = 28,
    this.recencyHalfLifeDays = 7,
    this.distanceHalfLifeKm = 15,
    this.saturationWeightedCount = 5,
    this.concentrationRadiusKm = 10,
    this.minOccurrencesPerOrganism = 1,
    this.minDiagnosisConfidence,
    this.excludeOtherCropOccurrences = true,
    this.duplicateDistanceKm = 0.05,
    this.duplicateTimeWindow = const Duration(hours: 2),
  })  : assert(radiusKm > 0),
        assert(windowDays > 0),
        assert(recencyHalfLifeDays > 0),
        assert(distanceHalfLifeKm > 0),
        assert(saturationWeightedCount > 0),
        assert(minOccurrencesPerOrganism >= 1);

  OccurrenceEvidenceConfig copyWith({double? radiusKm, int? windowDays}) =>
      OccurrenceEvidenceConfig(
        radiusKm: radiusKm ?? this.radiusKm,
        windowDays: windowDays ?? this.windowDays,
        recencyHalfLifeDays: recencyHalfLifeDays,
        distanceHalfLifeKm: distanceHalfLifeKm,
        saturationWeightedCount: saturationWeightedCount,
        concentrationRadiusKm: concentrationRadiusKm,
        minOccurrencesPerOrganism: minOccurrencesPerOrganism,
        minDiagnosisConfidence: minDiagnosisConfidence,
        excludeOtherCropOccurrences: excludeOtherCropOccurrences,
        duplicateDistanceKm: duplicateDistanceKm,
        duplicateTimeWindow: duplicateTimeWindow,
      );
}

/// Como a previsão é comparada com os critérios da regra científica.
class WeatherEvaluationConfig {
  /// Janela de previsão analisada a partir de agora (horas). Graus-dia
  /// usam todos os dias completos da previsão (ver [minDegreeDayDays]).
  final int horizonHours;

  /// Fração mínima de horas com dado presente para avaliar um fator.
  final double minHourlyCoverage;

  /// Pontuação de fator (0–1) a partir da qual o fator é "favorável".
  final double favorableScoreThreshold;

  /// Pontuação de fator a partir da qual é "parcialmente favorável".
  final double partialScoreThreshold;

  /// Pontuação de uma hora dentro da faixa tolerada, mas fora da faixa
  /// ótima de temperatura (quando a regra define faixa ótima).
  final double suboptimalTemperatureScore;

  /// Condição estimada de molhamento: hora com UR ≥ este valor (%)…
  final double wetnessHumidityThreshold;

  /// …ou com chuva ≥ este valor (mm) é considerada "provavelmente molhada".
  /// Heurística do sistema — NÃO é medição de molhamento foliar.
  final double wetnessPrecipitationThresholdMm;

  /// Chuva mínima (mm/h) para considerar que "choveu" quando a regra só
  /// diz que chuva é favorável/desfavorável, sem quantidade.
  final double rainEventThresholdMm;

  /// Horas com temperatura exigidas para um dia entrar no cálculo de
  /// graus-dia (dia incompleto é descartado, nunca extrapolado).
  final int degreeDayMinHoursPerDay;

  /// Dias completos exigidos para calcular graus-dia.
  final int minDegreeDayDays;

  /// Fração mínima (por peso) dos fatores meteorológicos da regra que
  /// precisam ser avaliados para gerar índice.
  final double minEnvironmentalCoverage;

  const WeatherEvaluationConfig({
    this.horizonHours = 72,
    this.minHourlyCoverage = 0.6,
    this.favorableScoreThreshold = 0.6,
    this.partialScoreThreshold = 0.2,
    this.suboptimalTemperatureScore = 0.5,
    this.wetnessHumidityThreshold = 90,
    this.wetnessPrecipitationThresholdMm = 0.1,
    this.rainEventThresholdMm = 0.2,
    this.degreeDayMinHoursPerDay = 24,
    this.minDegreeDayDays = 3,
    this.minEnvironmentalCoverage = 0.5,
  })  : assert(horizonHours > 0),
        assert(partialScoreThreshold <= favorableScoreThreshold),
        assert(minDegreeDayDays >= 1);
}

/// Pesos para combinar fatores e componentes no índice.
class ScoringConfig {
  /// Peso de cada fator no componente ambiental. Fator ausente do mapa
  /// usa peso 1.
  final Map<FactorKind, double> factorWeights;

  /// Peso do componente ambiental no índice final.
  final double environmentalWeight;

  /// Peso do componente de evidência regional no índice final.
  final double regionalWeight;

  const ScoringConfig({
    this.factorWeights = const {},
    this.environmentalWeight = 0.6,
    this.regionalWeight = 0.4,
  }) : assert(environmentalWeight + regionalWeight > 0);

  double weightOf(FactorKind kind) => factorWeights[kind] ?? 1.0;
}

/// Níveis de atenção.
enum AttentionLevel {
  low('Baixo', 'Condições pouco favoráveis'),
  moderate('Moderado', 'Condições moderadamente favoráveis'),
  high('Alto', 'Condições favoráveis'),
  veryHigh('Muito alto', 'Condições muito favoráveis');

  const AttentionLevel(this.label, this.headline);

  final String label;

  /// Frase de resultado. Descreve condições — nunca afirma que o organismo
  /// vai ocorrer.
  final String headline;
}

/// Limites do índice (0–100) para cada nível. Inclusivos no limite inferior:
///   < [moderate] → baixo; < [high] → moderado; < [veryHigh] → alto;
///   ≥ [veryHigh] → muito alto.
class AttentionLevelThresholds {
  final int moderate;
  final int high;
  final int veryHigh;

  const AttentionLevelThresholds({
    this.moderate = 30,
    this.high = 55,
    this.veryHigh = 75,
  }) : assert(0 < moderate && moderate < high && high < veryHigh &&
            veryHigh <= 100);

  AttentionLevel levelFor(int index) {
    if (index >= veryHigh) return AttentionLevel.veryHigh;
    if (index >= high) return AttentionLevel.high;
    if (index >= moderate) return AttentionLevel.moderate;
    return AttentionLevel.low;
  }
}

class FavorabilityConfig {
  final OccurrenceEvidenceConfig occurrences;
  final WeatherEvaluationConfig weather;
  final ScoringConfig scoring;
  final AttentionLevelThresholds levels;

  /// Valores de cultura tratados como "não informada" (comparação sem
  /// acento/caixa).
  final Set<String> unspecifiedCropValues;

  const FavorabilityConfig({
    this.occurrences = const OccurrenceEvidenceConfig(),
    this.weather = const WeatherEvaluationConfig(),
    this.scoring = const ScoringConfig(),
    this.levels = const AttentionLevelThresholds(),
    this.unspecifiedCropValues = const {'', 'outro', 'outra'},
  });

  FavorabilityConfig copyWith({OccurrenceEvidenceConfig? occurrences}) =>
      FavorabilityConfig(
        occurrences: occurrences ?? this.occurrences,
        weather: weather,
        scoring: scoring,
        levels: levels,
        unspecifiedCropValues: unspecifiedCropValues,
      );
}
