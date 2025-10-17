// Public entry for GSI sign-in button. Uses web implementation when available,
// otherwise falls back to a simple button that triggers the existing flow.
export 'gsi_signin_button_stub.dart'
    if (dart.library.html) 'gsi_signin_button_web.dart';
