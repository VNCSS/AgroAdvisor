import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

/// Tema visual centralizado do AgroAdvisor.
///
/// UX para produtores rurais: fontes grandes, contraste alto, botões generosos,
/// cores claras e feedback visual imediato. Segue Material Design 3.
abstract final class AppTheme {
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary:             AppColors.primary,
      onPrimary:           AppColors.onPrimary,
      primaryContainer:    AppColors.primaryContainer,
      onPrimaryContainer:  AppColors.primaryDark,
      secondary:           const Color(0xFF5B8A5E),
      onSecondary:         Colors.white,
      secondaryContainer:  const Color(0xFFD7EFDA),
      onSecondaryContainer: AppColors.primaryDark,
      error:               AppColors.error,
      onError:             Colors.white,
      errorContainer:      AppColors.riskHighContainer,
      onErrorContainer:    const Color(0xFFB71C1C),
      surface:             AppColors.surface,
      onSurface:           AppColors.textPrimary,
      onSurfaceVariant:    AppColors.textSecondary,
      outline:             AppColors.border,
      outlineVariant:      AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.onPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.onPrimary, size: 24),
        actionsIconTheme: const IconThemeData(color: AppColors.onPrimary, size: 24),
      ),

      // ── Cards ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Inputs ─────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      // ── FilledButton ───────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, AppSpacing.buttonH),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
          elevation: 0,
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, AppSpacing.buttonH),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── BottomAppBar ───────────────────────────────────────────────────
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.surface,
        elevation: 8,
        shape: CircularNotchedRectangle(),
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),

      // ── Divider ────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      // ── SnackBar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),

      // ── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryContainer,
        disabledColor: AppColors.surfaceVariant,
        labelStyle: AppTextStyles.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          side: const BorderSide(color: AppColors.border),
        ),
        showCheckmark: false,
      ),

      // ── Switch ─────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.textHint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
      ),

      // ── Slider ─────────────────────────────────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        overlayColor: Color(0x1A2D6A2F),
      ),

      // ── Tipografia ─────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:  AppTextStyles.displayLarge.copyWith(color: AppColors.textPrimary),
        displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.textPrimary),
        headlineLarge:  AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimary),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimary),
        headlineSmall:  AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
        titleLarge:  AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        titleSmall:  AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary),
        bodyLarge:   AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
        bodyMedium:  AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        bodySmall:   AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        labelLarge:  AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
        labelMedium: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
        labelSmall:  AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
