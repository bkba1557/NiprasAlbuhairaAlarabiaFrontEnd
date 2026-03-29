import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/chat_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/screens/chat/chat_conversation_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

bool _canOwnerStationChatWithRole(String role) {
  final normalized = role.trim().toLowerCase();
  return normalized == 'owner' || normalized == 'admin';
}

List<ChatUser> _visibleChatUsersForCurrentUser(
  BuildContext context,
  List<ChatUser> users,
) {
  final auth = context.read<AuthProvider>();
  if (!auth.isOwnerStation) {
    return users;
  }

  return users
      .where((user) => _canOwnerStationChatWithRole(user.role))
      .toList();
}

String _userPickerEmptyMessage(
  BuildContext context, {
  required bool hasSearch,
}) {
  final auth = context.read<AuthProvider>();
  if (!auth.isOwnerStation) {
    return 'لا يوجد مستخدمون مطابقون';
  }

  return hasSearch
      ? 'لا يوجد مالك أو مدير عام مطابق لبحثك'
      : 'يظهر هنا فقط المالك والمدير العام';
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _selectedConversationId;
  ChatUser? _selectedPeer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ChatProvider>();
      await provider.fetchConversations();
      await provider.fetchUsers(silent: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final isOwner = context.select<AuthProvider, bool>(
      (auth) => auth.user?.role == 'owner',
    );
    final isSplitView = _isSplitView(MediaQuery.sizeOf(context).width);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: _showUserPicker,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          if (isOwner)
            IconButton(
              tooltip: 'إنشاء مجموعة',
              onPressed: _showGroupCreator,
              icon: const Icon(Icons.group_add_outlined),
            ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => provider.fetchConversations(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _ChatListBackground(),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final splitView = _isSplitView(constraints.maxWidth);
                final isCompact = constraints.maxWidth < 700;
                final maxWidth = constraints.maxWidth < 980
                    ? constraints.maxWidth
                    : 980.0;
                final horizontalPadding = isCompact ? 12.0 : 18.0;
                final myId =
                    context.select<AuthProvider, String?>(
                      (auth) => auth.user?.id,
                    ) ??
                    '';

                final query = _search.trim().toLowerCase();
                final source = provider.conversations;
                final conversations = query.isEmpty
                    ? source
                    : source.where((conversation) {
                        final peerName = conversation.peer?.name.trim() ?? '';
                        final title = conversation.name.trim().isNotEmpty
                            ? conversation.name.trim()
                            : peerName;
                        final lastText =
                            conversation.lastMessage?.text.trim() ?? '';
                        final haystack =
                            '${title.toLowerCase()} ${peerName.toLowerCase()} ${lastText.toLowerCase()}';
                        return haystack.contains(query);
                      }).toList();

                if (provider.isLoadingConversations &&
                    provider.conversations.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final listView = RefreshIndicator(
                  onRefresh: () => provider.fetchConversations(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: splitView ? 14 : horizontalPadding,
                      vertical: 14,
                    ),
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      if (conversations.isEmpty)
                        _buildEmptyConversations(isSearching: query.isNotEmpty)
                      else
                        ...conversations.map(
                          (conversation) => _buildConversationCard(
                            conversation,
                            myId: myId,
                            isOwner: isOwner,
                            selectedConversationId: splitView
                                ? _selectedConversationId
                                : null,
                          ),
                        ),
                      SizedBox(height: splitView ? 16 : 90),
                    ],
                  ),
                );

                if (!splitView) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: listView,
                    ),
                  );
                }

                if (_selectedConversationId == null &&
                    conversations.isNotEmpty &&
                    query.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _selectedConversationId != null) return;
                    final first = conversations.first;
                    setState(() {
                      _selectedConversationId = first.id;
                      _selectedPeer = first.type == 'group' ? null : first.peer;
                    });
                  });
                }

                final listWidth = (constraints.maxWidth * 0.38)
                    .clamp(360.0, 460.0)
                    .toDouble();
                final selectedId = _selectedConversationId;
                final conversationPaneChild = (selectedId ?? '').trim().isEmpty
                    ? _buildSplitPlaceholder()
                    : ChatConversationScreen(
                        key: ValueKey('conversation_$selectedId'),
                        initialConversationId: selectedId,
                        initialPeer: _selectedPeer,
                        embedded: true,
                        onClose: () {
                          setState(() {
                            _selectedConversationId = null;
                            _selectedPeer = null;
                          });
                        },
                      );

                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox.expand(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: listWidth,
                          child: _buildSplitSurface(child: listView),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSplitSurface(
                            child: conversationPaneChild,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isSplitView
          ? null
          : FloatingActionButton.extended(
              onPressed: _showUserPicker,
              icon: const Icon(Icons.chat),
              label: const Text('محادثة جديدة'),
            ),
    );
  }

  bool _isSplitView(double width) => kIsWeb && width >= 1100;

  Widget _buildSplitSurface({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  Widget _buildSplitPlaceholder() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.appBarWaterGlow,
                      AppColors.appBarWaterBright,
                      AppColors.appBarWaterDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appBarWaterDeep.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'اختر محادثة',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.appBarWaterDeep,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختر مستخدمًا من القائمة لعرض المحادثة هنا.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.mediumGray,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _showUserPicker,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('بدء محادثة'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.appBarWaterMid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final hasQuery = _search.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _search = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'بحث عن اسم أو رسالة...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.mediumGray.withValues(alpha: 0.9),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.appBarWaterDeep.withValues(alpha: 0.8),
          ),
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: hasQuery
                ? IconButton(
                    key: const ValueKey('clear'),
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                      FocusScope.of(context).unfocus();
                    },
                    icon: Icon(
                      Icons.close,
                      color: AppColors.mediumGray.withValues(alpha: 0.9),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppColors.appBarWaterBright.withValues(alpha: 0.55),
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyConversations({required bool isSearching}) {
    final theme = Theme.of(context);
    final title = isSearching ? 'لا توجد نتائج' : 'لا توجد محادثات حاليا';
    final subtitle = isSearching
        ? 'جرّب كلمة أخرى أو ابدأ محادثة جديدة.'
        : 'ابدأ محادثة جديدة مع أحد المستخدمين.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.appBarWaterGlow,
                          AppColors.appBarWaterBright,
                          AppColors.appBarWaterDeep,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appBarWaterDeep.withValues(
                            alpha: 0.18,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.appBarWaterDeep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showUserPicker,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('بدء محادثة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appBarWaterMid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(
    ChatConversation conversation, {
    required String myId,
    required bool isOwner,
    String? selectedConversationId,
  }) {
    final theme = Theme.of(context);
    final peer = conversation.peer;
    final isGroup = conversation.type == 'group';
    final isSelected =
        (selectedConversationId ?? '').trim().isNotEmpty &&
        conversation.id == selectedConversationId;

    final typingIds = conversation.typingUserIds
        .where((id) => id.trim().isNotEmpty && id != myId)
        .toList();
    final isTyping = typingIds.isNotEmpty;

    final lastMessage = conversation.lastMessage;
    final baseTitle = conversation.name.trim().isNotEmpty
        ? conversation.name.trim()
        : (peer?.name.trim().isNotEmpty == true ? peer!.name.trim() : 'دردشة');

    final subtitle = () {
      if (isTyping) {
        return Text(
          typingIds.length > 1 ? 'يكتبون...' : 'يكتب...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.successGreen,
            fontWeight: FontWeight.w700,
          ),
        );
      }
      if (lastMessage == null) {
        return Text(
          'لا توجد رسائل بعد',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.mediumGray.withValues(alpha: 0.9),
          ),
        );
      }

      final isMine =
          lastMessage.senderId.trim().isNotEmpty &&
          lastMessage.senderId == myId;
      final senderPrefix =
          isGroup && !isMine && lastMessage.senderName.trim().isNotEmpty
          ? '${lastMessage.senderName.trim()}: '
          : isMine
          ? 'أنت: '
          : '';

      final messageText = lastMessage.text.trim().isNotEmpty
          ? lastMessage.text.trim()
          : '...';

      final attachmentKind = lastMessage.attachmentKind.trim();
      final attachmentIcon = _attachmentKindIcon(attachmentKind);
      final showAttachment =
          attachmentIcon != null &&
          attachmentKind.isNotEmpty &&
          attachmentKind != 'none';

      return Row(
        children: [
          if (showAttachment)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Icon(
                attachmentIcon,
                size: 18,
                color: AppColors.appBarWaterMid.withValues(alpha: 0.95),
              ),
            ),
          Expanded(
            child: Text(
              '$senderPrefix$messageText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mediumGray.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      );
    }();

    final stamp =
        lastMessage?.sentAt ?? conversation.updatedAt ?? conversation.createdAt;
    final timeText = stamp == null ? '' : _formatTime(stamp);
    final unread = conversation.unreadCount < 0 ? 0 : conversation.unreadCount;
    final showUnread = unread > 0;
    final unreadText = unread > 99 ? '99+' : unread.toString();

    final avatar = isGroup
        ? _GroupAvatar(radius: 24, avatarUrl: conversation.resolvedAvatarUrl)
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.appBarWaterGlow,
                      AppColors.appBarWaterBright,
                      AppColors.appBarWaterDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appBarWaterDeep.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(baseTitle),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -1,
                start: -1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _presenceColor(peer),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isSelected ? 0.98 : 0.90),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.appBarWaterBright.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.70),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              _openConversation(
                conversationId: conversation.id,
                peer: isGroup ? null : peer,
              );
            },
            onLongPress: isOwner
                ? () => _showConversationOwnerActions(conversation)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          baseTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.appBarWaterDeep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        subtitle,
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGray.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (showUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.appBarWaterBright,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.appBarWaterBright.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            unreadText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData? _attachmentKindIcon(String kind) {
    switch (kind) {
      case 'image':
        return Icons.photo_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.mic_none_outlined;
      case 'file':
        return Icons.insert_drive_file_outlined;
      case 'mixed':
        return Icons.attach_file;
      default:
        return null;
    }
  }

  Future<void> _showUserPicker() async {
    final provider = context.read<ChatProvider>();
    if (provider.users.isEmpty) {
      await provider.fetchUsers();
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ChatUserPicker(
          onSelect: (user) async {
            Navigator.pop(sheetContext);
            final conversation = await provider.startDirectConversation(
              user.id,
            );
            if (!mounted || conversation == null) return;
            _openConversation(
              conversationId: conversation.id,
              peer: conversation.peer ?? user,
            );
          },
        );
      },
    );
  }

  Future<void> _showGroupCreator() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ChatProvider>();
    if (auth.user?.role != 'owner') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فقط المالك يمكنه إنشاء مجموعة')),
      );
      return;
    }

    if (provider.users.isEmpty) {
      await provider.fetchUsers();
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ChatGroupCreatorSheet(
          onCreate: (selection) async {
            final selectedIds = selection.users.map((user) => user.id).toList();
            final conversation = await provider.startGroupConversation(
              selectedIds,
              name: selection.groupName,
              avatarPath: selection.avatarPath,
              avatarBytes: selection.avatarBytes,
              avatarFileName: selection.avatarFileName,
            );
            if (conversation == null) {
              if (!sheetContext.mounted) return;
              final error = provider.error?.trim();
              if ((error ?? '').isNotEmpty) {
                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text(error!)));
              }
              return;
            }

            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
            if (!mounted) return;
            _openConversation(conversationId: conversation.id);
          },
        );
      },
    );
  }

  Future<void> _showConversationOwnerActions(
    ChatConversation conversation,
  ) async {
    final isOwner = context.read<AuthProvider>().user?.role == 'owner';
    if (!isOwner) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conversation.type == 'group')
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('تعديل المجموعة'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditConversationGroupSheet(conversation);
                  },
                ),
              if (conversation.type == 'group')
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('إدارة الأعضاء'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openConversation(conversationId: conversation.id);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.errorRed,
                ),
                title: Text(
                  conversation.type == 'group'
                      ? 'حذف المجموعة'
                      : 'حذف المحادثة',
                  style: const TextStyle(color: AppColors.errorRed),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteConversationEntry(conversation);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditConversationGroupSheet(
    ChatConversation conversation,
  ) async {
    final provider = context.read<ChatProvider>();
    final imagePicker = ImagePicker();
    final nameController = TextEditingController(text: conversation.name);

    Uint8List? avatarBytes;
    String? avatarPath;
    String? avatarFileName;
    bool removeAvatar = false;
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'تعديل المجموعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'اسم المجموعة',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.appBarWaterMid.withValues(
                            alpha: 0.15,
                          ),
                          backgroundImage: avatarBytes != null
                              ? MemoryImage(avatarBytes!)
                              : (!removeAvatar &&
                                        conversation.resolvedAvatarUrl
                                            .trim()
                                            .isNotEmpty
                                    ? NetworkImage(
                                        conversation.resolvedAvatarUrl,
                                      )
                                    : null),
                          child:
                              (avatarBytes == null &&
                                  removeAvatar &&
                                  conversation.resolvedAvatarUrl.trim().isEmpty)
                              ? const Icon(Icons.groups_2_outlined)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: submitting
                                    ? null
                                    : () async {
                                        final picked = await imagePicker
                                            .pickImage(
                                              source: ImageSource.gallery,
                                              imageQuality: 86,
                                              maxWidth: 1400,
                                            );
                                        if (picked == null) return;
                                        final bytes = await picked
                                            .readAsBytes();
                                        if (!sheetContext.mounted) return;
                                        setSheetState(() {
                                          avatarBytes = bytes;
                                          avatarPath = picked.path;
                                          avatarFileName =
                                              picked.name.trim().isNotEmpty
                                              ? picked.name
                                              : null;
                                          removeAvatar = false;
                                        });
                                      },
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('اختيار صورة'),
                              ),
                              TextButton.icon(
                                onPressed: submitting
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          avatarBytes = null;
                                          avatarPath = null;
                                          avatarFileName = null;
                                          removeAvatar = true;
                                        });
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('حذف الصورة'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                setSheetState(() => submitting = true);
                                final updated = await provider
                                    .updateGroupConversation(
                                      conversation.id,
                                      name: nameController.text.trim(),
                                      avatarPath: avatarPath,
                                      avatarBytes: avatarBytes,
                                      avatarFileName: avatarFileName,
                                      removeAvatar: removeAvatar,
                                    );
                                if (!sheetContext.mounted) return;
                                setSheetState(() => submitting = false);
                                if (updated != null) {
                                  Navigator.pop(sheetContext);
                                  return;
                                }
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      provider.error?.trim().isNotEmpty == true
                                          ? provider.error!.trim()
                                          : 'تعذر تعديل المجموعة',
                                    ),
                                  ),
                                );
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(submitting ? 'جاري الحفظ...' : 'حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _deleteConversationEntry(ChatConversation conversation) async {
    final provider = context.read<ChatProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            conversation.type == 'group' ? 'حذف المجموعة' : 'حذف المحادثة',
          ),
          content: Text(
            conversation.type == 'group'
                ? 'هل تريد حذف هذه المجموعة نهائياً؟'
                : 'هل تريد حذف هذه المحادثة نهائياً؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.errorRed,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final ok = await provider.deleteConversation(conversation.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم الحذف' : (provider.error ?? 'تعذر الحذف')),
      ),
    );
  }

  void _openConversation({required String conversationId, ChatUser? peer}) {
    if (_isSplitView(MediaQuery.sizeOf(context).width)) {
      FocusScope.of(context).unfocus();
      setState(() {
        _selectedConversationId = conversationId;
        _selectedPeer = peer;
      });
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.chatConversation,
      arguments: {
        'conversationId': conversationId,
        if (peer != null) 'peer': peer.toJson(),
      },
    );
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  DateTime _toSaudiTime(DateTime value) {
    final utc = value.isUtc ? value : value.toUtc();
    return utc.add(const Duration(hours: 3));
  }

  bool _seenWithinHour(ChatUser? user) {
    final seen = user?.lastSeenAt;
    if (seen == null || user?.isOnline == true) return false;
    final delta = DateTime.now().toUtc().difference(seen.toUtc());
    return delta.inMinutes >= 0 && delta.inMinutes <= 60;
  }

  Color _presenceColor(ChatUser? user) {
    if (user?.isOnline == true) return AppColors.successGreen;
    if (_seenWithinHour(user)) return AppColors.infoBlue;
    return AppColors.silverDark;
  }

  String _formatTime(DateTime dateTime) {
    final saudiNow = _toSaudiTime(DateTime.now().toUtc());
    final saudiTime = _toSaudiTime(dateTime);
    final sameDay =
        saudiNow.year == saudiTime.year &&
        saudiNow.month == saudiTime.month &&
        saudiNow.day == saudiTime.day;
    if (sameDay) {
      return DateFormat('h:mm a', 'en').format(saudiTime);
    }
    return DateFormat('dd/MM').format(saudiTime);
  }
}

