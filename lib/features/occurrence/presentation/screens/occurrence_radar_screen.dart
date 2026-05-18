import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../data/occurrence_repository.dart';
import '../../domain/occurrence_model.dart';

class OccurrenceRadarScreen extends StatefulWidget {
  const OccurrenceRadarScreen({super.key});

  @override
  State<OccurrenceRadarScreen> createState() => _OccurrenceRadarScreenState();
}

class _OccurrenceRadarScreenState extends State<OccurrenceRadarScreen> {
  final _repo = OccurrenceRepository();
  final _mapController = MapController();

  double? _currentLat;
  double? _currentLng;
  String? _locationError;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
        });
      }
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } catch (e) {
      if (mounted) setState(() => _locationError = 'Erro ao obter localização: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  List<_OccurrenceWithDistance> _sortedByDistance(List<OccurrenceModel> all) {
    final lat = _currentLat;
    final lng = _currentLng;
    final list = all.map((o) {
      final dist = (lat != null && lng != null)
          ? LocationService.distanceBetween(lat, lng, o.latitude, o.longitude)
          : double.infinity;
      return _OccurrenceWithDistance(occurrence: o, distanceMeters: dist);
    }).toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radar de Pragas no Mapa')),
      body: Column(
        children: [
          if (_isLoadingLocation) const LinearProgressIndicator(minHeight: 4),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _locationError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<OccurrenceModel>>(
              stream: _repo.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma ocorrência encontrada.'),
                  );
                }

                final sorted = _sortedByDistance(snapshot.data!);
                final nearest =
                    sorted.take(AppConstants.radarNearestCount).toList();

                final center = (_currentLat != null && _currentLng != null)
                    ? LatLng(_currentLat!, _currentLng!)
                    : snapshot.data!.isNotEmpty
                        ? LatLng(
                            snapshot.data!.first.latitude,
                            snapshot.data!.first.longitude,
                          )
                        : const LatLng(
                            AppConstants.defaultLatitude,
                            AppConstants.defaultLongitude,
                          );

                return Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13,
                          maxZoom: 18,
                          minZoom: 3,
                          interactionOptions: const InteractionOptions(),
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
                              if (_currentLat != null && _currentLng != null)
                                Marker(
                                  point: center,
                                  width: 32,
                                  height: 32,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 32,
                                  ),
                                ),
                              ...nearest.map(
                                (item) => Marker(
                                  point: LatLng(
                                    item.occurrence.latitude,
                                    item.occurrence.longitude,
                                  ),
                                  width: 28,
                                  height: 28,
                                  child: const Icon(
                                    Icons.bug_report,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _NearestList(nearest: nearest, hasLocation: _currentLat != null),
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

// ─── Lista de ocorrências mais próximas ───────────────────────────────────────

class _NearestList extends StatelessWidget {
  final List<_OccurrenceWithDistance> nearest;
  final bool hasLocation;

  const _NearestList({required this.nearest, required this.hasLocation});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ocorrências próximas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                hasLocation ? '${nearest.length} visíveis' : 'Sem localização',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: nearest.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = nearest[index];
              return ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.red),
                title: Text(
                  item.occurrence.reportedBy.isEmpty
                      ? 'Ocorrência ${index + 1}'
                      : 'Usuário ${item.occurrence.reportedBy}',
                ),
                subtitle: Text(
                  item.distanceMeters.isFinite
                      ? '${item.distanceMeters.toStringAsFixed(0)} m de distância'
                      : 'Distância indisponível',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OccurrenceWithDistance {
  final OccurrenceModel occurrence;
  final double distanceMeters;

  const _OccurrenceWithDistance({
    required this.occurrence,
    required this.distanceMeters,
  });
}
