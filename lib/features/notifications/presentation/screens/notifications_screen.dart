import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/alert_screen_widgets.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/database_service.dart';
import '../../../../services/nearby_alert_service.dart';
import '../../../../services/notification_service.dart';
import '../../../favorability/data/environmental_alert_service.dart';
import '../../../settings/domain/user_settings_model.dart';
import 'nearby_demo_screen.dart';
import 'notification_detail_screen.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  Future<void> _check({bool force = false}) async {
    if (_checking) return;
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    setState(() => _checking = true);
    final results = await Future.wait([
      context.read<NearbyAlertService>().check(uid),
      context.read<EnvironmentalAlertService>().run(uid, force: force),
    ]);
    if (!mounted) return;
    setState(() => _checking = false);
    final errors = results.expand((e) => e).toList();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errors.join('\n'))));
    }
  }

  Future<void> _demo() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    try {
      final settings =
          await context.read<DatabaseService>().getUserSettings(uid) ??
          UserSettingsModel(userId: uid);
      if (!mounted) return;
      final notifications = context.read<NotificationService>();
      Navigator.of(context).push(
        alertScreenRoute(
          (_) => NearbyDemoScreen(
            radiusKm: settings.alertRadiusKm,
            enabled: settings.notificationsEnabled,
            showLocal: (alert) => notifications.showAlert(uid, alert),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar o raio configurado. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _markAllRead(String userId) async {
    await _repo.markAllRead(userId);
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como lidas',
            onPressed: () => _markAllRead(userId),
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<AppNotificationModel>>(
          stream: _repo.watchForUser(userId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: alertScreenPadding.copyWith(bottom: AppSpacing.sm),
                  sliver: SliverToBoxAdapter(
                    child: AlertSection(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.science_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Demonstrar ocorrência próxima'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _demo,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _checking
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.primary,
                                ),
                          title: Text(
                            _checking
                                ? 'Verificando alertas…'
                                : 'Verificar alertas agora',
                          ),
                          onTap: _checking ? null : () => _check(force: true),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: alertScreenPadding.copyWith(top: AppSpacing.sm),
                  sliver:
                      snapshot.hasError ||
                          snapshot.connectionState == ConnectionState.waiting ||
                          items.isEmpty
                      ? SliverToBoxAdapter(child: _historyStatus(snapshot))
                      : SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) {
                            final notification = items[i];
                            return _NotifCard(
                              notif: notification,
                              onTap: () async {
                                await _repo.markRead(userId, notification.id);
                                if (!context.mounted) return;
                                Navigator.of(context).push(
                                  alertScreenRoute(
                                    (_) => NotificationDetailScreen(
                                      notification: notification,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _historyStatus(AsyncSnapshot<List<AppNotificationModel>> snapshot) {
    if (snapshot.hasError) {
      return AlertSection(
        children: [
          Text(
            'Erro ao carregar notificações:\n${snapshot.error}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    return AlertSection(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.notifications_none_rounded),
        ),
        Text(
          'Nenhuma notificação ainda',
          style: AppTextStyles.titleSmall,
          textAlign: TextAlign.center,
        ),
        Text(
          'A verificação ocorre ao abrir ou retomar o app e ao acessar os alertas. Requer conexão.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Card de notificação ───────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotificationModel notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notif.read;

    return Card(
      color: unread ? AppColors.riskHighContainer : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: unread
              ? AppColors.riskHigh.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread
                      ? AppColors.riskHigh.withValues(alpha: 0.15)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  // Alertas preventivos (favorabilidade) têm ícone próprio;
                  // os de proximidade mantêm o ícone original.
                  notif.isPreventive
                      ? Icons.thermostat_rounded
                      : Icons.pest_control_rounded,
                  color: unread ? AppColors.riskHigh : AppColors.textHint,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.riskHigh,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${notif.simulated ? 'DEMONSTRAÇÃO · ' : ''}${notif.isPreventive ? 'Favorabilidade experimental' : 'Ocorrência próxima'}'
                      '${notif.region == null ? '' : ' · ${notif.region}'}',
                      style: AppTextStyles.caption,
                    ),
                    Text(
                      DateFormatter.format(notif.receivedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
