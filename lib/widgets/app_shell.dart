import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/circular_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/providers/circular_provider.dart';
import 'package:order_tracker/providers/note_provider.dart';
import 'package:order_tracker/services/whatsapp_service.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/role_route_policy.dart';
import 'package:order_tracker/widgets/chat_floating_button.dart';
import 'package:order_tracker/widgets/draggable_resizable_panel.dart';
import 'package:order_tracker/widgets/quick_notes_panel.dart';
import 'package:order_tracker/widgets/whatsapp_floating_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مراقب لتتبع حالة التحميل في الـ Navigator
class NavigationLoadingObserver extends NavigatorObserver {
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);

  void _show() {
    if (!isLoading.value) isLoading.value = true;
  }

  void _hideSoon() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (isLoading.value) isLoading.value = false;
    });
  }

  void _handleRoute(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (currentRouteName.value != name) currentRouteName.value = name;
    _show();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideSoon());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) {
    _handleRoute(route);
    super.didPush(route, previous);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _handleRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previous) {
    final name = previous?.settings.name;
    if (currentRouteName.value != name) currentRouteName.value = name;
    super.didPop(route, previous);
  }
}

/// الـ Shell العام للتطبيق
class AppShell extends StatefulWidget {
  final Widget child;
  final NavigationLoadingObserver observer;

