import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/alert_screen_widgets.dart';
import '../domain/experimental_profile.dart';
import '../domain/favorability_config.dart';
import '../domain/favorability_engine.dart';
import '../domain/favorability_result.dart';

/// O carregador operacional só é chamado sob ação explícita fora da demo.
class FavorabilityScreen extends StatefulWidget {
  final Future<ExperimentalAssessment> Function() loadOperational;
  final Future<String> Function(ExperimentalAssessment)?
  demonstrateNotification;
  const FavorabilityScreen({
    super.key,
    required this.loadOperational,
    this.demonstrateNotification,
  });

  @override
  State<FavorabilityScreen> createState() => _FavorabilityScreenState();
}

class _FavorabilityScreenState extends State<FavorabilityScreen> {
  final _engine = FavorabilityEngine();
  final _temperature = TextEditingController(text: '15');
  final _humidity = TextEditingController(text: '50');
  final _rain = TextEditingController(text: '0');
  bool _demo = false, _regional = false, _loading = false;
  AttentionLevel? _preset = AttentionLevel.low;
  ExperimentalAssessment? _result;
  String? _error;
  int _generation = 0;

  @override
  void dispose() {
    _temperature.dispose();
    _humidity.dispose();
    _rain.dispose();
    super.dispose();
  }

  void _toggle(bool value) => setState(() {
    _generation++; // Invalida respostas operacionais em voo.
    _demo = value;
    _loading = false;
    _result = null;
    _error = null;
    _select(AttentionLevel.low);
  });

  void _select(AttentionLevel level) {
    final input = DemonstrationInput.presets[level]!;
    _preset = level;
    _temperature.text = '${input.temperature}';
    _humidity.text = '${input.humidity}';
    _rain.text = '${input.precipitation}';
    _regional = input.regionalOccurrences;
    _result = null;
    _error = null;
  }

  Future<void> _evaluate() async {
    final generation = ++_generation;
    setState(() {
      _result = null;
      _error = null;
      _loading = true;
    });
    try {
      final result = _demo
          ? _engine.demonstrate(
              DemonstrationInput(
                double.tryParse(_temperature.text.replaceAll(',', '.')) ??
                    double.nan,
                double.tryParse(_humidity.text.replaceAll(',', '.')) ??
                    double.nan,
                double.tryParse(_rain.text.replaceAll(',', '.')) ?? double.nan,
                _regional,
              ),
              DateTime.now(),
            )
          : await widget.loadOperational();
      if (mounted && generation == _generation) {
        setState(() => _result = result);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Não foi possível carregar os dados. Tente novamente.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _edited() => setState(() {
    _preset = null;
    _result = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Favorabilidade experimental')),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_demo) const AlertDemoBanner(),
          Expanded(
            child: ListView(
              padding: alertScreenPadding,
              children: [
                AlertSection(
                  children: [
                    Text(
                      ExperimentalProfile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      ExperimentalProfile.disclaimer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Modo demonstração'),
                      value: _demo,
                      onChanged: _toggle,
                    ),
                    if (!_demo)
                      Text(
                        'Modo operacional: Open-Meteo e registros regionais reais. '
                        'Perfil genérico experimental; não avalia uma espécie de praga.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_demo) ...[
                  AlertSection(
                    children: [
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Cenário'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AttentionLevel>(
                            isDense: true,
                            value: _preset,
                            hint: const Text('Valores personalizados'),
                            isExpanded: true,
                            items: [
                              for (final level in AttentionLevel.values)
                                DropdownMenuItem(
                                  value: level,
                                  child: Text(level.label),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _select(v));
                            },
                          ),
                        ),
                      ),
                      _field(_temperature, 'Temperatura constante (°C)'),
                      _field(_humidity, 'Umidade constante (%)'),
                      _field(_rain, 'Precipitação acumulada em 72 h (mm)'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Simular ocorrências regionais'),
                        subtitle: const Text(
                          'Presença = 5 registros independentes, atuais, a 0 km; ausência = 0.',
                        ),
                        value: _regional,
                        onChanged: (v) {
                          _edited();
                          setState(() => _regional = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : _evaluate,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(_loading ? 'Avaliando…' : 'Executar avaliação'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AlertSection(
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_result case final result?) ...[
                  const SizedBox(height: AppSpacing.md),
                  _resultCard(result),
                ],
                if (_demo &&
                    _result?.simulated == true &&
                    _result?.level != null &&
                    _result!.level!.index >= AttentionLevel.high.index &&
                    widget.demonstrateNotification != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () async {
                      final result = _result!;
                      String status;
                      try {
                        status = await widget.demonstrateNotification!(result);
                      } catch (_) {
                        status = 'localFailed';
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localAlertStatusLabel(status))),
                      );
                    },
                    child: const Text(
                      'Gerar notificação local demonstrativa',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: (_) => _edited(),
    ),
  );

  Widget _resultCard(ExperimentalAssessment result) {
    final environmental = result.environmental.score;
    final regional = result.regional;
    final theme = Theme.of(context);
    final levelColor = switch (result.level) {
      AttentionLevel.high || AttentionLevel.veryHigh => AppColors.riskHigh,
      AttentionLevel.moderate => AppColors.riskMedium,
      AttentionLevel.low => AppColors.riskLow,
      null => AppColors.textSecondary,
    };
    return AlertSection(
      children: [
        Text(
          result.simulated
              ? 'Resultado simulado e experimental'
              : 'Resultado experimental com dados reais',
          style: theme.textTheme.titleMedium,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: levelColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              result.index == null
                  ? 'Dados insuficientes'
                  : '${result.index}/100 — ${result.level!.label}',
              style: theme.textTheme.headlineSmall?.copyWith(color: levelColor),
            ),
          ),
        ),
        if (result.index != null)
          Text(
            '${result.level!.headline}: as condições avaliadas '
            'atendem aos critérios indicados abaixo no modelo experimental.',
          ),
        Text(
          'Contribuição ambiental (peso 60%): ${environmental == null ? 'indisponível' : '${(60 * environmental).toStringAsFixed(1)} pontos'}',
        ),
        Text(
          'Contribuição regional (peso 40%): ${regional == null ? 'indisponível' : '${(40 * regional.score).toStringAsFixed(1)} pontos; ${regional.count} registros'}',
        ),
        const Divider(height: AppSpacing.md),
        Text('Fatores avaliados', style: theme.textTheme.titleSmall),
        Text(
          'Pontuação positiva aumenta o índice.',
          style: theme.textTheme.bodySmall,
        ),
        for (final factor in result.environmental.factors)
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(factor.kind.label, style: theme.textTheme.titleSmall),
                  Text(
                    '${factor.status.label}'
                    '${factor.score == null ? '' : ' (${(factor.score! * 100).round()}/100)'}',
                  ),
                  Text(factor.detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        for (final warning in result.warnings)
          Text(warning, style: theme.textTheme.bodySmall),
        const Divider(height: AppSpacing.md),
        Text('Dados da avaliação', style: theme.textTheme.titleSmall),
        Text('Avaliado em: ${result.generatedAt.toLocal()}'),
        Text(
          'Origem: ${result.simulated ? 'entradas simuladas locais' : 'Open-Meteo + registros Firestore; raio 50 km, últimos 28 dias'}',
        ),
        if (result.fetchedAt != null)
          Text('Clima obtido em: ${result.fetchedAt}'),
        Text(ExperimentalProfile.disclaimer, style: theme.textTheme.bodySmall),
        Text(favorabilityIndexDisclaimer, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
