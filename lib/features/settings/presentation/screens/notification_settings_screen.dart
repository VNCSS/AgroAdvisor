import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../services/auth_service.dart';
import '../../data/settings_repository.dart';
import '../../domain/user_settings_model.dart';

/// Configura alertas de pragas: ativar/desativar e raio de notificação.
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
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = context.read<AuthService>().currentUser!.uid;
    final s = await _repo.get(userId);
    if (!mounted) return;
    setState(() {
      _settings = s ?? UserSettingsModel(userId: userId);
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    try {
      await _repo.save(_settings!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final s = _settings!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Alertas de pragas')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          // ── Info banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Você receberá alertas quando pragas forem detectadas próximas à sua propriedade.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Toggle notificações ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              title: Text('Notificações de pragas',
                  style: AppTextStyles.titleMedium),
              subtitle: Text(
                s.notificationsEnabled
                    ? 'Alertas ativos — raio de ${s.alertRadiusKm.toStringAsFixed(0)} km'
                    : 'Alertas desativados',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.notificationsEnabled
                      ? AppColors.primaryContainer
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  s.notificationsEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: s.notificationsEnabled
                      ? AppColors.primary
                      : AppColors.textHint,
                  size: 22,
                ),
              ),
              value: s.notificationsEnabled,
              onChanged: (v) =>
                  setState(() => _settings = s.copyWith(notificationsEnabled: v)),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Slider raio ──────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: s.notificationsEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Raio de alerta', style: AppTextStyles.titleMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          '${s.alertRadiusKm.toStringAsFixed(0)} km',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Alertas para pragas detectadas dentro deste raio.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  Slider(
                    value: s.alertRadiusKm,
                    min: AppConstants.alertRadiusMin,
                    max: AppConstants.alertRadiusMax,
                    divisions: AppConstants.alertRadiusSliderDivisions,
                    label: '${s.alertRadiusKm.toStringAsFixed(0)} km',
                    onChanged: s.notificationsEnabled
                        ? (v) => setState(
                            () => _settings = s.copyWith(alertRadiusKm: v))
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${AppConstants.alertRadiusMin.toStringAsFixed(0)} km',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textHint)),
                      Text('${AppConstants.alertRadiusMax.toStringAsFixed(0)} km',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textHint)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            label: 'Salvar configurações',
            onPressed: _save,
            isLoading: _saving,
            icon: Icons.check_rounded,
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
