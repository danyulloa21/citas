import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/google_auth_service.dart';

class AuthStatusWidget extends StatefulWidget {
  const AuthStatusWidget({super.key});

  @override
  State<AuthStatusWidget> createState() => _AuthStatusWidgetState();
}

class _AuthStatusWidgetState extends State<AuthStatusWidget> {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;
  bool _loading = false;
  // Subscription to auth changes
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    // Listen for changes in the GoogleSignIn current user so the widget updates
    try {
      _authSub = TransparentGoogleAuthService.onCurrentUserChanged.listen((
        acc,
      ) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = TransparentGoogleAuthService.isSignedIn;
          _userEmail = acc?.email;
          _userName = acc?.displayName;
        });
      });
    } catch (_) {}
  }

  void _checkAuthStatus() {
    final user = TransparentGoogleAuthService.currentUser;
    setState(() {
      _isAuthenticated = TransparentGoogleAuthService.isSignedIn;
      _userEmail = user?.email;
      _userName = user?.displayName;
    });
  }

  Future<void> _onTap() async {
    setState(() => _loading = true);
    if (!TransparentGoogleAuthService.isSignedIn) {
      final ok = await TransparentGoogleAuthService.initializeTransparentAuth();
      if (ok) {
        Get.snackbar(
          'Autenticado',
          'Sesión iniciada con Google',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Error',
          'No se pudo autenticar con Google',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } else {
      await TransparentGoogleAuthService.signOut();
      Get.snackbar(
        'Sesión',
        'Sesión cerrada',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    _checkAuthStatus();
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Cargando...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    if (!_isAuthenticated) {
      return GestureDetector(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'No autenticado',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              _userName ?? _userEmail ?? 'Autenticado',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
