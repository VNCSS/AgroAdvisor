import 'package:agro_advisor/features/dashboard/domain/regional_summary.dart';
import 'package:agro_advisor/features/occurrence/domain/diagnosis_model.dart';
import 'package:agro_advisor/features/occurrence/domain/occurrence_model.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 2, 12);

// Propriedade de referência.
const propLat = -22.73;
const propLng = -47.65;

DiagnosisModel diag(String pest, {String risk = 'alto'}) => DiagnosisModel(
  pestName: pest,
  riskLevel: risk,
  description: '',
  recommendation: '',
  confidenceScore: 0.8,
  detectedIssues: const [],
  analyzedAt: now,
);

/// [km] é a distância simulada até a propriedade (codificada na longitude
/// para o cálculo de distância injetado no teste).
OccurrenceModel occ(
  String id, {
  required double km,
  required int daysAgo,
  DiagnosisModel? diagnosis,
  String reportedBy = 'outro',
  double? lat,
  double? lng,
}) => OccurrenceModel(
  id: id,
  imageBase64: '',
  latitude: lat ?? propLat,
  longitude: lng ?? (propLng + km),
  timestamp: now.subtract(Duration(days: daysAgo)),
  reportedBy: reportedBy,
  diagnosis: diagnosis,
);

/// Distância fake: diferença de longitude = km.
double fakeKm(double lat1, double lng1, double lat2, double lng2) =>
    (lng2 - lng1).abs();

RegionalSummary build(List<OccurrenceModel> list, {double radiusKm = 20}) =>
    RegionalSummary.build(
      occurrences: list,
      latitude: propLat,
      longitude: propLng,
      radiusKm: radiusKm,
      windowDays: 28,
      now: now,
      userId: 'eu',
      recentLimit: 3,
      organismLimit: 5,
      distanceKm: fakeKm,
    );

