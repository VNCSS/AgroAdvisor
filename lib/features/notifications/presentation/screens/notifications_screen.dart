import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../services/auth_service.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository();

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
          TextButton(
            onPressed: () => _markAllRead(userId),
            child: Text(
              'Marcar todas',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: _repo.watchForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar notificações:\n${snapshot.error}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 56, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text('Nenhuma notificação ainda',
                      style: AppTextStyles.titleSmall
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Quando uma praga for detectada\nna sua região, você será avisado.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _NotifCard(
              notif: items[i],
              onTap: () => _repo.markRead(userId, items[i].id),
            ),
          );
        },
      ),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread ? AppColors.riskHighContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: unread ? AppColors.riskHigh.withValues(alpha: 0.3) : AppColors.border,
            width: 0.8,
          ),
        ),
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
                Icons.pest_control_rounded,
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
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
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
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormatter.format(notif.receivedAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
