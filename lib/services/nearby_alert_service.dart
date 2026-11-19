import 'dart:async';
import 'dart:developer' as dev;

import '../core/constants/app_constants.dart';
import '../features/notifications/data/intelligent_alert_store.dart';
import '../features/notifications/domain/intelligent_alert.dart';
import '../features/occurrence/domain/occurrence_model.dart';
import '../features/property/domain/property_model.dart';
import '../features/settings/domain/user_settings_model.dart';

/// Cada cliente avalia somente seu usuário; não lê tokens de terceiros.
class NearbyAlertService {
  final AlertDispatcher dispatcher;
  final Future<UserSettingsModel?> Function(String) loadSettings;
  final Future<List<PropertyModel>> Function(String) loadProperties;
  final Stream<List<OccurrenceModel>> Function(DateTime) watchOccurrences;
  final Future<List<OccurrenceModel>> Function(DateTime) loadOccurrences;
  final DateTime Function() now;
  StreamSubscription<List<OccurrenceModel>>? _sub;
  String? _user;
  int _generation = 0;
  Future<void>? _initializing;

  NearbyAlertService({
    required this.dispatcher,
    required this.loadSettings,
    required this.loadProperties,
    required this.watchOccurrences,
    required this.loadOccurrences,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  Future<void> initialize(String userId) {
    if (_user == userId && (_sub != null || _initializing != null)) {
      return _initializing ?? Future.value();
    }
    final previous = _sub;
    _sub = null;
    _user = userId;
    final generation = ++_generation;
    final future = _start(userId, generation, previous);
    _initializing = future;
    return future;
  }

  Future<void> _start(
    String uid,
    int generation,
    StreamSubscription<List<OccurrenceModel>>? previous,
  ) async {
    await previous?.cancel();
    if (_generation != generation || _user != uid) return;
    final since = now().subtract(
      const Duration(days: AppConstants.nearbyAlertMaxAgeDays),
    );
    _sub = watchOccurrences(since).listen((items) {
      unawaited(_process(uid, items, generation));
    }, onError: (Object _) => dev.log('[NearbyAlert] consulta indisponível'));
    if (_generation == generation) _initializing = null;
  }

  Future<List<String>> check(String uid) async {
    try {
      await initialize(uid);
      final generation = _generation;
      final items = await loadOccurrences(
        now().subtract(
          const Duration(days: AppConstants.nearbyAlertMaxAgeDays),
        ),
      );
      return await _process(uid, items, generation);
    } catch (_) {
      return ['Não foi possível consultar ocorrências próximas.'];
    }
  }

  Future<List<String>> _process(
    String uid,
    List<OccurrenceModel> items,
    int generation,
  ) async {
    bool active() =>
        generation == _generation &&
        _user == uid &&
        dispatcher.activeUser() == uid;
    try {
      if (!active()) return [];
      final settings =
          await loadSettings(uid) ?? UserSettingsModel(userId: uid);
      if (!settings.notificationsEnabled) return [];
      final properties = await loadProperties(uid);
      for (final item in items) {
        if (!active()) break;
        final currentSettings = await loadSettings(uid) ?? settings;
        if (!currentSettings.notificationsEnabled || !active()) break;
        final alert = nearbyCandidate(
          userId: uid,
          settings: currentSettings,
          properties: properties,
          occurrence: item,
          now: now(),
        );
        if (alert != null) {
          await dispatcher.emit(uid, alert, stillActive: active);
        }
      }
      return [];
    } catch (_) {
      return ['Não foi possível registrar os alertas próximos.'];
    }
  }

  Future<void> stop() async {
    _generation++;
    _user = null;
    final sub = _sub;
    _sub = null;
    _initializing = null;
    await sub?.cancel();
  }

  static bool isRecentForAlert(
    DateTime timestamp,
    DateTime now, {
    int maxAgeDays = AppConstants.nearbyAlertMaxAgeDays,
  }) =>
      !timestamp.isAfter(now) &&
      !timestamp.isBefore(now.subtract(Duration(days: maxAgeDays)));
}
