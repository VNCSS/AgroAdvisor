import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';
import 'database_service.dart';

/// Handler de mensagens FCM em background — deve ser top-level.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  dev.log('[FCM] mensagem recebida em background: ${message.notification?.title}');
  // Firebase já exibe a notificação automaticamente quando o app está em background.
}

/// Gerencia FCM (Firebase Cloud Messaging) e notificações locais.
///
/// SETUP NECESSÁRIO (ver README):
///   Android → adicionar permissão POST_NOTIFICATIONS no AndroidManifest.xml
///   iOS     → configurar APNs key no Firebase Console
///
/// Uso:
///   Injetado como Provider em main.dart.
///   Chamado via context.read e initialize(userId) logo após o login.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _db = DatabaseService();

  bool _initialized = false;

  static const AndroidNotificationChannel _alertChannel =
      AndroidNotificationChannel(
    AppConstants.notifChannelId,
    AppConstants.notifChannelName,
    description: AppConstants.notifChannelDescription,
    importance: Importance.high,
  );

  /// Inicializa FCM, registra token e configura handlers.
  /// Idempotente — seguro chamar múltiplas vezes.
  Future<void> initialize(String userId) async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicita permissão ao usuário
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    dev.log('[FCM] permissão: ${settings.authorizationStatus}');

    await _setupLocalNotifications();
    await _registerToken(userId);

    // Escuta atualizações do token (rotação periódica do FCM)
    _fcm.onTokenRefresh.listen((newToken) async {
      dev.log('[FCM] token atualizado');
      await _db.saveUserFcmToken(userId, newToken);
    });

    // Mensagens recebidas com o app em foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    dev.log('[FCM] NotificationService inicializado para usuário $userId');
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // já solicitado via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Cria canal no Android 8+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_alertChannel);
  }

  Future<void> _registerToken(String userId) async {
    final token = await _fcm.getToken();
    if (token != null) {
      dev.log('[FCM] token registrado');
      await _db.saveUserFcmToken(userId, token);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('[FCM] foreground: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannel.id,
          _alertChannel.name,
          channelDescription: _alertChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Exibe notificação local de alerta de praga próxima.
  /// Usado para alertas detectados via stream (sem Cloud Function).
  Future<void> showNearbyPestAlert({
    required String pestInfo,
    required double distanceKm,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Alerta: Praga Detectada Próxima!',
      '$pestInfo detectada a ${distanceKm.toStringAsFixed(1)} km da sua propriedade.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannel.id,
          _alertChannel.name,
          channelDescription: _alertChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
