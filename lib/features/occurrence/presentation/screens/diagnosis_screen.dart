import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/diagnosis_model.dart';

/// Relatório completo do diagnóstico de IA.
/// Layout baseado no protótipo: risco em destaque, confiança circular, cards de contexto.
class DiagnosisScreen extends StatelessWidget {
  final DiagnosisModel diagnosis;
  const DiagnosisScreen({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diagnóstico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
            tooltip: 'Compartilhar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner de risco ──────────────────────────────────────────
            _RiskBanner(riskLevel: diagnosis.riskLevel),
            const SizedBox(height: AppSpacing.md),

            // ── Nome + confiança ─────────────────────────────────────────
            _DiagnosisHeader(
              pestName: diagnosis.pestName,
              confidenceScore: diagnosis.confidenceScore,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Problemas detectados ─────────────────────────────────────
            if (diagnosis.detectedIssues.isNotEmpty) ...[
              _DetectedIssues(issues: diagnosis.detectedIssues),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Por que esse diagnóstico ─────────────────────────────────
            _InfoCard(
              icon: Icons.psychology_outlined,
              title: 'Por que esse diagnóstico',
              content: diagnosis.description,
              iconColor: AppColors.primary,
              bgColor: AppColors.surfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Recomendação de manejo ───────────────────────────────────
            _InfoCard(
              icon: Icons.tips_and_updates_outlined,
              title: 'Recomendação de manejo',
              content: diagnosis.recommendation,
              iconColor: AppColors.primary,
              bgColor: AppColors.primaryContainer,
              borderColor: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Timestamp ─────────────────────────────────────────────────
            Text(
              'Análise realizada em ${DateFormatter.format(diagnosis.analyzedAt)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Aviso ─────────────────────────────────────────────────────
            _DisclaimerBanner(),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _RiskBanner extends StatelessWidget {
  final String riskLevel;
  const _RiskBanner({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (riskLevel.toLowerCase()) {
      'alto'             => (AppColors.riskHigh,   'RISCO ALTO',       Icons.warning_rounded),
      'médio' || 'medio' => (AppColors.riskMedium, 'RISCO MÉDIO',      Icons.warning_amber_rounded),
      'baixo'            => (AppColors.riskLow,    'RISCO BAIXO',      Icons.check_circle_outline_rounded),
      _                  => (AppColors.textHint,   'RISCO DESCONHECIDO', Icons.help_outline_rounded),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTextStyles.headlineMedium.copyWith(
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisHeader extends StatelessWidget {
  final String pestName;
  final double confidenceScore;
  const _DiagnosisHeader({required this.pestName, required this.confidenceScore});

  @override
  Widget build(BuildContext context) {
    final pct = (confidenceScore * 100).round();
    final color = confidenceScore >= 0.7
        ? AppColors.riskLow
        : confidenceScore >= 0.4
            ? AppColors.riskMedium
            : AppColors.riskHigh;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIAGNÓSTICO PRINCIPAL',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textHint, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(pestName, style: AppTextStyles.headlineSmall),
              ],
            ),
          ),
          // Indicador circular de confiança
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: confidenceScore,
                  strokeWidth: 5,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  '$pct%',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedIssues extends StatelessWidget {
  final List<String> issues;
  const _DetectedIssues({required this.issues});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OUTRAS HIPÓTESES',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textHint, letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(issue,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color iconColor;
  final Color bgColor;
  final Color? borderColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.iconColor,
    required this.bgColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Text(title,
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(content,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary, height: 1.6)),
        ],
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFF57C00), size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Diagnóstico informativo. Consulte um engenheiro agrônomo para avaliação definitiva.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
