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
            isLoggedIn &&
            !isOwner &&
            notice != null &&
            notice.appliesToUserId(auth.user?.id);

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
          constraints: const BoxConstraints(maxWidth: 980),
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFFFF8E8), Color(0xFFFFF2D8)],
                ),
                border: Border.all(
                  color: AppColors.warningOrange.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.pause_circle_filled_rounded,
                      color: AppColors.warningOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDarkBlue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _BannerPill(
                              icon: Icons.groups_rounded,
                              label: notice.audienceSummary,
                            ),
                            _BannerPill(
                              icon: Icons.person_outline_rounded,
                              label: 'بواسطة: ${notice.actorDisplayName}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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

class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryDarkBlue,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
