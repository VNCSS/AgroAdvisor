import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/diagnosis_service.dart';
import 'services/gemini_ai_service.dart';
import 'services/notification_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/property/presentation/screens/property_list_screen.dart';

/// Raiz do aplicativo: configura providers e tema, e exibe o AuthWrapper.
///
/// Separado de main.dart para que este cuide apenas do bootstrap
/// (Firebase init, runApp) e app.dart cuide da configuração do app.
class AgroAdvisorApp extends StatelessWidget {
  const AgroAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth — ChangeNotifier reativo; controla o AuthWrapper
        ChangeNotifierProvider(create: (_) => AuthService()),

        // Infraestrutura Firebase (singletons por sessão)
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => NotificationService()),

        // Diagnóstico de IA — troque GeminiAiService() para mudar de provedor
        Provider(
          create: (_) => DiagnosisService(
            aiService: GeminiAiService(),
            db: DatabaseService(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AgroAdvisor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Observa o estado de autenticação e redireciona automaticamente.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationService>().initialize(auth.currentUser!.uid);
      });
      return const PropertyListScreen();
    }

    return const LoginScreen();
  }
}
