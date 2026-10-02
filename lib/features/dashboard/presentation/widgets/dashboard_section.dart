import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Seção do dashboard: título no padrão das outras telas + conteúdo em card.
class DashboardSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Card branco com borda — mesmo estilo dos cards do Perfil/Histórico.
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: child,
    );
  }
}

/// Mensagem de estado (carregando, sem dados, erro) dentro de uma seção.
class DashboardStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final VoidCallback? onRetry;
  final bool loading;

  const DashboardStateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color = AppColors.textSecondary,
    this.onRetry,
    this.loading = false,
  });

  const DashboardStateMessage.loading({super.key, required this.title})
    : icon = Icons.hourglass_empty_rounded,
      message = null,
      color = AppColors.textSecondary,
      onRetry = null,
      loading = true;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (onRetry != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text('Tentar novamente'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
