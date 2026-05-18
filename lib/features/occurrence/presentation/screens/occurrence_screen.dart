import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/diagnosis_service.dart';
import '../../data/occurrence_repository.dart';
import '../../domain/occurrence_model.dart';
import '../widgets/occurrence_card.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';

/// Tela do Radar Colaborativo.
///
/// Registra ocorrências de praga (foto + GPS), dispara análise de IA
/// e exibe o feed em tempo real de todas as ocorrências.
class OccurrenceScreen extends StatefulWidget {
  const OccurrenceScreen({super.key});

  @override
  State<OccurrenceScreen> createState() => _OccurrenceScreenState();
}

class _OccurrenceScreenState extends State<OccurrenceScreen> {
  final _repo = OccurrenceRepository();
  final _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  bool _isUploading = false;
  String? _analyzingOccurrenceId;

  // ─── Seleção de imagem ──────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: AppConstants.imageQuality,
      maxWidth: AppConstants.imageMaxWidth,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Registro + IA ─────────────────────────────────────────────────────────

  Future<void> _registerOccurrence() async {
    if (_selectedImageBytes == null) {
      _showError('Selecione uma imagem para continuar.');
      return;
    }

    final userId = context.read<AuthService>().currentUser!.uid;
    setState(() => _isUploading = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) return;

      final imageBase64 = base64Encode(_selectedImageBytes!);
      final occurrence = OccurrenceModel(
        id: '',
        imageBase64: imageBase64,
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        reportedBy: userId,
      );

      final occurrenceId = await _repo.save(occurrence);

      if (!mounted) return;
      setState(() {
        _selectedImageBytes = null;
        _analyzingOccurrenceId = occurrenceId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência registrada! Análise IA em andamento...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      _runDiagnosis(occurrenceId, imageBase64);
    } on LocationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erro ao registrar ocorrência: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _runDiagnosis(String occurrenceId, String imageBase64) {
    context
        .read<DiagnosisService>()
        .analyzeAndSave(occurrenceId, imageBase64)
        .then((diagnosis) {
      if (!mounted) return;
      setState(() => _analyzingOccurrenceId = null);

      if (diagnosis != null) {
        dev.log('[OccurrenceScreen] diagnóstico: ${diagnosis.pestName}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Análise IA indisponível. Tente novamente no card.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Colaborativo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Configurar alertas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _RegistrationPanel(
            selectedImageBytes: _selectedImageBytes,
            isUploading: _isUploading,
            onPickImage: _showImageSourceDialog,
            onRegister: _registerOccurrence,
          ),
          const Divider(height: 1),
          Expanded(child: _OccurrenceFeed(analyzingId: _analyzingOccurrenceId, repo: _repo)),
        ],
      ),
    );
  }
}

// ─── Painel de registro ────────────────────────────────────────────────────────

class _RegistrationPanel extends StatelessWidget {
  final Uint8List? selectedImageBytes;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onRegister;

  const _RegistrationPanel({
    required this.selectedImageBytes,
    required this.isUploading,
    required this.onPickImage,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Registrar Nova Ocorrência',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: selectedImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(selectedImageBytes!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text('Toque para adicionar foto'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isUploading ? null : onRegister,
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(isUploading ? 'Enviando...' : 'Registrar Ocorrência'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feed de ocorrências ───────────────────────────────────────────────────────

class _OccurrenceFeed extends StatelessWidget {
  final String? analyzingId;
  final OccurrenceRepository repo;

  const _OccurrenceFeed({required this.analyzingId, required this.repo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OccurrenceModel>>(
      stream: repo.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Nenhuma ocorrência registrada ainda.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final occurrence = snapshot.data![index];
            return OccurrenceCard(
              occurrence: occurrence,
              isAnalyzingBySystem: analyzingId == occurrence.id,
            );
          },
        );
      },
    );
  }
}
