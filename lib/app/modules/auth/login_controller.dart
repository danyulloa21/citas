import 'dart:async';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class LoginController extends GetxController {
  StreamSubscription<AuthState>? _authSub; // ⭐️ Evitar múltiples listeners
  bool _navigating = false; // ⭐️ Anti-bucle de navegación

  @override
  void onInit() {
    super.onInit();
    // ⭐️ Listener centralizado del estado de autenticación (única suscripción)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn) {
        // Cierra spinners si volvemos del deep link
        loading.value = false;
        final ok = await insertarUsuario();
        if (!ok) {
          await Supabase.instance.client.auth.signOut();
          return;
        }
        // Navega solo si no estamos en /home y no hay navegación en curso
        if (!_navigating && Get.currentRoute != '/home') {
          _navigating = true; // ⭐️ antirrebote
          Get.offAllNamed('/home');
          Future.delayed(const Duration(milliseconds: 200), () {
            _navigating = false;
          });
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // Navega solo si no estamos en /login y no hay navegación en curso
        if (!_navigating && Get.currentRoute != '/login') {
          _navigating = true; // ⭐️ antirrebote
          Get.offAllNamed('/login');
          Future.delayed(const Duration(milliseconds: 200), () {
            _navigating = false;
          });
        }
      }
    });
  }

  final email = ''.obs;
  final password = ''.obs;
  final loading = false.obs;

  bool _isValidEmail(String e) {
    final re = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    return re.hasMatch(e);
  }

  Future<void> signIn() async {
    if (email.value.isEmpty || password.value.isEmpty) {
      Get.snackbar('Atención', 'Email y contraseña son obligatorios');
      return;
    }
    if (!_isValidEmail(email.value)) {
      Get.snackbar('Atención', 'Ingresa un email válido');
      return;
    }
    loading.value = true;
    try {
      final resp = await SupabaseService.instance.signIn(
        email: email.value,
        password: password.value,
      );
      if (resp['error'] != null) {
        Get.snackbar('Error', resp['error'].toString());
      } else {
        final ok = await insertarUsuario();
        if (!ok) {
          // ⭐️ Si no se pudo crear/sincronizar el perfil, cerramos sesión y NO avanzamos
          await Supabase.instance.client.auth.signOut();
          return;
        }
        // ⭐️ La navegación a /home la hará el listener en AuthChangeEvent.signedIn
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> signUp() async {
    if (email.value.isEmpty || password.value.isEmpty) {
      Get.snackbar('Atención', 'Email y contraseña son obligatorios');
      return;
    }
    if (!_isValidEmail(email.value)) {
      Get.snackbar('Atención', 'Ingresa un email válido');
      return;
    }
    if (password.value.length < 6) {
      Get.snackbar(
        'Atención',
        'La contraseña debe tener al menos 6 caracteres',
      );
      return;
    }

    loading.value = true;
    try {
      final resp = await SupabaseService.instance.signUp(
        email: email.value,
        password: password.value,
      );
      if (resp['error'] != null) {
        Get.snackbar('Error', resp['error'].toString());
      } else {
        Get.snackbar(
          'Listo',
          'Registro completado. Revisa tu email para confirmar.',
        );
        final ok = await insertarUsuario();
        if (!ok) {
          await Supabase.instance.client.auth.signOut();
          return;
        }
        // ⭐️ La navegación a /home la hará el listener en AuthChangeEvent.signedIn
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> forgotPassword() async {
    if (email.value.isEmpty) {
      Get.snackbar('Atención', 'Ingresa tu email para recuperar la contraseña');
      return;
    }
    if (!_isValidEmail(email.value)) {
      Get.snackbar('Atención', 'Ingresa un email válido');
      return;
    }
    loading.value = true;
    try {
      final resp = await SupabaseService.instance.resetPassword(
        email: email.value,
      );
      if (resp['error'] != null) {
        Get.snackbar('Error', resp['error'].toString());
      } else {
        Get.snackbar(
          'Listo',
          'Se envió un email para restablecer la contraseña',
        );
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    if (loading.value) return;
    loading.value = true;
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.vetcitas.app://login-callback', // tu deep link
        authScreenLaunchMode: LaunchMode
            .externalApplication, // ⭐️ Usa ASWebAuthenticationSession/Custom Tabs
        scopes: 'email profile openid',
        queryParams: {'prompt': 'select_account'},
      );
      // ⭐️ El upsert del perfil se ejecutará al recibir AuthChangeEvent.signedIn
      // La sesión se establecerá al regresar por deep link
    } on AuthException catch (e) {
      Get.snackbar(
        'Error de autenticación',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  Future<bool> insertarUsuario() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'No hay sesión activa para crear el perfil');
      return false;
    }
    final meta = user.userMetadata ?? {};
    final nombre = (meta['name'] as String?) ?? '';
    final email = user.email ?? '';

    try {
      // ⭐️ Usamos select() para asegurarnos que el UPSERT devolvió fila(s)
      final data = await Supabase.instance.client
          .from('usuarios')
          .upsert({
            'user_id': user.id, // UUID de auth.users
            'email': email,
            'nombre': nombre,
            'estatus': true,
          }, onConflict: 'user_id')
          .select('user_id');

      final ok = (data.isNotEmpty);
      if (!ok) {
        Get.snackbar(
          'Aviso',
          'No se pudo sincronizar tu perfil. Intenta de nuevo.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      return true;
    } catch (e) {
      // ⭐️ Bloqueamos avance si falla
      Get.snackbar(
        'Aviso',
        'No se pudo sincronizar el perfil: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _authSub = null;
    super.onClose();
  }
}
