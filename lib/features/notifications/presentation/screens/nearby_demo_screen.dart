import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/alert_screen_widgets.dart';
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
        _status = localAlertStatusLabel(status);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = _alert;
    return Scaffold(
      appBar: AppBar(title: const Text('Ocorrência próxima')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const AlertDemoBanner(),
            Expanded(
              child: ListView(
                padding: alertScreenPadding,
                children: [
                  AlertSection(
                    children: [
                      Text(
                        'Simular ocorrência próxima',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Raio configurado: ${widget.radiusKm.toStringAsFixed(1)} km',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<String>(
                        initialValue: _pest,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ocorrência',
                        ),
                        items: [
                          for (final name in [
                            'Ocorrência fictícia A',
                            'Ocorrência fictícia B',
                          ])
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _pest = value;
                            _alert = null;
                            _status = null;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs),
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
                      const SizedBox(height: AppSpacing.xs),
                      FilledButton.icon(
                        onPressed: _busy ? null : _simulate,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _busy ? 'Simulando…' : 'Simular ocorrência',
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    alignment: Alignment.topCenter,
                    child: _status == null && alert == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: AlertSection(
                              children: [
                                if (_status != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _status!,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                if (alert != null) ...[
                                  Text(
                                    alert.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(alert.body),
                                  OutlinedButton(
                                    onPressed: () => Navigator.of(context).push(
                                      alertScreenRoute(
                                        (_) => NotificationDetailScreen(
                                          notification:
                                              AppNotificationModel.fromMap(
                                                alert.toMap(),
                                                alert.historyId,
                                              ),
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Abrir detalhes demonstrativos',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'A simulação não grava ocorrências nem histórico real e não envia push a outros usuários.',
                    style: theme.textTheme.bodySmall,
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
