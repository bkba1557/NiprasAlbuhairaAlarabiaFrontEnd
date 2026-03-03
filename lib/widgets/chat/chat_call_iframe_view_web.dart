import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildChatCallIFrameView({required String callUrl}) {
  final viewType =
      'chat-call-iframe-${DateTime.now().microsecondsSinceEpoch.toString()}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final frame = web.HTMLIFrameElement()
      ..src = callUrl
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'camera; microphone; fullscreen; autoplay; display-capture';
    return frame;
  });

  return HtmlElementView(viewType: viewType);
}
