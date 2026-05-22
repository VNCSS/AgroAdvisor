import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary          = Color(0xFF2D6A2F);
  static const Color primaryDark      = Color(0xFF1B4D1D);
  static const Color primaryLight     = Color(0xFF4CAF50);
  static const Color primaryContainer = Color(0xFFE8F5E9);
  static const Color onPrimary        = Color(0xFFFFFFFF);

  // ── Superfícies ──────────────────────────────────────────────────────────
  static const Color background     = Color(0xFFF5F0E8); // creme — igual ao protótipo
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF2F8F2);

  // ── Risco ────────────────────────────────────────────────────────────────
  static const Color riskHigh            = Color(0xFFD32F2F);
  static const Color riskHighContainer   = Color(0xFFFFEBEE);
  static const Color riskMedium          = Color(0xFFE65100);
  static const Color riskMediumContainer = Color(0xFFFFF8E1);
  static const Color riskLow             = Color(0xFF2E7D32);
  static const Color riskLowContainer    = Color(0xFFE8F5E9);

  // ── Texto ────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textHint      = Color(0xFF9E9E9E);
  static const Color textOnDark    = Color(0xFFFFFFFF);

  // ── Chrome ───────────────────────────────────────────────────────────────
  static const Color border  = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFF5F5F5);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color error   = Color(0xFFD32F2F);
  static const Color info    = Color(0xFF1976D2);
}
