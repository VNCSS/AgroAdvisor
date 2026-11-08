import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/property_repository.dart';
import '../../domain/property_model.dart';

/// Formulário para criar ou editar uma propriedade rural.
class PropertyFormScreen extends StatefulWidget {
  final PropertyModel? existingProperty;

  const PropertyFormScreen({super.key, this.existingProperty});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _repo = PropertyRepository();

  String? _selectedCrop;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProperty;
    if (p != null) {
      _nameController.text = p.name;
      _latController.text = p.latitude.toString();
      _lngController.text = p.longitude.toString();
      _selectedCrop = p.mainCrop;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) return;
      setState(() {
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lngController.text = pos.longitude.toStringAsFixed(6);
      });
    } on LocationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erro ao obter localização: $e');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null) {
      _showError('Selecione a cultura principal.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthService>().currentUser!.uid;
      final property = PropertyModel(
        id: widget.existingProperty?.id ?? '',
        name: _nameController.text.trim(),
        mainCrop: _selectedCrop!,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        ownerId: userId,
      );

      await _repo.save(property);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Propriedade salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final property = widget.existingProperty;
    if (property == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir propriedade'),
        content: const Text(
          'Tem certeza que deseja excluir esta propriedade? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _repo.delete(property.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Propriedade excluída com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Erro ao excluir: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProperty != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Propriedade' : 'Cadastrar Propriedade'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir propriedade',
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Propriedade *',
                  prefixIcon: Icon(Icons.home_work_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Cultura Principal *',
                  prefixIcon: Icon(Icons.grass),
                  border: OutlineInputBorder(),
                ),
                items: AppConstants.availableCrops
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCrop = v),
                validator: (v) => v == null ? 'Selecione uma cultura' : null,
              ),
              const SizedBox(height: 16),

              const Text(
                'Localização',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                  _isGettingLocation
                      ? 'Obtendo localização...'
                      : 'Usar localização atual (GPS)',
                ),
              ),
              const SizedBox(height: 8),
              const Text('ou insira manualmente:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),

              TextFormField(
                controller: _latController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Latitude *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'ex: -22.9035',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obrigatório';
                  if (double.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _lngController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Longitude *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'ex: -43.1729',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obrigatório';
                  if (double.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'Salvar Propriedade',
                onPressed: _handleSave,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
