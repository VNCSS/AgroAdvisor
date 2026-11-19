import 'dart:convert';
import 'package:agro_advisor/features/notifications/domain/intelligent_alert.dart';
import 'package:agro_advisor/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  var permitted = true;
  Map<String, Object?>? launch;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    permitted = true;
    launch = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' || 'requestNotificationsPermission' => true,
            'areNotificationsEnabled' => permitted,
            'getNotificationAppLaunchDetails' => launch,
            _ => null,
          };
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  IntelligentAlert alert({bool simulated = false}) => IntelligentAlert(
    scope: 'local-test',
    type: 'nearby',
    title: 'Teste',
    body: 'Corpo',
    region: 'Área de teste',
    source: 'Teste automatizado',
    generatedAt: DateTime(2026, 11, 12),
    simulated: simulated,
  );

  test(
    'Apresentação local funciona sem inicializar FCM e inclui payload de navegação',
    () async {
      final service = NotificationService();
      await service.prepareLocal('b');
      expect(await service.showAlert('b', alert()), 'localSubmitted');
      final shown =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      final payload = jsonDecode(shown['payload'] as String) as Map;
      expect(payload['recipientId'], 'b');
      expect(payload['simulated'], false);
      expect(payload['region'], 'Área de teste');
      expect(
        calls.where((c) => c.method == 'createNotificationChannel'),
        hasLength(1),
      );
      await service.stop();
    },
  );
  test('Permissão negada e conta diferente não chamam show', () async {
    final service = NotificationService();
    await service.prepareLocal('b');
    permitted = false;
    expect(await service.showAlert('b', alert()), 'permissionDenied');
    permitted = true;
    expect(await service.showAlert('a', alert()), 'sessionEnded');
    expect(calls.where((c) => c.method == 'show'), isEmpty);
    await service.stop();
  });
  test('Demo usa título e payload simulados; não acessa Firebase', () async {
    final service = NotificationService();
    await service.prepareLocal('b');
    expect(
      await service.showAlert('b', alert(simulated: true)),
      'localSubmitted',
    );
    final shown = calls.singleWhere((c) => c.method == 'show').arguments as Map;
    expect(shown['title'], startsWith('DEMONSTRAÇÃO'));
    expect((jsonDecode(shown['payload'] as String) as Map)['simulated'], true);
    await service.stop();
  });
  test(
    'Toque que iniciou app é retido até navegador pronto e consumido uma vez',
    () async {
      var ready = false;
      final opened = <String>[];
      final payload = alert().payload('b');
      launch = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 1,
          'notificationResponseType': 0,
          'payload': payload,
        },
      };
      final service = NotificationService(
        onOpen: (p) {
          if (!ready) return false;
          opened.add(p);
          return true;
        },
      );
      await service.prepareLocal('b');
      service.openPending();
      expect(opened, isEmpty);
      ready = true;
      service.openPending();
      service.openPending();
      expect(opened, [payload]);
      await service.stop();
    },
  );
}
