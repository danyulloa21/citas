import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
// Conditional import: web implementation will use dart:html, other platforms use stub.
import 'web_message_listener_stub.dart'
    if (dart.library.html) 'web_message_listener_web.dart';

class TransparentGoogleAuthService {
  static GoogleSignIn? _googleSignIn;
  static GoogleSignInAccount? _currentUser;
  static Map<String, String>? _authHeaders;
  // Expose a stream so UI widgets can react to auth changes
  static bool _listenerAttached = false;
  // Broadcast controller to notify app about auth changes
  static final StreamController<GoogleSignInAccount?> _userController =
      StreamController<GoogleSignInAccount?>.broadcast();

  // Scopes necesarios para Google Calendar
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  static GoogleSignIn get _instance {
    if (_googleSignIn == null) {
      final clientId = dotenv.env['GOOGLE_CLIENT_ID'];

      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: _scopes,
          // Configuración específica para web
          signInOption: SignInOption.standard,
        );
      } else {
        _googleSignIn = GoogleSignIn(
          scopes: _scopes,
          signInOption: SignInOption.standard,
        );
      }

      // Attach listener once when instance is created
      // (GoogleSignIn exposes onCurrentUserChanged)
      if (!_listenerAttached) {
        _listenerAttached = true;
        _googleSignIn!.onCurrentUserChanged.listen((account) async {
          _currentUser = account;
          if (account != null) {
            await _setupAuthHeaders();
          } else {
            _authHeaders = null;
          }
          // Emit the change to any listeners
          try {
            _userController.add(_currentUser);
          } catch (_) {}
          // Debug print to help trace issues
          try {
            print('🔁 onCurrentUserChanged -> ${account?.email}');
          } catch (_) {}
        });
      }
    }

    // On web, listen for GSI credential responses forwarded from index.html
    if (kIsWeb) {
      try {
        addGsiMessageListener((msg) {
          try {
            final credential = msg['credential'] as String?;
            if (credential != null && credential.isNotEmpty) {
              // Silent sign-in disabled: force interactive sign-in to ensure
              // consistent behavior across platforms.
              _googleSignIn
                  ?.signIn()
                  .then((acct) async {
                    _currentUser = acct;
                    if (_currentUser != null) await _setupAuthHeaders();
                    _userController.add(_currentUser);
                  })
                  .catchError((e) {
                    _userController.add(null);
                  });
            }
          } catch (e) {
            // ignore
          }
        });
      } catch (e) {
        // ignore
      }
    }
    return _googleSignIn!;
  }

  // Getter para usuario actual
  static GoogleSignInAccount? get currentUser => _currentUser;

  // Getter para verificar si está logueado
  static bool get isSignedIn => _currentUser != null;

  // Getter para headers de autenticación
  static Map<String, String>? get authHeaders => _authHeaders;

  // Public stream for UI to listen to auth changes
  static Stream<GoogleSignInAccount?> get onCurrentUserChanged {
    // Ensure instance is initialized so the underlying stream exists
    _instance;
    // Return a stream that emits the current user immediately upon
    // subscription, then forwards subsequent events from the broadcast
    // controller. This avoids UI inconsistencies where UI reads the
    // current user separately from listening to changes.
    return Stream<GoogleSignInAccount?>.multi((controller) async {
      // Emit the current user immediately
      try {
        controller.add(_currentUser);
      } catch (_) {}

      // Forward future events
      final sub = _userController.stream.listen((u) {
        try {
          controller.add(u);
        } catch (_) {}
      });

      // Cancel forwarding when the subscriber cancels
      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  // Verificar si la plataforma soporta Google Sign-In
  static bool get _isPlatformSupported {
    if (kIsWeb) return true;

    try {
      if (!kIsWeb && Platform.isMacOS) {
        print('⚠️ macOS detectado - autenticación puede ser limitada');
        return false;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  // Inicialización automática y transparente
  static Future<bool> initializeTransparentAuth() async {
    try {
      print('🔐 Iniciando autenticación transparente...');

      if (!_isPlatformSupported) {
        print('⚠️ Plataforma no soportada para Google Sign-In');
        return false;
      }

      // Use interactive sign-in by default on all platforms. We disable
      // silent sign-in to avoid inconsistent web behaviors.
      print('⚠️ Intentando login interactivo (silent sign-in deshabilitado)');
      final interactiveUser = await _instance.signIn();

      if (interactiveUser != null) {
        print('✅ Login interactivo exitoso: ${interactiveUser.email}');
        _currentUser = interactiveUser;
        await _setupAuthHeaders();
        // Notify listeners
        try {
          _userController.add(_currentUser);
        } catch (_) {}
        return true;
      }

      print('❌ No se pudo autenticar');
      return false;
    } catch (error) {
      print('❌ Error en autenticación transparente: $error');
      return false;
    }
  }

  // Configurar headers de autenticación para requests HTTP
  static Future<void> _setupAuthHeaders() async {
    if (_currentUser == null) return;

    try {
      final auth = await _currentUser!.authentication;
      _authHeaders = {
        'Authorization': 'Bearer ${auth.accessToken}',
        'Content-Type': 'application/json',
      };
      print('✅ Headers de autenticación configurados');
    } catch (error) {
      print('❌ Error configurando headers: $error');
    }
  }

  // Obtener URL del calendario con token de acceso
  static Future<String?> getAuthenticatedCalendarUrl() async {
    if (!isSignedIn) {
      print('❌ Usuario no autenticado para URL del calendario');
      return null;
    }

    try {
      print('🔍 Obteniendo autenticación para calendario...');
      final auth = await _currentUser!.authentication;

      print('🔍 Access token disponible: ${auth.accessToken != null}');
      print('🔍 ID token disponible: ${auth.idToken != null}');

      if (auth.accessToken == null) {
        print('❌ No hay access token disponible');
        return null;
      }

      const baseUrl = 'https://calendar.google.com/calendar/embed';
      const calendarId =
          '02fe70469480b93b808fbbbbc7fbcb453059735d42171b343626393437d2314b%40group.calendar.google.com';

      final calendarUrl =
          '$baseUrl?src=$calendarId&ctz=America%2FHermosillo'
          '&showTitle=0&showNav=1&showDate=1&showCalendars=1&showTz=0'
          '&mode=WEEK&height=600&wkst=1&bgcolor=%23ffffff';

      print('✅ URL del calendario generada (sin token en URL)');
      print('🔗 URL: $calendarUrl');
      return calendarUrl;
    } catch (error) {
      print('❌ Error generando URL del calendario: $error');
      return null;
    }
  }

  static Future<bool> ensureAuthenticated() async {
    if (!isSignedIn) {
      return await initializeTransparentAuth();
    }

    try {
      final auth = await _currentUser!.authentication;
      if (auth.accessToken != null) {
        await _setupAuthHeaders();
        return true;
      }
    } catch (error) {
      print('⚠️ Token expirado, renovando autenticación...');
    }

    return await initializeTransparentAuth();
  }

  static Future<void> signOut() async {
    try {
      await _instance.signOut();
      _currentUser = null;
      _authHeaders = null;
      try {
        _userController.add(null);
      } catch (_) {}
      print('✅ Sesión cerrada');
    } catch (error) {
      print('❌ Error cerrando sesión: $error');
    }
  }

  static http.Client? getAuthenticatedHttpClient() {
    if (_authHeaders == null) return null;

    return http.Client();
  }
}
