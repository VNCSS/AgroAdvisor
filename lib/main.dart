import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/property/property_view_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase antes de rodar o app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AgroAdvisorApp());
}

class AgroAdvisorApp extends StatelessWidget {
  const AgroAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthService disponível globalmente
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'AgroAdvisor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // verde agrícola
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        // AuthWrapper decide qual tela exibir baseado no estado de login
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Observa o stream de autenticação e redireciona o usuário
/// para Login ou para a tela principal automaticamente.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.currentUser != null) {
      return const PropertyViewScreen();
    }
    return const LoginScreen();
  }
}
