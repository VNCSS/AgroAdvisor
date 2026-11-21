import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/alert_screen_widgets.dart';
import '../../../occurrence/presentation/screens/occurrence_radar_screen.dart';
import '../../domain/app_notification_model.dart';

class NotificationDetailScreen extends StatelessWidget {
  final AppNotificationModel notification;
  const NotificationDetailScreen({super.key, required this.notification});
  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          n.isPreventive ? 'Alerta preventivo' : 'Ocorrência próxima',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (n.simulated) const AlertDemoBanner(),
            Expanded(
              child: ListView(
                padding: alertScreenPadding,
                children: [
                  AlertSection(
                    children: [
                      Text(
                        n.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(DateFormatter.format(n.receivedAt)),
                      Text(
                        'Área monitorada: ${n.region ?? 'não informada no registro antigo'}',
                      ),
                      Text(
                        'Origem: ${n.source ?? 'Histórico de notificações'}',
                      ),
                      if (n.favorabilityIndex != null)
                        Text(
                          'Índice: ${n.favorabilityIndex}/100 — ${n.levelLabel}',
                        ),
                      const Divider(height: AppSpacing.md),
                      SelectableText(n.body),
                      if (n.latitude != null && n.longitude != null)
                        Text('Coordenadas: ${n.latitude}, ${n.longitude}'),
                      if (n.occurrenceId != null)
                        Text('Registro: ${n.occurrenceId}'),
                      Text(
                        'Apresentação local: ${localAlertStatusLabel(n.deliveryStatus ?? 'não confirmada')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Text(
                        'O registro não comprova que a notificação foi visualizada.',
                      ),
                    ],
                  ),
                  if (!n.simulated && n.occurrenceId != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OccurrenceRadarScreen(),
                        ),
                      ),
                      child: const Text('Abrir radar'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
