// Web implementation of the GSI sign-in button. Uses JS interop to render
// the Google Identity Services button and listen for credential responses.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:agenda_citas/app/services/google_auth_service.dart';

class GsiSignInButton extends StatefulWidget {
  final VoidCallback? onPressed; // fallback
  const GsiSignInButton({super.key, this.onPressed});

  @override
  State<GsiSignInButton> createState() => _GsiSignInButtonState();
}

class _GsiSignInButtonState extends State<GsiSignInButton> {
  late final html.DivElement _container;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  int _attempts = 0;
  late final String _containerId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _containerId =
          'gsi-button-container-\${DateTime.now().microsecondsSinceEpoch}';
      scheduleMicrotask(() {
        _createContainer();
        _initAndRender();
      });
    }
  }

  void _createContainer() {
    final doc = html.document;
    _container = html.DivElement()..id = _containerId;
    // Inline display so it doesn't block layout; styling can be adjusted as needed
    _container.style.display = 'inline-block';
    try {
      doc.body!.append(_container);
    } catch (_) {}
  }

  void _initAndRender() {
    final clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
    _attempts = 0;
    _tryInitRender(clientId);
  }

  void _tryInitRender(String clientId) {
    _attempts++;
    try {
      // Call the global init helper exposed in index.html
      final inited = js_util.callMethod(js.context, '__agenda_citas_gsi_init', [
        clientId,
      ]);
      if (inited == true) {
        // Now request render into our container
        js_util.callMethod(js.context, '__agenda_citas_gsi_render', [
          _containerId,
          js_util.jsify({
            'theme': 'outline',
            'size': 'large',
            'type': 'standard',
          }),
        ]);
        return;
      }
    } catch (e) {
      // ignore and retry
    }

    if (_attempts < 8) {
      _retryTimer = Timer(
        Duration(milliseconds: 500),
        () => _tryInitRender(clientId),
      );
    } else {
      // Give up after several attempts; the fallback button will be visible.
    }
  }

  // _renderGsi removed - rendering is handled via index.html helpers (__agenda_citas_gsi_init / __agenda_citas_gsi_render)

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    try {
      _container.remove();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Render a small placeholder; real button lives in DOM (the user will see it).
    // Provide also a fallback interactive button that calls existing flow.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed:
              widget.onPressed ??
              () => TransparentGoogleAuthService.initializeTransparentAuth(),
          icon: const Icon(Icons.login),
          label: const Text('Iniciar sesión con Google'),
        ),
      ],
    );
  }
}
