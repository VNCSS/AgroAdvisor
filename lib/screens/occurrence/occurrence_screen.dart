import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/occurrence_model.dart';

/// Tela do Radar Colaborativo.
/// Permite registrar uma ocorrência de praga com foto + GPS,
/// e exibe um feed em tempo real de todas as ocorrências.
class OccurrenceScreen extends StatefulWidget {
  const OccurrenceScreen({super.key});

  @override
  State<OccurrenceScreen> createState() => _OccurrenceScreenState();
}

class _OccurrenceScreenState extends State<OccurrenceScreen> {
  final _dbService = DatabaseService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;

  // ──────────────────────────────────────────────
  // SELECIONAR IMAGEM (câmera ou galeria)
  // ──────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70, // comprime para economizar Storage
      maxWidth: 1280,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = File(picked.path);
        _selectedImageBytes = bytes;
      });
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

  // ──────────────────────────────────────────────
  // REGISTRAR OCORRÊNCIA
  // ──────────────────────────────────────────────

  Future<void> _registerOccurrence() async {
    if (_selectedImage == null) {
      _showError('Selecione uma imagem para continuar.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Captura localização GPS atual
      final position = await _getLocation();
      if (position == null) return; // erro já exibido em _getLocation

      final userId = context.read<AuthService>().currentUser!.uid;

      // 2. Faz upload da imagem para o Firebase Storage
      final imageUrl = await _storageService.uploadOccurrenceImage(
        imageFile: kIsWeb ? null : _selectedImage,
        imageBytes: kIsWeb ? _selectedImageBytes : null,
        userId: userId,
      );

      // 3. Salva o documento no Firestore
      final occurrence = OccurrenceModel(
        id: '', // gerado automaticamente pelo Firestore
        imageUrl: imageUrl,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        reportedBy: userId,
      );
      await _dbService.saveOccurrence(occurrence);

      if (!mounted) return;
      setState(() {
        _selectedImage = null; // limpa a imagem selecionada
        _selectedImageBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrência registrada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Erro ao registrar ocorrência: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Captura a posição GPS atual com tratamento de permissões.
  Future<Position?> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('GPS desativado. Ative nas configurações do dispositivo.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Permissão de localização negada.');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError('Permissão negada permanentemente nas configurações.');
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Colaborativo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Painel de registro de nova ocorrência
          _buildRegistrationPanel(),
          const Divider(height: 1),

          // Feed em tempo real de ocorrências
          Expanded(child: _buildOccurrenceFeed()),
        ],
      ),
    );
  }

  /// Painel superior para selecionar foto e registrar ocorrência
  Widget _buildRegistrationPanel() {
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

          // Preview da imagem selecionada
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb && _selectedImageBytes != null
                          ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                          : Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        const Text('Toque para adicionar foto'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Botão de registro
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isUploading ? null : _registerOccurrence,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isUploading ? 'Enviando...' : 'Registrar Ocorrência'),
            ),
          ),
        ],
      ),
    );
  }

  /// Feed em tempo real com todas as ocorrências do Firestore
  Widget _buildOccurrenceFeed() {
    return StreamBuilder<List<OccurrenceModel>>(
      stream: _dbService.getOccurrencesStream(),
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

        final occurrences = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: occurrences.length,
          itemBuilder: (context, index) {
            final o = occurrences[index];
            return _OccurrenceCard(occurrence: o);
          },
        );
      },
    );
  }
}

/// Card que exibe uma ocorrência no feed
class _OccurrenceCard extends StatelessWidget {
  final OccurrenceModel occurrence;

  const _OccurrenceCard({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          // Miniatura da imagem
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Image.network(
              occurrence.imageUrl,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 60),
            ),
          ),
          const SizedBox(width: 12),

          // Detalhes da ocorrência
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 ${occurrence.latitude.toStringAsFixed(4)}, ${occurrence.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🕐 ${_formatDate(occurrence.timestamp)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
