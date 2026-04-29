import 'web_env_stub.dart'
    if (dart.library.html) 'web_env_web.dart';

/// Returns the current browser protocol on web (e.g. `http:` / `https:`).
/// Returns `null` on non-web platforms.
String? get webProtocol => webProtocolImpl();

