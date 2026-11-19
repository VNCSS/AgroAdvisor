// ⚠️ DADOS DE TESTE — NÃO SÃO CONHECIMENTO CIENTÍFICO.
//
// Regras, organismos e valores abaixo são fictícios e existem apenas para
// exercitar o motor de favorabilidade. Fontes usam o domínio reservado
// example.org.

import 'package:agro_advisor/features/favorability/domain/criteria.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_engine.dart';
import 'package:agro_advisor/features/favorability/domain/organism_type.dart';
import 'package:agro_advisor/features/favorability/domain/regional_occurrence.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_pest_rule.dart';
import 'package:agro_advisor/features/favorability/domain/scientific_source.dart';
import 'package:agro_advisor/features/weather/domain/weather_forecast.dart';

/// Instante de referência: meia-noite, para que a janela de 72 h e os dias
/// completos de graus-dia fiquem previsíveis.
final DateTime testNow = DateTime(2026, 10, 10);

const double propertyLat = -22.0;
const double propertyLng = -47.0;

/// km por grau de latitude na esfera usada por haversineKm.
const double kmPerDegree = 111.19508;

const testSource = ScientificSource(
  id: 'test-src',
  title: 'Fonte fictícia (teste)',
  url: 'https://example.org/test-source',
);

ScientificPestRule testRule({
  String id = 'test-org',
  String name = 'Organismo de Teste',
  String? scientificName,
  List<String> aliases = const [],
  List<String> crops = const [],
  OrganismType type = OrganismType.fungus,
  TemperatureCriteria? temperature,
  HumidityCriteria? humidity,
  PrecipitationCriteria? precipitation,
  LeafWetnessCriteria? leafWetness,
  DewPointCriteria? dewPoint,
  DegreeDayCriteria? degreeDays,
  WindCriteria? wind,
  PhenologyCriteria? phenology,
  bool available = true,
}) =>
    ScientificPestRule(
      id: id,
      organismName: name,
      scientificName: scientificName,
      aliases: aliases,
      organismType: type,
      affectedCrops: crops,
      temperature: temperature,
      humidity: humidity,
      precipitation: precipitation,
      leafWetness: leafWetness,
      dewPoint: dewPoint,
      degreeDays: degreeDays,
      wind: wind,
      phenology: phenology,
      sources: const [testSource],
      available: available,
    );

PropertyContext testProperty({String? crop = 'Soja', String? cropStage}) =>
    PropertyContext(
      id: 'prop-1',
      latitude: propertyLat,
      longitude: propertyLng,
      crop: crop,
      cropStage: cropStage,
    );

int _seq = 0;

/// Ocorrência a [km] ao norte da propriedade, registrada há [daysAgo] dias.
RegionalOccurrence occ(
  String organism, {
  double km = 5,
  double daysAgo = 1,
  String? id,
  String reportedBy = 'user-a',
  String? crop,
  double? confidence,
  double lngOffsetDeg = 0,
}) =>
    RegionalOccurrence(
      id: id ?? 'occ-${_seq++}',
      organismName: organism,
      latitude: propertyLat + km / kmPerDegree,
      longitude: propertyLng + lngOffsetDeg,
      timestamp: testNow.subtract(Duration(minutes: (daysAgo * 24 * 60).round())),
      reportedBy: reportedBy,
      crop: crop,
      diagnosisConfidence: confidence,
    );

/// Previsão horária sintética a partir de [testNow]. Cada função recebe o
/// índice da hora (0 = testNow) e devolve o valor, ou null (ausente).
/// Variável não informada = ausente na resposta.
WeatherForecast forecast({
  int hours = 168,
  double? Function(int h)? temperature,
  double? Function(int h)? humidity,
  double? Function(int h)? precipitation,
  double? Function(int h)? wind,
}) {
  final times = [
    for (var h = 0; h < hours; h++) testNow.add(Duration(hours: h)),
  ];
  List<double?> series(double? Function(int)? f) =>
      [for (var h = 0; h < hours; h++) f!(h)];
  return WeatherForecast(
    latitude: propertyLat,
    longitude: propertyLng,
    timezone: 'America/Sao_Paulo',
    fetchedAt: testNow,
    hourly: HourlyWeather(times: times, values: {
      if (temperature != null) HourlyVariable.temperature: series(temperature),
      if (humidity != null) HourlyVariable.relativeHumidity: series(humidity),
      if (precipitation != null)
        HourlyVariable.precipitation: series(precipitation),
      if (wind != null) HourlyVariable.windSpeed: series(wind),
    }),
    daily: const [],
  );
}

/// Previsão "amena" completa (todas as variáveis presentes).
WeatherForecast mildForecast({
  double temperature = 20,
  double humidity = 70,
  double precipitation = 0,
  double wind = 10,
}) =>
    forecast(
      temperature: (_) => temperature,
      humidity: (_) => humidity,
      precipitation: (_) => precipitation,
      wind: (_) => wind,
    );
