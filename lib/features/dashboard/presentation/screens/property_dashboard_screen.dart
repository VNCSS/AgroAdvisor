import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../services/auth_service.dart';
import '../../../occurrence/data/occurrence_repository.dart';
import '../../../property/domain/property_model.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../weather/data/weather_repository.dart';
import '../../../weather/domain/weather_result.dart';
import '../../domain/regional_summary.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/regional_section.dart';
import '../widgets/weather_section.dart';

/// Painel de inteligência da propriedade — somente leitura.
///
/// Combina a previsão do Open-Meteo (coordenadas cadastradas da propriedade)
/// com as ocorrências reais registradas no raio de alerta do usuário.
class PropertyDashboardScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDashboardScreen({super.key, required this.property});

  @override
  State<PropertyDashboardScreen> createState() =>
      _PropertyDashboardScreenState();
}

class _PropertyDashboardScreenState extends State<PropertyDashboardScreen> {
  final _occurrenceRepo = OccurrenceRepository();
  final _settingsRepo = SettingsRepository();

  late final bool _hasValidLocation;
  late DateTime _now;

  WeatherResult? _weather; // null = carregando
  Future<RegionalSummary>? _regional; // null = localização inválida

  PropertyModel get _property => widget.property;

  @override
  void initState() {
    super.initState();
    _hasValidLocation = WeatherRepository.isValidCoordinate(
      _property.latitude,
      _property.longitude,
    );
    _now = DateTime.now();
    _loadWeather();
    _loadRegional();
  }

  Future<void> _loadWeather({bool force = false}) async {
    setState(() => _weather = null);
    final result = await context
        .read<WeatherRepository>()
        .getForecastForProperty(_property, forceRefresh: force);
    if (mounted) setState(() => _weather = result);
  }

  Future<void> _loadRegional() {
    if (!_hasValidLocation) return Future.value();
    final future = _buildRegional();
    // Corpo em bloco: com `=>` o callback devolveria o Future atribuído,
    // e o setState recusa callbacks que retornam Future.
    setState(() {
      _regional = future;
    });
    // Erros são exibidos pelo FutureBuilder; aqui apenas evita erro não tratado.
    return future.then((_) {}, onError: (_) {});
  }

  Future<RegionalSummary> _buildRegional() async {
    final userId = context.read<AuthService>().currentUser?.uid ?? '';
    try {
      final settings = userId.isEmpty ? null : await _settingsRepo.get(userId);
      final radiusKm =
          settings?.alertRadiusKm ?? AppConstants.alertRadiusDefault;
      final since = _now.subtract(
        const Duration(days: AppConstants.dashboardWindowDays),
      );
      final occurrences = await _occurrenceRepo.getSince(since);

      return RegionalSummary.build(
        occurrences: occurrences,
        latitude: _property.latitude,
        longitude: _property.longitude,
        radiusKm: radiusKm,
        windowDays: AppConstants.dashboardWindowDays,
        now: _now,
        userId: userId,
        recentLimit: AppConstants.dashboardRecentCount,
        organismLimit: AppConstants.dashboardTopOrganisms,
      );
    } catch (e, st) {
      dev.log(
        '[Dashboard] falha ao carregar ocorrências',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _refresh() async {
    _now = DateTime.now();
    await Future.wait([_loadWeather(force: true), _loadRegional()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Painel da propriedade')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _PropertyHeader(
              property: _property,
              hasValidLocation: _hasValidLocation,
            ),
            WeatherSection(
              result: _weather,
              now: _now,
              onRetry: () => _loadWeather(force: true),
            ),
            _buildRegionalSection(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalSection() {
    if (!_hasValidLocation) {
      return const DashboardSection(
        title: 'Região',
        child: DashboardStateMessage(
          icon: Icons.location_off_outlined,
          title: 'Localização ausente',
          message:
              'Sem coordenadas válidas não é possível calcular a distância '
              'das ocorrências. Revise o cadastro da propriedade no Perfil.',
          color: AppColors.riskMedium,
        ),
      );
    }

    return FutureBuilder<RegionalSummary>(
      future: _regional,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const DashboardSection(
            title: 'Região',
            child: DashboardStateMessage.loading(
              title: 'Carregando ocorrências da região...',
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return DashboardSection(
            title: 'Região',
            child: DashboardStateMessage(
              icon: Icons.error_outline_rounded,
              title: 'Não foi possível carregar as ocorrências',
              message: 'Verifique sua conexão e tente novamente.',
              color: AppColors.error,
              onRetry: _loadRegional,
            ),
          );
        }
        return RegionalSection(summary: snap.data!, now: _now);
      },
    );
  }
}

class _PropertyHeader extends StatelessWidget {
  final PropertyModel property;
  final bool hasValidLocation;

  const _PropertyHeader({
    required this.property,
    required this.hasValidLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      child: DashboardCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.grass_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    property.mainCrop.isEmpty
                        ? 'Cultura não informada'
                        : property.mainCrop,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        hasValidLocation
                            ? Icons.location_on_outlined
                            : Icons.location_off_outlined,
                        size: 13,
                        color: hasValidLocation
                            ? AppColors.textHint
                            : AppColors.riskMedium,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          hasValidLocation
                              ? '${property.latitude.toStringAsFixed(4)}, '
                                    '${property.longitude.toStringAsFixed(4)}'
                              : 'Localização não cadastrada ou inválida',
                          style: AppTextStyles.caption.copyWith(
                            color: hasValidLocation
                                ? AppColors.textHint
                                : AppColors.riskMedium,
                          ),
                        ),
                      ),
                    ],
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