  const AppShell({
    super.key,
    required this.child,
    required this.observer,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  /* ---------- ثابتات ---------- */
  static const double _fabSize = 56.0; // حجم الزرّ الصغير
  static const double _fabMargin = 8.0; // المسافة بين الزرّ واللوحة

  /* ---------- المتغيّرات ---------- */
  late final AnimationController _controller;
  String? _lastCircularCheckUserId;

  // حالة لوحة الملاحظات
  bool _showQuickNotesPanel = false;
  late Offset _panelOffset; // سيتحدد عند الفتح
  late Size _panelSize; // ثابت (قابل لتغييره من داخل الـ panel)

  // موضع زرّ الملاحظات (قابل للسحب)
  late Offset _notesFabOffset; // يُسترجع من التخزين أو يُحسب بدئيًا

  @override
  void initState() {
    super.initState();

    // ---------- Animation ----------
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // ---------- حجم لوحة الملاحظات ----------
    _panelSize = const Size(360, 450);

    // ---------- تحميل موضع زرّ الملاحظات ----------
    _loadNotesFabPosition().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /* -------------------------------------------------------
   |  حفظ / تحميل موضع زرّ الملاحظات (تُحفظ بين الجلسات)   |
   ------------------------------------------------------- */
  Future<void> _saveNotesFabPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('notesFabX', _notesFabOffset.dx);
    await prefs.setDouble('notesFabY', _notesFabOffset.dy);
  }

  Future<void> _loadNotesFabPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('notesFabX');
    final dy = prefs.getDouble('notesFabY');

    if (dx != null && dy != null) {
      // تم حفظ موضع مسبقاً
      _notesFabOffset = Offset(dx, dy);
    } else {
      // حساب موضع بدائي (أعلى‑يمين)
      final mq = MediaQueryData.fromWindow(WidgetsBinding.instance.window);
      final safe = mq.padding;
      final double left = mq.size.width - safe.right - 12 - _fabSize;
      final double top = safe.top + 12;
      _notesFabOffset = Offset(left, top);
    }
  }

  /* -------------------------------------------------------
   |  حساب الموضع الذي تُفتح تحت الزرّ فيه لوحة الملاحظات      |
   ------------------------------------------------------- */
  Offset _panelOffsetBelowFab() {
    final mq = MediaQuery.of(context);
    final EdgeInsets safe = mq.padding;
    final Size screen = mq.size;

    // موضع الزرّ الحالي
    double left = _notesFabOffset.dx;
    double top = _notesFabOffset.dy + _fabSize + _fabMargin;

    // لا نسمح للـ panel بالخروج من اليمين أو الأسفل
    final double maxLeft = screen.width - safe.right - _panelSize.width;
    final double maxTop = screen.height - safe.bottom - _panelSize.height;

    left = left.clamp(safe.left, maxLeft);
    top = top.clamp(safe.top, maxTop);
    return Offset(left, top);
  }

  /* -------------------------------------------------------
   |  فتح وإغلاق لوحة الملاحظات                           |
   ------------------------------------------------------- */
  void _openQuickNotesPanel() {
    // حساب الموضع الجديد لكل مرة يُفتح فيها الـ panel
    _panelOffset = _panelOffsetBelowFab();
    setState(() => _showQuickNotesPanel = true);
    // تحميل الملاحظات إن لم تكن محمّلة
    context.read<NoteProvider>().fetchNotes();
  }

  void _closeQuickNotesPanel() {
    setState(() => _showQuickNotesPanel = false);
  }

  /* -------------------------------------------------------
   |  تعديل موضع الزرّ (السحب) مع تحديث موضع الـ panel   |
   ------------------------------------------------------- */
  void _onNotesFabDragUpdate(DragUpdateDetails details) {
    setState(() {
      _notesFabOffset += details.delta;

      // منع الخروج من حدود الشاشة
      final mq = MediaQuery.of(context);
      final EdgeInsets safe = mq.padding;
      final Size screen = mq.size;
      final double maxX = screen.width - safe.right - _fabSize;
      final double maxY = screen.height - safe.bottom - _fabSize;

      _notesFabOffset = Offset(
        _notesFabOffset.dx.clamp(safe.left, maxX),
        _notesFabOffset.dy.clamp(safe.top, maxY),
      );

      // إذا كانت لوحة الملاحظات مفتوحة، نجعلها تتبع الزرّ
      if (_showQuickNotesPanel) {
        _panelOffset = _panelOffsetBelowFab();
      }
    });
  }

  void _onNotesFabDragEnd(DragEndDetails details) {
    // حفظ الموضع إلى التخزين الدائم
    _saveNotesFabPosition();
  }

  /* -------------------------------------------------------
   |  باقي الكود (animation, chat, circular, …)           |
   ------------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final barHeight = kToolbarHeight + topPadding;

    // Providers
    final auth = context.watch<AuthProvider>();
    final normalizedRole = auth.user?.role.trim().toLowerCase();
    final isDriverUser = normalizedRole == 'driver';
    final noteProvider = context.watch<NoteProvider>();
    final chat = context.watch<ChatProvider>();
    final canShowChat = auth.isAuthenticated && auth.user != null && !isDriverUser;
    final canShowQuickNotes = auth.isAuthenticated && !isDriverUser;

    // إلغاء مزامنة الدردشة إذا لا يُسمح بإظهارها
    if (!canShowChat && (chat.hasRunningSync || chat.totalUnread > 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ChatProvider>().clearState();
      });
    }

    final circularProvider = context.watch<CircularProvider>();
    _syncPendingCircularGate(auth, circularProvider);

    // ---------- تعريف المسارات التي يجب إخفاء زرّ الدردشة فيها ----------
    const Set<String> _routesWithoutChatFab = {
      AppRoutes.movement, // ← اضافة اسم مسار شاشة الحركة
      // يمكن إضافة مسارات إضافية إذا رغبت
    };

    return Stack(
      children: [
        // ---------------------------------------------------
        // شريط العلوية المتحرك (animation)
        // ---------------------------------------------------
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: barHeight,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final begin = Alignment.lerp(
                  Alignment.topLeft,
                  Alignment.bottomRight,
                  t,
                )!;
                final end = Alignment.lerp(
                  Alignment.bottomRight,
                  Alignment.topLeft,
                  t,
                )!;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: begin,
                          end: end,
                          colors: const [
                            AppColors.appBarWaterDeep,
                            AppColors.appBarWaterMid,
                            AppColors.appBarWaterBright,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color:
                                AppColors.appBarWaterGlow.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.appBarWaterGlow.withValues(alpha: 0.28),
                            AppColors.appBarWaterMid.withValues(alpha: 0.12),
                            AppColors.appBarWaterDeep.withValues(alpha: 0.18),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -barHeight * 0.35,
                      left: -barHeight * 0.2,
                      child: Container(
                        width: barHeight * 1.4,
                        height: barHeight * 1.4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.appBarWaterGlow,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.75],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // ---------------------------------------------------
        // محتوى الصفحة الفعلي
        // ---------------------------------------------------
        Positioned.fill(child: widget.child),

        // ---------------------------------------------------
        // زرّ الملاحظات (قابل للسحب)
        // ---------------------------------------------------
        if (canShowQuickNotes)
          Positioned(
            left: _notesFabOffset.dx,
            top: _notesFabOffset.dy,
            child: GestureDetector(
              onPanUpdate: _onNotesFabDragUpdate,
              onPanEnd: _onNotesFabDragEnd,
              child: Material(
                color: Colors.transparent,
                child: FloatingActionButton.small(
                  onPressed: _showQuickNotesPanel
                      ? _closeQuickNotesPanel
                      : _openQuickNotesPanel,
                  tooltip: 'المذكرات',
                  elevation: 4,
                  backgroundColor: AppColors.appBarWaterBright,
                  foregroundColor: AppColors.white,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined),
                      if (noteProvider.activeNotesCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.errorRed,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                noteProvider.activeNotesCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ---------------------------------------------------
        // مؤشر التحميل (spinner) في منتصف الشاشة
        // ---------------------------------------------------
        ValueListenableBuilder<bool>(
          valueListenable: widget.observer.isLoading,
          builder: (context, loading, _) => IgnorePointer(
            ignoring: !loading,
            child: AnimatedOpacity(
              opacity: loading ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.appBarBlue,
                  ),
                ),
              ),
            ),
          ),
        ),

        // ---------------------------------------------------
        // أزرار الـ FAB العالمية (دردشة / واتس آب)
        // ---------------------------------------------------
        ValueListenableBuilder<String?>(
          valueListenable: widget.observer.currentRouteName,
          builder: (context, currentRouteName, _) {
            // تحويل اسم المسار إلى الـ path فقط
            final normalizedRoute = currentRouteName == null
                ? null
                : (Uri.tryParse(currentRouteName)?.path ?? currentRouteName);

            // هل نحتاج لإخفاء زر الدردشة لهذا المسار؟
            final hideChatFab = normalizedRoute != null &&
                _routesWithoutChatFab.contains(normalizedRoute);

            final restrictToSingleRoute =
                isRestrictedSingleRouteRole(auth.user?.role);
            final showGlobalChatFab =
                canShowChat && !restrictToSingleRoute && !hideChatFab;
            final showGlobalWhatsAppFab = auth.isAuthenticated &&
                !restrictToSingleRoute &&
                WhatsAppService.canAccessForRole(auth.user?.role);

            if (!showGlobalChatFab && !showGlobalWhatsAppFab) {
              return const SizedBox.shrink();
            }

            // حساب إزاحة 2.5 سم من الطرفين الأيسر/السفلي
            double cmToLogicalPx(double cm) {
              final inches = cm / 2.54;
              final platform = Theme.of(context).platform;
              final isDesktop = platform == TargetPlatform.windows ||
                  platform == TargetPlatform.macOS ||
                  platform == TargetPlatform.linux;
              final dpi = (kIsWeb || isDesktop) ? 96.0 : 160.0;
              return inches * dpi;
            }

            final offsetPx = cmToLogicalPx(2.5);
            final safe = MediaQuery.of(context).padding;
            final fabLeft = safe.left + offsetPx;
            final fabBottom = safe.bottom + offsetPx;
            final fabRight = safe.right + offsetPx;

            final isAlreadyInChat = normalizedRoute == AppRoutes.chat ||
                normalizedRoute == AppRoutes.chatConversation;

            return Stack(
              children: [
                if (showGlobalChatFab)
                  ChatFloatingButton(
                    heroTag: 'global_chat_fab',
                    draggable: true,
                    persistKey: 'global_chat_fab_v2',
                    initialAlignment: Alignment.bottomLeft,
                    initialMargin: EdgeInsets.only(
                      left: fabLeft,
                      bottom: fabBottom,
                    ),
                    onPressed: () {
                      if (isAlreadyInChat) return;
                      appNavigatorKey.currentState?.pushNamed(AppRoutes.chat);
                    },
                  ),
                if (showGlobalWhatsAppFab)
                  WhatsAppFloatingButton(
                    heroTag: 'global_whatsapp_fab',
                    draggable: true,
                    persistKey: 'global_whatsapp_fab_v1',
                    initialAlignment: Alignment.bottomRight,
                    initialMargin: EdgeInsets.only(
                      right: fabRight,
                      bottom: fabBottom + 72,
                    ),
                  ),
              ],
            );
          },
        ),

        // ---------------------------------------------------
        // لوحة الملاحظات القابلة للسحب وإعادة التحجيم
        // ---------------------------------------------------
        if (canShowQuickNotes && _showQuickNotesPanel)
          Positioned(
            left: _panelOffset.dx,
            top: _panelOffset.dy,
            child: DraggableResizablePanel(
              initialPosition: _panelOffset,
              initialSize: _panelSize,
              onPositionChanged: (newPos) =>
                  setState(() => _panelOffset = newPos),
              onSizeChanged: (newSize) =>
                  setState(() => _panelSize = newSize),
              child: QuickNotesPanel(onClose: _closeQuickNotesPanel),
            ),
          ),

        // ---------------------------------------------------
        // نافذة التعميم (Pending Circular)
        // ---------------------------------------------------
        if (auth.isAuthenticated && circularProvider.pendingCircular != null)
          _PendingCircularOverlay(
            circular: circularProvider.pendingCircular!,
            isAccepting: circularProvider.isAccepting,
            onAccept: () async {
              try {
                await context
                    .read<CircularProvider>()
                    .acceptPendingCircular();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل قبول التعميم: $e')),
                );
              }
            },
          ),
      ],
    );
  }

  /* -------------------------------------------------------
   |  مزامنة حالة التعميم (Pending Circular)               |
   ------------------------------------------------------- */
  void _syncPendingCircularGate(
      AuthProvider auth, CircularProvider circulars) {
    final userId = auth.user?.id;
    if (!auth.isAuthenticated ||
        userId == null ||
        userId.trim().isEmpty) {
      if (_lastCircularCheckUserId != null) {
        _lastCircularCheckUserId = null;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => circulars.reset());
      }
      return;
    }
    if (_lastCircularCheckUserId == userId) return;
    _lastCircularCheckUserId = userId;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => circulars.checkPendingCircular());
  }
}

/* -------------------------------------------------------
|  نافذة التعميم (Pending Circular Overlay)                |
------------------------------------------------------- */
class _PendingCircularOverlay extends StatelessWidget {
  final CircularModel circular;
  final bool isAccepting;
  final Future<void> Function() onAccept;

  const _PendingCircularOverlay({
    required this.circular,
    required this.isAccepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxHeight = size.height * 0.86;
    final subject = circular.subject.trim();
    final body = circular.body.trim().isEmpty
        ? circular.bodyHtml.trim()
        : circular.body.trim();

    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 760, maxHeight: maxHeight),
              child: Material(
                color: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'تعميم جديد',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        circular.number,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subject.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          subject,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              body.isEmpty ? '-' : body,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                height: 1.7,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isAccepting ? null : onAccept,
                        icon: isAccepting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('أوافق وأفتح التطبيق'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
