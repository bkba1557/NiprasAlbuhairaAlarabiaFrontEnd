import 'package:flutter/widgets.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

Widget buildWebDropzone({
  void Function(dynamic controller)? onCreated,
  VoidCallback? onHover,
  VoidCallback? onLeave,
  Future<void> Function(dynamic event)? onDrop,
}) {
  return DropzoneView(
    onCreated: (controller) => onCreated?.call(controller),
    onHover: onHover,
    onLeave: onLeave,
    onDrop: (event) async {
      if (onDrop != null) {
        await onDrop(event);
      }
    },
  );
}
