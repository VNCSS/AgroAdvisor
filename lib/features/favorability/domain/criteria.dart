import 'json_utils.dart';

// Critérios ambientais de favorabilidade.
//
// Regras gerais:
// - Todo campo numérico é opcional. Ausente = "a fonte não informa", nunca
//   zero nem um valor padrão.
// - Cada critério pode citar as fontes de onde veio ([sourceIds]),
//   referenciando ScientificSource.id da mesma regra.
// - Unidades fixas por critério (documentadas em cada classe) para que o
//   futuro motor de risco compare direto com os dados do Open-Meteo.

/// Base comum: observação livre + rastreabilidade de fonte.
abstract class Criterion {
  final String? note;
  final List<String> sourceIds;

  const Criterion({this.note, this.sourceIds = const []});

  /// true quando ao menos um parâmetro objetivo (numérico ou lista) foi
  /// informado. Um critério só com [note] não é avaliável pelo motor.
  bool get hasParameters;

  /// Problemas de consistência (ex.: mínimo maior que máximo).
  List<String> validate() => const [];

  Map<String, dynamic> toJson();

  Map<String, dynamic> baseJson() => {
        'note': note,
        'sourceIds': sourceIds.isEmpty ? null : sourceIds,
      };
}

void _checkRange(
  List<String> issues,
  String label,
  double? min,
  double? max, {
  double? optimal,
}) {
  if (min != null && max != null && min > max) {
    issues.add('$label: mínimo ($min) maior que máximo ($max)');
  }
  if (optimal != null) {
    if (min != null && optimal < min) {
      issues.add('$label: ótimo ($optimal) abaixo do mínimo ($min)');
    }
    if (max != null && optimal > max) {
      issues.add('$label: ótimo ($optimal) acima do máximo ($max)');
    }
  }
}

void _checkNonNegative(List<String> issues, String label, double? value) {
  if (value != null && value < 0) {
    issues.add('$label não pode ser negativo ($value)');
  }
}

/// Temperatura do ar, em °C.
///
/// [optimalMin]/[optimalMax] permitem uma faixa ótima; [optimal] é um
/// valor pontual quando a fonte informa só um número.
class TemperatureCriteria extends Criterion {
  final double? min;
  final double? max;
  final double? optimal;
  final double? optimalMin;
  final double? optimalMax;

  static const String unit = '°C';

  const TemperatureCriteria({
    this.min,
    this.max,
    this.optimal,
    this.optimalMin,
    this.optimalMax,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters => [min, max, optimal, optimalMin, optimalMax]
      .any((v) => v != null);

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkRange(issues, 'Temperatura', min, max, optimal: optimal);
    _checkRange(issues, 'Temperatura ótima', optimalMin, optimalMax);
    _checkRange(issues, 'Temperatura (faixa ótima)', min, max,
        optimal: optimalMin);
    _checkRange(issues, 'Temperatura (faixa ótima)', min, max,
        optimal: optimalMax);
    return issues;
  }

  factory TemperatureCriteria.fromJson(Map<String, dynamic> json) =>
      TemperatureCriteria(
        min: readDouble(json, 'min'),
        max: readDouble(json, 'max'),
        optimal: readDouble(json, 'optimal'),
        optimalMin: readDouble(json, 'optimalMin'),
        optimalMax: readDouble(json, 'optimalMax'),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'min': min,
        'max': max,
        'optimal': optimal,
        'optimalMin': optimalMin,
        'optimalMax': optimalMax,
        ...baseJson(),
      });
}

/// Umidade relativa do ar, em %.
///
/// [minDurationHours]: por quantas horas a umidade precisa permanecer na
/// faixa, quando a fonte especifica.
class HumidityCriteria extends Criterion {
  final double? min;
  final double? max;
  final double? minDurationHours;

  static const String unit = '%';

  const HumidityCriteria({
    this.min,
    this.max,
    this.minDurationHours,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters =>
      [min, max, minDurationHours].any((v) => v != null);

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkRange(issues, 'Umidade', min, max);
    for (final v in [min, max]) {
      if (v != null && (v < 0 || v > 100)) {
        issues.add('Umidade fora de 0–100% ($v)');
      }
    }
    _checkNonNegative(issues, 'Duração da umidade', minDurationHours);
    return issues;
  }

  factory HumidityCriteria.fromJson(Map<String, dynamic> json) =>
      HumidityCriteria(
        min: readDouble(json, 'min'),
        max: readDouble(json, 'max'),
        minDurationHours: readDouble(json, 'minDurationHours'),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'min': min,
        'max': max,
        'minDurationHours': minDurationHours,
        ...baseJson(),
      });
}

