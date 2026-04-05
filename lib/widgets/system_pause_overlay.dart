import 'package:flutter/material.dart';
import 'package:order_tracker/models/system_pause_notice_model.dart';
import 'package:order_tracker/utils/constants.dart';

class SystemPauseOverlay extends StatelessWidget {
  final SystemPauseNotice notice;
  final bool isRefreshing;
  final VoidCallback? onRefresh;

  const SystemPauseOverlay({
    super.key,
    required this.notice,
    this.isRefreshing = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxHeight = size.height * 0.92;

    final title = notice.title.trim().isEmpty
        ? 'النظام متوقف مؤقتاً'
        : notice.title.trim();
    final message = notice.message.trim().isEmpty
        ? 'تم إيقاف النظام مؤقتاً بسبب أعمال تطوير أو تحديث. يرجى الانتظار حتى استئناف العمل.'
        : notice.message.trim();
    final actor = notice.actorDisplayName;

    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
              child: Material(
                color: Colors.white,
                elevation: 18,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FC)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                AppColors.primaryDarkBlue,
                                AppColors.primaryBlue,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.pause_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      title,
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _OverlayMetaChip(
                                          icon: Icons.person_outline_rounded,
                                          label: 'بواسطة: $actor',
                                        ),
                                        _OverlayMetaChip(
                                          icon: Icons.groups_rounded,
                                          label: notice.audienceSummary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                message,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  height: 1.9,
                                  fontSize: 14,
                                  color: AppColors.darkGray,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.warningOrange.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.warningOrange.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                          child: const Text(
                            'سيظل النظام متوقفاً لديك حتى يقوم المالك بإلغاء التوقف المؤقت أو تعديل الجمهور المستهدف.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.primaryDarkBlue,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: isRefreshing ? null : onRefresh,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: isRefreshing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: const Text('تحديث'),
                          ),
                        ),
                      ],
                    ),
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

class _OverlayMetaChip extends StatelessWidget {
  const _OverlayMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
