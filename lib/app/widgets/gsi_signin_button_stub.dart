import 'package:flutter/material.dart';

class GsiSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const GsiSignInButton({
    super.key,
    this.onPressed,
    this.label = 'Iniciar sesión con Google',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login),
      label: Text(label),
    );
  }
}
