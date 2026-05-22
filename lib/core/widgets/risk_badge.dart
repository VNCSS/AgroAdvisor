import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';

/// Badge colorido que exibe o nível de risco de uma praga/doença.
/// Usado em cards, listas e telas de diagnóstico.
class RiskBadge extends StatelessWidget {
  final String riskLevel;
  final bool compact;

  const RiskBadge({super.key, required this.riskLevel, this.compact = false});

  static ({Color fg, Color bg, String label, IconData icon}) _resolve(String level) {
    return switch (level.toLowerCase()) {
      'alto'             => (fg: AppColors.riskHigh,   bg: AppColors.riskHighContainer,   label: 'ALTO',   icon: Icons.warning_rounded),
      'médio' || 'medio' => (fg: AppColors.riskMedium, bg: AppColors.riskMediumContainer, label: 'MÉDIO',  icon: Icons.warning_amber_rounded),
      'baixo'            => (fg: AppColors.riskLow,    bg: AppColors.riskLowContainer,    label: 'BAIXO',  icon: Icons.check_circle_outline_rounded),
      _                  => (fg: AppColors.textHint,   bg: AppColors.surfaceVariant,      label: '—',      icon: Icons.help_outline_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolve(riskLevel);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: r.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: r.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(r.icon, size: compact ? 12 : 14, color: r.fg),
          const SizedBox(width: 4),
          Text(
            r.label,
            style: (compact ? AppTextStyles.labelSmall : AppTextStyles.labelMedium)
                .copyWith(color: r.fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
