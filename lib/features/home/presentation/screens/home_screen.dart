import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../services/auth_service.dart';
import '../../../occurrence/data/occurrence_repository.dart';
import '../../../occurrence/domain/occurrence_model.dart';
import '../../../occurrence/presentation/screens/occurrence_screen.dart';
import '../../../occurrence/presentation/screens/occurrence_radar_screen.dart';
import '../../../occurrence/presentation/widgets/occurrence_card.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';

/// Tela inicial — painel do produtor.
/// UX: ação principal evidente, informações contextuais no topo, radar recente embaixo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  static String _date() {
    const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    const meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final now = DateTime.now();
    return '${dias[now.weekday % 7]} · ${now.day} ${meses[now.month - 1]}';
  }

  static String _displayName(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._\-]'), ' ');
    final parts = local.trim().split(' ');
    final first = parts.isNotEmpty ? parts.first : local;
    if (first.isEmpty) return email;
    return '${first[0].toUpperCase()}${first.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final email = auth.currentUser?.email ?? '';
    final userId = auth.currentUser?.uid ?? '';
    final repo = OccurrenceRepository();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<OccurrenceModel>>(
        stream: repo.watchAll(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final mine = all.where((o) => o.reportedBy == userId).toList();
          final diagCount = mine.where((o) => o.diagnosis != null).length;
          final recent = all.take(3).toList();
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(
                  greeting: _greeting(),
                  name: _displayName(email),
                  date: _date(),
                ),
              ),

              // ── CTA principal ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                  vertical: AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: _DiagnoseButton(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OccurrenceScreen())),
                  ),
                ),
              ),

              // ── Cards rápidos ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickCard(
                          icon: Icons.radar_rounded,
                          iconColor: AppColors.riskMedium,
                          iconBg: AppColors.riskMediumContainer,
                          title: 'Radar de pragas',
                          subtitle: all.isNotEmpty
                              ? '${all.length > 8 ? 8 : all.length} alertas próximos'
                              : 'Sem alertas',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const OccurrenceRadarScreen())),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _QuickCard(
                          icon: Icons.history_rounded,
                          iconColor: AppColors.primary,
                          iconBg: AppColors.primaryContainer,
                          title: 'Histórico',
                          subtitle: diagCount > 0 ? '$diagCount diagnósticos' : 'Nenhum ainda',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Seção "Próximo a você" ────────────────────────────────────
              if (!loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, AppSpacing.lg,
                      AppSpacing.screenH, AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Próximo a você', style: AppTextStyles.headlineSmall),
                        TextButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const OccurrenceRadarScreen())),
                          child: const Text('Ver mapa →'),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Lista de ocorrências recentes ────────────────────────────
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (recent.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.eco_rounded,
                    title: 'Tudo tranquilo por aqui!',
                    subtitle: 'Nenhuma ocorrência registrada.\nSeja o primeiro a reportar.',
                    actionLabel: 'Diagnosticar agora',
                    onAction: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OccurrenceScreen())),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  sliver: SliverList.separated(
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (ctx, i) =>
                        OccurrenceCard(occurrence: recent[i], isAnalyzingBySystem: false),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting;
  final String name;
  final String date;

  const _Header({required this.greeting, required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('$greeting, $name',
                    style: AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _NotifButton(),
        ],
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        icon: const Icon(Icons.notifications_outlined, size: 22),
        color: AppColors.textSecondary,
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
      ),
    );
  }
}

class _DiagnoseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DiagnoseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF3D8B40)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Diagnosticar agora',
                      style: AppTextStyles.titleLarge
                          .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('Tire uma foto — IA identifica em segundos',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title,
                style: AppTextStyles.titleSmall
                    .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
