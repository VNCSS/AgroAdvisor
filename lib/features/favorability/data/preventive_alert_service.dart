import 'dart:developer' as dev;

import '../../../core/constants/app_constants.dart';
import '../../../services/database_service.dart';
import '../../notifications/data/preventive_alert_store.dart';
import '../../occurrence/data/occurrence_repository.dart';
import '../../occurrence/domain/occurrence_model.dart';
import '../../property/domain/property_model.dart';
import '../../settings/domain/user_settings_model.dart';
import '../../weather/data/weather_repository.dart';
import '../domain/favorability_engine.dart';
import '../domain/preventive_alert.dart';
import 'favorability_service.dart';
import 'scientific_rule_repository.dart';

/// Resultado de uma verificação de alertas preventivos.
class PreventiveAlertRunResult {
  /// false quando a verificação não rodou (ver [notRunReason]).
  final bool ran;
  final String? notRunReason;

  final List<PreventiveAlert> created;
  final List<PreventiveAlert> updated;
  final List<PreventiveAlert> unchanged;

  /// Organismos analisados que não geraram alerta, com o motivo (inclui a
  /// mensagem de ausência de base científica).
  final List<SkippedOrganism> skipped;

  /// Falhas por propriedade (a verificação das demais continua).
  final List<String> errors;

  const PreventiveAlertRunResult({
    required this.ran,
    this.notRunReason,
    this.created = const [],
    this.updated = const [],
    this.unchanged = const [],
    this.skipped = const [],
    this.errors = const [],
  });

  const PreventiveAlertRunResult.notRun(String reason)
      : this(ran: false, notRunReason: reason);
}

/// Gera alertas preventivos de favorabilidade para as propriedades de um
/// usuário, gravando-os no sistema de notificações existente.
///
/// - Respeita `notificationsEnabled` e usa `alertRadiusKm` das
///   configurações do usuário (as mesmas do alerta de proximidade).
/// - Nunca lança exceção: falhas viram [PreventiveAlertRunResult.errors].
/// - Chamadas repetidas em sequência (ex.: rebuild de tela) são limitadas
///   por [minInterval]; chamadas simultâneas compartilham a mesma execução.
///   A deduplicação real é persistente (id determinístico + impressão das
///   condições), então reiniciar o app também não duplica alertas.
class PreventiveAlertService {
  final FavorabilityService favorability;
  final PreventiveAlertStore store;
  final Future<UserSettingsModel?> Function(String userId) loadSettings;
  final Future<List<PropertyModel>> Function(String userId) loadProperties;
  final PreventiveAlertPolicy policy;
  final Duration minInterval;

  final Map<String, DateTime> _lastRun = {};
  final Map<String, Future<PreventiveAlertRunResult>> _inFlight = {};

  PreventiveAlertService({
    required this.favorability,
    required this.store,
    required this.loadSettings,
    required this.loadProperties,
    this.policy = const PreventiveAlertPolicy(),
    this.minInterval = const Duration(minutes: 30),
  });

  /// Montagem com as dependências reais do app (Firestore + Open-Meteo).
  factory PreventiveAlertService.create({required WeatherRepository weather}) {
    final db = DatabaseService();
    final occurrences = OccurrenceRepository();
    return PreventiveAlertService(
      favorability: FavorabilityService(
        engine: FavorabilityEngine(),
        rules: ScientificRuleRepository(),
        loadOccurrencesSince: occurrences.getSince,
        loadForecast: weather.getForecastForProperty,
      ),
      store: FirestorePreventiveAlertStore(),
      loadSettings: db.getUserSettings,
      loadProperties: db.getUserProperties,
    );
  }

  Future<PreventiveAlertRunResult> run(String userId, {bool force = false}) {
    final pending = _inFlight[userId];
    if (pending != null) return pending;

    final last = _lastRun[userId];
    if (!force &&
        last != null &&
        favorability.now().difference(last) < minInterval) {
      return Future.value(const PreventiveAlertRunResult.notRun(
          'verificação recente; aguardando intervalo mínimo'));
    }

    // Bloco com chaves de propósito: `=> _inFlight.remove(...)` devolveria
    // o próprio future, e o whenComplete esperaria por si mesmo (deadlock).
    final future = _run(userId).whenComplete(() {
      _inFlight.remove(userId);
    });
    _inFlight[userId] = future;
    return future;
  }

  /// Esquece o estado em memória (ex.: logout).
  void reset() {
    _lastRun.clear();
  }

  Future<PreventiveAlertRunResult> _run(String userId) async {
    try {
      final settings = await loadSettings(userId);
      if (settings?.notificationsEnabled == false) {
        return const PreventiveAlertRunResult.notRun('notificações desativadas');
      }
      final radiusKm = settings?.alertRadiusKm ?? AppConstants.alertRadiusDefault;

      final properties = await loadProperties(userId);
      if (properties.isEmpty) {
        _lastRun[userId] = favorability.now();
        return const PreventiveAlertRunResult.notRun('nenhuma propriedade');
      }

      final now = favorability.now();
      final List<OccurrenceModel> occurrences = await favorability
          .loadOccurrencesSince(favorability.occurrencesSince(now));

      final builder = PreventiveAlertBuilder(policy);
      final config = favorability.engine.config;
      final created = <PreventiveAlert>[];
      final updated = <PreventiveAlert>[];
      final unchanged = <PreventiveAlert>[];
      final skipped = <SkippedOrganism>[];
      final errors = <String>[];

      for (final property in properties) {
        try {
          final report = await favorability.assess(property,
              radiusKm: radiusKm, occurrences: occurrences);
          final evaluation = builder.build(
            report: report,
            propertyName: property.name,
            radiusKm: radiusKm,
            windowDays: config.occurrences.windowDays,
            horizonHours: config.weather.horizonHours,
          );
          skipped.addAll(evaluation.skipped);

          for (final alert in evaluation.alerts) {
            final existing = await store.find(userId, alert.alertId);
            switch (decideAlertAction(
                existing: existing,
                candidate: alert,
                now: report.generatedAt,
                policy: policy)) {
              case AlertAction.create:
                await store.save(userId, alert);
                created.add(alert);
              case AlertAction.update:
                final update = alert.asUpdate();
                await store.save(userId, update);
                updated.add(update);
              case AlertAction.skip:
                unchanged.add(alert);
            }
          }
        } catch (e, st) {
          dev.log('[PreventiveAlert] falha na propriedade ${property.id}',
              error: e, stackTrace: st);
          errors.add('${property.name}: $e');
        }
      }

      _lastRun[userId] = now;
      dev.log('[PreventiveAlert] criados=${created.length} '
          'atualizados=${updated.length} inalterados=${unchanged.length} '
          'sem alerta=${skipped.length} erros=${errors.length}');
      return PreventiveAlertRunResult(
        ran: true,
        created: created,
        updated: updated,
        unchanged: unchanged,
        skipped: skipped,
        errors: errors,
      );
    } catch (e, st) {
      dev.log('[PreventiveAlert] falha geral', error: e, stackTrace: st);
      return PreventiveAlertRunResult(ran: false, notRunReason: 'erro: $e');
    }
  }
}