class _ChatListBackground extends StatelessWidget {
  const _ChatListBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: const [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF6F8FE),
                    Color(0xFFF2F5FC),
                    Color(0xFFEEF2FA),
                  ],
                ),
              ),
            ),
            _SoftBlob(
              alignment: Alignment(-1.05, -0.65),
              size: 520,
              color: Color(0x336BCBFF),
            ),
            _SoftBlob(
              alignment: Alignment(1.05, -0.25),
              size: 460,
              color: Color(0x2626D0CE),
            ),
            _SoftBlob(
              alignment: Alignment(0.0, 1.1),
              size: 540,
              color: Color(0x1A1D4ED8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _SoftBlob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

class _ChatUserPicker extends StatefulWidget {
  final ValueChanged<ChatUser> onSelect;

  const _ChatUserPicker({required this.onSelect});

  @override
  State<_ChatUserPicker> createState() => _ChatUserPickerState();
}

class _ChatUserPickerState extends State<_ChatUserPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final isOwnerStation = context.select<AuthProvider, bool>(
      (auth) => auth.isOwnerStation,
    );
    final source = _visibleChatUsersForCurrentUser(context, provider.users);

    final filtered = source.where((user) {
      if (_search.trim().isEmpty) return true;
      final text = _search.toLowerCase();
      return user.name.toLowerCase().contains(text) ||
          user.email.toLowerCase().contains(text) ||
          user.company.toLowerCase().contains(text);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                isOwnerStation ? 'اختر المالك أو المدير العام' : 'اختر مستخدم',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: isOwnerStation
                    ? 'بحث باسم المالك أو المدير العام'
                    : 'بحث بالاسم أو البريد',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            if (provider.isLoadingUsers)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _userPickerEmptyMessage(
                    context,
                    hasSearch: _search.trim().isNotEmpty,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.name.trim().isNotEmpty
                              ? user.name.trim()[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      onTap: () => widget.onSelect(user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupCreateSelection {
  final String groupName;
  final List<ChatUser> users;
  final String? avatarPath;
  final Uint8List? avatarBytes;
  final String? avatarFileName;

  const _GroupCreateSelection({
    required this.groupName,
    required this.users,
    this.avatarPath,
    this.avatarBytes,
    this.avatarFileName,
  });
}

class _ChatGroupCreatorSheet extends StatefulWidget {
  final Future<void> Function(_GroupCreateSelection selection) onCreate;

  const _ChatGroupCreatorSheet({required this.onCreate});

  @override
  State<_ChatGroupCreatorSheet> createState() => _ChatGroupCreatorSheetState();
}

class _ChatGroupCreatorSheetState extends State<_ChatGroupCreatorSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  final ImagePicker _imagePicker = ImagePicker();

  String _search = '';
  bool _submitting = false;
  Uint8List? _avatarBytes;
  String? _avatarPath;
  String? _avatarFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final source = provider.users;
    final filtered = source.where((user) {
      if (_search.trim().isEmpty) return true;
      final text = _search.toLowerCase();
      return user.name.toLowerCase().contains(text) ||
          user.email.toLowerCase().contains(text) ||
          user.company.toLowerCase().contains(text);
    }).toList();
    final canCreate = !_submitting && _selectedIds.length >= 2;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'إنشاء مجموعة جديدة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'اسم المجموعة',
                hintText: 'مثال: فريق التشغيل',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _GroupAvatarPickerPreview(bytes: _avatarBytes),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickGroupAvatar,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          _avatarBytes == null
                              ? 'اختيار صورة للمجموعة'
                              : 'تغيير الصورة',
                        ),
                      ),
                      if (_avatarBytes != null)
                        TextButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => setState(() {
                                  _avatarBytes = null;
                                  _avatarPath = null;
                                  _avatarFileName = null;
                                }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف الصورة'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'ابحث عن مستخدم',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اختر عضوين على الأقل (${_selectedIds.length} محدد)',
                style: const TextStyle(color: AppColors.mediumGray),
              ),
            ),
            const SizedBox(height: 8),
            if (provider.isLoadingUsers)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا يوجد مستخدمون مطابقون'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final selected = _selectedIds.contains(user.id);
                    return CheckboxListTile(
                      value: selected,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIds.add(user.id);
                          } else {
                            _selectedIds.remove(user.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canCreate ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add_outlined),
                label: Text(_submitting ? 'جارٍ الإنشاء...' : 'إنشاء المجموعة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting || _selectedIds.length < 2) return;
    final provider = context.read<ChatProvider>();
    final users = provider.users
        .where((user) => _selectedIds.contains(user.id))
        .toList();
    setState(() => _submitting = true);
    await widget.onCreate(
      _GroupCreateSelection(
        groupName: _nameController.text.trim(),
        users: users,
        avatarPath: _avatarPath,
        avatarBytes: _avatarBytes,
        avatarFileName: _avatarFileName,
      ),
    );
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _pickGroupAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1400,
    );
    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarPath = picked.path;
      _avatarFileName = picked.name.trim().isNotEmpty ? picked.name : null;
    });
  }
}

class _GroupAvatar extends StatelessWidget {
  final double radius;
  final String avatarUrl;

  const _GroupAvatar({required this.radius, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl.trim().isNotEmpty;
    if (!hasAvatar) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.appBarWaterMid.withValues(alpha: 0.15),
        child: const Icon(
          Icons.groups_2_outlined,
          color: AppColors.appBarWaterDeep,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.appBarWaterMid.withValues(alpha: 0.15),
            child: const Icon(
              Icons.groups_2_outlined,
              color: AppColors.appBarWaterDeep,
            ),
          );
        },
      ),
    );
  }
}

class _GroupAvatarPickerPreview extends StatelessWidget {
  final Uint8List? bytes;

  const _GroupAvatarPickerPreview({required this.bytes});

  @override
  Widget build(BuildContext context) {
    if (bytes == null || bytes!.isEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.appBarWaterMid.withValues(alpha: 0.15),
        child: const Icon(
          Icons.groups_2_outlined,
          color: AppColors.appBarWaterDeep,
        ),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundImage: MemoryImage(bytes!),
      backgroundColor: Colors.transparent,
    );
  }
}
