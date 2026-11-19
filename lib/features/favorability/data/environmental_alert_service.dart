import '../../notifications/data/intelligent_alert_store.dart';
import '../../notifications/domain/intelligent_alert.dart';
import '../../property/domain/property_model.dart';
import '../../settings/domain/user_settings_model.dart';
import '../domain/experimental_profile.dart';

/// Execução oportunista gratuita: login, retomada e abertura dos alertas.
class EnvironmentalAlertService {
  final Future<UserSettingsModel?> Function(String) loadSettings;
  final Future<List<PropertyModel>> Function(String) loadProperties;
  final Future<ExperimentalAssessment> Function(PropertyModel) assess;
  final AlertDispatcher dispatcher;
  final DateTime Function() now;
  final Duration interval;
  final Map<String, DateTime> _last = {};
  final Map<String, Future<List<String>>> _pending = {};
  int _generation = 0;
  EnvironmentalAlertService({
    required this.loadSettings,
    required this.loadProperties,
    required this.assess,
    required this.dispatcher,
    DateTime Function()? now,
    this.interval = const Duration(hours: 6),
  }) : now = now ?? DateTime.now;

  void reset() {
    _generation++;
    _last.clear();
    _pending.clear();
  }

  Future<List<String>> run(String userId, {bool force = false}) {
    if (_pending[userId] case final pending?) return pending;
    if (!force &&
        _last[userId] != null &&
        now().difference(_last[userId]!) < interval) {
      return Future.value([]);
    }
    final generation = _generation;
    final future = _run(userId, generation).whenComplete(() {
      if (generation == _generation) _pending.remove(userId);
    });
    _pending[userId] = future;
    return future;
  }

  Future<List<String>> _run(String userId, int generation) async {
    final errors = <String>[];
    bool active() =>
        generation == _generation && dispatcher.activeUser() == userId;
    try {
      if (!active() ||
          (await loadSettings(userId))?.notificationsEnabled == false) {
        return errors;
      }
      final properties = await loadProperties(userId);
      for (final property in properties) {
        if (!active()) break;
        if (property.ownerId != userId) continue;
        try {
          final result = await assess(property);
          if (result.simulated || !active()) continue;
          if ((await loadSettings(userId))?.notificationsEnabled == false ||
              !active()) {
            break;
          }
          await dispatcher.store.evaluation(userId, property.id, {
            'propertyId': property.id,
            'region': property.name,
            'profile': ExperimentalProfile.name,
            'simulated': false,
            'evaluatedAt': result.generatedAt.toIso8601String(),
            'index': result.index,
            'level': result.level?.name,
            'warnings': result.warnings,
          });
          final alert = environmentalCandidate(result, property);
          if (alert != null) {
            await dispatcher.emit(userId, alert, stillActive: active);
          }
          if (result.index == null) {
            errors.add('${property.name}: dados insuficientes');
          }
        } catch (_) {
          errors.add(
            '${property.name}: falha na avaliação ou no registro do alerta',
          );
        }
      }
      if (active() && errors.isEmpty) _last[userId] = now();
    } catch (_) {
      errors.add('Não foi possível carregar as preferências ou propriedades.');
    }
    return errors;
  }
}
