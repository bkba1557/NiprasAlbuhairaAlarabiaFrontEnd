import 'dart:ui_web' as ui;

void registerViewFactory(String viewType, ui.PlatformViewFactory factory) {
  ui.platformViewRegistry.registerViewFactory(viewType, factory);
}
