import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/property_model.dart';
import 'property_form_screen.dart';
import '../occurrence/occurrence_screen.dart';

/// Tela principal após o login. Mostra a lista de propriedades
/// e permite navegar para o Radar Colaborativo.
class PropertyViewScreen extends StatelessWidget {
  const PropertyViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final dbService = DatabaseService();
    final userId = authService.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Propriedades'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Botão de logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<PropertyModel>>(
        future: dbService.getUserProperties(userId),
        builder: (context, snapshot) {
          // Estado de carregamento
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final properties = snapshot.data ?? [];

          // Se não há propriedades cadastradas, mostra CTA de cadastro
          if (properties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.agriculture,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma propriedade cadastrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _goToForm(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar Propriedade'),
                  ),
                ],
              ),
            );
          }

          // Exibe a lista de propriedades
          return Column(
            children: [
              // Header com botão de adicionar
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
                      onPressed: () => _goToForm(context, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Nova'),
                    ),
                  ],
                ),
              ),

              // Lista de propriedades
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.agriculture, size: 40),
                        title: Text(
                          property.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(property.mainCrop),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _goToForm(context, property),
                        ),
                        onTap: () => _showPropertyDetails(context, property),
                      ),
                    );
                  },
                ),
              ),

              // Card de acesso ao Radar Colaborativo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.bug_report, size: 36),
                    title: const Text(
                      'Radar Colaborativo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        const Text('Registre e visualize ocorrências de pragas'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OccurrenceScreen()),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToForm(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _goToForm(BuildContext context, PropertyModel? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyFormScreen(existingProperty: existing),
      ),
    );
  }

  void _showPropertyDetails(BuildContext context, PropertyModel property) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    property.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),
              _PropertyInfoCard(property: property),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _goToForm(context, property);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card com os detalhes da propriedade exibidos na tela
class _PropertyInfoCard extends StatelessWidget {
  final PropertyModel property;

  const _PropertyInfoCard({required this.property});

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
                value: property.mainCrop),
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

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

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
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
