import 'package:flutter/material.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class NavigationLoadingObserver extends NavigatorObserver {
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);

  void _show() {
    if (!isLoading.value) {
      isLoading.value = true;
    }
  }

  void _hideSoon() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (isLoading.value) {
        isLoading.value = false;
      }
    });
  }

  void _handleRoute(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final routeName = route.settings.name;
    if (currentRouteName.value != routeName) {
      currentRouteName.value = routeName;
    }
    _show();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideSoon());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _handleRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _handleRoute(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final routeName = previousRoute?.settings.name;
    if (currentRouteName.value != routeName) {
      currentRouteName.value = routeName;
    }
    super.didPop(route, previousRoute);
  }
}

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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final barHeight = kToolbarHeight + topPadding;
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();
    final canShowChat = auth.isAuthenticated && auth.user != null;
    const embeddedChatFabRoutes = <String>{
      AppRoutes.dashboard,
      AppRoutes.mainHome,
      AppRoutes.maintenanceDashboard,
      AppRoutes.periodicMaintenance,
      AppRoutes.marketingStations,
      AppRoutes.chat,
      AppRoutes.chatConversation,
    };

    if (canShowChat) {
      chat.startBackgroundSync();
    } else if (chat.hasRunningSync || chat.totalUnread > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ChatProvider>().clearState();
      });
    }

    return Stack(
      children: [
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
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: AppColors.appBarWaterGlow.withOpacity(0.35),
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
                            AppColors.appBarWaterGlow.withOpacity(0.28),
                            AppColors.appBarWaterMid.withOpacity(0.12),
                            AppColors.appBarWaterDeep.withOpacity(0.18),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.appBarWaterGlow.withOpacity(0.35),
                              AppColors.appBarWaterGlow.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.75],
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
        Positioned.fill(child: widget.child),
        ValueListenableBuilder<bool>(
          valueListenable: widget.observer.isLoading,
          builder: (context, loading, _) {
            return IgnorePointer(
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
            );
          },
        ),
        ValueListenableBuilder<String?>(
          valueListenable: widget.observer.currentRouteName,
          builder: (context, currentRouteName, _) {
            final normalizedRoute =
                currentRouteName == null
                    ? null
                    : (Uri.tryParse(currentRouteName)?.path ?? currentRouteName);
            final showGlobalChatFab =
                canShowChat && !embeddedChatFabRoutes.contains(normalizedRoute);
            if (!showGlobalChatFab) {
              return const SizedBox.shrink();
            }
            const chatFabLiftPx = 132.0; // ~3.5 cm on standard 96dpi displays
            final fabBottom =
                MediaQuery.of(context).padding.bottom + 32 + chatFabLiftPx;

            return Positioned(
              left: 22,
              bottom: fabBottom,
              child: Badge(
                isLabelVisible: chat.totalUnread > 0,
                label: Text(
                  chat.totalUnread > 99 ? '99+' : chat.totalUnread.toString(),
                ),
                child: FloatingActionButton(
                  heroTag: 'global_chat_fab',
                  onPressed: () {
                    appNavigatorKey.currentState?.pushNamed(AppRoutes.chat);
                  },
                  child: const Icon(Icons.chat_bubble_outline),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
