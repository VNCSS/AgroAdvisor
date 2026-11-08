import 'dart:math' as math;

import '../../property/domain/property_model.dart';
import '../../weather/data/weather_repository.dart';
import '../../weather/domain/weather_forecast.dart';
import 'favorability_config.dart';
import 'favorability_result.dart';
import 'organism_name.dart';
import 'pt_format.dart';
import 'regional_occurrence.dart';
import 'scientific_pest_rule.dart';
import 'scientific_rule_catalog.dart';
import 'weather_factor_evaluator.dart';

/// Dados da propriedade necessários ao motor.
class PropertyContext {
  final String id;
  final double latitude;
  final double longitude;

  /// Cultura principal; null/vazio = não informada.
  final String? crop;

  /// Estádio fenológico atual, se conhecido (o app ainda não registra).
  final String? cropStage;

  const PropertyContext({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.crop,
    this.cropStage,
  });

  factory PropertyContext.fromProperty(PropertyModel p, {String? cropStage}) =>
      PropertyContext(
        id: p.id,
        latitude: p.latitude,
        longitude: p.longitude,
        crop: p.mainCrop,
        cropStage: cropStage,
      );
}

/// Distância em km entre dois pontos (injetável para testes).
typedef DistanceFn = double Function(
    double lat1, double lng1, double lat2, double lng2);

/// Distância de grande círculo (haversine), em km.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0088;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Motor dinâmico de favorabilidade.
///
/// Puro e síncrono: recebe dados já carregados e devolve um
/// [FavorabilityReport]. Não acessa Firestore, rede nem interface.
///
/// Não há código específico por organismo: cada organismo é avaliado pela
/// própria regra científica e só pelos parâmetros que ela define. Sem regra
/// utilizável, não há índice (status insufficientScientificData), mas as
/// ocorrências continuam no resultado.
class FavorabilityEngine {
  final FavorabilityConfig config;
  final DistanceFn _distance;

  FavorabilityEngine({
    this.config = const FavorabilityConfig(),
    DistanceFn? distanceKm,
  }) : _distance = distanceKm ?? haversineKm;

  /// Mesmo motor (e mesma função de distância) com outra configuração.
  FavorabilityEngine withConfig(FavorabilityConfig config) =>
      FavorabilityEngine(config: config, distanceKm: _distance);

  WeatherFactorEvaluator get _evaluator =>
      WeatherFactorEvaluator(config.weather);

  FavorabilityReport assess({
    required PropertyContext property,
    required List<RegionalOccurrence> occurrences,
    required ScientificRuleCatalog catalog,
    required WeatherForecast? forecast,
    required DateTime now,
    bool forecastIsStale = false,
  }) {
    final crop = _cropOf(property.crop);
    final warnings = <ReportWarning>[
      if (crop == null) ReportWarning.cropMissing,
      if (forecast == null) ReportWarning.forecastUnavailable,
      if (forecast != null && forecastIsStale) ReportWarning.forecastStale,
    ];

    FavorabilityReport report(ReportStatus status,
            {OccurrenceScreening screening = OccurrenceScreening.empty,
            List<OrganismAssessment> organisms = const []}) =>
        FavorabilityReport(
          propertyId: property.id,
          crop: crop,
          generatedAt: now,
          status: status,
          warnings: warnings,
          screening: screening,
          organisms: organisms,
        );

    if (!WeatherRepository.isValidCoordinate(
        property.latitude, property.longitude)) {
      return report(ReportStatus.locationUnavailable,
          screening: OccurrenceScreening.empty);
    }

    final (accepted, screening) = _screen(property, occurrences, crop, now);
    if (accepted.any((e) => e.occurrence.crop == null)) {
      warnings.add(ReportWarning.occurrenceCropUnknown);
    }

    final groups = _group(accepted, catalog);
    final assessments = [
      for (final g in groups)
        if (g.items.length >= config.occurrences.minOccurrencesPerOrganism)
          _assessOrganism(g, property, crop, forecast, now),
    ]..sort(_byRelevance);

    if (assessments.isEmpty) {
      return report(ReportStatus.noRecentOccurrences, screening: screening);
    }
    return report(ReportStatus.ok,
        screening: screening, organisms: assessments);
  }

  // ── 1. Cultura ────────────────────────────────────────────────────────────

  String? _cropOf(String? raw) {
    if (raw == null) return null;
    final normalized = normalizeOrganismName(raw);
    final unspecified =
        config.unspecifiedCropValues.map(normalizeOrganismName).toSet();
    return unspecified.contains(normalized) ? null : raw.trim();
  }

