import 'dart:ui' as ui;

void registerViewFactory(String viewType, ui.PlatformViewFactory factory) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, factory);
}
