import 'package:flutter/material.dart';
import '../../domain/intelligent_alert.dart';
import '../../domain/app_notification_model.dart';
import 'notification_detail_screen.dart';

/// Sem repositório nem escrita: o emissor fornecido só apresenta no aparelho.
class NearbyDemoScreen extends StatefulWidget {
  final double radiusKm;
  final bool enabled;
  final Future<String> Function(IntelligentAlert) showLocal;
  const NearbyDemoScreen({
    super.key,
    required this.radiusKm,
    required this.enabled,
    required this.showLocal,
  });
  @override
  State<NearbyDemoScreen> createState() => _NearbyDemoScreenState();
}

class _NearbyDemoScreenState extends State<NearbyDemoScreen> {
  final _distance = TextEditingController(text: '8');
  String _pest = 'Ocorrência fictícia A';
  IntelligentAlert? _alert;
  String? _status;
  bool _busy = false;
  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  Future<void> _simulate() async {
    final distance = double.tryParse(_distance.text.replaceAll(',', '.'));
    setState(() {
      _alert = null;
      _status = null;
    });
    if (distance == null || !distance.isFinite || distance < 0) {
      setState(() => _status = 'Informe uma distância válida, em km.');
      return;
    }
    if (!widget.enabled || !withinMonitoringRadius(distance, widget.radiusKm)) {
      setState(
        () => _status = !widget.enabled
            ? 'Notificações desativadas nas preferências.'
            : 'Fora do raio: nenhuma notificação gerada.',
      );
      return;
    }
    final alert = IntelligentAlert(
      scope: 'demo-nearby',
      type: 'nearby',
      title: 'Ocorrência próxima — $_pest',
      body:
          'DADOS SIMULADOS: ocorrência fictícia '
          'a ${distance.toStringAsFixed(1)} km; raio configurado ${widget.radiusKm} km.',
      region: 'Área fictícia de demonstração',
      source: 'Simulação local',
      generatedAt: DateTime.now(),
      simulated: true,
    );
    setState(() {
      _alert = alert;
      _busy = true;
    });
    String status;
    try {
      status = await widget.showLocal(alert);
    } catch (_) {
      status = 'localFailed';
    }
    if (mounted) {
      setState(() {
        _status = 'Apresentação local: $status';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demonstrar ocorrência próxima')),
    body: Column(
      children: [
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
              Text(
                'Raio configurado do usuário: ${widget.radiusKm.toStringAsFixed(1)} km',
              ),
              DropdownButton<String>(
                value: _pest,
                isExpanded: true,
                items: [
                  for (final name in [
                    'Ocorrência fictícia A',
                    'Ocorrência fictícia B',
                  ])
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _pest = v;
                      _alert = null;
                      _status = null;
                    });
                  }
                },
              ),
              TextField(
                controller: _distance,
                decoration: const InputDecoration(
                  labelText: 'Distância simulada (km)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {
                  _alert = null;
                  _status = null;
                }),
              ),
              FilledButton(
                onPressed: _busy ? null : _simulate,
                child: const Text('Simular ocorrência'),
              ),
              if (_status != null) Text(_status!),
              if (_alert case final alert?) ...[
                Text(alert.title),
                Text(alert.body),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotificationDetailScreen(
                        notification: AppNotificationModel.fromMap(
                          alert.toMap(),
                          alert.historyId,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Abrir detalhes demonstrativos'),
                ),
              ],
              const Text(
                'A simulação não grava ocorrências nem histórico real e não envia push a outros usuários.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