  // ── 2. Triagem das ocorrências ────────────────────────────────────────────

  (List<OccurrenceEvidence>, OccurrenceScreening) _screen(
    PropertyContext property,
    List<RegionalOccurrence> occurrences,
    String? crop,
    DateTime now,
  ) {
    final cfg = config.occurrences;
    final since = now.subtract(Duration(days: cfg.windowDays));
    var outsideWindow = 0,
        invalidLocation = 0,
        outsideRadius = 0,
        lowConfidence = 0,
        otherCrop = 0,
        duplicates = 0;

    final candidates = <OccurrenceEvidence>[];
    for (final o in occurrences) {
      if (o.timestamp.isBefore(since) || o.timestamp.isAfter(now)) {
        outsideWindow++;
        continue;
      }
      if (!WeatherRepository.isValidCoordinate(o.latitude, o.longitude)) {
        invalidLocation++;
        continue;
      }
      final d = _distance(
          property.latitude, property.longitude, o.latitude, o.longitude);
      if (d > cfg.radiusKm) {
        outsideRadius++;
        continue;
      }
      final minConf = cfg.minDiagnosisConfidence;
      if (minConf != null &&
          (o.diagnosisConfidence == null || o.diagnosisConfidence! < minConf)) {
        lowConfidence++;
        continue;
      }
      if (cfg.excludeOtherCropOccurrences &&
          crop != null &&
          o.crop != null &&
          normalizeOrganismName(o.crop!) != normalizeOrganismName(crop)) {
        otherCrop++;
        continue;
      }
      final ageDays = now.difference(o.timestamp).inMinutes / (60 * 24);
      final weight = math.pow(0.5, ageDays / cfg.recencyHalfLifeDays) *
          math.pow(0.5, d / cfg.distanceHalfLifeKm);
      candidates.add(OccurrenceEvidence(
        occurrence: o,
        distanceKm: d,
        ageDays: ageDays,
        weight: weight.toDouble(),
      ));
    }

    // Duplicidade: mesmo id, ou mesmo autor + organismo muito próximos no
    // espaço e no tempo (reenvio da mesma constatação). Mantém a mais antiga.
    candidates.sort((a, b) => a.occurrence.timestamp.compareTo(b.occurrence.timestamp));
    // Só ocorrências do mesmo autor e organismo podem ser duplicatas entre
    // si: compara dentro desse grupo, não com todas (evita custo quadrático).
    final kept = <OccurrenceEvidence>[];
    final ids = <String>{};
    final keptByAuthorAndOrganism = <String, List<RegionalOccurrence>>{};
    for (final c in candidates) {
      final o = c.occurrence;
      var isDuplicate = !ids.add(o.id);
      if (!isDuplicate && o.reportedBy.isNotEmpty) {
        final bucket = keptByAuthorAndOrganism.putIfAbsent(
            '${o.reportedBy}|${normalizeOrganismName(o.organismName)}',
            () => []);
        isDuplicate = bucket.any((other) =>
            o.timestamp.difference(other.timestamp).abs() <=
                cfg.duplicateTimeWindow &&
            _distance(other.latitude, other.longitude, o.latitude,
                    o.longitude) <=
                cfg.duplicateDistanceKm);
        if (!isDuplicate) bucket.add(o);
      }
      if (isDuplicate) {
        duplicates++;
      } else {
        kept.add(c);
      }
    }

    return (
      kept,
      OccurrenceScreening(
        received: occurrences.length,
        accepted: kept.length,
        outsideWindow: outsideWindow,
        invalidLocation: invalidLocation,
        outsideRadius: outsideRadius,
        lowConfidence: lowConfidence,
        otherCrop: otherCrop,
        duplicates: duplicates,
      ),
    );
  }

  // ── 3. Agrupamento por organismo ──────────────────────────────────────────

  /// Agrupa pelo organismo. Nomes que resolvem para a mesma regra (nome
  /// popular, científico ou sinônimo) formam um único grupo; os demais
  /// agrupam pelo nome normalizado. O tipo informado pela IA não é usado.
  List<_OrganismGroup> _group(
      List<OccurrenceEvidence> items, ScientificRuleCatalog catalog) {
    final groups = <String, _OrganismGroup>{};
    for (final e in items) {
      final lookup = catalog.lookup(e.occurrence.organismName);
      final rule = switch (lookup) {
        RuleFound(:final rule) => rule,
        RuleUnavailable(:final rule) => rule,
        RuleNotFound() => null,
      };
      final key = rule != null
          ? 'rule:${rule.id}'
          : 'name:${normalizeOrganismName(e.occurrence.organismName)}';
      groups.putIfAbsent(key, () => _OrganismGroup(lookup, rule)).items.add(e);
    }
    return groups.values.toList();
  }

