import 'dart:async';

import 'package:agro_advisor/features/favorability/data/environmental_alert_service.dart';
import 'package:agro_advisor/features/favorability/domain/experimental_profile.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_config.dart';
import 'package:agro_advisor/features/favorability/domain/favorability_engine.dart';
import 'package:agro_advisor/features/favorability/domain/regional_occurrence.dart';
import 'package:agro_advisor/features/favorability/presentation/favorability_screen.dart';
import 'package:agro_advisor/features/notifications/data/intelligent_alert_store.dart';
import 'package:agro_advisor/features/notifications/domain/app_notification_model.dart';
import 'package:agro_advisor/features/notifications/domain/intelligent_alert.dart';
import 'package:agro_advisor/features/notifications/presentation/screens/nearby_demo_screen.dart';
import 'package:agro_advisor/features/occurrence/domain/diagnosis_model.dart';
import 'package:agro_advisor/features/occurrence/domain/occurrence_model.dart';
import 'package:agro_advisor/features/property/domain/property_model.dart';
import 'package:agro_advisor/features/settings/domain/user_settings_model.dart';
import 'package:agro_advisor/services/nearby_alert_service.dart';
import 'package:agro_advisor/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 12, 12);
const property = PropertyModel(
  id: 'prop-b',
  name: 'Fazenda B',
  mainCrop: 'Soja',
  latitude: -22,
  longitude: -47,
  ownerId: 'b',
);
const settings = UserSettingsModel(userId: 'b', alertRadiusKm: 20);
final engine = FavorabilityEngine();

OccurrenceModel occurrence({
  String id = 'occ-a',
  String author = 'a',
  double km = 12,
  double? lat,
  DateTime? at,
  bool diagnosed = true,
}) => OccurrenceModel(
  id: id,
  imageBase64: '',
  latitude:
      lat ?? property.latitude + km / (6371.0088 * 3.141592653589793 / 180),
  longitude: property.longitude,
  timestamp: at ?? now,
  reportedBy: author,
  diagnosis: diagnosed
      ? DiagnosisModel(
          pestName: 'Organismo relatado',
          riskLevel: 'alto',
          description: '',
          recommendation: '',
          confidenceScore: 0.9,
          detectedIssues: [],
          analyzedAt: now,
        )
      : null,
);

ExperimentalAssessment assessment(
  AttentionLevel level, {
  bool simulated = false,
  DateTime? at,
}) {
  final input = DemonstrationInput.presets[level]!;
  final clock = at ?? now;
  if (simulated) return engine.demonstrate(input, clock);
  return engine.assessExperimental(
    property: const PropertyContext(
      id: 'prop-b',
      latitude: -22,
      longitude: -47,
    ),
    occurrences: [
      if (input.regionalOccurrences)
        for (var i = 0; i < 5; i++)
          RegionalOccurrence(
            id: 'real-test-$i',
            organismName: 'Relato',
            reportedBy: 'author-$i',
            latitude: -22,
            longitude: -47,
            timestamp: clock,
          ),
    ],
    forecast: input.forecast(clock),
    now: clock,
  );
}

class MemoryStore implements IntelligentAlertStore {
  final states = <String, AlertReservation>{};
  final history = <IntelligentAlert>[];
  final evaluations = <Map<String, dynamic>>[];
  final statuses = <String>[];
  @override
  Future<bool> reserve(String uid, IntelligentAlert alert) async {
    final key = '$uid|${alert.scope}';
    if (!shouldReserve(alert, states[key])) return false;
    states[key] = AlertReservation(alert.generatedAt, alert.level);
    history.add(alert);
    return true;
  }

  @override
  Future<void> delivery(
    String uid,
    IntelligentAlert alert,
    String status,
  ) async => statuses.add(status);
  @override
  Future<void> evaluation(
    String uid,
    String propertyId,
    Map<String, dynamic> data,
  ) async => evaluations.add(data);
}

