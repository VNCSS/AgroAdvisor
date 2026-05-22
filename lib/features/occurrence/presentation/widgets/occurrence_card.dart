import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../services/diagnosis_service.dart';
import '../../domain/occurrence_model.dart';
import '../screens/diagnosis_screen.dart';

/// Card de uma ocorrência no feed — thumbnail + localização + badge de risco.
class OccurrenceCard extends StatefulWidget {
  final OccurrenceModel occurrence;
  final bool isAnalyzingBySystem;

  const OccurrenceCard({
    super.key,
    required this.occurrence,
    this.isAnalyzingBySystem = false,
  });

  @override
  State<OccurrenceCard> createState() => _OccurrenceCardState();
}

class _OccurrenceCardState extends State<OccurrenceCard> {
  bool _analyzing = false;

  Future<void> _analyzeManually() async {
    setState(() => _analyzing = true);
    String? err;
    try {
      final result = await context.read<DiagnosisService>().analyzeAndSave(
            widget.occurrence.id,
            widget.occurrence.imageBase64,
            onError: (e) => err = e,
          );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Erro desconhecido na análise.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 10),
          ),
        );
      } else {
        dev.log('[OccurrenceCard] análise manual: ${result.pestName}');
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.occurrence;
    final isAnalyzing = widget.isAnalyzingBySystem || _analyzing;
    final hasDiag = o.diagnosis != null;

    return GestureDetector(
      onTap: hasDiag
          ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DiagnosisScreen(diagnosis: o.diagnosis!)))
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────────────────────
            SizedBox(
              width: 96,
              height: 96,
              child: Image.memory(
                base64Decode(o.imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textHint, size: 32),
                ),
              ),
            ),

            // ── Conteúdo ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Localização
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${o.latitude.toStringAsFixed(4)}, ${o.longitude.toStringAsFixed(4)}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Timestamp
                    Text(
                      DateFormatter.format(o.timestamp),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Badge
                    _Badge(
                      isAnalyzing: isAnalyzing,
                      hasDiag: hasDiag,
                      diagnosis: o.diagnosis,
                      onAnalyze: _analyzeManually,
                    ),
                  ],
                ),
              ),
            ),

            // Chevron
            if (hasDiag)
              const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Badge de diagnóstico ──────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final bool isAnalyzing;
  final bool hasDiag;
  final dynamic diagnosis; // DiagnosisModel?
  final VoidCallback onAnalyze;

  const _Badge({
    required this.isAnalyzing,
    required this.hasDiag,
    required this.diagnosis,
    required this.onAnalyze,
  });

  static Color _riskFg(String level) => switch (level.toLowerCase()) {
        'alto'             => AppColors.riskHigh,
        'médio' || 'medio' => AppColors.riskMedium,
        'baixo'            => AppColors.riskLow,
        _                  => AppColors.textHint,
      };

  static Color _riskBg(String level) => switch (level.toLowerCase()) {
        'alto'             => AppColors.riskHighContainer,
        'médio' || 'medio' => AppColors.riskMediumContainer,
        'baixo'            => AppColors.riskLowContainer,
        _                  => AppColors.surfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Analisando...',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );
    }

    if (hasDiag && diagnosis != null) {
      final fg = _riskFg(diagnosis.riskLevel as String);
      final bg = _riskBg(diagnosis.riskLevel as String);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, size: 12, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                diagnosis.pestName as String,
                style: AppTextStyles.labelSmall
                    .copyWith(color: fg, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onAnalyze,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_fix_high_rounded,
                size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('Analisar com IA',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
