import 'package:flutter/material.dart';

/// FilledButton padronizado com suporte a estado de loading.
///
/// Substitui o padrão repetido em todas as telas:
///   FilledButton(onPressed: _isLoading ? null : _handler,
///     child: _isLoading ? CircularProgressIndicator() : Text('Label'))
///
/// Uso:
///   PrimaryButton(
///     label: 'Salvar',
///     onPressed: _handleSave,
///     isLoading: _isSaving,
///   )
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 16)),
                ],
              )
            : Text(label, style: const TextStyle(fontSize: 16));

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: child,
      ),
    );
  }
}
