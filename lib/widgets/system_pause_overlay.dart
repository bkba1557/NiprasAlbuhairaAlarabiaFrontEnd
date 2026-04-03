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

    final title =
        notice.title.trim().isEmpty ? 'النظام متوقف مؤقتاً' : notice.title.trim();
    final message = notice.message.trim().isEmpty
        ? 'النظام متوقف مؤقتاً بسبب أعمال تطوير/تحديث. يرجى الانتظار.'
        : notice.message.trim();
    final developer = notice.developerName.trim();

    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
              child: Material(
                color: Colors.white,
                elevation: 10,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.pause_circle_filled_rounded,
                              color: AppColors.warningOrange,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              textAlign: TextAlign.right,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDarkBlue,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              message,
                              textAlign: TextAlign.right,
                              style: const TextStyle(height: 1.8, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      if (developer.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'بواسطة المطور: $developer',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'لن تتمكن من استخدام النظام حتى يقوم المالك بإلغاء التوقف المؤقت.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: isRefreshing ? null : onRefresh,
                            icon: isRefreshing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: const Text('تحديث'),
                          ),
                        ],
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

