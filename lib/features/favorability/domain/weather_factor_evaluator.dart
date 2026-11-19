import 'dart:math' as math;

import '../../weather/domain/weather_forecast.dart';
import 'criteria.dart';
import 'favorability_config.dart';
import 'favorability_result.dart';
import 'organism_name.dart';
import 'pt_format.dart';
import 'scientific_pest_rule.dart';

/// Uma hora da previsão. Valores ausentes ficam null — nunca preenchidos.
class HourSample {
  final DateTime time;
  final double? temperature;
  final double? humidity;
  final double? precipitation;
  final double? windSpeed;

  const HourSample(
    this.time, {
    this.temperature,
    this.humidity,
    this.precipitation,
    this.windSpeed,
  });
}

/// Compara os critérios de UMA regra científica com a previsão.
///
/// Só avalia critérios presentes na regra; dentro de cada critério, só os
/// parâmetros definidos. Não existe fórmula por organismo: o mesmo código
/// serve a qualquer regra, e cada uma usa apenas os parâmetros que tem.
///
/// Convenções do sistema (parâmetros em [WeatherEvaluationConfig]):
/// - Fatores horários pontuam pela fração de horas da janela que atendem ao
///   critério; com duração mínima definida, pela maior sequência contínua.
/// - Status vem da pontuação (limiares favorável/parcial configuráveis).
class WeatherFactorEvaluator {
  final WeatherEvaluationConfig config;

  const WeatherFactorEvaluator([this.config = const WeatherEvaluationConfig()]);

  /// Avalia todos os critérios da regra. [forecast] null = sem previsão.
  /// [cropStage]: estádio fenológico atual da lavoura, se conhecido.
  List<FactorEvaluation> evaluate(
    ScientificPestRule rule, {
    required WeatherForecast? forecast,
    required DateTime now,
    String? cropStage,
  }) {
    final window = forecast == null ? null : _window(forecast, now);
    final noData = forecast == null ? 'previsão indisponível' : null;

    FactorEvaluation run(
      FactorKind kind,
      FactorEvaluation Function(List<HourSample> hours) eval,
    ) {
      if (noData != null) return _notEvaluable(kind, noData);
      if (window!.isEmpty) {
        return _notEvaluable(kind, 'previsão sem horários no período analisado');
      }
      return eval(window);
    }

    return [
      if (rule.temperature case final c?)
        run(FactorKind.temperature, (h) => _temperature(c, h)),
      if (rule.humidity case final c?)
        run(FactorKind.humidity, (h) => _humidity(c, h)),
      if (rule.precipitation case final c?)
        run(FactorKind.precipitation, (h) => _precipitation(c, h)),
      if (rule.leafWetness case final c?)
        run(FactorKind.leafWetness, (h) => _leafWetness(c, h)),
      if (rule.dewPoint case final c?)
        run(FactorKind.dewPoint, (h) => _dewPoint(c, h)),
      if (rule.degreeDays case final c?)
        noData != null
            ? _notEvaluable(FactorKind.degreeDays, noData)
            : _degreeDays(c, forecast!, now),
      if (rule.wind case final c?) run(FactorKind.wind, (h) => _wind(c, h)),
      if (rule.phenology case final c?) _phenology(c, cropStage),
    ];
  }

  // ── Janela ────────────────────────────────────────────────────────────────

  /// Horas da previsão em [hora atual, hora atual + horizonte).
  List<HourSample> _window(WeatherForecast forecast, DateTime now) {
    final start = DateTime(now.year, now.month, now.day, now.hour);
    final end = start.add(Duration(hours: config.horizonHours));
    return _samples(forecast)
        .where((s) => !s.time.isBefore(start) && s.time.isBefore(end))
        .toList();
  }

