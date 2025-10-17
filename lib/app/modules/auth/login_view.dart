import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:agenda_citas/app/widgets/modal.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Bienvenido',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => controller.email.value = v.trim(),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    onChanged: (v) => controller.password.value = v,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  const SizedBox(height: 20),
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.loading.value
                          ? null
                          : controller.signIn,
                      child: controller.loading.value
                          ? const CircularProgressIndicator()
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: controller.loading.value
                        ? null
                        : controller.signUp,
                    child: const Text('Registrarse'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('o continúa con'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => OutlinedButton.icon(
                      onPressed: controller.loading.value
                          ? null
                          : controller.signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('Continuar con Google'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: controller.loading.value
                        ? null
                        : () async {
                            final temp = TextEditingController(
                              text: controller.email.value,
                            );
                            await VModal.show(
                              title: 'Recuperar contraseña',
                              children: [
                                TextField(
                                  controller: temp,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                  ),
                                ),
                              ],
                              cancelText: 'Cancelar',
                              confirmText: 'Enviar',
                              onConfirm: () async {
                                final emailInput = temp.text.trim();
                                if (emailInput.isEmpty) {
                                  Get.snackbar(
                                    'Aviso',
                                    'Ingresa un email válido',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return false; // no cerrar el modal
                                }
                                controller.email.value = emailInput;
                                await controller.forgotPassword();
                                return true; // cerrar el modal
                              },
                            );
                          },
                    child: const Text('Olvidé mi contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
