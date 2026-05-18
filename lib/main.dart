import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

/// Ponto de entrada do app.
///
/// Responsabilidade única: inicializar o Firebase e chamar runApp.
/// Toda a configuração do app (tema, providers, rotas) está em app.dart.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AgroAdvisorApp());
}