  // ── 4–13. Avaliação de um organismo ───────────────────────────────────────

  OrganismAssessment _assessOrganism(
    _OrganismGroup group,
    PropertyContext property,
    String? crop,
    WeatherForecast? forecast,
    DateTime now,
  ) {
    final regional = _regionalEvidence(group.items);
    final names = group.items.map((e) => e.occurrence.organismName.trim()).toSet();
    final displayName = group.rule?.organismName ?? _mostFrequent(group.items);

    OrganismAssessment withoutIndex(AssessmentStatus status, String message,
        List<String> reasons, EnvironmentalAssessment? environmental) {
      return OrganismAssessment(
        organismName: displayName,
        reportedNames: names,
        rule: group.rule,
        status: status,
        message: message,
        reasons: reasons,
        environmental: environmental,
        regional: regional,
        favorabilityIndex: null,
        level: null,
        explanation: _explain(
          name: displayName,
          rule: group.rule,
          crop: crop,
          environmental: environmental,
          regional: regional,
          now: now,
          resultLines: [message, ...reasons.map((r) => 'Motivo: $r')],
        ),
      );
    }

    // 5–6. Regra científica disponível?
    final rule = switch (group.lookup) {
      RuleFound(:final rule) => rule,
      _ => null,
    };
    if (rule == null) {
      final reasons = switch (group.lookup) {
        RuleUnavailable(:final reasons) => reasons,
        _ => ['Nenhuma regra científica cadastrada para este organismo'],
      };
      return withoutIndex(AssessmentStatus.insufficientScientificData,
          insufficientScientificDataMessage, reasons, null);
    }

    // Cultura afetada?
    if (crop != null && rule.appliesToCrop(crop) == false) {
      return withoutIndex(
        AssessmentStatus.cropNotAffected,
        'A regra científica deste organismo não lista a cultura "$crop" '
        'entre as culturas afetadas. Favorabilidade não estimada.',
        ['Culturas na regra: ${rule.affectedCrops.join(', ')}'],
        null,
      );
    }

    // 7–9. Clima.
    final factors = _evaluator.evaluate(rule,
        forecast: forecast, now: now, cropStage: property.cropStage);
    final environmental = _environmental(factors);
    if (environmental.score == null) {
      final missing = factors
          .where((f) => f.status == FactorStatus.notEvaluable)
          .map((f) => '${f.kind.label}: ${f.detail}')
          .toList();
      return withoutIndex(AssessmentStatus.insufficientWeatherData,
          insufficientWeatherDataMessage, missing, environmental);
    }

    // 11–12. Combinação e nível.
    final s = config.scoring;
    final combined = (s.environmentalWeight * environmental.score! +
            s.regionalWeight * regional.score) /
        (s.environmentalWeight + s.regionalWeight);
    final index = (combined * 100).round().clamp(0, 100);
    final level = config.levels.levelFor(index);

    return OrganismAssessment(
      organismName: displayName,
      reportedNames: names,
      rule: rule,
      status: AssessmentStatus.assessed,
      message: level.headline,
      reasons: const [],
      environmental: environmental,
      regional: regional,
      favorabilityIndex: index,
      level: level,
      explanation: _explain(
        name: displayName,
        rule: rule,
        crop: crop,
        environmental: environmental,
        regional: regional,
        now: now,
        resultLines: [
          'Índice de favorabilidade: $index/100 '
              '(componente ambiental ${(environmental.score! * 100).round()}/100, '
              'evidência regional ${(regional.score * 100).round()}/100)',
          'Nível de atenção: ${level.label}',
          'Resultado: ${level.headline}',
          favorabilityIndexDisclaimer,
        ],
      ),
    );
  }

