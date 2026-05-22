import 'package:flutter/material.dart';

// Fontes maiores para produtores rurais com menor familiaridade digital.
abstract final class AppTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3,
  );
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700, height: 1.25,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700, height: 1.3,
  );
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, height: 1.4,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w500, height: 1.4,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, height: 1.4,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.6,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.6,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
  );
}
