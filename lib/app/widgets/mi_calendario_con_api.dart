/* import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_auth_service.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'calendar_api_widget.dart';
import 'dart:io' show Platform;

class MiCalendarioConAPI extends StatefulWidget {
  const MiCalendarioConAPI({super.key});

  @override
  State<MiCalendarioConAPI> createState() => _MiCalendarioConAPIState();
}

class _MiCalendarioConAPIState extends State<MiCalendarioConAPI> {
  GoogleSignInAccount? _googleUser = TransparentGoogleAuthService.currentUser;
  bool _isPlatformUnsupported = false;
  User? _supabaseUser = SupabaseService.instance.client.auth.currentUser;

  StreamSubscription<GoogleSignInAccount?>? _gSub;
  StreamSubscription<AuthState>? _sSub;

  @override
  void initState() {
    super.initState();
    _isPlatformUnsupported = _computePlatformUnsupported();

    // Listen to google sign-in changes
    _gSub = TransparentGoogleAuthService.onCurrentUserChanged.listen((u) {
      setState(() {
        _googleUser = u;
      });
    });

    // Listen to Supabase auth changes
    try {
      _sSub = SupabaseService.instance.authStateChanges.listen((_) {
        setState(() {
          try {
            _supabaseUser = SupabaseService.instance.client.auth.currentUser;
          } catch (e) {
            _supabaseUser = null;
          }
        });
      });
    } catch (e) {
      // ignore
    }
  }

  bool _computePlatformUnsupported() {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _gSub?.cancel();
    _sSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _googleUser != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _isPlatformUnsupported
                    ? Icons.warning
                    : (isAuthenticated
                          ? Icons.event_available
                          : Icons.warning_amber),
                color: _isPlatformUnsupported
                    ? Colors.red
                    : (isAuthenticated ? Colors.green : Colors.orange),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Calendario',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: _isPlatformUnsupported
                                ? Colors.red
                                : (isAuthenticated
                                      ? Colors.green
                                      : Colors.orange),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Row(
                      children: [
                        Icon(
                          _isPlatformUnsupported
                              ? Icons.error
                              : (isAuthenticated
                                    ? Icons.verified_user
                                    : Icons.warning_amber),
                          size: 16,
                          color: _isPlatformUnsupported
                              ? Colors.red.shade600
                              : (isAuthenticated
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _isPlatformUnsupported
                                ? 'Funcionalidad limitada en esta plataforma'
                                : (isAuthenticated
                                      ? 'Conectado: ${_googleUser?.displayName ?? _googleUser?.email ?? "Usuario autenticado"}'
                                      : (_supabaseUser != null
                                            ? 'Cuenta app conectada pero Google no vinculado'
                                            : 'No autenticado')),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _isPlatformUnsupported
                                      ? Colors.red.shade600
                                      : (isAuthenticated
                                            ? Colors.green.shade600
                                            : Colors.orange.shade600),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isAuthenticated && !_isPlatformUnsupported) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.api,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Usando Google Calendar API',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.blue.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _isPlatformUnsupported
                ? _buildPlatformUnsupportedView(context)
                : (isAuthenticated
                      ? const GoogleCalendarApiWidget(height: 500)
                      : _buildNotAuthenticatedView(context)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlatformUnsupportedView(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.desktop_access_disabled,
            size: 64,
            color: Colors.red.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Plataforma no soportada',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'El calendario de Google no está disponible en esta plataforma. Te recomendamos usar la versión web.',
              style: TextStyle(color: Colors.red.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Usa la versión web para acceso completo',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotAuthenticatedView(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 64, color: Colors.orange.shade600),
          const SizedBox(height: 16),
          Text(
            'Autenticación requerida',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Necesitas autenticarte con Google para ver tu calendario',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          if (_supabaseUser != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Si la app ya tiene sesión en Supabase, permitimos iniciar
                  // el flujo de OAuth para vincular la cuenta de Google en el
                  // backend (abre navegador/external app).
                  try {
                    await Supabase.instance.client.auth.signInWithOAuth(
                      OAuthProvider.google,
                      redirectTo: 'com.vetcitas.app://login-callback',
                      authScreenLaunchMode: LaunchMode.externalApplication,
                      scopes: 'email profile openid',
                      queryParams: {'prompt': 'select_account'},
                    );
                  } catch (e) {
                    // fallback: intentar login local con google_sign_in
                    await TransparentGoogleAuthService.initializeTransparentAuth();
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Vincular cuenta de Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: () async {
              await TransparentGoogleAuthService.initializeTransparentAuth();
            },
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión con Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
 */