/// Como a precipitação influencia o organismo.
enum PrecipitationCondition {
  /// Chuva favorece (ex.: dispersão de esporos por respingo).
  favorable('favorable'),

  /// Chuva desfavorece (ex.: lavagem de insetos pequenos).
  unfavorable('unfavorable');

  const PrecipitationCondition(this.key);
  final String key;

  static PrecipitationCondition? parse(String? raw) {
    if (raw == null) return null;
    for (final c in values) {
      if (c.key == raw) return c;
    }
    throw FormatException('Condição de precipitação desconhecida', raw);
  }
}

/// Precipitação, em mm acumulados em [periodHours].
class PrecipitationCriteria extends Criterion {
  final double? minAmountMm;
  final double? maxAmountMm;
  final double? periodHours;
  final PrecipitationCondition? condition;

  static const String unit = 'mm';

  const PrecipitationCriteria({
    this.minAmountMm,
    this.maxAmountMm,
    this.periodHours,
    this.condition,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters =>
      [minAmountMm, maxAmountMm, periodHours, condition].any((v) => v != null);

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkRange(issues, 'Precipitação', minAmountMm, maxAmountMm);
    _checkNonNegative(issues, 'Precipitação mínima', minAmountMm);
    _checkNonNegative(issues, 'Período de precipitação', periodHours);
    return issues;
  }

  factory PrecipitationCriteria.fromJson(Map<String, dynamic> json) =>
      PrecipitationCriteria(
        minAmountMm: readDouble(json, 'minAmountMm'),
        maxAmountMm: readDouble(json, 'maxAmountMm'),
        periodHours: readDouble(json, 'periodHours'),
        condition: PrecipitationCondition.parse(readString(json, 'condition')),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'minAmountMm': minAmountMm,
        'maxAmountMm': maxAmountMm,
        'periodHours': periodHours,
        'condition': condition?.key,
        ...baseJson(),
      });
}

/// Molhamento foliar (água livre sobre a folha), em horas.
///
/// [condition]: descrição textual da condição exigida pela fonte (ex.:
/// temperatura durante o período de molhamento), quando não couber nos
/// campos numéricos.
class LeafWetnessCriteria extends Criterion {
  final double? minDurationHours;
  final double? optimalDurationHours;
  final String? condition;

  static const String unit = 'h';

  const LeafWetnessCriteria({
    this.minDurationHours,
    this.optimalDurationHours,
    this.condition,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters =>
      [minDurationHours, optimalDurationHours].any((v) => v != null);

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkNonNegative(issues, 'Duração de molhamento', minDurationHours);
    if (minDurationHours != null &&
        optimalDurationHours != null &&
        optimalDurationHours! < minDurationHours!) {
      issues.add('Molhamento: duração ótima menor que a mínima');
    }
    return issues;
  }

  factory LeafWetnessCriteria.fromJson(Map<String, dynamic> json) =>
      LeafWetnessCriteria(
        minDurationHours: readDouble(json, 'minDurationHours'),
        optimalDurationHours: readDouble(json, 'optimalDurationHours'),
        condition: readString(json, 'condition'),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'minDurationHours': minDurationHours,
        'optimalDurationHours': optimalDurationHours,
        'condition': condition,
        ...baseJson(),
      });
}

/// Ponto de orvalho, em °C.
///
/// [maxDepression]: diferença máxima entre temperatura do ar e ponto de
/// orvalho (ar próximo da saturação), quando a fonte usa esse indicador.
class DewPointCriteria extends Criterion {
  final double? min;
  final double? max;
  final double? maxDepression;

  static const String unit = '°C';

  const DewPointCriteria({
    this.min,
    this.max,
    this.maxDepression,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters => [min, max, maxDepression].any((v) => v != null);

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkRange(issues, 'Ponto de orvalho', min, max);
    _checkNonNegative(issues, 'Depressão do ponto de orvalho', maxDepression);
    return issues;
  }

  factory DewPointCriteria.fromJson(Map<String, dynamic> json) =>
      DewPointCriteria(
        min: readDouble(json, 'min'),
        max: readDouble(json, 'max'),
        maxDepression: readDouble(json, 'maxDepression'),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'min': min,
        'max': max,
        'maxDepression': maxDepression,
        ...baseJson(),
      });
}

/// Um limiar de graus-dia acumulados associado a um estágio biológico.
class DegreeDayThreshold {
  /// Graus-dia acumulados (°C·dia) para atingir [stage].
  final double accumulated;

  /// Estágio relacionado (ex.: "ovo a adulto", "geração completa").
  final String? stage;

  const DegreeDayThreshold({required this.accumulated, this.stage});

