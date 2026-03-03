import 'package:flutter/material.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:provider/provider.dart';

class ChatFloatingButton extends StatelessWidget {
  final String heroTag;
  final bool mini;
  final bool enableBadge;

  const ChatFloatingButton({
    super.key,
    required this.heroTag,
    this.mini = false,
    this.enableBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<ChatProvider>().totalUnread;

    return Badge(
      isLabelVisible: enableBadge && unread > 0,
      label: Text(unread > 99 ? '99+' : unread.toString()),
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: mini,
        tooltip: 'المحادثات',
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.chat);
        },
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
