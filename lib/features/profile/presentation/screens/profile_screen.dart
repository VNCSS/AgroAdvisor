import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../services/auth_service.dart';
import '../../../property/data/property_repository.dart';
import '../../../property/domain/property_model.dart';
import '../../../property/presentation/screens/property_form_screen.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';

/// Tela de perfil: dados do usuário + gestão de propriedades rurais.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  void _reload() => setState(() {
        _propertiesFuture = _repo.getByOwner(_userId);
      });

  static String _initials(String email) {
    final parts = email.split('@').first.split(RegExp(r'[._\-]'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final local = email.split('@').first;
    return local.substring(0, local.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final email = auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<PropertyModel>>(
        future: _propertiesFuture,
        builder: (context, snap) {
          final properties = snap.data ?? [];

          return CustomScrollView(
            slivers: [
              // ── Header com dados do usuário ──────────────────────────────
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  initials: _initials(email),
                  email: email,
                  propertyCount: properties.length,
                  onSettings: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen())),
                  onLogout: () => auth.signOut(),
                ),
              ),

              // ── Título da seção de propriedades ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.lg,
                    AppSpacing.screenH, AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Minha propriedade', style: AppTextStyles.headlineSmall),
                      TextButton.icon(
                        onPressed: () => _goToForm(null),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Talhão'),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Lista de propriedades ─────────────────────────────────────
              if (snap.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (properties.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.agriculture_rounded,
                    title: 'Nenhuma propriedade',
                    subtitle: 'Cadastre sua fazenda para\norganizar seus diagnósticos.',
                    actionLabel: 'Adicionar propriedade',
                    onAction: () => _goToForm(null),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  sliver: SliverList.separated(
                    itemCount: properties.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _PropertyCard(
                      property: properties[i],
                      onTap: () => _goToForm(properties[i]),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
          builder: (_) => PropertyFormScreen(existingProperty: existing)),
    );
    if (updated == true && mounted) _reload();
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String email;
  final int propertyCount;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _ProfileHeader({
    required this.initials,
    required this.email,
    required this.propertyCount,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + ações
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Perfil', style: AppTextStyles.headlineLarge),
              Row(
                children: [
                  _IconBtn(icon: Icons.settings_outlined, onTap: onSettings),
                  const SizedBox(width: AppSpacing.xs),
                  _IconBtn(icon: Icons.logout_rounded, onTap: onLogout),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Card do usuário
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: AppTextStyles.headlineMedium
                          .copyWith(color: AppColors.onPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Dados
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: AppTextStyles.titleSmall
                            .copyWith(color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip('$propertyCount propriedade${propertyCount != 1 ? "s" : ""}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: AppColors.textSecondary,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  const _PropertyCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.grass_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.name,
                      style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text(property.mainCrop,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
