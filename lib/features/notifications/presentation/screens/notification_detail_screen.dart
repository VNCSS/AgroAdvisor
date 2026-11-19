import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
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
      body: Column(
        children: [
          if (n.simulated)
            Container(
              width: double.infinity,
              color: Colors.amber,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'MODO DEMONSTRAÇÃO — DADOS SIMULADOS',
                style: TextStyle(color: Colors.black),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(n.title, style: Theme.of(context).textTheme.titleLarge),
                Text(DateFormatter.format(n.receivedAt)),
                Text(
                  'Área monitorada: ${n.region ?? 'não informada no registro antigo'}',
                ),
                Text('Origem: ${n.source ?? 'Histórico de notificações'}'),
                if (n.favorabilityIndex != null)
                  Text('Índice: ${n.favorabilityIndex}/100 — ${n.levelLabel}'),
                const SizedBox(height: 16),
                SelectableText(n.body),
                if (n.latitude != null && n.longitude != null)
                  Text('Coordenadas: ${n.latitude}, ${n.longitude}'),
                if (n.occurrenceId != null) Text('Registro: ${n.occurrenceId}'),
                Text(
                  'Apresentação local: ${n.deliveryStatus ?? 'não confirmada'}. '
                  'O registro não comprova que a notificação foi visualizada.',
                ),
                if (!n.simulated && n.occurrenceId != null)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OccurrenceRadarScreen(),
                      ),
                    ),
                    child: const Text('Abrir radar'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
