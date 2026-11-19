import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/diagnosis_service.dart';
import 'services/gemini_ai_service.dart';
import 'services/nearby_alert_service.dart';
import 'services/notification_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/favorability/data/preventive_alert_service.dart';
import 'features/main_shell.dart';
import 'features/weather/data/weather_repository.dart';
import 'features/favorability/data/environmental_alert_service.dart';
import 'features/favorability/data/favorability_service.dart';
import 'features/favorability/data/scientific_rule_repository.dart';
import 'features/favorability/domain/favorability_engine.dart';
import 'features/notifications/data/intelligent_alert_store.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/notifications/domain/app_notification_model.dart';
import 'features/notifications/presentation/alert_session.dart';
import 'features/notifications/presentation/screens/notification_detail_screen.dart';
import 'features/occurrence/data/occurrence_repository.dart';

final _notificationNavigator = GlobalKey<NavigatorState>();

bool _openNotification(String payload) {
  final context = _notificationNavigator.currentContext;
  if (context == null) return false;
  final uid = context.read<AuthService>().currentUser?.uid;
  if (uid == null) return false;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    // Descarta notificações locais de uma sessão anterior de outra conta.
    if (data['recipientId'] != uid) return true;
    final notification = AppNotificationModel.fromMap(
      data,
      data['id'] as String? ?? 'local',
    );
    if (!notification.simulated && notification.id.startsWith('alert_')) {
      unawaited(
        NotificationRepository()
            .markRead(uid, notification.id)
            .catchError((Object _) {}),
      );
    }
    _notificationNavigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
  } catch (_) {
    /* Payload antigo/inválido: não navega nem expõe dados. */
  }
  return true;
}

/// Raiz do aplicativo: configura providers, tema e AuthWrapper.
class AgroAdvisorApp extends StatelessWidget {
  const AgroAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => NotificationService(onOpen: _openNotification)),
        Provider(
          create: (context) => AlertDispatcher(
            store: FirestoreIntelligentAlertStore(),
            showLocal: context.read<NotificationService>().showAlert,
            activeUser: () => context.read<AuthService>().currentUser?.uid,
          ),
        ),
        Provider(
          create: (context) => NearbyAlertService(
            dispatcher: context.read<AlertDispatcher>(),
            loadSettings: context.read<DatabaseService>().getUserSettings,
            loadProperties: context.read<DatabaseService>().getUserProperties,
            watchOccurrences: OccurrenceRepository().watchSince,
            loadOccurrences: OccurrenceRepository().getSince,
          ),
        ),
        Provider(
          create: (_) => DiagnosisService(
            aiService: GeminiAiService(),
            db: DatabaseService(),
          ),
        ),
        // Instância única para compartilhar o cache de previsões entre telas.
        Provider(create: (_) => WeatherRepository()),
        Provider(
          create: (context) {
            final occurrences = OccurrenceRepository();
            final service = FavorabilityService(
              engine: FavorabilityEngine(),
              rules: ScientificRuleRepository(),
              loadOccurrencesSince: occurrences.getSince,
              loadForecast: context
                  .read<WeatherRepository>()
                  .getForecastForProperty,
            );
            return EnvironmentalAlertService(
              dispatcher: context.read<AlertDispatcher>(),
              loadSettings: context.read<DatabaseService>().getUserSettings,
              loadProperties: context.read<DatabaseService>().getUserProperties,
              assess: service.assessExperimental,
            );
          },
        ),
        // Alertas preventivos de favorabilidade: gravam no mesmo sistema de
        // notificações e reutilizam o cache de previsões acima.
        Provider(
          create: (context) => PreventiveAlertService.create(
            weather: context.read<WeatherRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _notificationNavigator,
        title: 'AgroAdvisor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Observa o estado de autenticação e redireciona para o shell principal ou login.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.currentUser != null) {
      final uid = auth.currentUser!.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || auth.currentUser?.uid != uid) return;
        // Não lança exceção; repetições são limitadas e deduplicadas.
        context.read<PreventiveAlertService>().run(uid);
      });
      return AlertSession(
        key: ValueKey(auth.currentUser!.uid),
        userId: auth.currentUser!.uid,
        child: const MainShell(),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || auth.currentUser != null) return;
      context.read<NearbyAlertService>().stop();
      context.read<PreventiveAlertService>().reset();
      context.read<EnvironmentalAlertService>().reset();
      context.read<NotificationService>().stop();
    });
    return const LoginScreen();
  }
}
