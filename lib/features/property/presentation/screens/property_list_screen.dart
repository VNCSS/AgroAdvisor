import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/auth_service.dart';
import '../../data/property_repository.dart';
import '../../domain/property_model.dart';
import 'property_form_screen.dart';
import '../../../occurrence/presentation/screens/occurrence_screen.dart';
import '../../../occurrence/presentation/screens/occurrence_radar_screen.dart';

/// Tela inicial após login: lista as propriedades do usuário e
/// dá acesso ao Radar Colaborativo.
class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  late final PropertyRepository _repo;
  late Future<List<PropertyModel>> _propertiesFuture;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _repo = PropertyRepository();
    _userId = context.read<AuthService>().currentUser!.uid;
    _reload();
  }

  void _reload() {
    setState(() {
      _propertiesFuture = _repo.getByOwner(_userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Propriedades'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<PropertyModel>>(
        future: _propertiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final properties = snapshot.data ?? [];

          if (properties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.agriculture, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma propriedade cadastrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _goToForm(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar Propriedade'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${properties.length} propriedade${properties.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    FilledButton.icon(
                      onPressed: () => _goToForm(null),
                      icon: const Icon(Icons.add),
                      label: const Text('Nova'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final p = properties[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.agriculture, size: 40),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(p.mainCrop),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _goToForm(p),
                        ),
                        onTap: () => _showDetails(p),
                      ),
                    );
                  },
                ),
              ),
              _BottomNavCards(
                onRadarTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OccurrenceScreen()),
                ),
                onMapTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OccurrenceRadarScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _goToForm(PropertyModel? existing) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyFormScreen(existingProperty: existing),
      ),
    );
    if (updated == true && mounted) _reload();
  }

  void _showDetails(PropertyModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),
              _PropertyDetailsCard(property: p),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _goToForm(p);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets internos ─────────────────────────────────────────────────────────

class _BottomNavCards extends StatelessWidget {
  final VoidCallback onRadarTap;
  final VoidCallback onMapTap;

  const _BottomNavCards({required this.onRadarTap, required this.onMapTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.bug_report, size: 36),
              title: const Text(
                'Radar Colaborativo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Registre e visualize ocorrências de pragas'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: onRadarTap,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.map, size: 36),
              title: const Text(
                'Radar no Mapa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Veja as pragas mais próximas em um mapa'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: onMapTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyDetailsCard extends StatelessWidget {
  final PropertyModel property;
  const _PropertyDetailsCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              property.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.grass,
              label: 'Cultura Principal',
              value: property.mainCrop,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on,
              label: 'Localização',
              value:
                  'Lat: ${property.latitude.toStringAsFixed(4)}\nLng: ${property.longitude.toStringAsFixed(4)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
