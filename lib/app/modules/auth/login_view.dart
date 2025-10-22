import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    spacing: 24,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bienvenido',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Obx(
                        () => OutlinedButton.icon(
                          onPressed: controller.loading.value
                              ? null
                              : controller.signInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text('Continuar con Google'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ⭐️ Overlay de carga cuando se está autenticando/regresando del deep link
          Obx(
            () => controller.loading.value
                ? Positioned.fill(
                    child: AbsorbPointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.25),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
