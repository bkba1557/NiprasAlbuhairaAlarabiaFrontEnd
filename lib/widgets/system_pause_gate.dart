import 'package:flutter/material.dart';
import 'package:order_tracker/models/system_pause_notice_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/system_pause_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/system_pause_overlay.dart';
import 'package:provider/provider.dart';

class SystemPauseGate extends StatelessWidget {
  final Widget child;

  const SystemPauseGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, SystemPauseProvider>(
      builder: (context, auth, systemPause, _) {
        final notice = systemPause.notice;
        final isLoggedIn = auth.isAuthenticated && auth.user != null;
        final role = auth.user?.role ?? '';
        final isOwner = role.trim().toLowerCase() == 'owner';

        final shouldBlock =
            isLoggedIn && !isOwner && (notice?.isActive ?? false);

        return Stack(
          children: [
            child,
            if (isLoggedIn && isOwner && (notice?.isActive ?? false))
              _SystemPauseOwnerBanner(
                notice: notice!,
                isRefreshing: systemPause.isLoading,
                onRefresh: () => systemPause.refresh(),
                onManage: () =>
                    Navigator.pushNamed(context, AppRoutes.systemPause),
              ),
            if (shouldBlock)
              SystemPauseOverlay(
                notice: notice!,
                isRefreshing: systemPause.isLoading,
                onRefresh: () => systemPause.refresh(),
              ),
          ],
        );
      },
    );
  }
}

class _SystemPauseOwnerBanner extends StatelessWidget {
  final SystemPauseNotice notice;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onManage;

  const _SystemPauseOwnerBanner({
    required this.notice,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final title = notice.title.trim().isEmpty
        ? 'تم تفعيل التوقف المؤقت للنظام'
        : notice.title.trim();

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Material(
            color: const Color(0xFFFFF7ED),
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.pause_circle_filled_rounded,
                    color: AppColors.warningOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDarkBlue,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: isRefreshing ? null : onRefresh,
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                  FilledButton(
                    onPressed: onManage,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('إدارة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