  static List<HourSample> _samples(WeatherForecast forecast) {
    final h = forecast.hourly;
    final t = h.valuesOf(HourlyVariable.temperature);
    final rh = h.valuesOf(HourlyVariable.relativeHumidity);
    final p = h.valuesOf(HourlyVariable.precipitation);
    final w = h.valuesOf(HourlyVariable.windSpeed);
    return [
      for (var i = 0; i < h.times.length; i++)
        HourSample(h.times[i],
            temperature: t[i],
            humidity: rh[i],
            precipitation: p[i],
            windSpeed: w[i]),
    ];
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  FactorEvaluation _notEvaluable(FactorKind kind, String why,
          {bool estimated = false}) =>
      FactorEvaluation(
        kind: kind,
        status: FactorStatus.notEvaluable,
        detail: why,
        estimated: estimated,
      );

  FactorEvaluation _scored(FactorKind kind, double score, String detail,
      {bool estimated = false}) {
    final s = score.clamp(0.0, 1.0);
    final status = s >= config.favorableScoreThreshold
        ? FactorStatus.favorable
        : s >= config.partialScoreThreshold
            ? FactorStatus.partiallyFavorable
            : FactorStatus.unfavorable;
    return FactorEvaluation(
      kind: kind,
      status: status,
      score: s,
      detail: detail,
      estimated: estimated,
    );
  }

  /// Mensagem de cobertura insuficiente, ou null se a cobertura basta.
  String? _coverageProblem(int present, int total, String variable) {
    if (total == 0 || present / total < config.minHourlyCoverage) {
      return 'dados de $variable insuficientes na previsão '
          '($present de $total horas)';
    }
    return null;
  }

  static bool _inRange(double v, double? min, double? max) =>
      (min == null || v >= min) && (max == null || v <= max);

  /// Maior sequência contínua de horas com `true`. null quebra a sequência.
  static int _longestRun(Iterable<bool?> flags) {
    var best = 0, current = 0;
    for (final f in flags) {
      current = f == true ? current + 1 : 0;
      best = math.max(best, current);
    }
    return best;
  }

  String get _windowLabel => 'próximas ${config.horizonHours} h';

  // ── Temperatura ───────────────────────────────────────────────────────────

  FactorEvaluation _temperature(TemperatureCriteria c, List<HourSample> hours) {
    const kind = FactorKind.temperature;
    final lo = c.min ?? c.optimalMin;
    final hi = c.max ?? c.optimalMax;
    if (lo == null && hi == null) {
      return _notEvaluable(kind,
          'a regra informa apenas um valor ótimo pontual, sem faixa para comparar');
    }
    final values =
        hours.map((h) => h.temperature).whereType<double>().toList();
    final problem = _coverageProblem(values.length, hours.length, 'temperatura');
    if (problem != null) return _notEvaluable(kind, problem);

    final hasOptimal = c.optimalMin != null || c.optimalMax != null;
    double hourScore(double t) {
      if (!_inRange(t, lo, hi)) return 0;
      if (!hasOptimal) return 1;
      return _inRange(t, c.optimalMin, c.optimalMax)
          ? 1
          : config.suboptimalTemperatureScore;
    }

    final inRange = values.where((t) => _inRange(t, lo, hi)).length;
    final score = values.map(hourScore).reduce((a, b) => a + b) / values.length;
    final optimalText = hasOptimal
        ? ', ${values.where((t) => _inRange(t, c.optimalMin, c.optimalMax)).length} '
            'na faixa ótima (${fmtRange(c.optimalMin, c.optimalMax, TemperatureCriteria.unit)})'
        : '';
    return _scored(
      kind,
      score,
      '$inRange de ${values.length} horas ($_windowLabel) na faixa favorável '
      '(${fmtRange(lo, hi, TemperatureCriteria.unit)})$optimalText',
    );
  }

  // ── Umidade ───────────────────────────────────────────────────────────────

  FactorEvaluation _humidity(HumidityCriteria c, List<HourSample> hours) {
    const kind = FactorKind.humidity;
    if (c.min == null && c.max == null) {
      return _notEvaluable(kind, 'a regra não define faixa de umidade');
    }
    final present = hours.where((h) => h.humidity != null).length;
    final problem =
        _coverageProblem(present, hours.length, 'umidade relativa');
    if (problem != null) return _notEvaluable(kind, problem);

    final range = fmtRange(c.min, c.max, HumidityCriteria.unit);
    final flags = hours
        .map((h) => h.humidity == null ? null : _inRange(h.humidity!, c.min, c.max))
        .toList();
    final matching = flags.where((f) => f == true).length;

    final duration = c.minDurationHours;
    if (duration != null && duration > 0) {
      final run = _longestRun(flags);
      return _scored(
        kind,
        run / duration,
        'maior período contínuo com UR $range: $run h '
        '(regra: ≥ ${fmtNum(duration)} h) nas $_windowLabel',
      );
    }
    return _scored(
      kind,
      matching / present,
      '$matching de $present horas ($_windowLabel) com UR $range',
    );
  }

  // ── Precipitação ──────────────────────────────────────────────────────────

  FactorEvaluation _precipitation(
      PrecipitationCriteria c, List<HourSample> hours) {
    const kind = FactorKind.precipitation;
    final present = hours.where((h) => h.precipitation != null).length;
    final problem = _coverageProblem(present, hours.length, 'precipitação');
    if (problem != null) return _notEvaluable(kind, problem);

    final hasAmount = c.minAmountMm != null || c.maxAmountMm != null;
    if (!hasAmount && c.condition == null) {
      return _notEvaluable(kind, 'a regra não define quantidade nem condição');
    }

    final bool matches;
    final String observed;
    if (hasAmount) {
      // Período da regra; sem período, a janela inteira (dito na explicação).
      final period = c.periodHours?.round();
      final size = (period == null || period <= 0 || period > hours.length)
          ? hours.length
          : period;
      // Só janelas com todas as horas presentes — hora sem dado nunca vale 0.
      final sums = <double>[];
      for (var i = 0; i + size <= hours.length; i++) {
        final values = hours.sublist(i, i + size).map((h) => h.precipitation);
        if (values.any((v) => v == null)) continue;
        sums.add(values.whereType<double>().reduce((a, b) => a + b));
      }
      if (sums.isEmpty) {
        return _notEvaluable(kind,
            'nenhum período de $size h com precipitação completa na previsão');
      }
      matches = sums.any((s) => _inRange(s, c.minAmountMm, c.maxAmountMm));
      final maxSum = sums.reduce(math.max);
      final periodText = period == null
          ? 'em toda a janela (regra sem período definido)'
          : 'em $size h';
      observed = 'maior acumulado previsto $periodText: '
          '${fmtNum(maxSum)} mm (regra: '
          '${fmtRange(c.minAmountMm, c.maxAmountMm, PrecipitationCriteria.unit)})';
    } else {
      final rainyHours = hours
          .where((h) => (h.precipitation ?? 0) >= config.rainEventThresholdMm)
          .length;
      matches = rainyHours > 0;
      observed = '$rainyHours horas com chuva prevista '
          '(≥ ${fmtNum(config.rainEventThresholdMm)} mm/h) nas $_windowLabel';
    }

    final rainIsUnfavorable =
        c.condition == PrecipitationCondition.unfavorable;
    final favorable = rainIsUnfavorable ? !matches : matches;
    final conditionText = rainIsUnfavorable
        ? 'a regra indica chuva como desfavorável'
        : 'a regra indica chuva como favorável';
    return _scored(kind, favorable ? 1 : 0, '$observed; $conditionText');
  }

  // ── Molhamento (estimado) ─────────────────────────────────────────────────

  FactorEvaluation _leafWetness(LeafWetnessCriteria c, List<HourSample> hours) {
    const kind = FactorKind.leafWetness;
    final required = c.minDurationHours ?? c.optimalDurationHours;
    if (required == null || required <= 0) {
      return _notEvaluable(kind, 'a regra não define duração de molhamento',
          estimated: true);
    }
    // Hora "provavelmente molhada": UR alta ou chuva. "Seca" só quando os
    // dois dados existem e nenhum indica molhamento; senão, desconhecida.
    bool? wet(HourSample h) {
      final byRh = h.humidity == null
          ? null
          : h.humidity! >= config.wetnessHumidityThreshold;
      final byRain = h.precipitation == null
          ? null
          : h.precipitation! >= config.wetnessPrecipitationThresholdMm;
      if (byRh == true || byRain == true) return true;
      if (byRh == false && byRain == false) return false;
      return null;
    }

    final flags = hours.map(wet).toList();
    final known = flags.where((f) => f != null).length;
    final problem =
        _coverageProblem(known, hours.length, 'umidade/chuva para estimar molhamento');
    if (problem != null) return _notEvaluable(kind, problem, estimated: true);

    final run = _longestRun(flags);
    return _scored(
      kind,
      run / required,
      'maior período contínuo com condição estimada de molhamento: $run h '
      '(regra: ≥ ${fmtNum(required)} h). Estimativa por UR ≥ '
      '${fmtNum(config.wetnessHumidityThreshold)}% ou chuva — não é medição '
      'direta de molhamento foliar',
      estimated: true,
    );
  }

  // ── Ponto de orvalho (estimado) ───────────────────────────────────────────

  /// Ponto de orvalho pela aproximação de Magnus (coeficientes 17,62 e
  /// 243,12 °C), a partir de temperatura e UR. null se UR inválida.
  static double? dewPointMagnus(double temperature, double humidity) {
    if (humidity <= 0 || humidity > 100) return null;
    const a = 17.62, b = 243.12;
    final gamma =
        math.log(humidity / 100) + a * temperature / (b + temperature);
    return b * gamma / (a - gamma);
  }

  FactorEvaluation _dewPoint(DewPointCriteria c, List<HourSample> hours) {
    const kind = FactorKind.dewPoint;
    if (!c.hasParameters) {
      return _notEvaluable(kind, 'a regra não define parâmetros de ponto de orvalho',
          estimated: true);
    }
    final matches = <bool>[];
    for (final h in hours) {
      if (h.temperature == null || h.humidity == null) continue;
      final td = dewPointMagnus(h.temperature!, h.humidity!);
      if (td == null) continue;
      final depression = h.temperature! - td;
      matches.add(_inRange(td, c.min, c.max) &&
          (c.maxDepression == null || depression <= c.maxDepression!));
    }
    final problem = _coverageProblem(
        matches.length, hours.length, 'temperatura/umidade para estimar o ponto de orvalho');
    if (problem != null) return _notEvaluable(kind, problem, estimated: true);

    final ok = matches.where((m) => m).length;
    final parts = [
      ?fmtRange(c.min, c.max, DewPointCriteria.unit),
      if (c.maxDepression != null)
        'diferença temperatura − orvalho ≤ ${fmtNum(c.maxDepression!)} °C',
    ];
    return _scored(
      kind,
      ok / matches.length,
      '$ok de ${matches.length} horas ($_windowLabel) atendem '
      '${parts.join(' e ')}. Ponto de orvalho estimado a partir de '
      'temperatura e UR (fórmula de Magnus)',
      estimated: true,
    );
  }

  // ── Graus-dia ─────────────────────────────────────────────────────────────

  /// Graus-dia pelo método horário: média, ao longo do dia, de
  /// max(0, min(T, limite superior) − base). Só dias completos (ver
  /// [WeatherEvaluationConfig.degreeDayMinHoursPerDay]) a partir de hoje.
  FactorEvaluation _degreeDays(
      DegreeDayCriteria c, WeatherForecast forecast, DateTime now) {
    const kind = FactorKind.degreeDays;
    final base = c.baseTemperature;
    if (base == null) {
      return _notEvaluable(kind, 'a regra não define temperatura-base');
    }
    final upper = c.upperThreshold;
    final today = DateTime(now.year, now.month, now.day);

    final byDay = <DateTime, List<double>>{};
    final hoursPerDay = <DateTime, int>{};
    for (final s in _samples(forecast)) {
      final day = DateTime(s.time.year, s.time.month, s.time.day);
      if (day.isBefore(today)) continue;
      hoursPerDay[day] = (hoursPerDay[day] ?? 0) + 1;
      if (s.temperature != null) byDay.putIfAbsent(day, () => []).add(s.temperature!);
    }
    final completeDays = byDay.entries
        .where((e) =>
            e.value.length >= config.degreeDayMinHoursPerDay &&
            e.value.length == hoursPerDay[e.key])
        .toList();
    if (completeDays.length < config.minDegreeDayDays) {
      return _notEvaluable(
        kind,
        'graus-dia exigem ao menos ${config.minDegreeDayDays} dias completos '
        'de temperatura na previsão (disponíveis: ${completeDays.length})',
      );
    }

    var accumulated = 0.0;
    for (final day in completeDays) {
      final temps = day.value;
      final dd = temps
              .map((t) => math.max(0.0, (upper == null ? t : math.min(t, upper)) - base))
              .reduce((a, b) => a + b) /
          temps.length;
      accumulated += dd;
    }

    final baseText = 'base ${fmtNum(base)} °C'
        '${upper == null ? '' : ', limite superior ${fmtNum(upper)} °C'}';
    final observed = '${fmtNum(accumulated)} graus-dia projetados em '
        '${completeDays.length} dias de previsão ($baseText)';
    const caveat =
        '. O acúmulo desde o início do ciclo não é conhecido; '
        'avaliado apenas o período previsto';

    if (c.thresholds.isEmpty) {
      return FactorEvaluation(
        kind: kind,
        status: FactorStatus.informational,
        detail: '$observed; a regra não define acumulado de referência$caveat',
      );
    }
    final target = c.thresholds
        .reduce((a, b) => a.accumulated <= b.accumulated ? a : b);
    final stage = target.stage == null ? '' : ' (${target.stage})';
    return _scored(
      kind,
      target.accumulated <= 0 ? 1 : accumulated / target.accumulated,
      '$observed; referência da regra: ${fmtNum(target.accumulated)} '
      'graus-dia$stage$caveat',
    );
  }

  // ── Vento ─────────────────────────────────────────────────────────────────

  FactorEvaluation _wind(WindCriteria c, List<HourSample> hours) {
    const kind = FactorKind.wind;
    if (!c.hasParameters) {
      return _notEvaluable(kind, 'a regra não define faixa de vento');
    }
    final values = hours.map((h) => h.windSpeed).whereType<double>().toList();
    final problem = _coverageProblem(values.length, hours.length, 'vento');
    if (problem != null) return _notEvaluable(kind, problem);
    final ok = values.where((v) => _inRange(v, c.minSpeed, c.maxSpeed)).length;
    return _scored(
      kind,
      ok / values.length,
      '$ok de ${values.length} horas ($_windowLabel) com vento '
      '${fmtRange(c.minSpeed, c.maxSpeed, WindCriteria.unit)}',
    );
  }

  // ── Fenologia ─────────────────────────────────────────────────────────────

  FactorEvaluation _phenology(PhenologyCriteria c, String? cropStage) {
    const kind = FactorKind.phenology;
    if (c.susceptibleStages.isEmpty) {
      return _notEvaluable(kind, 'a regra não lista estádios suscetíveis');
    }
    final stages = c.susceptibleStages.join(', ');
    if (cropStage == null || cropStage.trim().isEmpty) {
      return _notEvaluable(kind,
          'estádio fenológico da lavoura não informado (regra: $stages)');
    }
    final target = normalizeOrganismName(cropStage);
    final match =
        c.susceptibleStages.any((s) => normalizeOrganismName(s) == target);
    return _scored(
      kind,
      match ? 1 : 0,
      'estádio atual "$cropStage"; estádios suscetíveis na regra: $stages',
    );
  }
}