void main() {
  group('propriedade sem ocorrências', () {
    test('lista vazia gera resumo vazio', () {
      final s = build([]);

      expect(s.isEmpty, isTrue);
      expect(s.totalInRadius, 0);
      expect(s.withProblem, 0);
      expect(s.organisms, isEmpty);
      expect(s.recent, isEmpty);
      expect(s.nearestProblemKm, isNull);
      expect(s.weekly, hasLength(4));
      expect(s.weekly.every((w) => w.count == 0), isTrue);
    });

    test(
      'ocorrências só fora do raio ou do período também geram resumo vazio',
      () {
        final s = build([
          occ('longe', km: 50, daysAgo: 1, diagnosis: diag('Lagarta')),
          occ('antiga', km: 2, daysAgo: 40, diagnosis: diag('Lagarta')),
        ]);

        expect(s.isEmpty, isTrue);
      },
    );
  });

  group('propriedade com ocorrências', () {
    late RegionalSummary s;

    setUp(() {
      s = build([
        occ('a', km: 3, daysAgo: 1, diagnosis: diag('Ferrugem asiática')),
        occ('b', km: 8, daysAgo: 10, diagnosis: diag('ferrugem  Asiática ')),
        occ(
          'c',
          km: 1.5,
          daysAgo: 20,
          diagnosis: diag('Lagarta-do-cartucho', risk: 'médio'),
        ),
        occ('d', km: 5, daysAgo: 2, diagnosis: diag('Ferrugem asiática')),
        occ('pendente', km: 4, daysAgo: 0),
        occ(
          'saudavel',
          km: 6,
          daysAgo: 3,
          diagnosis: diag('Nenhuma praga', risk: 'baixo'),
        ),
        occ(
          'inconclusiva',
          km: 6,
          daysAgo: 3,
          diagnosis: diag('Análise inconclusiva', risk: 'desconhecido'),
        ),
        occ(
          'minha',
          km: 2,
          daysAgo: 5,
          diagnosis: diag('Lagarta-do-cartucho'),
          reportedBy: 'eu',
        ),
        occ('fora', km: 30, daysAgo: 1, diagnosis: diag('Percevejo')),
        occ('antiga', km: 1, daysAgo: 29, diagnosis: diag('Percevejo')),
      ]);
    });

    test('contagens por categoria', () {
      expect(s.totalInRadius, 8);
      expect(s.withProblem, 5);
      expect(s.pendingAnalysis, 1);
      expect(s.withoutProblem, 2);
      expect(s.ownCount, 1);
      expect(s.isEmpty, isFalse);
    });

    test('problema mais próximo', () {
      expect(s.nearestProblemKm, 1.5);
    });

    test(
      'organismos agrupados por nome normalizado e ordenados por contagem',
      () {
        expect(s.organisms.map((o) => o.name), [
          'Ferrugem asiática',
          'Lagarta-do-cartucho',
        ]);
        expect(s.organisms[0].count, 3);
        expect(s.organisms[0].nearestKm, 3);
        expect(s.organisms[0].lastSeen, now.subtract(const Duration(days: 1)));
        expect(s.organisms[1].count, 2);
        expect(s.organisms[1].nearestKm, 1.5);
      },
    );

    test('Percevejo não aparece (fora do raio / fora do período)', () {
      expect(s.organisms.any((o) => o.name == 'Percevejo'), isFalse);
    });

    test('recentes: apenas com problema, mais nova primeiro, limitado', () {
      expect(s.recent.map((e) => e.occurrence.id), ['a', 'd', 'minha']);
      expect(s.recent.first.distanceKm, 3);
    });

    test('distribuição semanal (mais antiga primeiro)', () {
      // a(1d), d(2d), minha(5d) → semana atual; b(10d) → 2ª; c(20d) → 3ª.
      expect(s.weekly.map((w) => w.count), [0, 1, 1, 3]);
      expect(s.weekly.first.start, now.subtract(const Duration(days: 28)));
      expect(s.weekly.last.end, now);
    });

    test('soma da distribuição semanal = ocorrências com problema', () {
      expect(s.weekly.fold<int>(0, (t, w) => t + w.count), s.withProblem);
    });
  });

  group('casos de borda', () {
    test('ocorrência sem localização (0,0) é descartada e contabilizada', () {
      final s = build([
        occ(
          'semgps',
          km: 0,
          daysAgo: 1,
          diagnosis: diag('Lagarta'),
          lat: 0,
          lng: 0,
        ),
        occ('ok', km: 2, daysAgo: 1, diagnosis: diag('Lagarta')),
      ]);

      expect(s.discardedInvalidLocation, 1);
      expect(s.totalInRadius, 1);
    });

    test('limite do raio é inclusivo', () {
      final s = build([
        occ('borda', km: 20, daysAgo: 1, diagnosis: diag('Lagarta')),
      ]);
      expect(s.totalInRadius, 1);
    });

    test('raio menor reduz o resultado', () {
      final list = [
        occ('perto', km: 3, daysAgo: 1, diagnosis: diag('Lagarta')),
        occ('medio', km: 15, daysAgo: 1, diagnosis: diag('Lagarta')),
      ];
      expect(build(list, radiusKm: 20).totalInRadius, 2);
      expect(build(list, radiusKm: 5).totalInRadius, 1);
    });

    test('ocorrência registrada exatamente agora entra na última semana', () {
      final s = build([
        occ('agora', km: 1, daysAgo: 0, diagnosis: diag('Lagarta')),
      ]);
      expect(s.weekly.last.count, 1);
    });

    test('limites de recentes e organismos são respeitados', () {
      final list = [
        for (var i = 0; i < 8; i++)
          occ('o$i', km: 1, daysAgo: i, diagnosis: diag('Organismo $i')),
      ];
      final s = RegionalSummary.build(
        occurrences: list,
        latitude: propLat,
        longitude: propLng,
        radiusKm: 20,
        windowDays: 28,
        now: now,
        userId: 'eu',
        recentLimit: 2,
        organismLimit: 3,
        distanceKm: fakeKm,
      );
      expect(s.recent, hasLength(2));
      expect(s.organisms, hasLength(3));
    });

    test('distância padrão (Geolocator) é usada quando não injetada', () {
      final s = RegionalSummary.build(
        occurrences: [
          OccurrenceModel(
            id: 'x',
            imageBase64: '',
            latitude: -22.74,
            longitude: -47.65,
            timestamp: now.subtract(const Duration(days: 1)),
            reportedBy: 'outro',
            diagnosis: diag('Lagarta'),
          ),
        ],
        latitude: propLat,
        longitude: propLng,
        radiusKm: 20,
        windowDays: 28,
        now: now,
        userId: 'eu',
      );
      // 0,01° de latitude ≈ 1,11 km.
      expect(s.nearestProblemKm, closeTo(1.11, 0.02));
    });
  });
}