  // 9. Componente ambiental.
  EnvironmentalAssessment _environmental(List<FactorEvaluation> factors) {
    final s = config.scoring;
    double weightSum(Iterable<FactorEvaluation> fs) =>
        fs.fold(0.0, (sum, f) => sum + s.weightOf(f.kind));

    final scored = factors.where((f) => f.isScored).toList();
    final meteo = factors.where((f) =>
        f.kind.meteorological && f.status != FactorStatus.informational);
    final meteoScored = meteo.where((f) => f.isScored);
    final meteoTotal = weightSum(meteo);
    final coverage = meteoTotal == 0 ? 0.0 : weightSum(meteoScored) / meteoTotal;

    final enough = meteoScored.isNotEmpty &&
        coverage >= config.weather.minEnvironmentalCoverage;
    final scoredWeight = weightSum(scored);
    final score = !enough || scoredWeight == 0
        ? null
        : scored.fold(0.0, (sum, f) => sum + s.weightOf(f.kind) * f.score!) /
            scoredWeight;

    return EnvironmentalAssessment(
        factors: factors, score: score, coverage: coverage);
  }

  // 10. Evidência regional.
  RegionalEvidence _regionalEvidence(List<OccurrenceEvidence> items) {
    final cfg = config.occurrences;
    final sorted = [...items]
      ..sort((a, b) => b.occurrence.timestamp.compareTo(a.occurrence.timestamp));
    final weighted = sorted.fold(0.0, (sum, e) => sum + e.weight);
    return RegionalEvidence(
      occurrences: List.unmodifiable(sorted),
      weightedCount: weighted,
      score: math.min(1.0, weighted / cfg.saturationWeightedCount),
      withinConcentrationRadius:
          sorted.where((e) => e.distanceKm <= cfg.concentrationRadiusKm).length,
      unknownCropCount: sorted.where((e) => e.occurrence.crop == null).length,
    );
  }

  static String _mostFrequent(List<OccurrenceEvidence> items) {
    final counts = <String, int>{};
    for (final e in items) {
      final n = e.occurrence.organismName.trim();
      counts[n] = (counts[n] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  static int _byRelevance(OrganismAssessment a, OrganismAssessment b) {
    if (a.hasIndex != b.hasIndex) return a.hasIndex ? -1 : 1;
    if (a.hasIndex) {
      final byIndex = b.favorabilityIndex!.compareTo(a.favorabilityIndex!);
      if (byIndex != 0) return byIndex;
    }
    return b.regional.score.compareTo(a.regional.score);
  }

  // 13. Explicação.
  List<String> _explain({
    required String name,
    required ScientificPestRule? rule,
    required String? crop,
    required EnvironmentalAssessment? environmental,
    required RegionalEvidence regional,
    required DateTime now,
    required List<String> resultLines,
  }) {
    final cfg = config.occurrences;
    final lines = <String>[
      'Organismo: $name'
          '${rule?.scientificName == null ? '' : ' (${rule!.scientificName})'}',
      'Cultura: ${crop ?? 'não informada'}',
    ];

    if (rule != null && rule.sources.isNotEmpty) {
      final reviewed = rule.lastReviewedAt == null
          ? ''
          : ', revisada em ${fmtDate(rule.lastReviewedAt!)}';
      lines.add('Regra científica: ${rule.id}$reviewed');
      for (final src in rule.sources) {
        final who = src.institution == null ? '' : ' — ${src.institution}';
        lines.add('Fonte: ${src.title}$who${src.url == null ? '' : ' (${src.url})'}');
      }
    }

    if (environmental != null) {
      lines.add('Condições:');
      for (final f in environmental.factors) {
        lines.add('- ${f.kind.label}: ${f.status.label} — ${f.detail}');
      }
    }

    lines.add('Evidência regional (raio de ${fmtNum(cfg.radiusKm)} km, '
        'últimos ${cfg.windowDays} dias):');
    final n = regional.count;
    lines.add('- $n ${n == 1 ? 'ocorrência recente' : 'ocorrências recentes'}');
    if (regional.nearestKm != null) {
      lines.add('- ocorrência mais próxima: ${fmtKm(regional.nearestKm!)}');
    }
    if (regional.mostRecent != null) {
      lines.add('- ocorrência mais recente: '
          '${fmtDaysAgo(regional.mostRecent!.occurrence.timestamp, now)}');
    }
    lines.add('- ${regional.withinConcentrationRadius} a até '
        '${fmtNum(cfg.concentrationRadiusKm)} km da propriedade');
    if (regional.unknownCropCount > 0) {
      lines.add('- ${regional.unknownCropCount} sem cultura informada');
    }

    return [...lines, ...resultLines];
  }
}

class _OrganismGroup {
  final RuleLookup lookup;
  final ScientificPestRule? rule;
  final List<OccurrenceEvidence> items = [];
  _OrganismGroup(this.lookup, this.rule);
}