  factory DegreeDayThreshold.fromJson(Map<String, dynamic> json) {
    final accumulated = readDouble(json, 'accumulated');
    if (accumulated == null) {
      throw const FormatException('Limiar de graus-dia sem "accumulated"');
    }
    return DegreeDayThreshold(
      accumulated: accumulated,
      stage: readString(json, 'stage'),
    );
  }

  Map<String, dynamic> toJson() =>
      compactJson({'accumulated': accumulated, 'stage': stage});
}

/// Modelo de graus-dia (desenvolvimento dependente de temperatura), em °C.
class DegreeDayCriteria extends Criterion {
  /// Temperatura-base inferior de desenvolvimento.
  final double? baseTemperature;

  /// Limite superior (acima dele o desenvolvimento não acelera/cessa).
  final double? upperThreshold;

  final List<DegreeDayThreshold> thresholds;

  static const String unit = '°C·dia';

  const DegreeDayCriteria({
    this.baseTemperature,
    this.upperThreshold,
    this.thresholds = const [],
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters =>
      baseTemperature != null ||
      upperThreshold != null ||
      thresholds.isNotEmpty;

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkRange(issues, 'Graus-dia (base/limite superior)', baseTemperature,
        upperThreshold);
    for (final t in thresholds) {
      _checkNonNegative(issues, 'Graus-dia acumulados', t.accumulated);
    }
    if (thresholds.isNotEmpty && baseTemperature == null) {
      issues.add('Graus-dia acumulados sem temperatura-base');
    }
    return issues;
  }

  factory DegreeDayCriteria.fromJson(Map<String, dynamic> json) =>
      DegreeDayCriteria(
        baseTemperature: readDouble(json, 'baseTemperature'),
        upperThreshold: readDouble(json, 'upperThreshold'),
        thresholds: List.unmodifiable(
          readObjectList(json, 'thresholds').map(DegreeDayThreshold.fromJson),
        ),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'baseTemperature': baseTemperature,
        'upperThreshold': upperThreshold,
        'thresholds': thresholds.isEmpty
            ? null
            : thresholds.map((t) => t.toJson()).toList(),
        ...baseJson(),
      });
}

/// Velocidade do vento a 10 m, em km/h (mesma unidade do Open-Meteo).
class WindCriteria extends Criterion {
  final double? minSpeed;
  final double? maxSpeed;

  static const String unit = 'km/h';

  const WindCriteria({
    this.minSpeed,
    this.maxSpeed,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters => minSpeed != null || maxSpeed != null;

  @override
  List<String> validate() {
    final issues = <String>[];
    _checkRange(issues, 'Vento', minSpeed, maxSpeed);
    _checkNonNegative(issues, 'Vento mínimo', minSpeed);
    return issues;
  }

  factory WindCriteria.fromJson(Map<String, dynamic> json) => WindCriteria(
        minSpeed: readDouble(json, 'minSpeed'),
        maxSpeed: readDouble(json, 'maxSpeed'),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'minSpeed': minSpeed,
        'maxSpeed': maxSpeed,
        ...baseJson(),
      });
}

/// Estádios fenológicos da cultura em que o organismo é relevante.
///
/// Os estádios ficam em texto (ex.: "R1", "V4", "florescimento") porque
/// cada cultura usa sua própria escala.
class PhenologyCriteria extends Criterion {
  final List<String> susceptibleStages;

  const PhenologyCriteria({
    this.susceptibleStages = const [],
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters => susceptibleStages.isNotEmpty;

  factory PhenologyCriteria.fromJson(Map<String, dynamic> json) =>
      PhenologyCriteria(
        susceptibleStages: readStringList(json, 'susceptibleStages'),
        note: readString(json, 'note'),
        sourceIds: readStringList(json, 'sourceIds'),
      );

  @override
  Map<String, dynamic> toJson() => compactJson({
        'susceptibleStages':
            susceptibleStages.isEmpty ? null : susceptibleStages,
        ...baseJson(),
      });
}

/// Critério que não se encaixa nos tipos acima (ex.: presença de
/// hospedeiro alternativo, vazio sanitário). Apenas descritivo: o motor
/// pode exibi-lo, mas não avaliá-lo numericamente.
class AdditionalCriterion extends Criterion {
  final String description;

  const AdditionalCriterion({
    required this.description,
    super.note,
    super.sourceIds,
  });

  @override
  bool get hasParameters => false;

  factory AdditionalCriterion.fromJson(Map<String, dynamic> json) {
    final description = readString(json, 'description');
    if (description == null) {
      throw const FormatException('Critério adicional sem "description"');
    }
    return AdditionalCriterion(
      description: description,
      note: readString(json, 'note'),
      sourceIds: readStringList(json, 'sourceIds'),
    );
  }

  @override
  Map<String, dynamic> toJson() => compactJson({
        'description': description,
        ...baseJson(),
      });
}
