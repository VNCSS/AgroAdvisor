import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/occurrence_repository.dart';
import '../../domain/occurrence_model.dart';

/// Radar de pragas no mapa — mostra as 8 ocorrências mais próximas.
class OccurrenceRadarScreen extends StatefulWidget {
  const OccurrenceRadarScreen({super.key});

  @override
  State<OccurrenceRadarScreen> createState() => _OccurrenceRadarScreenState();
}

class _OccurrenceRadarScreenState extends State<OccurrenceRadarScreen> {
  final _repo = OccurrenceRepository();
  final _mapController = MapController();

  double? _lat;
  double? _lng;
  String? _locationError;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) setState(() { _lat = pos.latitude; _lng = pos.longitude; });
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } catch (e) {
      if (mounted) setState(() => _locationError = 'Erro ao obter localização.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  List<_OccDist> _sorted(List<OccurrenceModel> all) {
    return all.map((o) {
      final d = (_lat != null && _lng != null)
          ? LocationService.distanceBetween(_lat!, _lng!, o.latitude, o.longitude)
          : double.infinity;
      return _OccDist(o, d);
    }).toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));
  }

  @override
  Widget build(BuildContext context) {
    // Quando aberta via bottom nav, não tem AppBar própria
    final isStandalone = ModalRoute.of(context)?.settings.name != null ||
        Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Radar de pragas'),
            Text(
              'RAIO ${AppConstants.alertRadiusDefault.toStringAsFixed(0)} KM',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.onPrimary.withValues(alpha: 0.75)),
            ),
          ],
        ),
        automaticallyImplyLeading: isStandalone,
      ),
      body: Column(
        children: [
          if (_loadingLocation)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primaryLight,
              backgroundColor: AppColors.primaryContainer,
            ),

          if (_locationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              color: AppColors.riskHighContainer,
              child: Row(
                children: [
                  const Icon(Icons.location_off_outlined,
                      color: AppColors.riskHigh, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(_locationError!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.riskHigh)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<List<OccurrenceModel>>(
              stream: _repo.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];

                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.radar_rounded,
                    title: 'Nenhuma ocorrência no radar',
                    subtitle: 'Quando produtores registrarem\nocorrências, elas aparecerão aqui.',
                  );
                }

                final sorted = _sorted(all);
                final nearest = sorted.take(AppConstants.radarNearestCount).toList();

                final center = (_lat != null && _lng != null)
                    ? LatLng(_lat!, _lng!)
                    : LatLng(all.first.latitude, all.first.longitude);

                return Column(
                  children: [
                    // ── Mapa ────────────────────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13,
                          maxZoom: 18,
                          minZoom: 3,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.agro_advisor',
                          ),
                          MarkerLayer(
                            markers: [
                              // Marcador do usuário
                              if (_lat != null && _lng != null)
                                Marker(
                                  point: center,
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.info,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.my_location_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              // Marcadores de ocorrências
                              ...nearest.map((item) {
                                final risk =
                                    item.o.diagnosis?.riskLevel.toLowerCase();
                                final color = switch (risk) {
                                  'alto'             => AppColors.riskHigh,
                                  'médio' || 'medio' => AppColors.riskMedium,
                                  _                  => AppColors.textSecondary,
                                };
                                return Marker(
                                  point: LatLng(
                                      item.o.latitude, item.o.longitude),
                                  width: 32,
                                  height: 32,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.bug_report_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Lista inferior ───────────────────────────────────────
                    _NearestPanel(nearest: nearest, hasLocation: _lat != null),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painel de ocorrências próximas ────────────────────────────────────────────

class _NearestPanel extends StatelessWidget {
  final List<_OccDist> nearest;
  final bool hasLocation;

  const _NearestPanel({required this.nearest, required this.hasLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${nearest.length} ALERTAS NO RAIO',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textHint, letterSpacing: 0.8),
                ),
                Text(
                  hasLocation ? 'Ordenar: distância' : 'Sem localização',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 180,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: nearest.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = nearest[i];
                final risk = item.o.diagnosis?.riskLevel;
                final pestName = item.o.diagnosis?.pestName;
                final distKm = item.dist.isFinite
                    ? item.dist < 1000
                        ? '${item.dist.toStringAsFixed(0)} m'
                        : '${(item.dist / 1000).toStringAsFixed(1)} km'
                    : 'dist. indisponível';

                final (dotColor) = switch (risk?.toLowerCase()) {
                  'alto'             => AppColors.riskHigh,
                  'médio' || 'medio' => AppColors.riskMedium,
                  'baixo'            => AppColors.riskLow,
                  _                  => AppColors.textHint,
                };

                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.riskHighContainer,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(Icons.bug_report_outlined,
                        color: dotColor, size: 20),
                  ),
                  title: Text(
                    pestName ?? 'Ocorrência ${i + 1}',
                    style: AppTextStyles.titleSmall,
                  ),
                  subtitle: Text(
                    distKm,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textHint),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OccDist {
  final OccurrenceModel o;
  final double dist;
  const _OccDist(this.o, this.dist);
}
