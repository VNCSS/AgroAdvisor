import '../../weather/domain/weather_forecast.dart';
import 'favorability_config.dart';
import 'favorability_result.dart';

/// Parâmetros didáticos de projeto, sem validação agronômica e sem espécie.
/// Arquivo separado do catálogo científico deliberadamente vazio.
class ExperimentalProfile {
  static const name = 'Cenário experimental de favorabilidade';
  static const disclaimer =
      'Parâmetros heurísticos experimentais, sem validação agronômica. '
      'O índice não é probabilidade de infestação. '
      'Recomenda-se monitoramento da cultura e inspeção visual.';
  static const hours = 72;

  /// Exige 72 horas consecutivas completas; dado inválido não vira zero.
  static List<FactorEvaluation> evaluate(
    WeatherForecast? forecast,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, now.day, now.hour);
    final times = forecast?.hourly.times ?? const <DateTime>[];
    final positions = List.generate(
      hours,
      (h) => times.indexOf(start.add(Duration(hours: h))),
    );
    FactorEvaluation factor(
      FactorKind kind,
      HourlyVariable variable,
      bool Function(double) valid,
      double Function(List<double>) score,
      String Function(List<double>) detail,
    ) {
      final column = forecast?.hourly.valuesOf(variable) ?? const <double?>[];
      final values = <double>[];
      for (final i in positions) {
        final v = i < 0 || i >= column.length ? null : column[i];
        if (v != null && v.isFinite && valid(v)) values.add(v);
      }
      if (values.length != hours) {
        return FactorEvaluation(
          kind: kind,
          status: FactorStatus.notEvaluable,
          detail:
              'Dados ausentes ou inválidos: ${values.length}/72 horas válidas',
        );
      }
      final s = score(values);
      return FactorEvaluation(
        kind: kind,
        score: s,
        status: s >= 0.6
            ? FactorStatus.favorable
            : s >= 0.2
            ? FactorStatus.partiallyFavorable
            : FactorStatus.unfavorable,
        detail: detail(values),
      );
    }

    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    return [
      factor(
        FactorKind.temperature,
        HourlyVariable.temperature,
        (v) => v >= -90 && v <= 60,
        (v) => v.where((t) => t >= 22 && t <= 30).length / hours,
        (v) =>
            'Temperatura média: ${mean(v).toStringAsFixed(1)} °C; '
            '${v.where((t) => t >= 22 && t <= 30).length}/72 h entre 22 e 30 °C',
      ),
      factor(
        FactorKind.humidity,
        HourlyVariable.relativeHumidity,
        (v) => v >= 0 && v <= 100,
        (v) => v.where((rh) => rh >= 80).length / hours,
        (v) =>
            'Umidade média: ${mean(v).toStringAsFixed(1)}%; '
            '${v.where((rh) => rh >= 80).length}/72 h com UR ≥ 80%',
      ),
      factor(
        FactorKind.precipitation,
        HourlyVariable.precipitation,
        (v) => v >= 0,
        (v) {
          final sum = v.reduce((a, b) => a + b);
          return sum >= 5 && sum <= 30 ? 1 : 0;
        },
        (v) =>
            'Precipitação acumulada nas próximas 72 h: '
            '${v.reduce((a, b) => a + b).toStringAsFixed(1)} mm; faixa experimental: 5–30 mm',
      ),
    ];
  }
}

/// Resultado distinto dos alertas persistíveis por organismo.
class ExperimentalAssessment {
  final EnvironmentalAssessment environmental;
  final RegionalEvidence? regional;
  final int? index;
  final AttentionLevel? level;
  final bool simulated;
  final DateTime generatedAt;
  final DateTime? fetchedAt;
  final List<String> warnings;
  const ExperimentalAssessment({
    required this.environmental,
    required this.regional,
    required this.index,
    required this.level,
    required this.simulated,
    required this.generatedAt,
    this.fetchedAt,
    this.warnings = const [],
  });
}

class DemonstrationInput {
  final double temperature, humidity, precipitation;
  final bool regionalOccurrences;
  const DemonstrationInput(
    this.temperature,
    this.humidity,
    this.precipitation,
    this.regionalOccurrences,
  );
  static const presets = {
    AttentionLevel.low: DemonstrationInput(15, 50, 0, false),
    AttentionLevel.moderate: DemonstrationInput(26, 85, 0, false),
    AttentionLevel.high: DemonstrationInput(26, 85, 12, false),
    AttentionLevel.veryHigh: DemonstrationInput(26, 85, 12, true),
  };
  WeatherForecast forecast(DateTime now) => WeatherForecast(
    latitude: -22,
    longitude: -47,
    timezone: 'simulado',
    fetchedAt: now,
    daily: const [],
    hourly: HourlyWeather(
      times: List.generate(
        72,
        (h) => DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
        ).add(Duration(hours: h)),
      ),
      values: {
        HourlyVariable.temperature: List.filled(72, temperature),
        HourlyVariable.relativeHumidity: List.filled(72, humidity),
        // Chuva sintética na primeira hora; a entrada é o TOTAL em 72 h.
        HourlyVariable.precipitation: List.generate(
          72,
          (h) => h == 0 ? precipitation : 0.0,
        ),
      },
    ),
  );
}
