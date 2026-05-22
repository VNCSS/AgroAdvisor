import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';

/// Botão primário padronizado com suporte a estado de carregamento e ícone.
/// Tamanho generoso (56 dp) para facilitar o uso em campo.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool outlined;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label, style: AppTextStyles.labelLarge),
                ],
              )
            : Text(label, style: AppTextStyles.labelLarge);

    final effectiveOnPressed = isLoading ? null : onPressed;

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonH,
        child: OutlinedButton(onPressed: effectiveOnPressed, child: child),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonH,
      child: FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isLoading ? AppColors.primaryLight : AppColors.primary,
        ),
        child: child,
      ),
    );
  }
}
