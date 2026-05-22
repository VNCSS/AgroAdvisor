import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/diagnosis_service.dart';
import 'services/gemini_ai_service.dart';
import 'services/notification_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/main_shell.dart';

/// Raiz do aplicativo: configura providers, tema e AuthWrapper.
class AgroAdvisorApp extends StatelessWidget {
  const AgroAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => NotificationService()),
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

/// Observa o estado de autenticação e redireciona para o shell principal ou login.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationService>().initialize(auth.currentUser!.uid);
      });
      return const MainShell();
    }

    return const LoginScreen();
  }
}
