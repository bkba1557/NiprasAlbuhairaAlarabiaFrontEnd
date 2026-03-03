typedef PlatformViewFactory = Object Function(int viewId);

void registerViewFactory(String viewType, PlatformViewFactory factory) {}
