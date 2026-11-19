import 'dart:convert';

import '../../favorability/domain/experimental_profile.dart';
import '../../favorability/domain/favorability_config.dart';
import '../../favorability/domain/favorability_engine.dart';
import '../../occurrence/domain/occurrence_model.dart';
import '../../property/domain/property_model.dart';
import '../../settings/domain/user_settings_model.dart';
import '../../weather/data/weather_repository.dart';
import '../../../core/constants/app_constants.dart';

/// Apenas alertas operacionais entram no armazenamento persistente.
class IntelligentAlert {
  final String scope, type, title, body, region, source;
  final DateTime generatedAt;
  final String? occurrenceId, propertyId, level;
  final double? latitude, longitude;
  final int? index;
  final bool simulated;
  const IntelligentAlert({
    required this.scope,
    required this.type,
    required this.title,
    required this.body,
    required this.region,
    required this.source,
    required this.generatedAt,
    this.occurrenceId,
    this.propertyId,
    this.level,
    this.index,
    this.latitude,
    this.longitude,
    this.simulated = false,
  });

  static String key(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  String get stateId => 'state_${key(scope)}';
  String get historyId =>
      'alert_${key('$scope|${level ?? '-'}|${generatedAt.microsecondsSinceEpoch}')}';

  Map<String, dynamic> toMap() => {
    'type': type,
    'title': title,
    'body': body,
    'region': region,
    'source': source,
    'receivedAt': generatedAt.toIso8601String(),
    'read': false,
    'occurrenceId': occurrenceId,
    'propertyId': propertyId,
    'level': level,
    'favorabilityIndex': index,
    'latitude': latitude,
    'longitude': longitude,
    'simulated': simulated,
  };
  String payload(String userId) =>
      jsonEncode({...toMap(), 'id': historyId, 'recipientId': userId});
}

class AlertReservation {
  final DateTime generatedAt;
  final String? level;
  const AlertReservation(this.generatedAt, this.level);
}

bool shouldReserve(IntelligentAlert candidate, AlertReservation? previous) {
  if (candidate.simulated) return false;
  if (previous == null) return true;
  if (candidate.type == 'nearby') return false;
  return previous.level != candidate.level ||
      !candidate.generatedAt.isBefore(
        previous.generatedAt.add(const Duration(hours: 24)),
      );
}

bool withinMonitoringRadius(double distanceKm, double radiusKm) =>
    distanceKm.isFinite &&
    distanceKm >= 0 &&
    radiusKm.isFinite &&
    radiusKm > 0 &&
    distanceKm <= radiusKm + 1e-9;

/// Política pura, compartilhada entre o serviço e a demonstração.
IntelligentAlert? nearbyCandidate({
  required String userId,
  required UserSettingsModel settings,
  required List<PropertyModel> properties,
  required OccurrenceModel occurrence,
  required DateTime now,
}) {
  final d = occurrence.diagnosis;
  if (!settings.notificationsEnabled ||
      occurrence.reportedBy == userId ||
      occurrence.id.isEmpty ||
      occurrence.reportedBy.isEmpty ||
      d == null ||
      d.isHealthy ||
      d.pestName.trim().isEmpty ||
      occurrence.timestamp.isAfter(now) ||
      occurrence.timestamp.isBefore(
        now.subtract(const Duration(days: AppConstants.nearbyAlertMaxAgeDays)),
      ) ||
      !WeatherRepository.isValidCoordinate(
        occurrence.latitude,
        occurrence.longitude,
      )) {
    return null;
  }
  PropertyModel? nearest;
  var distance = double.infinity;
  for (final p in properties) {
    if (p.ownerId != userId ||
        !WeatherRepository.isValidCoordinate(p.latitude, p.longitude)) {
      continue;
    }
    final km = haversineKm(
      p.latitude,
      p.longitude,
      occurrence.latitude,
      occurrence.longitude,
    );
    if (km < distance) {
      distance = km;
      nearest = p;
    }
  }
  if (nearest == null ||
      !withinMonitoringRadius(distance, settings.alertRadiusKm)) {
    return null;
  }
  return IntelligentAlert(
    scope: 'nearby|${occurrence.id}',
    type: 'nearby',
    title: 'Ocorrência próxima — ${d.pestName}',
    body:
        'Uma ocorrência foi registrada a aproximadamente ${distance.toStringAsFixed(1)} km '
        'de ${nearest.name}. Registro de outro usuário; consulte o radar e faça inspeção visual.',
    region: nearest.name,
    source: 'Registro regional no Firestore',
    generatedAt: now,
    propertyId: nearest.id,
    occurrenceId: occurrence.id,
    latitude: occurrence.latitude,
    longitude: occurrence.longitude,
  );
}

/// Usa exclusivamente a classificação já produzida pelo motor.
IntelligentAlert? environmentalCandidate(
  ExperimentalAssessment result,
  PropertyModel property,
) {
  if (result.index == null ||
      result.level == null ||
      result.level!.index < AttentionLevel.high.index) {
    return null;
  }
  return IntelligentAlert(
    scope:
        'experimental-v1|${property.id}|${property.latitude}|${property.longitude}',
    type: 'preventive',
    title: result.level == AttentionLevel.veryHigh
        ? 'Alerta preventivo — Favorabilidade muito elevada'
        : 'Alerta preventivo — Favorabilidade elevada',
    body:
        'As condições ambientais monitoradas atendem aos critérios experimentais '
        'de favorabilidade. Consulte os fatores avaliados no AgroAdvisor.\n'
        '${ExperimentalProfile.name}\nÍndice: ${result.index}/100 — ${result.level!.label}\n'
        '${result.environmental.factors.map((f) => f.detail).join('\n')}\n'
        'Contribuição ambiental: ${((result.environmental.score ?? 0) * 60).toStringAsFixed(1)} pontos; '
        'regional: ${((result.regional?.score ?? 0) * 40).toStringAsFixed(1)} pontos.\n'
        '${result.warnings.join('\n')}\n${ExperimentalProfile.disclaimer}',
    region: property.name,
    source: result.simulated
        ? 'Entradas simuladas locais'
        : 'Open-Meteo.com + registros regionais (50 km / 28 dias); clima obtido em ${result.fetchedAt}',
    generatedAt: result.generatedAt,
    propertyId: property.id,
    level: result.level!.name,
    index: result.index,
    latitude: property.latitude,
    longitude: property.longitude,
    simulated: result.simulated,
  );
}