void main() {
  test('Proximidade dentro, exatamente no limite e fora do raio', () {
    for (final km in [12.0, 20.0, 20.001]) {
      final alert = nearbyCandidate(
        userId: 'b',
        settings: settings,
        properties: [property],
        occurrence: occurrence(km: km),
        now: now,
      );
      expect(alert != null, km <= 20);
    }
  });
  test(
    'Sem propriedade válida, autor e preferências desativadas não alertam',
    () {
      expect(
        nearbyCandidate(
          userId: 'b',
          settings: settings,
          properties: [],
          occurrence: occurrence(),
          now: now,
        ),
        isNull,
      );
      const invalid = PropertyModel(
        id: 'invalid',
        name: '',
        mainCrop: '',
        latitude: 0,
        longitude: 0,
        ownerId: 'b',
      );
      expect(
        nearbyCandidate(
          userId: 'b',
          settings: settings,
          properties: [invalid],
          occurrence: occurrence(),
          now: now,
        ),
        isNull,
      );
      expect(
        nearbyCandidate(
          userId: 'b',
          settings: settings,
          properties: [property],
          occurrence: occurrence(author: 'b'),
          now: now,
        ),
        isNull,
      );
      expect(
        nearbyCandidate(
          userId: 'b',
          settings: settings.copyWith(notificationsEnabled: false),
          properties: [property],
          occurrence: occurrence(),
          now: now,
        ),
        isNull,
      );
    },
  );
  test(
    'Localização inválida, diagnóstico ausente, data futura e antiga são excluídos',
    () {
      for (final item in [
        occurrence(lat: double.nan),
        occurrence(lat: 100),
        occurrence(diagnosed: false),
        occurrence(at: now.add(const Duration(seconds: 1))),
        occurrence(at: now.subtract(const Duration(days: 8))),
      ]) {
        expect(
          nearbyCandidate(
            userId: 'b',
            settings: settings,
            properties: [property],
            occurrence: item,
            now: now,
          ),
          isNull,
        );
      }
    },
  );
  test(
    'Múltiplos destinatários respeitam suas propriedades e preferências',
    () {
      const propC = PropertyModel(
        id: 'c',
        name: 'C',
        mainCrop: '',
        latitude: -22,
        longitude: -47,
        ownerId: 'c',
      );
      final recipients = <String>[];
      for (final uid in ['a', 'b', 'c', 'd']) {
        final s = UserSettingsModel(
          userId: uid,
          alertRadiusKm: uid == 'c' ? 5 : 20,
        );
        if (nearbyCandidate(
              userId: uid,
              settings: s,
              properties: [property, propC],
              occurrence: occurrence(),
              now: now,
            ) !=
            null) {
          recipients.add(uid);
        }
      }
      expect(recipients, ['b']);
    },
  );

  test(
    'Reserva concorrente e reprocessamento produzem uma apresentação',
    () async {
      final store = MemoryStore();
      var shown = 0;
      final dispatcher = AlertDispatcher(
        store: store,
        activeUser: () => 'b',
        showLocal: (_, _) async {
          shown++;
          return 'localSubmitted';
        },
      );
      final alert = nearbyCandidate(
        userId: 'b',
        settings: settings,
        properties: [property],
        occurrence: occurrence(),
        now: now,
      )!;
      await Future.wait(List.generate(20, (_) => dispatcher.emit('b', alert)));
      expect(shown, 1);
      expect(store.history, hasLength(1));
      expect(store.statuses, ['localSubmitted']);
      final restarted = AlertDispatcher(
        store: store,
        activeUser: () => 'b',
        showLocal: (_, _) async {
          shown++;
          return 'localSubmitted';
        },
      );
      await restarted.emit('b', alert);
      expect(shown, 1);
    },
  );

  test(
    'Baixo e moderado não notificam; alto sem ocorrências e muito alto notificam',
    () {
      expect(
        environmentalCandidate(assessment(AttentionLevel.low), property),
        isNull,
      );
      expect(
        environmentalCandidate(assessment(AttentionLevel.moderate), property),
        isNull,
      );
      final high = assessment(AttentionLevel.high);
      expect(high.regional!.count, 0);
      expect(environmentalCandidate(high, property)!.index, 60);
      final veryHigh = environmentalCandidate(
        assessment(AttentionLevel.veryHigh),
        property,
      )!;
      expect(veryHigh.simulated, isFalse);
      expect(veryHigh.level, 'veryHigh');
    },
  );

  test('Janela de 24 h e mudança relevante de nível', () {
    final high = environmentalCandidate(
      assessment(AttentionLevel.high),
      property,
    )!;
    final old = AlertReservation(now, 'high');
    expect(shouldReserve(high, old), isFalse);
    expect(
      shouldReserve(
        environmentalCandidate(
          assessment(
            AttentionLevel.high,
            at: now.add(const Duration(hours: 24)),
          ),
          property,
        )!,
        old,
      ),
      isTrue,
    );
    final veryHigh = environmentalCandidate(
      assessment(AttentionLevel.veryHigh),
      property,
    )!;
    expect(shouldReserve(veryHigh, old), isTrue);
    expect(veryHigh.historyId, isNot(high.historyId));
    expect(
      shouldReserve(
        high,
        AlertReservation(now.add(const Duration(days: 1)), 'high'),
      ),
      isFalse,
    );
  });

  test(
    'Avaliação automática registra baixo/moderado e envia alto sem ocorrência',
    () async {
      for (final level in [
        AttentionLevel.low,
        AttentionLevel.moderate,
        AttentionLevel.high,
      ]) {
        final store = MemoryStore();
        var shown = 0;
        var calls = 0;
        final service = EnvironmentalAlertService(
          loadSettings: (_) async => settings,
          loadProperties: (_) async => [property],
          now: () => now,
          assess: (_) async {
            calls++;
            return assessment(level);
          },
          dispatcher: AlertDispatcher(
            store: store,
            activeUser: () => 'b',
            showLocal: (_, _) async {
              shown++;
              return 'localSubmitted';
            },
          ),
        );
        expect(await service.run('b'), isEmpty);
        expect(store.evaluations, hasLength(1));
        expect(shown, level == AttentionLevel.high ? 1 : 0);
        await service.run('b');
        expect(calls, 1);
        await service.run('b', force: true);
        expect(shown, level == AttentionLevel.high ? 1 : 0);
      }
    },
  );

  test('Dados ausentes registram insuficiência, sem apresentação', () async {
    final store = MemoryStore();
    var shown = 0;
    final service = EnvironmentalAlertService(
      loadSettings: (_) async => settings,
      loadProperties: (_) async => [property],
      assess: (_) async => engine.assessExperimental(
        property: const PropertyContext(id: 'p', latitude: -22, longitude: -47),
        occurrences: [],
        forecast: null,
        now: now,
      ),
      dispatcher: AlertDispatcher(
        store: store,
        activeUser: () => 'b',
        showLocal: (_, _) async {
          shown++;
          return 'localSubmitted';
        },
      ),
    );
    expect(await service.run('b'), isNotEmpty);
    expect(shown, 0);
    expect(store.evaluations.single['index'], isNull);
  });

  test(
    'Desativadas, simulação e troca de conta impedem persistência operacional',
    () async {
      for (final disabled in [true, false]) {
        final store = MemoryStore();
        var shown = 0;
        final service = EnvironmentalAlertService(
          loadSettings: (_) async =>
              settings.copyWith(notificationsEnabled: !disabled),
          loadProperties: (_) async => [property],
          assess: (_) async => assessment(AttentionLevel.high, simulated: true),
          dispatcher: AlertDispatcher(
            store: store,
            activeUser: () => 'b',
            showLocal: (_, _) async {
              shown++;
              return 'localSubmitted';
            },
          ),
        );
        await service.run('b');
        expect(store.evaluations, isEmpty);
        expect(store.history, isEmpty);
        expect(shown, 0);
      }
      final store = MemoryStore();
      final dispatcher = AlertDispatcher(
        store: store,
        activeUser: () => 'c',
        showLocal: (_, _) async => throw StateError('não chamar'),
      );
      expect(
        await dispatcher.emit(
          'b',
          environmentalCandidate(assessment(AttentionLevel.high), property)!,
        ),
        isFalse,
      );
      expect(store.history, isEmpty);
    },
  );

  test('Logout durante avaliação descarta resposta tardia', () async {
    final pending = Completer<ExperimentalAssessment>();
    final store = MemoryStore();
    final started = Completer<void>();
    final service = EnvironmentalAlertService(
      loadSettings: (_) async => settings,
      loadProperties: (_) async => [property],
      assess: (_) {
        started.complete();
        return pending.future;
      },
      dispatcher: AlertDispatcher(
        store: store,
        activeUser: () => 'b',
        showLocal: (_, _) async => 'localSubmitted',
      ),
    );
    final running = service.run('b');
    await started.future;
    service.reset();
    pending.complete(assessment(AttentionLevel.high));
    await running;
    expect(store.history, isEmpty);
    expect(store.evaluations, isEmpty);
  });

  test(
    'Falha local e permissão negada não são relatadas como visualização',
    () async {
      for (final status in ['permissionDenied', 'localFailed']) {
        final store = MemoryStore();
        final dispatcher = AlertDispatcher(
          store: store,
          activeUser: () => 'b',
          showLocal: (_, _) async {
            if (status == 'localFailed') throw StateError('plugin');
            return status;
          },
        );
        await dispatcher.emit(
          'b',
          environmentalCandidate(assessment(AttentionLevel.high), property)!,
        );
        expect(store.statuses, [status]);
      }
    },
  );

  test(
    'Token inválido/ausente não grava; token rotacionado grava só na sessão atual',
    () async {
      final saved = <String>[];
      expect(
        await registerTokenSafely(
          requestToken: () async =>
              throw PlatformException(code: 'invalid-token'),
          saveToken: (v) async => saved.add(v),
          isCurrent: () => true,
        ),
        isFalse,
      );
      expect(
        await registerTokenSafely(
          requestToken: () async => null,
          saveToken: (v) async => saved.add(v),
          isCurrent: () => true,
        ),
        isFalse,
      );
      expect(
        await registerTokenSafely(
          requestToken: () async => 'rotated-test-token',
          saveToken: (v) async => saved.add(v),
          isCurrent: () => false,
        ),
        isFalse,
      );
      expect(saved, isEmpty);
      expect(
        await registerTokenSafely(
          requestToken: () async => 'rotated-test-token',
          saveToken: (v) async => saved.add(v),
          isCurrent: () => true,
        ),
        isTrue,
      );
      expect(saved, ['rotated-test-token']);
    },
  );

  test(
    'Stream detecta diagnóstico adicionado e reprocessa sem duplicar',
    () async {
      final stream = StreamController<List<OccurrenceModel>>.broadcast();
      final store = MemoryStore();
      var shown = 0;
      List<OccurrenceModel> items = [occurrence(diagnosed: false)];
      final service = NearbyAlertService(
        loadSettings: (_) async => settings,
        loadProperties: (_) async => [property],
        watchOccurrences: (_) => stream.stream,
        loadOccurrences: (_) async => items,
        now: () => now,
        dispatcher: AlertDispatcher(
          store: store,
          activeUser: () => 'b',
          showLocal: (_, _) async {
            shown++;
            return 'localSubmitted';
          },
        ),
      );
      await service.check('b');
      expect(shown, 0);
      items = [occurrence()];
      stream.add(items);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.check('b');
      expect(shown, 1);
      await service.stop();
      stream.add([occurrence(id: 'other')]);
      await Future<void>.delayed(Duration.zero);
      expect(shown, 1);
      await stream.close();
    },
  );

  test('Metadados antigos e novos continuam legíveis', () {
    final old = AppNotificationModel.fromMap({'title': 'Antiga'}, 'old');
    expect(old.isPreventive, isFalse);
    expect(old.simulated, isFalse);
    final alert = environmentalCandidate(
      assessment(AttentionLevel.high),
      property,
    )!;
    final n = AppNotificationModel.fromMap(alert.toMap(), alert.historyId);
    expect(n.isPreventive, isTrue);
    expect(n.region, 'Fazenda B');
    expect(
      settings
          .copyWith(fcmToken: 'rotated-test-token')
          .toMap()
          .containsKey('fcmToken'),
      isFalse,
    );
    expect(n.favorabilityIndex, 60);
  });

  testWidgets(
    'Demo de ocorrência usa raio configurado e somente apresentação local',
    (tester) async {
      final shown = <IntelligentAlert>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NearbyDemoScreen(
            radiusKm: 20,
            enabled: true,
            showLocal: (alert) async {
              shown.add(alert);
              return 'localSubmitted';
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '21');
      await tester.tap(find.text('Simular ocorrência'));
      await tester.pumpAndSettle();
      expect(shown, isEmpty);
      expect(
        find.text('Fora do raio: nenhuma notificação gerada.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '20');
      await tester.tap(find.text('Simular ocorrência'));
      await tester.pumpAndSettle();
      expect(shown.single.simulated, isTrue);
      await tester.tap(find.text('Abrir detalhes demonstrativos'));
      await tester.pumpAndSettle();
      expect(find.text('MODO DEMONSTRAÇÃO — DADOS SIMULADOS'), findsOneWidget);
      expect(find.textContaining('Área monitorada:'), findsOneWidget);
    },
  );

  testWidgets(
    'Demo de favorabilidade envia resultado simulado e limpa ao desativar',
    (tester) async {
      final shown = <ExperimentalAssessment>[];
      var operationalLoads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: FavorabilityScreen(
            loadOperational: () async {
              operationalLoads++;
              return assessment(AttentionLevel.high);
            },
            demonstrateNotification: (result) async {
              shown.add(result);
              return 'localSubmitted';
            },
          ),
        ),
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<AttentionLevel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alto').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Executar avaliação'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Executar avaliação'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Gerar notificação local demonstrativa'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Gerar notificação local demonstrativa'));
      await tester.pumpAndSettle();
      expect(shown.single.simulated, isTrue);
      expect(shown.single.index, 60);
      expect(operationalLoads, 0);
      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Gerar notificação local demonstrativa'), findsNothing);
    },
  );
}
