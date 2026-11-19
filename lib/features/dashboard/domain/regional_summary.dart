import '../../../core/services/location_service.dart';
import '../../favorability/domain/organism_name.dart';
import '../../occurrence/domain/occurrence_model.dart';
import '../../weather/data/weather_repository.dart';

/// Ocorrência acompanhada da distância até a propriedade.
class OccurrenceDistance {
  final OccurrenceModel occurrence;
  final double distanceKm;
  const OccurrenceDistance(this.occurrence, this.distanceKm);
}

/// Organismo identificado pela IA, agregado na região.
///
/// O agrupamento é feito pelo nome retornado pela IA, normalizado da mesma
/// forma que no motor de favorabilidade (sem acentos, caixa e pontuação),
/// para que Dashboard e alertas contem as mesmas ocorrências. Sinônimos e
/// nomes científicos não são unificados aqui.
class OrganismCount {
  final String name;
  final int count;
  final double nearestKm;
  final DateTime lastSeen;

  const OrganismCount({
    required this.name,
    required this.count,
    required this.nearestKm,
    required this.lastSeen,
  });
}

/// Contagem de ocorrências com problema em um intervalo de 7 dias.
class WeeklyCount {
  final DateTime start; // inclusivo
  final DateTime end; // exclusivo
  final int count;
  const WeeklyCount({
    required this.start,
    required this.end,
    required this.count,
  });
}

/// Resumo das ocorrências reais registradas no raio e no período da propriedade.
///
/// Classificação de cada ocorrência:
///   - com problema: diagnóstico presente e não saudável (mesmo critério do radar);
///   - aguardando análise: sem diagnóstico;
///   - sem problema identificado: diagnóstico saudável ou inconclusivo.
class RegionalSummary {
  final double radiusKm;
  final int windowDays;
  final DateTime periodStart;
  final DateTime periodEnd;

  final int totalInRadius;
  final int withProblem;
  final int pendingAnalysis;
  final int withoutProblem;

  /// Ocorrências do próprio usuário dentro do raio e do período.
  final int ownCount;

  /// Ocorrências descartadas por coordenadas inválidas ou ausentes.
  final int discardedInvalidLocation;

  /// Ocorrências com problema mais recentes (mais nova primeiro).
  final List<OccurrenceDistance> recent;

  /// Organismos mais registrados (mais registros primeiro).
  final List<OrganismCount> organisms;

  /// Distribuição semanal das ocorrências com problema (mais antiga primeiro).
  final List<WeeklyCount> weekly;

  /// Distância da ocorrência com problema mais próxima (null se não houver).
  final double? nearestProblemKm;

  const RegionalSummary({
    required this.radiusKm,
    required this.windowDays,
    required this.periodStart,
    required this.periodEnd,
    required this.totalInRadius,
    required this.withProblem,
    required this.pendingAnalysis,
    required this.withoutProblem,
    required this.ownCount,
    required this.discardedInvalidLocation,
    required this.recent,
    required this.organisms,
    required this.weekly,
    required this.nearestProblemKm,
  });

  bool get isEmpty => totalInRadius == 0;

  /// Monta o resumo a partir das ocorrências reais.
  ///
  /// [occurrences] pode conter registros fora do raio/período — eles são
  /// filtrados aqui. [distanceKm] é injetável para testes.
  factory RegionalSummary.build({
    required List<OccurrenceModel> occurrences,
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int windowDays,
    required DateTime now,
    required String userId,
    int recentLimit = 3,
    int organismLimit = 5,
    double Function(double, double, double, double)? distanceKm,
  }) {
    final dist =
        distanceKm ??
        (lat1, lng1, lat2, lng2) =>
            LocationService.distanceBetween(lat1, lng1, lat2, lng2) / 1000;

    final periodStart = now.subtract(Duration(days: windowDays));

    var discarded = 0;
    final inRadius = <OccurrenceDistance>[];

    for (final o in occurrences) {
      if (o.timestamp.isBefore(periodStart) || o.timestamp.isAfter(now)) {
        continue;
      }
      if (!WeatherRepository.isValidCoordinate(o.latitude, o.longitude)) {
        discarded++;
        continue;
      }
      final d = dist(latitude, longitude, o.latitude, o.longitude);
      if (d <= radiusKm) inRadius.add(OccurrenceDistance(o, d));
    }

    final problems =
        inRadius
            .where(
              (e) =>
                  e.occurrence.diagnosis != null &&
                  !e.occurrence.diagnosis!.isHealthy,
            )
            .toList()
          ..sort(
            (a, b) => b.occurrence.timestamp.compareTo(a.occurrence.timestamp),
          );

    final pending = inRadius
        .where((e) => e.occurrence.diagnosis == null)
        .length;

    return RegionalSummary(
      radiusKm: radiusKm,
      windowDays: windowDays,
      periodStart: periodStart,
      periodEnd: now,
      totalInRadius: inRadius.length,
      withProblem: problems.length,
      pendingAnalysis: pending,
      withoutProblem: inRadius.length - problems.length - pending,
      ownCount: inRadius.where((e) => e.occurrence.reportedBy == userId).length,
      discardedInvalidLocation: discarded,
      recent: problems.take(recentLimit).toList(),
      organisms: _groupOrganisms(problems).take(organismLimit).toList(),
      weekly: _weekly(problems, now, windowDays),
      nearestProblemKm: problems.isEmpty
          ? null
          : problems.map((e) => e.distanceKm).reduce((a, b) => a < b ? a : b),
    );
  }

  static String _normalize(String name) => normalizeOrganismName(name);

  static List<OrganismCount> _groupOrganisms(
    List<OccurrenceDistance> problems,
  ) {
    final groups = <String, List<OccurrenceDistance>>{};
    for (final e in problems) {
      final name = e.occurrence.diagnosis!.pestName;
      if (name.trim().isEmpty) continue;
      groups.putIfAbsent(_normalize(name), () => []).add(e);
    }

    final result =
        groups.values.map((items) {
          // Exibe a grafia mais frequente do grupo.
          final spellings = <String, int>{};
          for (final e in items) {
            final n = e.occurrence.diagnosis!.pestName.trim();
            spellings[n] = (spellings[n] ?? 0) + 1;
          }
          final name = spellings.entries
              .reduce((a, b) => b.value > a.value ? b : a)
              .key;
          return OrganismCount(
            name: name,
            count: items.length,
            nearestKm: items
                .map((e) => e.distanceKm)
                .reduce((a, b) => a < b ? a : b),
            lastSeen: items
                .map((e) => e.occurrence.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );
        }).toList()..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : b.lastSeen.compareTo(a.lastSeen);
        });
    return result;
  }

  static List<WeeklyCount> _weekly(
    List<OccurrenceDistance> problems,
    DateTime now,
    int windowDays,
  ) {
    final weeks = (windowDays / 7).ceil();
    return List.generate(weeks, (i) {
      // i = 0 é a semana mais antiga.
      final end = now.subtract(Duration(days: 7 * (weeks - 1 - i)));
      final start = end.subtract(const Duration(days: 7));
      final count = problems.where((e) {
        final t = e.occurrence.timestamp;
        // Última semana inclui o instante "now".
        final beforeEnd = i == weeks - 1 ? !t.isAfter(end) : t.isBefore(end);
        return !t.isBefore(start) && beforeEnd;
      }).length;
      return WeeklyCount(start: start, end: end, count: count);
    });
  }
}
