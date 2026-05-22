import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../services/auth_service.dart';
import '../../../occurrence/data/occurrence_repository.dart';
import '../../../occurrence/domain/occurrence_model.dart';
import '../../../occurrence/presentation/screens/diagnosis_screen.dart';
import '../../../occurrence/presentation/screens/occurrence_screen.dart';

/// Histórico de diagnósticos do produtor.
/// Filtra apenas as ocorrências do próprio usuário, ordenadas por data.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = OccurrenceRepository();
  int _filterIndex = 0;

  static const _filters = ['Todos', 'Doenças', 'Pragas', 'Solo'];

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              MediaQuery.of(context).padding.top + AppSpacing.md,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: Text('Histórico', style: AppTextStyles.headlineLarge),
          ),

          // ── Filtros ──────────────────────────────────────────────────────
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final selected = _filterIndex == i;
                return FilterChip(
                  label: Text(_filters[i]),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterIndex = i),
                  selectedColor: AppColors.primaryContainer,
                  backgroundColor: AppColors.surface,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Lista ────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<OccurrenceModel>>(
              stream: _repo.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mine = (snapshot.data ?? [])
                    .where((o) => o.reportedBy == userId)
                    .toList();

                if (mine.isEmpty) {
                  return EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nenhum diagnóstico ainda',
                    subtitle:
                        'Tire uma foto de uma planta para receber\num diagnóstico da IA.',
                    actionLabel: 'Diagnosticar agora',
                    onAction: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OccurrenceScreen())),
                  );
                }

                final diagnosed = mine.where((o) => o.diagnosis != null).toList();
                final pending = mine.where((o) => o.diagnosis == null).toList();
                final critical = diagnosed
                    .where((o) => o.diagnosis?.riskLevel.toLowerCase() == 'alto')
                    .length;

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // ── Resumo do período ──────────────────────────────────
                    _StatsCard(
                      total: mine.length,
                      critical: critical,
                      diagnosed: diagnosed.length,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (diagnosed.isNotEmpty) ...[
                      _SectionLabel('ÚLTIMOS 30 DIAS'),
                      const SizedBox(height: AppSpacing.sm),
                      ...diagnosed.map((o) => _HistoryItem(occurrence: o)),
                    ],

                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SectionLabel('AGUARDANDO ANÁLISE'),
                      const SizedBox(height: AppSpacing.sm),
                      ...pending.map((o) => _HistoryItem(occurrence: o)),
                    ],

                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int total;
  final int critical;
  final int diagnosed;
  const _StatsCard({required this.total, required this.critical, required this.diagnosed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          _Stat(value: '$total', label: 'Diagnósticos', color: AppColors.textPrimary),
          _VDivider(),
          _Stat(value: '$critical', label: 'Críticos', color: AppColors.riskHigh),
          _VDivider(),
          _Stat(value: '$diagnosed', label: 'Analisados', color: AppColors.primary),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headlineMedium.copyWith(color: color)),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelSmall
          .copyWith(color: AppColors.textHint, letterSpacing: 0.8),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final OccurrenceModel occurrence;
  const _HistoryItem({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final d = occurrence.diagnosis;
    final hasD = d != null;

    final (iconColor, iconBg) = switch (d?.riskLevel.toLowerCase()) {
      'alto'             => (AppColors.riskHigh,   AppColors.riskHighContainer),
      'médio' || 'medio' => (AppColors.riskMedium, AppColors.riskMediumContainer),
      'baixo'            => (AppColors.riskLow,    AppColors.riskLowContainer),
      _                  => (AppColors.textHint,   AppColors.surfaceVariant),
    };

    return GestureDetector(
      onTap: hasD
          ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DiagnosisScreen(diagnosis: d)))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            // Ícone
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                hasD ? Icons.eco_rounded : Icons.hourglass_empty_rounded,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Informações
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d?.pestName ?? 'Aguardando análise...',
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormatter.format(occurrence.timestamp),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Badge de confiança
            if (hasD) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(d.confidenceScore * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.titleSmall
                        .copyWith(color: iconColor, fontWeight: FontWeight.w700),
                  ),
                  Text('confiança',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
