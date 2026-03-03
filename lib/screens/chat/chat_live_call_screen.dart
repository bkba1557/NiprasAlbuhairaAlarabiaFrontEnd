import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/chat/chat_call_iframe_view.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatLiveCallScreen extends StatefulWidget {
  final String callId;
  final String conversationId;
  final Uri callUri;
  final String title;
  final bool isVideo;
  final DateTime? callStartedAt;

  const ChatLiveCallScreen({
    super.key,
    required this.callId,
    required this.conversationId,
    required this.callUri,
    required this.title,
    required this.isVideo,
    this.callStartedAt,
  });

  @override
  State<ChatLiveCallScreen> createState() => _ChatLiveCallScreenState();
}

class _ChatLiveCallScreenState extends State<ChatLiveCallScreen> {
  WebViewController? _controller;
  bool _endingCall = false;
  bool _endedOnce = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  bool _syncingCallState = false;
  late final ChatProvider _chatProvider;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  Timer? _callStateTicker;

  bool get _supportsNativeWebView {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _startedAt = widget.callStartedAt;
    _isCameraOff = !widget.isVideo;

    _updateElapsed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateElapsed();
    });
    _callStateTicker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _endingCall || _startedAt != null) return;
      unawaited(_syncCallState());
    });
    unawaited(_syncCallState());

    if (_supportsNativeWebView) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(widget.callUri);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _callStateTicker?.cancel();
    if (!_endedOnce) {
      _endedOnce = true;
      unawaited(_chatProvider.endCall(widget.callId));
    }
    super.dispose();
  }

  Future<void> _endCallAndClose() async {
    if (_endingCall) return;
    setState(() => _endingCall = true);
    if (!_endedOnce) {
      _endedOnce = true;
      await _chatProvider.endCall(widget.callId);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _onBackPressed() async {
    await _endCallAndClose();
    return false;
  }

  void _updateElapsed() {
    final startedAt = _startedAt;
    if (startedAt == null) {
      if (_elapsed != Duration.zero) {
        setState(() {
          _elapsed = Duration.zero;
        });
      }
      return;
    }

    final diff = DateTime.now().difference(startedAt);
    setState(() {
      _elapsed = diff.isNegative ? Duration.zero : diff;
    });
  }

  Future<void> _syncCallState() async {
    if (_syncingCallState || _endingCall || _startedAt != null) return;
    _syncingCallState = true;
    try {
      final session = await _chatProvider.fetchActiveCall(widget.conversationId);
      if (!mounted) return;
      final startedAt = session?.startedAt;
      if (startedAt != null) {
        setState(() {
          _startedAt = startedAt;
        });
        _updateElapsed();
      }
    } finally {
      _syncingCallState = false;
    }
  }

  String _formatElapsed(Duration value) {
    final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      final mm = minutes.toString().padLeft(2, '0');
      final ss = seconds.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String get _callStatusLabel {
    if (_endingCall) {
      return '\u062C\u0627\u0631\u064D \u0625\u0646\u0647\u0627\u0621 \u0627\u0644\u0645\u0643\u0627\u0644\u0645\u0629...';
    }
    if (_startedAt == null || _elapsed.inSeconds <= 0) {
      return '\u062C\u0627\u0631\u064D \u0627\u0644\u0627\u062A\u0635\u0627\u0644...';
    }
    return _formatElapsed(_elapsed);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  void _toggleCamera() {
    if (!widget.isVideo) return;
    setState(() => _isCameraOff = !_isCameraOff);
  }

  @override
  Widget build(BuildContext context) {
    final safeTitle = widget.title.trim().isNotEmpty
        ? widget.title.trim()
        : '\u0645\u0643\u0627\u0644\u0645\u0629';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBackPressed());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildCallBody(),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _endCallAndClose,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                safeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _callStatusLabel,
                                style: TextStyle(
                                  color: _endingCall
                                      ? AppColors.errorRed
                                      : const Color(0xFFE5E7EB),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!widget.isVideo)
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        safeTitle.isEmpty
                            ? '?'
                            : safeTitle.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CallControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted
                              ? '\u0625\u0644\u063A\u0627\u0621 \u0627\u0644\u0643\u062A\u0645'
                              : '\u0643\u062A\u0645',
                          active: _isMuted,
                          onPressed: _toggleMute,
                        ),
                        _CallControlButton(
                          icon: _isSpeakerOn
                              ? Icons.volume_up
                              : Icons.hearing_outlined,
                          label: '\u0627\u0644\u0633\u0645\u0627\u0639\u0629',
                          active: _isSpeakerOn,
                          onPressed: _toggleSpeaker,
                        ),
                        _CallControlButton(
                          icon: _isCameraOff
                              ? Icons.videocam_off
                              : Icons.videocam,
                          label: '\u0627\u0644\u0643\u0627\u0645\u064A\u0631\u0627',
                          active: !_isCameraOff,
                          onPressed: widget.isVideo ? _toggleCamera : null,
                        ),
                        _CallControlButton(
                          icon: Icons.call_end,
                          label: '\u0625\u0646\u0647\u0627\u0621',
                          active: true,
                          backgroundColor: AppColors.errorRed,
                          foregroundColor: Colors.white,
                          onPressed: _endCallAndClose,
                          loading: _endingCall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallBody() {
    final callUrl = widget.callUri.toString();

    if (kIsWeb) {
      return buildChatCallIFrameView(callUrl: callUrl);
    }
    if (_supportsNativeWebView && _controller != null) {
      return WebViewWidget(controller: _controller!);
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '\u0647\u0630\u0647 \u0627\u0644\u0645\u0646\u0635\u0629 \u0644\u0627 \u062A\u062F\u0639\u0645 \u0639\u0631\u0636 \u0627\u0644\u0645\u0643\u0627\u0644\u0645\u0629 \u0645\u0628\u0627\u0634\u0631\u0629 \u062F\u0627\u062E\u0644 \u0627\u0644\u062A\u0637\u0628\u064A\u0642 \u062D\u0627\u0644\u064A\u0627\u064B.',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = backgroundColor ??
        (active
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.15));
    final fg = foregroundColor ?? Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: enabled ? bg : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: fg,
                    ),
                  )
                : Icon(icon, color: fg, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 58,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
