import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/chat_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
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
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final isOwner = context.select<AuthProvider, bool>(
      (auth) => auth.user?.role == 'owner',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات'),
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
      body: provider.isLoadingConversations && provider.conversations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.fetchConversations(),
              child: provider.conversations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 130),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 88,
                          color: Colors.blueGrey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'لا توجد محادثات بعد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'ابدأ محادثة جديدة مع أي مستخدم',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _showUserPicker,
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('بدء محادثة'),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: provider.conversations.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, index) {
                        final conversation = provider.conversations[index];
                        final isGroup = conversation.type == 'group';
                        final peer = conversation.peer;
                        final isTyping = conversation.typingUserIds.isNotEmpty;
                        final preview = isTyping
                            ? 'يكتب الآن...'
                            : conversation.lastMessage?.text
                                      .trim()
                                      .isNotEmpty ==
                                  true
                            ? conversation.lastMessage!.text.trim()
                            : 'لا توجد رسائل بعد';
                        final sentAt =
                            conversation.lastMessage?.sentAt ??
                            conversation.updatedAt;
                        final title = conversation.name.trim().isNotEmpty
                            ? conversation.name.trim()
                            : (peer?.name ?? 'مستخدم');

                        return ListTile(
                          onTap: () => _openConversation(
                            conversationId: conversation.id,
                            peer: isGroup ? null : peer,
                          ),
                          onLongPress: isOwner
                              ? () =>
                                    _showConversationOwnerActions(conversation)
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: isGroup
                              ? _GroupAvatar(
                                  radius: 24,
                                  avatarUrl: conversation.resolvedAvatarUrl,
                                )
                              : Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.appBarWaterMid
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        _initials(peer?.name ?? '?'),
                                        style: const TextStyle(
                                          color: AppColors.appBarWaterDeep,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    PositionedDirectional(
                                      end: -1,
                                      bottom: -1,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _presenceColor(peer),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isTyping
                                    ? AppColors.successGreen
                                    : conversation.unreadCount > 0
                                    ? AppColors.darkGray
                                    : AppColors.mediumGray,
                                fontWeight: isTyping
                                    ? FontWeight.w700
                                    : conversation.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (sentAt != null)
                                Text(
                                  _formatTime(sentAt),
                                  style: const TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 11,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              if (conversation.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    conversation.unreadCount > 99
                                        ? '99+'
                                        : conversation.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUserPicker,
        icon: const Icon(Icons.chat),
        label: const Text('محادثة جديدة'),
      ),
    );
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
    final source = provider.users;

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
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اختر مستخدم',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو البريد',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
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
