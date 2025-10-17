import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Callback que puede ser síncrono o asíncrono y devuelve si debe cerrarse el modal
typedef VModalConfirm = FutureOr<bool> Function();

class VModal {
  VModal._();

  /// Muestra un modal reutilizable con título, contenido y acciones.
  /// Si [onConfirm] devuelve `true` (o se omite), el modal se cierra.
  /// Si devuelve `false`, permanece abierto.
  static Future<T?> show<T>({
    BuildContext? context,
    required String title,
    List<Widget> children = const <Widget>[],
    VModalConfirm? onConfirm,
    VoidCallback? onDismiss,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool showCancel = true,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    Widget? leadingIcon,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 0),
    double maxWidth = 560,
    CrossAxisAlignment contentAlignment = CrossAxisAlignment.stretch,
  }) async {
    final ctx = context ?? Get.context;
    assert(ctx != null, 'Se requiere un BuildContext o Get.context');

    bool loading = false;

    Future<void> close([T? result]) async {
      if (ctx != null && Navigator.of(ctx).canPop()) {
        Navigator.of(ctx, rootNavigator: useRootNavigator).pop(result);
      }
    }

    return showDialog<T>(
      context: ctx!,
      barrierDismissible: barrierDismissible && !loading,
      useRootNavigator: useRootNavigator,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            Future<void> handleConfirm() async {
              if (loading) return;
              setState(() => loading = true);
              bool shouldClose = true;
              try {
                if (onConfirm != null) {
                  final res = await onConfirm();
                  shouldClose = res;
                }
              } catch (e) {
                // No cerrar si falla el callback
                shouldClose = false;
                debugPrint('VModal onConfirm error: $e');
              } finally {
                setState(() => loading = false);
              }
              if (shouldClose) await close();
            }

            void handleDismiss() {
              if (loading) return;
              try {
                onDismiss?.call();
              } finally {
                close();
              }
            }

            return WillPopScope(
              onWillPop: () async => !loading,
              child: AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                contentPadding: EdgeInsets.zero,
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leadingIcon != null) ...[
                      IconTheme(
                        data: Theme.of(dialogCtx).iconTheme,
                        child: leadingIcon,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(dialogCtx).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close),
                      onPressed: loading ? null : handleDismiss,
                    ),
                  ],
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: contentPadding,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: contentAlignment,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (children.isNotEmpty)
                            ...children
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                'Sin contenido',
                                style: Theme.of(dialogCtx).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(dialogCtx).hintColor,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                actionsAlignment: MainAxisAlignment.end,
                actions: <Widget>[
                  if (showCancel)
                    TextButton(
                      onPressed: loading ? null : handleDismiss,
                      child: Text(cancelText),
                    ),
                  FilledButton.icon(
                    onPressed: loading ? null : handleConfirm,
                    icon: loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(confirmText),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Cierra el modal activo (si existe)
  static void close<T>({
    BuildContext? context,
    T? result,
    bool useRootNavigator = true,
  }) {
    final ctx = context ?? Get.context;
    if (ctx != null && Navigator.of(ctx).canPop()) {
      Navigator.of(ctx, rootNavigator: useRootNavigator).pop(result);
    }
  }
}
