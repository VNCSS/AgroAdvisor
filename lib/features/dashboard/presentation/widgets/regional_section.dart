import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../occurrence/presentation/widgets/occurrence_card.dart';
import '../../domain/regional_summary.dart';
import '../dashboard_format.dart';
import 'dashboard_section.dart';

/// Indicadores, organismos, tendência e ocorrências recentes da região.
/// Todos os números vêm das ocorrências reais do Firestore.
class RegionalSection extends StatelessWidget {
  final RegionalSummary summary;
  final DateTime now;

  const RegionalSection({super.key, required this.summary, required this.now});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final scope =
        'Raio de ${DashboardFormat.number(s.radiusKm, decimals: 0)} km · '
        'últimos ${s.windowDays} dias';

    if (s.isEmpty) {
      return DashboardSection(
        title: 'Região',
        subtitle: scope,
        child: const DashboardStateMessage(
          icon: Icons.eco_outlined,
          title: 'Nenhuma ocorrência registrada na região',
          message: 'Não há registros no raio e no período considerados.',
          color: AppColors.riskLow,
        ),
      );
    }

    return Column(
      children: [
        // ── Indicadores ─────────────────────────────────────────────────────
        DashboardSection(
          title: 'Região',
          subtitle: scope,
          child: Column(
            children: [
              Row(
                children: [
                  _Indicator(
                    value: '${s.totalInRadius}',
                    label: 'Ocorrências registradas',
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Indicator(
                    value: '${s.withProblem}',
                    label: 'Com problema identificado',
                    color: s.withProblem > 0
                        ? AppColors.riskMedium
                        : AppColors.riskLow,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Indicator(
                    value: '${s.pendingAnalysis}',
                    label: 'Aguardando análise',
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Indicator(
                    value: s.nearestProblemKm == null
                        ? DashboardFormat.missing
                        : DashboardFormat.distance(s.nearestProblemKm!),
                    label: 'Problema mais próximo',
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${s.ownCount} registrada(s) por você · '
                  '${s.withoutProblem} sem problema identificado ou inconclusiva(s)',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Organismos ──────────────────────────────────────────────────────
        DashboardSection(
          title: 'Organismos identificados',
          subtitle: 'Nomes conforme o diagnóstico da IA',
          child: s.organisms.isEmpty
              ? const DashboardStateMessage(
                  icon: Icons.search_off_rounded,
                  title: 'Nenhum organismo identificado no período',
                )
              : DashboardCard(
                  child: Column(
                    children: [
                      for (final org in s.organisms)
                        _OrganismRow(
                          organism: org,
                          maxCount: s.organisms.first.count,
                          now: now,
                        ),
                    ],
                  ),
                ),
        ),

        // ── Tendência semanal ───────────────────────────────────────────────
        if (s.withProblem > 0)
          DashboardSection(
            title: 'Tendência',
            subtitle: 'Ocorrências com problema por semana (registros no app)',
            child: DashboardCard(child: _WeeklyBars(weeks: s.weekly)),
          ),

        // ── Ocorrências recentes ────────────────────────────────────────────
        if (s.recent.isNotEmpty)
          DashboardSection(
            title: 'Ocorrências recentes',
            child: Column(
              children: [
                for (final item in s.recent) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 13,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'a ${DashboardFormat.distance(item.distanceKm)} da propriedade',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OccurrenceCard(
                    key: ValueKey(item.occurrence.id),
                    occurrence: item.occurrence,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Indicator({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DashboardCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganismRow extends StatelessWidget {
  final OrganismCount organism;
  final int maxCount;
  final DateTime now;

  const _OrganismRow({
    required this.organism,
    required this.maxCount,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  organism.name,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${organism.count}×',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.riskMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: maxCount == 0 ? 0 : organism.count / maxCount,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.riskMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mais próximo a ${DashboardFormat.distance(organism.nearestKm)} · '
            'último registro ${DashboardFormat.daysAgo(organism.lastSeen, now)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  final List<WeeklyCount> weeks;

  const _WeeklyBars({required this.weeks});

  static const double _maxBarHeight = 72;

  @override
  Widget build(BuildContext context) {
    final max = weeks.fold<int>(0, (m, w) => w.count > m ? w.count : m);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final w in weeks)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${w.count}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: max == 0
                        ? 2
                        : 2 + (_maxBarHeight - 2) * w.count / max,
                    decoration: BoxDecoration(
                      color: w.count == 0
                          ? AppColors.border
                          : AppColors.riskMedium,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DashboardFormat.dayMonth(w.start),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
