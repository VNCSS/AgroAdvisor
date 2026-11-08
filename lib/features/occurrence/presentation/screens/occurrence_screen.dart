import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/diagnosis_service.dart';
import '../../data/occurrence_repository.dart';
import '../../domain/occurrence_model.dart';
import '../widgets/occurrence_card.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';

/// Radar Colaborativo — registra ocorrência (foto + GPS) e exibe o feed em tempo real.
class OccurrenceScreen extends StatefulWidget {
  const OccurrenceScreen({super.key});

  @override
  State<OccurrenceScreen> createState() => _OccurrenceScreenState();
}

class _OccurrenceScreenState extends State<OccurrenceScreen> {
  final _repo = OccurrenceRepository();
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _isUploading = false;
  String? _analyzingId;

  // ── Seleção de imagem ────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: AppConstants.imageQuality,
      maxWidth: AppConstants.imageMaxWidth,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
              ),
              title: Text('Tirar foto', style: AppTextStyles.titleMedium),
              subtitle: Text('Abrir câmera do celular',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.textSecondary, size: 22),
              ),
              title: Text('Escolher da galeria', style: AppTextStyles.titleMedium),
              subtitle: Text('Selecionar foto existente',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  // ── Registro + IA ────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (_imageBytes == null) {
      _showError('Selecione uma imagem para continuar.');
      return;
    }

    final userId = context.read<AuthService>().currentUser!.uid;
    setState(() => _isUploading = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) return;

      final imageBase64 = base64Encode(_imageBytes!);
      final occurrence = OccurrenceModel(
        id: '',
        imageBase64: imageBase64,
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        reportedBy: userId,
      );

      final id = await _repo.save(occurrence);

      if (!mounted) return;
      setState(() {
        _imageBytes = null;
        _analyzingId = id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência registrada! Análise IA em andamento...'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );

      _runDiagnosis(id, imageBase64);
    } on LocationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erro ao registrar: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _runDiagnosis(String id, String imageBase64) {
    context.read<DiagnosisService>().analyzeAndSave(id, imageBase64).then((d) {
      if (!mounted) return;
      setState(() => _analyzingId = null);
      if (d != null) {
        dev.log('[OccurrenceScreen] diagnóstico: ${d.pestName}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Análise IA indisponível. Tente novamente no card.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Radar Colaborativo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alertas',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          _RegistrationPanel(
            imageBytes: _imageBytes,
            isUploading: _isUploading,
            onPickImage: _showSourceSheet,
            onRegister: _register,
            onClearImage: () => setState(() => _imageBytes = null),
          ),
          const Divider(height: 1),
          Expanded(child: _Feed(analyzingId: _analyzingId, repo: _repo)),
        ],
      ),
    );
  }
}

// ── Painel de registro ────────────────────────────────────────────────────────

class _RegistrationPanel extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onRegister;
  final VoidCallback onClearImage;

  const _RegistrationPanel({
    required this.imageBytes,
    required this.isUploading,
    required this.onPickImage,
    required this.onRegister,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar ocorrência', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),

          // Área de imagem
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: imageBytes != null
                      ? AppColors.primary
                      : AppColors.border,
                  width: imageBytes != null ? 2 : 1,
                ),
              ),
              child: imageBytes != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
                          child: Image.memory(imageBytes!, fit: BoxFit.cover,
                              width: double.infinity, height: double.infinity),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onClearImage,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined,
                            size: 36, color: AppColors.primary),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Toque para adicionar foto',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                        Text('Use a câmera ou galeria',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textHint)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Botão registrar
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonH,
            child: FilledButton.icon(
              onPressed: isUploading ? null : onRegister,
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                isUploading ? 'Enviando...' : 'Registrar ocorrência',
                style: AppTextStyles.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feed de ocorrências ───────────────────────────────────────────────────────

class _Feed extends StatelessWidget {
  final String? analyzingId;
  final OccurrenceRepository repo;

  const _Feed({required this.analyzingId, required this.repo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OccurrenceModel>>(
      stream: repo.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.radar_rounded,
            title: 'Nenhuma ocorrência ainda',
            subtitle: 'Seja o primeiro a registrar uma\nocorrência no radar colaborativo.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => OccurrenceCard(
            occurrence: items[i],
            isAnalyzingBySystem: analyzingId == items[i].id,
          ),
        );
      },
    );
  }
}
