import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../services/auth_service.dart';
import '../../data/settings_repository.dart';
import '../../domain/user_settings_model.dart';

/// Configura o raio de alertas de pragas e ativa/desativa notificações push.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _repo = SettingsRepository();
  UserSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = context.read<AuthService>().currentUser!.uid;
    final settings = await _repo.get(userId);
    if (!mounted) return;
    setState(() {
      _settings = settings ?? UserSettingsModel(userId: userId);
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _isSaving = true);
    try {
      await _repo.save(_settings!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final settings = _settings!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações de Alertas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoBanner(color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),

          Card(
            child: SwitchListTile(
              title: const Text(
                'Notificações de pragas próximas',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                settings.notificationsEnabled
                    ? 'Alertas ativos — raio de ${settings.alertRadiusKm.toStringAsFixed(0)} km'
                    : 'Alertas desativados',
              ),
              value: settings.notificationsEnabled,
              onChanged: (v) =>
                  setState(() => _settings = settings.copyWith(notificationsEnabled: v)),
              secondary: Icon(
                settings.notificationsEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: settings.notificationsEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),

          AnimatedOpacity(
            opacity: settings.notificationsEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Raio de alerta',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${settings.alertRadiusKm.toStringAsFixed(0)} km',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alertas para pragas detectadas dentro deste raio.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Slider(
                      value: settings.alertRadiusKm,
                      min: AppConstants.alertRadiusMin,
                      max: AppConstants.alertRadiusMax,
                      divisions: AppConstants.alertRadiusSliderDivisions,
                      label: '${settings.alertRadiusKm.toStringAsFixed(0)} km',
                      onChanged: settings.notificationsEnabled
                          ? (v) => setState(
                                () => _settings = settings.copyWith(alertRadiusKm: v),
                              )
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppConstants.alertRadiusMin.toStringAsFixed(0)} km',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          '${AppConstants.alertRadiusMax.toStringAsFixed(0)} km',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            label: _isSaving ? 'Salvando...' : 'Salvar Configurações',
            onPressed: _save,
            isLoading: _isSaving,
            icon: Icons.save_outlined,
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final Color color;
  const _InfoBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_active_outlined, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Você receberá alertas push quando pragas forem detectadas próximas à sua propriedade.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
