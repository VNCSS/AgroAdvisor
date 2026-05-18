import 'package:flutter/material.dart';

/// Tema visual centralizado do AgroAdvisor.
///
/// Alterar a cor primária aqui propaga para o app inteiro.
class AppTheme {
  AppTheme._();

  static const Color _primarySeed = Color(0xFF2E7D32); // verde agrícola

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primarySeed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
}
