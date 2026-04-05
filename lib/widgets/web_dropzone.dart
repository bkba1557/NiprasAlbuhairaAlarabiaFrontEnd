import 'package:flutter/widgets.dart';
import 'package:order_tracker/widgets/web_dropzone_stub.dart'
    if (dart.library.html) 'package:order_tracker/widgets/web_dropzone_web.dart';

class WebDropzone extends StatelessWidget {
  final void Function(dynamic controller)? onCreated;
  final VoidCallback? onHover;
  final VoidCallback? onLeave;
  final Future<void> Function(dynamic event)? onDrop;

  const WebDropzone({
    super.key,
    this.onCreated,
    this.onHover,
    this.onLeave,
    this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return buildWebDropzone(
      onCreated: onCreated,
      onHover: onHover,
      onLeave: onLeave,
      onDrop: onDrop,
    );
  }
}
