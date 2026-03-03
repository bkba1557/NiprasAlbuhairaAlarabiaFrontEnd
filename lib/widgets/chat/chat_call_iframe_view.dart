import 'package:flutter/widgets.dart';

import 'chat_call_iframe_view_stub.dart'
    if (dart.library.html) 'chat_call_iframe_view_web.dart'
    as impl;

Widget buildChatCallIFrameView({required String callUrl}) {
  return impl.buildChatCallIFrameView(callUrl: callUrl);
}
