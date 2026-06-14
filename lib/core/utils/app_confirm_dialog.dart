import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class AppConfirmDialog {
  AppConfirmDialog._();

  /// Dialog de confirmación para ELIMINAR (borde rojo, icono trash).
  /// Devuelve `true` si el usuario confirma, `false` si cancela.
  static Future<bool> showDelete(
    BuildContext context, {
    required String itemName,
    String title = 'Confirmar Eliminación',
    String? message,
    String confirmLabel = 'Eliminar',
    String cancelLabel = 'Cancelar',
  }) async {
    final body = message ??
        '¿Estás seguro de que deseas eliminar "$itemName"?\n\nEsta acción no se puede deshacer.';

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => _StyledDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.red,
        borderColor: AppColors.red,
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: AppColors.red,
        confirmTextColor: AppColors.white,
      ),
    );
    return result ?? false;
  }

  /// Dialog de confirmación para acciones de ADVERTENCIA (borde dorado, icono warning).
  /// Usado para cancelar citas, anular ventas, terminar temprano, etc.
  static Future<bool> showWarning(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => _StyledDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.gold,
        borderColor: AppColors.gold.withOpacity(0.6),
        title: title,
        body: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: AppColors.gold,
        confirmTextColor: Colors.black,
      ),
    );
    return result ?? false;
  }
}

class _StyledDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final Color confirmTextColor;

  const _StyledDialog({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
    required this.confirmTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.greyLight,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.greyLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: confirmTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
