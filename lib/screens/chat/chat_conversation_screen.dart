import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:order_tracker/models/chat_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/screens/chat/chat_live_call_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatConversationScreen extends StatefulWidget {
  final String? initialConversationId;
  final String? initialPeerId;
  final ChatUser? initialPeer;

  const ChatConversationScreen({
    super.key,
    this.initialConversationId,
    this.initialPeerId,
    this.initialPeer,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<ChatUploadFile> _attachments = [];

  String? _conversationId;
  ChatUser? _peer;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  DateTime? _recordStartedAt;
  bool _typing = false;
  Timer? _typingTimer;
  String? _playUrl;
  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;
  final AudioPlayer _draftAudioPlayer = AudioPlayer();
  bool _isDraftPlaying = false;
  Duration _draftPlayPosition = Duration.zero;
  Duration _draftPlayDuration = Duration.zero;
  String? _loadedDraftPath;
  Timer? _recordTicker;
  Duration _recordDuration = Duration.zero;
  ChatUploadFile? _draftVoiceAttachment;
  AudioEncoder? _lastRecordEncoder;
  ChatMessage? _replyingToMessage;
  final List<String> _quickReactions = const [
    '\u{1F44D}',
    '\u{2764}\u{FE0F}',
    '\u{1F602}',
    '\u{1F62E}',
    '\u{1F64F}',
    '\u{1F525}',
    '\u{1F44F}',
    '\u{1F4AA}',
  ];
  final List<String> _quickEmojis = const [
    '\u{1F600}',
    '\u{1F602}',
    '\u{1F60D}',
    '\u{1F60E}',
    '\u{1F973}',
    '\u{1F64F}',
    '\u{1F4AA}',
    '\u{1F525}',
    '\u{2764}\u{FE0F}',
    '\u{1F44D}',
    '\u{1F44E}',
    '\u{1F44F}',
    '\u{1F389}',
    '\u{2705}',
    '\u{1F69A}',
    '\u{26FD}',
    '\u{1F4E6}',
    '\u{1F4CD}',
  ];
  final List<String> _quickStickers = const [
    '\u{1FAF6}',
    '\u{1F91D}',
    '\u{1F4AF}',
    '\u{2728}',
    '\u{1F680}',
    '\u{26A1}',
    '\u{1F929}',
    '\u{1F970}',
    '\u{1F605}',
    '\u{1F634}',
    '\u{1F914}',
    '\u{1FAE1}',
    '\u{1F3AF}',
    '\u{1F3C6}',
    '\u{1F4E3}',
    '\u{1F6E0}\u{FE0F}',
    '\u{1F9FE}',
    '\u{1F4DE}',
  ];

  static const List<double> _voiceWaveform = [
    0.18,
    0.36,
    0.22,
    0.48,
    0.62,
    0.31,
    0.55,
    0.28,
    0.72,
    0.44,
    0.26,
    0.68,
    0.33,
    0.52,
    0.24,
    0.58,
    0.40,
    0.30,
    0.66,
    0.38,
    0.50,
    0.21,
    0.61,
    0.35,
    0.54,
    0.27,
    0.70,
    0.32,
    0.46,
    0.23,
    0.57,
    0.29,
  ];

  static const TextStyle _emojiPickerTextStyle = TextStyle(
    fontSize: 28,
    fontFamilyFallback: [
      'Noto Color Emoji',
      'Segoe UI Emoji',
      'Apple Color Emoji',
      'Noto Emoji',
    ],
  );

  static const TextStyle _stickerPickerTextStyle = TextStyle(
    fontSize: 34,
    fontFamilyFallback: [
      'Noto Color Emoji',
      'Segoe UI Emoji',
      'Apple Color Emoji',
      'Noto Emoji',
    ],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playUrl = null;
          _playPosition = Duration.zero;
          _playDuration = Duration.zero;
        });
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (!mounted || _playUrl == null) return;
      setState(() => _playPosition = position);
    });
    _audioPlayer.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _playDuration = duration);
    });
    _draftAudioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isDraftPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isDraftPlaying = false;
          _draftPlayPosition = Duration.zero;
        });
      }
    });
    _draftAudioPlayer.positionStream.listen((position) {
      if (!mounted || _loadedDraftPath == null) return;
      setState(() => _draftPlayPosition = position);
    });
    _draftAudioPlayer.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _draftPlayDuration = duration);
    });
  }

  Future<void> _bootstrap() async {
    final provider = context.read<ChatProvider>();
    ChatConversation? conversation;

    if ((widget.initialConversationId ?? '').trim().isNotEmpty) {
      _conversationId = widget.initialConversationId!.trim();
      conversation = await provider.fetchConversationById(_conversationId!);
    } else if ((widget.initialPeerId ?? '').trim().isNotEmpty) {
      conversation = await provider.startDirectConversation(
        widget.initialPeerId!.trim(),
      );
      _conversationId = conversation?.id;
    }
    _peer = conversation?.peer ?? widget.initialPeer;

    final cid = _conversationId;
    if (cid == null || cid.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    await provider.fetchMessages(cid, markRead: true);
    await provider.markConversationRead(cid);
    provider.startActiveConversationSync(cid);
    provider.setActiveConversation(cid);
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom(jump: true);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTicker?.cancel();
    final cid = _conversationId;
    if ((cid ?? '').isNotEmpty) {
      unawaited(
        context.read<ChatProvider>().setTyping(cid!, false, force: true),
      );
    }
    context.read<ChatProvider>().stopActiveConversationSync();
    _audioPlayer.dispose();
    _draftAudioPlayer.dispose();
    _audioRecorder.dispose();
    _composerFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final myId =
        context.select<AuthProvider, String?>((auth) => auth.user?.id) ?? '';
    final isOwner = context.select<AuthProvider, bool>(
      (auth) => auth.user?.role == 'owner',
    );
    final cid = _conversationId;
    final conversation = cid == null ? null : provider.conversationById(cid);
    final isGroup = conversation?.type == 'group';
    final peer = conversation?.peer ?? _peer;
    final groupAvatarUrl = conversation?.resolvedAvatarUrl.trim() ?? '';
    final typingNow = conversation?.typingUserIds.isNotEmpty ?? false;
    final conversationName = conversation?.name.trim() ?? '';
    final headerTitle = conversationName.isNotEmpty
        ? conversationName
        : (peer?.name ?? (isGroup ? 'مجموعة' : 'محادثة'));
    final headerSubtitle = isGroup
        ? _groupPresenceText(conversation, typingNow: typingNow)
        : _peerPresenceText(peer, typingNow: typingNow);
    final messages = cid == null
        ? const <ChatMessage>[]
        : provider.messagesFor(cid);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            isGroup
                ? (groupAvatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            groupAvatarUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              child: const Icon(
                                Icons.groups_2_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          child: const Icon(Icons.groups_2_outlined, size: 18),
                        ))
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        child: Text(
                          _initials(peer?.name ?? '?'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      PositionedDirectional(
                        end: -1,
                        bottom: -1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: _presenceColor(peer),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.appBarWaterDeep,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    headerSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'مكالمة صوتية',
            onPressed: () => _startCall(isVideo: false),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'مكالمة فيديو',
            onPressed: () => _startCall(isVideo: true),
            icon: const Icon(Icons.videocam_outlined),
          ),
          if (isOwner && isGroup && (cid ?? '').isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'خيارات المجموعة',
              onSelected: (value) {
                if (value == 'edit_group') {
                  _showEditGroupSheet();
                } else if (value == 'members') {
                  _showGroupMembersSheet();
                } else if (value == 'delete_group') {
                  _deleteCurrentConversation();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'edit_group',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('تعديل المجموعة'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'members',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined),
                    title: Text('إدارة الأعضاء'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete_group',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppColors.errorRed,
                    ),
                    title: Text(
                      'حذف المجموعة',
                      style: TextStyle(color: AppColors.errorRed),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == myId;
                      return _bubble(
                        context,
                        message,
                        isMe,
                        myId,
                        isGroup: isGroup,
                      );
                    },
                  ),
                ),
                if (_replyingToMessage != null) _buildReplyComposerPreview(),
                if (_attachments.isNotEmpty) _buildAttachmentsDraftPreview(),
                if (_draftVoiceAttachment != null)
                  _buildDraftVoicePreviewWhatsApp(),
                SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _recording
                          ? _buildRecordingComposer()
                          : _buildNormalComposer(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNormalComposer() {
    final hasDraft =
        _messageController.text.trim().isNotEmpty ||
        _attachments.isNotEmpty ||
        _draftVoiceAttachment != null;

    return Row(
      key: const ValueKey('normal_composer'),
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: _pickAttachment,
        ),
        IconButton(
          tooltip: 'إيموجي وملصقات',
          icon: const Icon(Icons.emoji_emotions_outlined),
          onPressed: _showEmojiStickerPicker,
        ),
        Expanded(
          child: Focus(
            onKeyEvent: (_, event) {
              final isEnter =
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter;
              if (!isEnter) return KeyEventResult.ignored;
              if (HardwareKeyboard.instance.isShiftPressed) {
                return KeyEventResult.ignored;
              }
              if (event is KeyDownEvent) {
                _send();
              }
              return KeyEventResult.handled;
            },
            child: TextField(
              focusNode: _composerFocusNode,
              controller: _messageController,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 5,
              onSubmitted: (_) => _send(),
              onChanged: _handleTyping,
              decoration: const InputDecoration(
                hintText:
                    '\u0627\u0643\u062A\u0628 \u0631\u0633\u0627\u0644\u0629...',
              ),
            ),
          ),
        ),
        CircleAvatar(
          backgroundColor: AppColors.appBarWaterMid,
          child: IconButton(
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    hasDraft ? Icons.send : Icons.mic_none,
                    color: Colors.white,
                  ),
            onPressed: _sending
                ? null
                : () {
                    if (hasDraft) {
                      _send();
                    } else {
                      _startRecording();
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildReplyComposerPreview() {
    final reply = _replyingToMessage;
    if (reply == null) return const SizedBox.shrink();
    final previewText = reply.text.trim().isNotEmpty
        ? reply.text.trim()
        : reply.attachments.isNotEmpty
        ? 'مرفق'
        : '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.silverLight),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.appBarWaterMid,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'رد على ${reply.senderName.trim().isNotEmpty ? reply.senderName.trim() : 'رسالة'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.appBarWaterMid,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (previewText.isNotEmpty)
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'إلغاء الرد',
              onPressed: () => setState(() => _replyingToMessage = null),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEmojiStickerPicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DefaultTabController(
            length: 2,
            child: SizedBox(
              height: 340,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.emoji_emotions_outlined),
                        text: 'إيموجي',
                      ),
                      Tab(
                        icon: Icon(Icons.sticky_note_2_outlined),
                        text: 'ملصقات',
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: _quickEmojis.length,
                          itemBuilder: (context, index) {
                            final emoji = _quickEmojis[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _insertEmoji(emoji),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: _emojiPickerTextStyle,
                                ),
                              ),
                            );
                          },
                        ),
                        GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                          itemCount: _quickStickers.length,
                          itemBuilder: (context, index) {
                            final sticker = _quickStickers[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await _sendQuickSticker(sticker);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundGray,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    sticker,
                                    style: _stickerPickerTextStyle,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _insertEmoji(String emoji) {
    final current = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.isValid ? selection.start : current.length;
    final end = selection.isValid ? selection.end : current.length;
    final safeStart = start < 0 ? current.length : start;
    final safeEnd = end < 0 ? current.length : end;

    final updated = current.replaceRange(safeStart, safeEnd, emoji);
    _messageController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: safeStart + emoji.length),
    );
    _handleTyping(updated);
  }

  Future<void> _sendQuickSticker(String sticker) async {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty || _sending) return;

    setState(() => _sending = true);
    final sent = await context.read<ChatProvider>().sendMessage(cid!, sticker);
    if (!mounted) return;
    setState(() => _sending = false);

    if (sent != null) {
      _typing = false;
      unawaited(
        context.read<ChatProvider>().setTyping(cid, false, force: true),
      );
      _scrollToBottom();
    }
  }

  Widget _buildRecordingComposer() {
    return Row(
      key: const ValueKey('recording_composer'),
      children: [
        IconButton(
          tooltip: 'إلغاء التسجيل',
          onPressed: () => _stopRecording(keepDraft: false),
          icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fiber_manual_record,
                  size: 12,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordDuration),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'جاري التسجيل...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.mediumGray),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'إنهاء التسجيل',
          onPressed: () => _stopRecording(keepDraft: true),
          icon: const Icon(
            Icons.stop_circle_outlined,
            color: AppColors.appBarWaterMid,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsDraftPreview() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = _attachments[i];
            final isImage = item.mimeType.startsWith('image/');
            final isVideo = item.mimeType.startsWith('video/');
            final isAudio = item.mimeType.startsWith('audio/');

            Widget preview;
            if (isImage && item.bytes != null && item.bytes!.isNotEmpty) {
              preview = ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  Uint8List.fromList(item.bytes!),
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              final icon = isVideo
                  ? Icons.video_library_outlined
                  : isAudio
                  ? Icons.multitrack_audio_outlined
                  : isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined;
              preview = Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.appBarWaterMid),
              );
            }

            return Stack(
              children: [
                preview,
                Positioned(
                  top: 2,
                  right: 2,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _attachments.removeAt(i)),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDraftVoicePreview() {
    final draft = _draftVoiceAttachment;
    if (draft == null) return const SizedBox.shrink();

    final duration = Duration(seconds: draft.durationSec ?? 0);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'حذف التسجيل',
              onPressed: _clearDraftVoice,
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
            ),
            IconButton(
              tooltip: _isDraftPlaying ? 'إيقاف' : 'تشغيل',
              onPressed: _toggleDraftVoicePlayback,
              icon: Icon(
                _isDraftPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                color: AppColors.appBarWaterMid,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.multitrack_audio,
              size: 18,
              color: AppColors.mediumGray,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'رسالة صوتية ${_formatDuration(duration)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftVoicePreviewWhatsApp() {
    final draft = _draftVoiceAttachment;
    if (draft == null) return const SizedBox.shrink();

    final knownDuration = Duration(seconds: draft.durationSec ?? 0);
    final duration = _resolveVoiceDuration(
      knownDuration: knownDuration,
      playerDuration: _draftPlayDuration,
      position: _draftPlayPosition,
    );
    final showProgress = _draftPlayPosition > Duration.zero;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _buildVoiceActionButton(
              isPlaying: _isDraftPlaying,
              onTap: _toggleDraftVoicePlayback,
              background: AppColors.appBarWaterMid,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoiceWaveform(
                    progress: _progressValue(_draftPlayPosition, duration),
                    activeColor: AppColors.appBarWaterMid,
                    inactiveColor: Colors.black26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _voiceDurationLabel(
                      position: _draftPlayPosition,
                      total: duration,
                      showProgress: showProgress,
                    ),
                    style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'حذف التسجيل',
              onPressed: _clearDraftVoice,
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
              splashRadius: 20,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMessageTile({
    required bool isMe,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required bool showProgress,
    required VoidCallback onPressed,
  }) {
    final activeColor = isMe ? Colors.white : AppColors.appBarWaterMid;
    final inactiveColor = isMe ? Colors.white24 : Colors.black26;
    final timeColor = isMe ? Colors.white70 : AppColors.mediumGray;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 170, maxWidth: 250),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildVoiceActionButton(
                  isPlaying: isPlaying,
                  onTap: onPressed,
                  background: isMe ? Colors.white : AppColors.appBarWaterMid,
                  iconColor: isMe ? AppColors.appBarWaterMid : Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVoiceWaveform(
                    progress: _progressValue(position, duration),
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 40),
              child: Text(
                _voiceDurationLabel(
                  position: position,
                  total: duration,
                  showProgress: showProgress,
                ),
                style: TextStyle(
                  color: timeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceActionButton({
    required bool isPlaying,
    required VoidCallback onTap,
    required Color background,
    required Color iconColor,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            size: 20,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceWaveform({
    required double progress,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const slotWidth = 4.0;
          final maxBars = _voiceWaveform.length;
          int visibleBars;
          if (constraints.maxWidth.isFinite) {
            final estimated = (constraints.maxWidth / slotWidth).floor();
            if (estimated < 8) {
              visibleBars = 8;
            } else if (estimated > maxBars) {
              visibleBars = maxBars;
            } else {
              visibleBars = estimated;
            }
          } else {
            visibleBars = maxBars;
          }

          final normalizedProgress = progress.clamp(0.0, 1.0);
          final playedBars = (visibleBars * normalizedProgress).round();

          return Row(
            children: List.generate(visibleBars, (index) {
              final sourceIndex = visibleBars == 1
                  ? 0
                  : ((index / (visibleBars - 1)) * (maxBars - 1)).round();
              final value = _voiceWaveform[sourceIndex];
              final height = 6.0 + (value * 16.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2.4,
                    height: height,
                    decoration: BoxDecoration(
                      color: index < playedBars ? activeColor : inactiveColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  String _voiceDurationLabel({
    required Duration position,
    required Duration total,
    required bool showProgress,
  }) {
    final safeTotal = total > Duration.zero ? total : position;
    if (!showProgress) {
      return _formatDuration(safeTotal);
    }
    return '${_formatDuration(position)} / ${_formatDuration(safeTotal)}';
  }

  Duration _resolveVoiceDuration({
    required Duration knownDuration,
    required Duration playerDuration,
    required Duration position,
  }) {
    if (playerDuration > Duration.zero) return playerDuration;
    if (knownDuration > Duration.zero) return knownDuration;
    if (position > Duration.zero) return position;
    return Duration.zero;
  }

  double _progressValue(Duration position, Duration duration) {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return 0;
    return (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  Widget _bubble(
    BuildContext context,
    ChatMessage message,
    bool isMe,
    String myId, {
    required bool isGroup,
  }) {
    final color = isMe ? AppColors.appBarWaterMid : Colors.white;
    final textColor = isMe ? Colors.white : AppColors.darkGray;
    final read = message.isReadByOther(myId);
    final delivered = message.isDeliveredToOther(myId);
    final bubbleAlignment = isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final reactionEntries = _reactionEntries(message);
    final myReaction = message.myReaction(myId);

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showMessageActions(message, isMe: isMe),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: const Radius.circular(14),
                  topEnd: const Radius.circular(14),
                  bottomStart: Radius.circular(isMe ? 14 : 4),
                  bottomEnd: Radius.circular(isMe ? 4 : 14),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: bubbleAlignment,
                children: [
                  if (isGroup &&
                      !isMe &&
                      message.senderName.trim().isNotEmpty) ...[
                    Text(
                      message.senderName.trim(),
                      style: const TextStyle(
                        color: AppColors.appBarWaterMid,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (message.forwardedFrom != null) ...[
                    Text(
                      'مُعاد توجيهها',
                      style: TextStyle(
                        color: isMe ? Colors.white70 : AppColors.mediumGray,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (message.replyTo != null)
                    _buildReplyQuote(message.replyTo!, isMe: isMe),
                  if (message.attachments.isNotEmpty)
                    ...message.attachments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _attachmentView(a, isMe),
                      ),
                    ),
                  if (message.text.trim().isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(color: textColor),
                      textAlign: TextAlign.start,
                    ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatSaudiTime(message.createdAt),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppColors.lightGray,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          read
                              ? Icons.done_all
                              : delivered
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: read
                              ? const Color(0xFF8ED4FF)
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (reactionEntries.isNotEmpty)
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: isMe ? 0 : 6,
                end: isMe ? 6 : 0,
                top: 2,
              ),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: reactionEntries.map((entry) {
                  final highlighted = myReaction == entry.key;
                  return InkWell(
                    onTap: () => _reactToMessage(message, entry.key),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? AppColors.infoBlue.withValues(alpha: 0.18)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: highlighted
                              ? AppColors.infoBlue
                              : AppColors.silver,
                        ),
                      ),
                      child: Text(
                        '${entry.key} ${entry.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyQuote(ChatMessageReply reply, {required bool isMe}) {
    final borderColor = isMe ? Colors.white70 : AppColors.appBarWaterMid;
    final captionColor = isMe ? Colors.white70 : AppColors.mediumGray;
    final textColor = isMe ? Colors.white : AppColors.darkGray;
    final text = reply.text.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsetsDirectional.only(
        start: 8,
        end: 8,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: isMe ? Colors.white10 : AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reply.senderName.trim().isNotEmpty
                ? reply.senderName.trim()
                : 'رسالة',
            style: TextStyle(
              color: captionColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (text.isNotEmpty)
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _reactionEntries(ChatMessage message) {
    final counts = <String, int>{};
    for (final reaction in message.reactions) {
      final emoji = reaction.emoji.trim();
      if (emoji.isEmpty) continue;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts.entries.toList();
  }

  Future<void> _showMessageActions(
    ChatMessage message, {
    required bool isMe,
  }) async {
    if (!mounted) return;
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;
    final canDelete =
        isMe || context.read<AuthProvider>().user?.role == 'owner';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('رد'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _replyingToMessage = message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('ريأكت'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReactionPicker(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward_outlined),
                title: const Text('فورورد'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showForwardPicker(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('نسخ'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final value = _buildMessageShareText(message);
                  if (value.isEmpty) return;
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الرسالة')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('مشاركة'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final value = _buildMessageShareText(message);
                  if (value.isEmpty) return;
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ المحتوى للمشاركة')),
                  );
                },
              ),
              if (canDelete)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.errorRed,
                  ),
                  title: const Text(
                    'حذف الرسالة',
                    style: TextStyle(color: AppColors.errorRed),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('حذف الرسالة'),
                          content: const Text(
                            'هل تريد حذف هذه الرسالة نهائياً؟',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('إلغاء'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.errorRed,
                              ),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('حذف'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed != true || !mounted) return;
                    final ok = await context.read<ChatProvider>().deleteMessage(
                      cid!,
                      message.id,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'تم حذف الرسالة' : 'تعذر حذف الرسالة',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reactToMessage(ChatMessage message, String emoji) async {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;
    await context.read<ChatProvider>().reactToMessage(cid!, message.id, emoji);
  }

  Future<void> _showReactionPicker(ChatMessage message) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickReactions.map((emoji) {
                return InkWell(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _reactToMessage(message, emoji);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.silverLight),
                    ),
                    child: Text(emoji, style: _emojiPickerTextStyle),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showForwardPicker(ChatMessage sourceMessage) async {
    final provider = context.read<ChatProvider>();
    if (provider.conversations.isEmpty) {
      await provider.fetchConversations(silent: true);
    }
    if (!mounted) return;

    final selected = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final conversations = provider.conversations;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'فورورد إلى',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: conversations.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          final title = conversation.name.trim().isNotEmpty
                              ? conversation.name.trim()
                              : (conversation.peer?.name.trim().isNotEmpty ==
                                        true
                                    ? conversation.peer!.name.trim()
                                    : 'محادثة');
                          final checked = selected.contains(conversation.id);
                          return CheckboxListTile(
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(title),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(conversation.id);
                                } else {
                                  selected.remove(conversation.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                final count = await provider.forwardMessage(
                                  sourceMessage.id,
                                  selected.toList(),
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      count > 0
                                          ? 'تم فوروورد الرسالة إلى $count محادثة'
                                          : 'تعذر عمل فوروورد للرسالة',
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.forward_outlined),
                        label: const Text('إرسال'),
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
  }

  String _buildMessageShareText(ChatMessage message) {
    final buffer = StringBuffer();
    final text = message.text.trim();
    if (text.isNotEmpty) {
      buffer.writeln(text);
    }
    for (final attachment in message.attachments) {
      final url = attachment.resolvedUrl.trim();
      if (url.isEmpty) continue;
      if (buffer.length > 0) {
        buffer.writeln();
      }
      buffer.write(url);
    }
    return buffer.toString().trim();
  }

  Widget _attachmentView(ChatMessageAttachment attachment, bool isMe) {
    final url = attachment.resolvedUrl;
    if (attachment.isImage) {
      return GestureDetector(
        onTap: () => _openUrl(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 180,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    if (attachment.isAudio) {
      final hasActivePlayer = _playUrl == url;
      final isPlayingNow = hasActivePlayer && _isPlaying;
      final knownDuration = Duration(seconds: attachment.durationSec ?? 0);
      final duration = _resolveVoiceDuration(
        knownDuration: knownDuration,
        playerDuration: hasActivePlayer ? _playDuration : Duration.zero,
        position: hasActivePlayer ? _playPosition : Duration.zero,
      );
      return _buildAudioMessageTile(
        isMe: isMe,
        isPlaying: isPlayingNow,
        position: hasActivePlayer ? _playPosition : Duration.zero,
        duration: duration,
        showProgress: hasActivePlayer && _playPosition > Duration.zero,
        onPressed: () => _toggleAudio(url),
      );
      /*
      final playing = _playUrl == url && _isPlaying;
      return InkWell(
        onTap: () => _toggleAudio(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.pause_circle : Icons.play_circle_fill,
              color: isMe ? Colors.white : AppColors.appBarWaterMid,
            ),
            const SizedBox(width: 6),
            Text(
              attachment.durationSec != null
                  ? 'رسالة صوتية ${_formatDuration(Duration(seconds: attachment.durationSec!))}'
                  : 'رسالة صوتية',
              style: TextStyle(color: isMe ? Colors.white : AppColors.darkGray),
            ),
          ],
        ),
      );
      */
    }

    if (attachment.isVideo) {
      return InkWell(
        onTap: () => _openUrl(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: isMe ? Colors.white : AppColors.appBarWaterMid,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 170,
              child: Text(
                attachment.name.trim().isNotEmpty ? attachment.name : 'فيديو',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.darkGray,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _openUrl(url),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            color: isMe ? Colors.white : AppColors.appBarWaterMid,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 170,
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isMe ? Colors.white : AppColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleAudio(String url) async {
    await _draftAudioPlayer.stop();
    if (_isDraftPlaying && mounted) {
      setState(() => _isDraftPlaying = false);
    }

    if (_playUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }
    if (_playUrl != url) {
      await _audioPlayer.setUrl(url);
      _playUrl = url;
      _playPosition = Duration.zero;
      _playDuration = Duration.zero;
    }
    await _audioPlayer.play();
  }

  void _handleTyping(String text) {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;
    final provider = context.read<ChatProvider>();
    if (mounted) {
      setState(() {});
    }
    if (text.trim().isNotEmpty) {
      if (!_typing) {
        _typing = true;
        provider.setTyping(cid!, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _typing = false;
        provider.setTyping(cid!, false, force: true);
      });
    } else if (_typing) {
      _typing = false;
      provider.setTyping(cid!, false, force: true);
    }
  }

  String _guessMimeTypeFromName(
    String name, {
    String fallback = 'application/octet-stream',
  }) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.mp3':
        return 'audio/mpeg';
      case '.ogg':
      case '.oga':
        return 'audio/ogg';
      case '.opus':
        return 'audio/opus';
      case '.amr':
        return 'audio/amr';
      case '.weba':
        return 'audio/webm';
      case '.mp4':
      case '.m4v':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      case '.3gp':
        return 'video/3gpp';
      case '.wmv':
        return 'video/x-ms-wmv';
      case '.flv':
        return 'video/x-flv';
      default:
        return fallback;
    }
  }

  Future<void> _pickAudioAsVoiceFallback({String? reason}) async {
    if (!mounted) return;
    final trimmedReason = (reason ?? '').trim();
    if (trimmedReason.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(trimmedReason)));
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'm4a',
        'aac',
        'wav',
        'mp3',
        'ogg',
        'oga',
        'opus',
        'amr',
        'weba',
        'webm',
      ],
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    if ((file.path == null || file.path!.isEmpty) &&
        (file.bytes == null || file.bytes!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على ملف صوتي صالح')),
      );
      return;
    }

    final sourceName = file.name.trim().isNotEmpty ? file.name : 'voice.m4a';
    final durationSec = await _probePickedAudioDurationSec(file);
    if (!mounted) return;
    setState(() {
      _draftVoiceAttachment = ChatUploadFile(
        name: sourceName,
        mimeType: _guessMimeTypeFromName(sourceName, fallback: 'audio/mpeg'),
        filePath: kIsWeb ? null : file.path,
        bytes: file.bytes,
        durationSec: durationSec != null && durationSec > 0
            ? durationSec
            : null,
      );
      _isDraftPlaying = false;
      _draftPlayPosition = Duration.zero;
      _draftPlayDuration = durationSec != null && durationSec > 0
          ? Duration(seconds: durationSec)
          : Duration.zero;
      _loadedDraftPath = null;
    });
  }

  Future<int?> _probePickedAudioDurationSec(PlatformFile file) async {
    final path = file.path;
    if ((path ?? '').isEmpty) return null;

    final probePlayer = AudioPlayer();
    try {
      await probePlayer.setFilePath(path!);
      final seconds = probePlayer.duration?.inSeconds;
      if (seconds == null || seconds <= 0) return null;
      return seconds;
    } catch (_) {
      return null;
    } finally {
      await probePlayer.dispose();
    }
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('صورة'),
              onTap: () async {
                Navigator.pop(context);
                final image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image == null) return;
                final displayName = image.name.trim().isNotEmpty
                    ? image.name
                    : p.basename(image.path);
                final bytes = await image.readAsBytes();
                setState(() {
                  _attachments.add(
                    ChatUploadFile(
                      name: displayName,
                      mimeType: _guessMimeTypeFromName(
                        displayName,
                        fallback: 'image/jpeg',
                      ),
                      filePath: kIsWeb ? null : image.path,
                      bytes: bytes,
                    ),
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة'),
              onTap: () async {
                Navigator.pop(context);
                final image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (image == null) return;
                final displayName = image.name.trim().isNotEmpty
                    ? image.name
                    : p.basename(image.path);
                final bytes = await image.readAsBytes();
                setState(() {
                  _attachments.add(
                    ChatUploadFile(
                      name: displayName,
                      mimeType: _guessMimeTypeFromName(
                        displayName,
                        fallback: 'image/jpeg',
                      ),
                      filePath: kIsWeb ? null : image.path,
                      bytes: bytes,
                    ),
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('فيديو'),
              onTap: () async {
                Navigator.pop(context);
                final video = await _imagePicker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (video == null) return;
                final displayName = video.name.trim().isNotEmpty
                    ? video.name
                    : p.basename(video.path);
                final bytes = kIsWeb ? await video.readAsBytes() : null;
                setState(() {
                  _attachments.add(
                    ChatUploadFile(
                      name: displayName,
                      mimeType: _guessMimeTypeFromName(
                        displayName,
                        fallback: 'video/mp4',
                      ),
                      filePath: kIsWeb ? null : video.path,
                      bytes: bytes,
                    ),
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('تصوير فيديو'),
              onTap: () async {
                Navigator.pop(context);
                final video = await _imagePicker.pickVideo(
                  source: ImageSource.camera,
                );
                if (video == null) return;
                final displayName = video.name.trim().isNotEmpty
                    ? video.name
                    : p.basename(video.path);
                final bytes = kIsWeb ? await video.readAsBytes() : null;
                setState(() {
                  _attachments.add(
                    ChatUploadFile(
                      name: displayName,
                      mimeType: _guessMimeTypeFromName(
                        displayName,
                        fallback: 'video/mp4',
                      ),
                      filePath: kIsWeb ? null : video.path,
                      bytes: bytes,
                    ),
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: const Text('رسالة صوتية (ملف)'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAudioAsVoiceFallback();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('ملف'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                  withData: kIsWeb,
                );
                if (picked == null) return;
                setState(() {
                  for (final file in picked.files) {
                    if ((file.path == null || file.path!.isEmpty) &&
                        (file.bytes == null || file.bytes!.isEmpty)) {
                      continue;
                    }
                    _attachments.add(
                      ChatUploadFile(
                        name: file.name,
                        mimeType: _guessMimeTypeFromName(file.name),
                        filePath: file.path,
                        bytes: file.bytes,
                      ),
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_recording) return;

    await _audioPlayer.stop();
    await _draftAudioPlayer.stop();

    final ok = await _audioRecorder.hasPermission();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u064a\u0644\u0632\u0645 \u0627\u0644\u0633\u0645\u0627\u062d \u0644\u0644\u0645\u064a\u0643\u0631\u0648\u0641\u0648\u0646 \u0644\u0628\u062f\u0621 \u0627\u0644\u062a\u0633\u062c\u064a\u0644',
          ),
        ),
      );
      return;
    }

    final encoder = await _pickBestRecordingEncoder();
    _lastRecordEncoder = encoder;

    final fileName =
        'chat-audio-${DateTime.now().millisecondsSinceEpoch}'
        '.${_recordFileExtensionForEncoder(encoder)}';
    final outputPath = kIsWeb
        ? fileName
        : p.join((await getTemporaryDirectory()).path, fileName);

    try {
      await _audioRecorder.start(
        RecordConfig(encoder: encoder),
        path: outputPath,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062A\u0639\u0630\u0631 \u0628\u062F\u0621 \u0627\u0644\u062A\u0633\u062C\u064A\u0644 \u0627\u0644\u0635\u0648\u062A\u064A \u0639\u0644\u0649 \u0647\u0630\u0627 \u0627\u0644\u062C\u0647\u0627\u0632',
          ),
        ),
      );
      return;
    }

    _recordTicker?.cancel();
    setState(() {
      _recording = true;
      _recordStartedAt = DateTime.now();
      _recordDuration = Duration.zero;
      _isDraftPlaying = false;
    });

    _recordTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final startedAt = _recordStartedAt;
      if (!mounted || !_recording || startedAt == null) return;
      setState(() {
        _recordDuration = DateTime.now().difference(startedAt);
      });
    });
  }

  Future<void> _stopRecording({required bool keepDraft}) async {
    if (!_recording) return;

    final path = await _audioRecorder.stop();
    final encoder =
        _lastRecordEncoder ?? (kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc);
    _recordTicker?.cancel();
    _recordTicker = null;

    final startedAt = _recordStartedAt;
    final duration = startedAt == null
        ? _recordDuration
        : DateTime.now().difference(startedAt);
    final safeSeconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
    final recordedBytes = kIsWeb
        ? await _readBytesFromRecordedPath(path)
        : null;
    final hasPath = (path ?? '').isNotEmpty;
    final hasBytes = recordedBytes != null && recordedBytes.isNotEmpty;

    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordStartedAt = null;
      _recordDuration = Duration.zero;
      _isDraftPlaying = false;
      _draftPlayPosition = Duration.zero;
      _draftPlayDuration = Duration.zero;
      _loadedDraftPath = null;
      if (keepDraft && (hasPath || hasBytes)) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        _draftVoiceAttachment = ChatUploadFile(
          name: 'voice-$stamp.${_recordFileExtensionForEncoder(encoder)}',
          mimeType: _recordMimeTypeForEncoder(encoder),
          filePath: hasPath ? path : null,
          bytes: hasBytes ? recordedBytes : null,
          durationSec: safeSeconds,
        );
        _draftPlayDuration = Duration(seconds: safeSeconds);
      }
    });
  }

  Future<void> _toggleDraftVoicePlayback() async {
    final draft = _draftVoiceAttachment;
    final bytes = draft?.bytes;
    final path = draft?.filePath;
    if (draft == null) return;

    await _audioPlayer.stop();
    if (_playUrl != null && mounted) {
      setState(() => _playUrl = null);
    }

    if (_isDraftPlaying) {
      await _draftAudioPlayer.pause();
      return;
    }

    final sourceKey = (path ?? '').trim().isNotEmpty
        ? 'path:$path'
        : 'bytes:${draft.name}:${bytes?.length ?? 0}';

    if (_loadedDraftPath != sourceKey) {
      if (bytes != null && bytes.isNotEmpty) {
        final uri = Uri.dataFromBytes(
          bytes,
          mimeType: draft.mimeType.trim().isNotEmpty
              ? draft.mimeType.trim()
              : 'audio/webm',
        );
        await _draftAudioPlayer.setAudioSource(AudioSource.uri(uri));
      } else if ((path ?? '').trim().isNotEmpty) {
        final rawPath = path!.trim();
        if (kIsWeb ||
            rawPath.startsWith('blob:') ||
            rawPath.startsWith('http://') ||
            rawPath.startsWith('https://')) {
          await _draftAudioPlayer.setUrl(rawPath);
        } else {
          await _draftAudioPlayer.setFilePath(rawPath);
        }
      } else {
        return;
      }

      if (!mounted) return;
      setState(() {
        _loadedDraftPath = sourceKey;
        _draftPlayPosition = Duration.zero;
      });
    }

    await _draftAudioPlayer.play();
  }

  Future<AudioEncoder> _pickBestRecordingEncoder() async {
    final candidates = kIsWeb
        ? const [AudioEncoder.opus, AudioEncoder.wav, AudioEncoder.pcm16bits]
        : const [
            AudioEncoder.aacLc,
            AudioEncoder.opus,
            AudioEncoder.wav,
            AudioEncoder.pcm16bits,
          ];

    for (final encoder in candidates) {
      try {
        final supported = await _audioRecorder.isEncoderSupported(encoder);
        if (supported) return encoder;
      } catch (_) {}
    }

    return kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc;
  }

  String _recordFileExtensionForEncoder(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.wav:
        return 'wav';
      case AudioEncoder.pcm16bits:
        return 'pcm';
      case AudioEncoder.opus:
        return kIsWeb ? 'webm' : 'opus';
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'm4a';
      case AudioEncoder.amrNb:
      case AudioEncoder.amrWb:
        return 'amr';
      case AudioEncoder.flac:
        return 'flac';
    }
  }

  String _recordMimeTypeForEncoder(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.wav:
        return 'audio/wav';
      case AudioEncoder.pcm16bits:
        return 'audio/wav';
      case AudioEncoder.opus:
        return kIsWeb ? 'audio/webm' : 'audio/opus';
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'audio/mp4';
      case AudioEncoder.amrNb:
      case AudioEncoder.amrWb:
        return 'audio/amr';
      case AudioEncoder.flac:
        return 'audio/flac';
    }
  }

  Future<List<int>?> _readBytesFromRecordedPath(String? recordedPath) async {
    final raw = (recordedPath ?? '').trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    if (uri.scheme == 'data') {
      return uri.data?.contentAsBytes();
    }

    try {
      final response = await http.get(uri);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _clearDraftVoice() async {
    await _draftAudioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _draftVoiceAttachment = null;
      _isDraftPlaying = false;
      _draftPlayPosition = Duration.zero;
      _draftPlayDuration = Duration.zero;
      _loadedDraftPath = null;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;
    final chatProvider = context.read<ChatProvider>();
    final text = _messageController.text.trim();
    final outgoingAttachments = List<ChatUploadFile>.from(_attachments);
    if (_draftVoiceAttachment != null) {
      outgoingAttachments.add(_draftVoiceAttachment!);
    }
    if (text.isEmpty && outgoingAttachments.isEmpty) return;

    setState(() => _sending = true);
    final message = await chatProvider.sendMessage(
      cid!,
      text,
      replyToMessageId: _replyingToMessage?.id,
      attachments: outgoingAttachments,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (message != null) {
      await _draftAudioPlayer.stop();
      _messageController.clear();
      _attachments.clear();
      _draftVoiceAttachment = null;
      _isDraftPlaying = false;
      _draftPlayPosition = Duration.zero;
      _draftPlayDuration = Duration.zero;
      _loadedDraftPath = null;
      _replyingToMessage = null;
      _typing = false;
      unawaited(chatProvider.setTyping(cid, false, force: true));
      setState(() {});
      _scrollToBottom();
    }
  }

  DateTime _toSaudiTime(DateTime value) {
    final utc = value.isUtc ? value : value.toUtc();
    return utc.add(const Duration(hours: 3));
  }

  String _formatSaudiTime(DateTime value) {
    return DateFormat('h:mm a', 'en').format(_toSaudiTime(value));
  }

  bool _wasSeenWithinOneHour(ChatUser? peer) {
    final seen = peer?.lastSeenAt;
    if (seen == null || peer?.isOnline == true) return false;
    final delta = DateTime.now().toUtc().difference(seen.toUtc());
    return delta.inMinutes >= 0 && delta.inMinutes <= 60;
  }

  Color _presenceColor(ChatUser? peer) {
    if (peer?.isOnline == true) {
      return AppColors.successGreen;
    }
    if (_wasSeenWithinOneHour(peer)) {
      return AppColors.infoBlue;
    }
    return AppColors.silverDark;
  }

  String _peerPresenceText(ChatUser? peer, {required bool typingNow}) {
    if (typingNow) {
      return 'يكتب الآن...';
    }
    if (peer == null) {
      return 'غير متاح';
    }
    if (peer.isOnline) {
      return 'متصل الآن';
    }
    if (peer.lastSeenAt != null) {
      return 'آخر ظهور ${_formatSaudiTime(peer.lastSeenAt!)}';
    }
    final email = peer.email.trim();
    if (email.isNotEmpty) {
      return email;
    }
    return 'غير متصل';
  }

  String _groupPresenceText(
    ChatConversation? conversation, {
    required bool typingNow,
  }) {
    if (typingNow) return 'أحد الأعضاء يكتب الآن...';
    final count = conversation?.participants.length ?? 0;
    if (count <= 0) return 'مجموعة';
    return '$count أعضاء';
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

  Future<void> _showEditGroupSheet() async {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;
    final provider = context.read<ChatProvider>();
    final conversation = provider.conversationById(cid!);
    if (conversation == null) return;

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
            Future<void> pickAvatar() async {
              final picked = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 86,
                maxWidth: 1400,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              if (!sheetContext.mounted) return;
              setSheetState(() {
                avatarBytes = bytes;
                avatarPath = picked.path;
                avatarFileName = picked.name.trim().isNotEmpty
                    ? picked.name
                    : null;
                removeAvatar = false;
              });
            }

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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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
                                onPressed: submitting ? null : pickAvatar,
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
                                      cid,
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
                                } else {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        provider.error?.trim().isNotEmpty ==
                                                true
                                            ? provider.error!.trim()
                                            : 'تعذر تعديل المجموعة',
                                      ),
                                    ),
                                  );
                                }
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

  Future<void> _showGroupMembersSheet() async {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;
    final provider = context.read<ChatProvider>();
    if (provider.users.isEmpty) {
      await provider.fetchUsers();
    }
    if (!mounted) return;

    final selectedToAdd = <String>{};
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final conversation = provider.conversationById(cid!);
            if (conversation == null) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('تعذر تحميل بيانات المجموعة'),
                ),
              );
            }

            final participantIds = conversation.participants
                .map((item) => item.id)
                .where((id) => id.trim().isNotEmpty)
                .toSet();
            final addCandidates = provider.users
                .where((user) => !participantIds.contains(user.id))
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إدارة أعضاء المجموعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأعضاء الحاليون',
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: conversation.participants.length,
                        itemBuilder: (context, index) {
                          final member = conversation.participants[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              member.name.trim().isNotEmpty
                                  ? member.name.trim()
                                  : member.email,
                            ),
                            subtitle: Text(member.email),
                            trailing: IconButton(
                              tooltip: 'حذف من المجموعة',
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      setSheetState(() => submitting = true);
                                      final updated = await provider
                                          .removeGroupParticipant(
                                            cid,
                                            member.id,
                                          );
                                      if (!sheetContext.mounted) return;
                                      setSheetState(() => submitting = false);
                                      if (updated == null) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              provider.error
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? provider.error!.trim()
                                                  : 'تعذر إزالة العضو',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.errorRed,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إضافة أعضاء',
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: addCandidates.length,
                        itemBuilder: (context, index) {
                          final user = addCandidates[index];
                          final checked = selectedToAdd.contains(user.id);
                          return CheckboxListTile(
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(user.name),
                            subtitle: Text(user.email),
                            onChanged: submitting
                                ? null
                                : (value) {
                                    setSheetState(() {
                                      if (value == true) {
                                        selectedToAdd.add(user.id);
                                      } else {
                                        selectedToAdd.remove(user.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: submitting || selectedToAdd.isEmpty
                            ? null
                            : () async {
                                setSheetState(() => submitting = true);
                                final updated = await provider
                                    .addGroupParticipants(
                                      cid,
                                      selectedToAdd.toList(),
                                    );
                                if (!sheetContext.mounted) return;
                                setSheetState(() {
                                  submitting = false;
                                  if (updated != null) {
                                    selectedToAdd.clear();
                                  }
                                });
                                if (updated == null) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        provider.error?.trim().isNotEmpty ==
                                                true
                                            ? provider.error!.trim()
                                            : 'تعذر إضافة الأعضاء',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          submitting ? 'جاري التحديث...' : 'إضافة المحددين',
                        ),
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
  }

  Future<void> _deleteCurrentConversation() async {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف المجموعة'),
          content: const Text('هل تريد حذف هذه المجموعة نهائياً؟'),
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

    final ok = await context.read<ChatProvider>().deleteConversation(cid!);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }

    final error = context.read<ChatProvider>().error?.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error?.isNotEmpty == true ? error! : 'تعذر حذف المجموعة'),
      ),
    );
  }

  Future<void> _startCall({required bool isVideo}) async {
    final cid = _conversationId;
    if ((cid ?? '').isEmpty || _sending) return;
    final conversationId = cid!;

    final auth = context.read<AuthProvider>();
    final myUser = auth.user;
    final myName = myUser?.name.trim();
    final safeName = (myName ?? '').isNotEmpty ? myName! : 'Order Track User';
    final myUserId = (myUser?.id ?? '').trim();

    final chatProvider = context.read<ChatProvider>();
    setState(() => _sending = true);
    final callSession = await chatProvider.startCall(
      conversationId,
      isVideo: isVideo,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (callSession == null) {
      final reason = (chatProvider.lastCallError ?? '').trim();
      final message = reason.isEmpty
          ? 'تعذر بدء المكالمة الحية من الخادم.'
          : 'تعذر بدء المكالمة الحية من الخادم: $reason';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    ChatCallParticipant? myParticipant;
    if (myUserId.isNotEmpty) {
      for (final participant in callSession.participants) {
        if (participant.userId.trim() == myUserId) {
          myParticipant = participant;
          break;
        }
      }
    }

    final myState = (myParticipant?.state ?? '').trim().toLowerCase();
    if (myState == 'ringing' || myState == 'invited') {
      await chatProvider.respondToCall(callSession.id, action: 'accept');
    }

    final roomSeed = callSession.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final roomId = roomSeed.isEmpty
        ? 'ordertrack${DateTime.now().millisecondsSinceEpoch}'
        : 'ordertrack$roomSeed';
    final effectiveIsVideo = callSession.callType.toLowerCase() == 'video';
    final conversationTitle =
        chatProvider.conversationById(conversationId)?.name ??
        _peer?.name ??
        '\u0645\u0643\u0627\u0644\u0645\u0629';

    final callUri = _buildCallUri(
      roomId: roomId,
      isVideo: effectiveIsVideo,
      displayName: safeName,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatLiveCallScreen(
          callId: callSession.id,
          conversationId: conversationId,
          callUri: callUri,
          title: conversationTitle,
          isVideo: effectiveIsVideo,
          callStartedAt: callSession.startedAt,
        ),
      ),
    );
  }

  Uri _buildCallUri({
    required String roomId,
    required bool isVideo,
    required String displayName,
  }) {
    final encodedName = Uri.encodeComponent(displayName);
    final startWithVideoMuted = isVideo ? 'false' : 'true';
    return Uri.parse(
      'https://meet.jit.si/$roomId'
      '#userInfo.displayName="$encodedName"'
      '&config.disableDeepLinking=true'
      '&config.prejoinConfig.enabled=false'
      '&interfaceConfig.MOBILE_APP_PROMO=false'
      '&interfaceConfig.DISABLE_JOIN_LEAVE_NOTIFICATIONS=true'
      '&config.startWithVideoMuted=$startWithVideoMuted'
      '&config.startWithAudioMuted=false',
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent + 80;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
