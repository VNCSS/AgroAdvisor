import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/domain/weather_result.dart';
import '../dashboard_format.dart';
import 'dashboard_section.dart';

/// Clima atual + previsão diária, a partir do [WeatherResult].
///
/// [result] null = carregando.
class WeatherSection extends StatelessWidget {
  final WeatherResult? result;
  final VoidCallback onRetry;
  final DateTime now;

  const WeatherSection({
    super.key,
    required this.result,
    required this.onRetry,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: 'Clima',
      child: switch (result) {
        null => const DashboardStateMessage.loading(
          title: 'Carregando previsão do tempo...',
        ),
        WeatherFailure(
          reason: WeatherFailureReason.invalidLocation,
          :final message,
        ) =>
          DashboardStateMessage(
            icon: Icons.location_off_outlined,
            title: 'Localização ausente',
            message: message,
            color: AppColors.riskMedium,
          ),
        WeatherFailure(:final message) => DashboardStateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Previsão indisponível',
          message: message,
          color: AppColors.riskMedium,
          onRetry: onRetry,
        ),
        WeatherSuccess(:final forecast, :final isStale) => _WeatherContent(
          forecast: forecast,
          isStale: isStale,
          now: now,
        ),
      },
    );
  }
}

class _WeatherContent extends StatelessWidget {
  final WeatherForecast forecast;
  final bool isStale;
  final DateTime now;

  const _WeatherContent({
    required this.forecast,
    required this.isStale,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final c = forecast.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStale) ...[
          DashboardStateMessage(
            icon: Icons.history_toggle_off_rounded,
            title: 'Exibindo última previsão obtida',
            message:
                'Não foi possível atualizar. Dados de '
                '${DashboardFormat.dayMonth(forecast.fetchedAt)} às '
                '${DashboardFormat.time(forecast.fetchedAt)}.',
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Condições atuais ──────────────────────────────────────────────
        DashboardCard(
          child: c == null
              ? Text(
                  'Condições atuais indisponíveis.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agora · ${DashboardFormat.time(c.time)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.thermostat_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            DashboardFormat.withUnit(c.temperature, '°C'),
                            style: AppTextStyles.headlineLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.water_drop_outlined,
                          label: 'Umidade',
                          value: DashboardFormat.withUnit(
                            c.relativeHumidity,
                            '%',
                            decimals: 0,
                          ),
                        ),
                        _Metric(
                          icon: Icons.umbrella_outlined,
                          label: 'Precipitação',
                          value: DashboardFormat.withUnit(
                            c.precipitation,
                            'mm',
                          ),
                        ),
                        _Metric(
                          icon: Icons.air_rounded,
                          label: 'Vento',
                          value: DashboardFormat.withUnit(c.windSpeed, 'km/h'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        // ── Previsão diária ───────────────────────────────────────────────
        if (forecast.daily.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          // Sem altura fixa: acompanha o tamanho de fonte do sistema.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, day) in forecast.daily.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  _DayCard(day: day, now: now),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),
        Text(
          'Dados meteorológicos: Open-Meteo.com · previsão de modelo, sujeita a incertezas.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Metric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DailyWeather day;
  final DateTime now;

  const _DayCard({required this.day, required this.now});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DashboardFormat.dayLabel(day.date, now),
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            DashboardFormat.dayMonth(day.date),
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DashboardFormat.withUnit(day.temperatureMax, '°', decimals: 0),
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            DashboardFormat.withUnit(day.temperatureMin, '°', decimals: 0),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                size: 12,
                color: AppColors.info,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  DashboardFormat.withUnit(day.precipitationSum, 'mm'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.info),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            day.precipitationProbabilityMax == null
                ? DashboardFormat.missing
                : '${DashboardFormat.number(day.precipitationProbabilityMax, decimals: 0)}% chance',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
