import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

const alertScreenPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenH,
  AppSpacing.md,
  AppSpacing.screenH,
  AppSpacing.lg,
);

class AlertSection extends StatelessWidget {
  final List<Widget> children;

  const AlertSection({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        spacing: AppSpacing.sm,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class AlertDemoBanner extends StatelessWidget {
  const AlertDemoBanner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenH,
      AppSpacing.md,
      AppSpacing.screenH,
      0,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.riskMediumContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.riskMedium.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppColors.riskMedium),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'MODO DEMONSTRAÇÃO — DADOS SIMULADOS',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Route<void> alertScreenRoute(WidgetBuilder builder) => PageRouteBuilder<void>(
  pageBuilder: (context, _, _) => builder(context),
  transitionsBuilder: (context, animation, _, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: child,
    );
  },
);

String localAlertStatusLabel(String status) => switch (status) {
  'localSubmitted' => 'Notificação encaminhada ao sistema.',
  'permissionDenied' =>
    'Notificações bloqueadas nas configurações do aparelho.',
  'sessionEnded' => 'Sessão encerrada.',
  'localFailed' => 'Falha ao exibir a notificação.',
  'ignored' => 'Notificação indisponível.',
  _ => status,
};
