// Web-only implementation for listening to window.postMessage and forwarding
// recognized GSI credential responses to a Dart handler.
// This file should only be used on web builds.
import 'dart:html';

void addGsiMessageListener(void Function(Map<String, dynamic>) handler) {
  window.addEventListener('message', (evt) {
    try {
      final msg = (evt as MessageEvent).data;
      if (msg is Map && msg['type'] == 'GSI_CREDENTIAL_RESPONSE') {
        handler(Map<String, dynamic>.from(msg));
      }
    } catch (e) {
      // ignore
    }
  });
}
