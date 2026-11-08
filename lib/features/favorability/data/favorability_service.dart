import '../../occurrence/domain/occurrence_model.dart';
import '../../property/domain/property_model.dart';
import '../../weather/domain/weather_result.dart';
import '../domain/favorability_engine.dart';
import '../domain/favorability_result.dart';
import '../domain/regional_occurrence.dart';
import '../domain/scientific_rule_catalog.dart';
import 'scientific_rule_repository.dart';

/// Carrega os dados de uma propriedade e executa o [FavorabilityEngine].
///
/// As dependências são funções para não acoplar o serviço ao Firestore nem
/// à rede (e permitir testes). Exemplo de uso:
/// ```dart
/// FavorabilityService(
///   engine: FavorabilityEngine(),
///   rules: ScientificRuleRepository(),
///   loadOccurrencesSince: occurrenceRepository.getSince,
///   loadForecast: weatherRepository.getForecastForProperty,
/// )
/// ```
class FavorabilityService {
  final FavorabilityEngine engine;
  final ScientificRuleRepository rules;
  final Future<List<OccurrenceModel>> Function(DateTime since)
      loadOccurrencesSince;
  final Future<WeatherResult> Function(PropertyModel property) loadForecast;
  final DateTime Function() _now;

  FavorabilityService({
    required this.engine,
    required this.rules,
    required this.loadOccurrencesSince,
    required this.loadForecast,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Erros de ocorrências propagam (a interface decide como exibir); falha
  /// de previsão vira "sem previsão" no relatório, sem interromper a análise.
  ///
  /// [radiusKm] substitui o raio padrão do motor (ex.: raio de alerta do
  /// usuário). [occurrences] permite reaproveitar ocorrências já carregadas
  /// ao analisar várias propriedades.
  Future<FavorabilityReport> assess(
    PropertyModel property, {
    String? cropStage,
    double? radiusKm,
    List<OccurrenceModel>? occurrences,
  }) async {
    final now = _now();
    final runEngine = radiusKm == null
        ? engine
        : engine.withConfig(engine.config.copyWith(
            occurrences:
                engine.config.occurrences.copyWith(radiusKm: radiusKm),
          ));

    // Future.wait repassa o erro original (o record.wait o embrulharia).
    final results = await Future.wait<Object>([
      rules.loadCatalog(),
      if (occurrences == null) loadOccurrencesSince(occurrencesSince(now)),
      loadForecast(property),
    ]);
    final catalog = results.first as ScientificRuleCatalog;
    final loaded = occurrences ?? results[1] as List<OccurrenceModel>;
    final weather = results.last as WeatherResult;

    final forecast = switch (weather) {
      WeatherSuccess(:final forecast) => forecast,
      WeatherFailure() => null,
    };

    return runEngine.assess(
      property: PropertyContext.fromProperty(property, cropStage: cropStage),
      occurrences: loaded
          .map(RegionalOccurrence.fromOccurrence)
          .whereType<RegionalOccurrence>()
          .toList(),
      catalog: catalog,
      forecast: forecast,
      forecastIsStale: weather is WeatherSuccess && weather.isStale,
      now: now,
    );
  }

  /// Início da janela de ocorrências considerada pelo motor.
  DateTime occurrencesSince(DateTime now) =>
      now.subtract(Duration(days: engine.config.occurrences.windowDays));

  DateTime now() => _now();
}
