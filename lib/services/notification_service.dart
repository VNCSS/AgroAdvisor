import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';
import '../features/notifications/domain/intelligent_alert.dart';
import 'database_service.dart';

/// Falha/rotação do token não deve interromper o transporte local.
Future<bool> registerTokenSafely({
  required Future<String?> Function() requestToken,
  required Future<void> Function(String) saveToken,
  required bool Function() isCurrent,
}) async {
  try {
    final token = await requestToken();
    if (token == null || token.isEmpty || !isCurrent()) return false;
    await saveToken(token);
    return isCurrent();
  } catch (_) {
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Mensagens com notification são apresentadas pelo SO. Não exibir outra.
}

/// FCM é compatibilidade opcional. Alertas Spark usam exclusivamente showAlert.
class NotificationService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final bool Function(String payload)? onOpen;
  NotificationService({this.onOpen});
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  String? _user, _pendingPayload;
  Future<void>? _localSetup;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub, _openSub;
  int _generation = 0;
  bool _tokenReady = false;

  static const _channel = AndroidNotificationChannel(
    AppConstants.notifChannelId,
    AppConstants.notifChannelName,
    description: AppConstants.notifChannelDescription,
    importance: Importance.high,
  );

  Future<void> _setup() => _localSetup ??= _setupLocal().catchError((Object e) {
    _localSetup = null;
    throw e;
  });

  Future<void> _setupLocal() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _tap(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _pendingPayload = launch?.notificationResponse?.payload;
    }
  }

  void _tap(String? payload) {
    if (payload == null) return;
    _pendingPayload = payload;
    openPending();
  }

  void openPending() {
    final payload = _pendingPayload;
    if (payload != null && (onOpen?.call(payload) ?? false)) {
      _pendingPayload = null;
    }
  }

  Future<void> initialize(String userId) async {
    if (_user == userId && _tokenReady) {
      openPending();
      return;
    }
    await prepareLocal(userId);
    final generation = _generation;
    bool active() => generation == _generation && _user == userId;
    // Falha no token nunca bloqueia a configuração local.
    try {
      _tokenReady = await registerTokenSafely(
        requestToken: () async {
          await _fcm.requestPermission(alert: true, badge: true, sound: true);
          return _fcm.getToken();
        },
        saveToken: (token) => DatabaseService().saveUserFcmToken(userId, token),
        isCurrent: active,
      );
      if (!active()) return;
      await _tokenSub?.cancel();
      _tokenSub = _fcm.onTokenRefresh.listen((token) async {
        if (!active()) return;
        try {
          await DatabaseService().saveUserFcmToken(userId, token);
        } catch (_) {
          dev.log('[FCM] não foi possível atualizar o token próprio');
        }
      }, onError: (Object _) => dev.log('[FCM] token indisponível'));
    } catch (_) {
      dev.log(
        '[FCM] registro indisponível; alertas locais continuam independentes',
      );
    }
    if (!active()) return;
    _messageSub ??= FirebaseMessaging.onMessage.listen((message) {
      if (_user == null || message.notification == null) return;
      unawaited(_foreground(message));
    });
    _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _tap(_remotePayload(message)),
    );
    try {
      final initial = await _fcm.getInitialMessage();
      if (initial != null && active()) {
        _pendingPayload = _remotePayload(initial);
      }
    } catch (_) {
      /* Compatibilidade FCM opcional no modo gratuito. */
    }
    openPending();
  }

  Future<void> prepareLocal(String userId) async {
    if (_user != userId) {
      final stopping = stop();
      final generation = _generation;
      _user = userId;
      await stopping;
      if (_generation != generation || _user != userId) return;
    }
    try {
      await _setup();
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      dev.log('[Notifications] apresentação local indisponível');
    }
    if (_user == userId) openPending();
  }

  String _remotePayload(RemoteMessage message) => jsonEncode({
    ...message.data,
    'recipientId': _user,
    'id': message.messageId ?? 'remote',
    'title': message.notification?.title,
    'body': message.notification?.body,
    'receivedAt': (message.sentTime ?? DateTime.now()).toIso8601String(),
    'source': 'FCM (infraestrutura externa)',
    'simulated': false,
  });

  Future<void> _foreground(RemoteMessage message) async {
    final uid = _user;
    if (uid == null) return;
    try {
      if ((await DatabaseService().getUserSettings(
                uid,
              ))?.notificationsEnabled ==
              false ||
          _user != uid) {
        return;
      }
      await _show(
        message.notification!.title ?? 'Alerta',
        message.notification!.body ?? '',
        _remotePayload(message),
      );
    } catch (_) {
      dev.log('[FCM] apresentação local falhou');
    }
  }

  Future<String> showAlert(String userId, IntelligentAlert alert) async {
    await _setup();
    if (_user != userId) return 'sessionEnded';
    final enabled = await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    if (enabled == false) return 'permissionDenied';
    if (_user != userId) return 'sessionEnded';
    await _show(
      alert.simulated ? 'DEMONSTRAÇÃO — ${alert.title}' : alert.title,
      alert.simulated ? 'DADOS SIMULADOS\n${alert.body}' : alert.body,
      alert.payload(userId),
    );
    return 'localSubmitted'; // Plugin aceitou a chamada; não comprova visualização.
  }

  Future<void> _show(String title, String body, String payload) async {
    // ID estável dentro do intervalo Android de 32 bits; não depende de hashCode.
    var id = 0;
    for (final value in utf8.encode(payload)) {
      id = (id * 31 + value) & 0x7fffffff;
    }
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Deve ser chamado antes do signOut enquanto a escrita própria é permitida.
  Future<void> unregister() async {
    final uid = _user;
    _pendingPayload = null;
    await stop();
    if (uid != null) {
      try {
        await DatabaseService().removeUserFcmToken(uid);
      } catch (_) {}
      try {
        await _fcm.deleteToken();
      } catch (_) {}
    }
    try {
      await _local.cancelAll();
    } catch (_) {}
  }

  Future<void> stop() async {
    _generation++;
    _user = null;
    _tokenReady = false;
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _messageSub?.cancel();
    _messageSub = null;
    await _openSub?.cancel();
    _openSub = null;
  }

  /// Compatibilidade com chamadas antigas; não envia push.
  Future<void> showNearbyPestAlert({
    required String pestInfo,
    required double distanceKm,
  }) => _show(
    'Ocorrência próxima',
    '$pestInfo a ${distanceKm.toStringAsFixed(1)} km.',
    '{}',
  );
}
