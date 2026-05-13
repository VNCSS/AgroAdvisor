import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/property_model.dart';

/// Formulário para criar ou editar uma propriedade rural.
/// Suporta captura de localização via GPS ou inserção manual.
class PropertyFormScreen extends StatefulWidget {
  /// Passado quando o usuário está editando uma propriedade existente
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

  // Lista de culturas disponíveis no MVP
  final List<String> _crops = [
    'Milho',
    'Soja',
    'Café',
    'Cana-de-açúcar',
    'Algodão',
    'Trigo',
    'Arroz',
    'Feijão',
    'Outro',
  ];
  String? _selectedCrop;

  bool _isLoading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    // Pré-preenche os campos se estiver editando
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

  // ──────────────────────────────────────────────
  // CAPTURA DE LOCALIZAÇÃO VIA GPS
  // ──────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Verifica se o serviço de localização está habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Ative o GPS do dispositivo e tente novamente.');
        return;
      }

      // Solicita permissão de localização
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Permissão de localização negada.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError(
            'Permissão negada permanentemente. Habilite nas configurações do app.');
        return;
      }

      // Captura a posição atual com precisão alta
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      _showError('Erro ao obter localização: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  // ──────────────────────────────────────────────
  // SALVAR PROPRIEDADE
  // ──────────────────────────────────────────────

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
        id: widget.existingProperty?.id ?? '', // ID vazio para novas propriedades
        name: _nameController.text.trim(),
        mainCrop: _selectedCrop!,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        ownerId: userId,
      );

      await DatabaseService().saveProperty(property);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Propriedade salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _showError('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome da propriedade
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

              // Dropdown de cultura
              DropdownButtonFormField<String>(
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Cultura Principal *',
                  prefixIcon: Icon(Icons.grass),
                  border: OutlineInputBorder(),
                ),
                items: _crops
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCrop = value),
                validator: (v) => v == null ? 'Selecione uma cultura' : null,
              ),
              const SizedBox(height: 16),

              // Seção de localização
              const Text(
                'Localização',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Botão para capturar GPS
              OutlinedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(_isGettingLocation
                    ? 'Obtendo localização...'
                    : 'Usar localização atual (GPS)'),
              ),
              const SizedBox(height: 8),
              const Text('ou insira manualmente:',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),

              // Latitude manual
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

              // Longitude manual
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

              // Botão salvar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salvar Propriedade',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
