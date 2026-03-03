import 'package:flutter/material.dart';
import 'package:order_tracker/models/order_timer.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/widgets/dashboard/countdown_card.dart';

class CountdownSection extends StatefulWidget {
  final List<OrderTimer> timers;
  final VoidCallback onViewAll;
  final String title;
  final bool showOverdueOnly;
  final bool showApproachingOnly;
  final bool compactView;

  const CountdownSection({
    super.key,
    required this.timers,
    required this.onViewAll,
    this.title = 'الطلبات القريبة من وقتها',
    this.showOverdueOnly = false,
    this.showApproachingOnly = false,
    this.compactView = false,
  });

  @override
  State<CountdownSection> createState() => _CountdownSectionState();
}

class _CountdownSectionState extends State<CountdownSection> {
  List<OrderTimer> _getFilteredTimers() {
    List<OrderTimer> filteredTimers = widget.timers;

    if (widget.showOverdueOnly) {
      filteredTimers = filteredTimers
          .where((timer) => timer.isOverdue)
          .toList();
    } else if (widget.showApproachingOnly) {
      filteredTimers = filteredTimers
          .where(
            (timer) => timer.isApproachingArrival || timer.isApproachingLoading,
          )
          .toList();
    }

    return filteredTimers;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTimers = _getFilteredTimers();

    if (filteredTimers.isEmpty) {
      return _buildEmptyState();
    }

    final overdueTimers = filteredTimers
        .where((timer) => timer.isOverdue)
        .toList();
    final approachingTimers = filteredTimers
        .where(
          (timer) =>
              !timer.isOverdue &&
              (timer.isApproachingArrival || timer.isApproachingLoading),
        )
        .toList();

    final urgentTimers = filteredTimers
        .where(
          (timer) =>
              timer.remainingTimeToArrival <=
                  const Duration(hours: 2, minutes: 30) &&
              timer.remainingTimeToArrival > Duration.zero,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildSectionHeader(
          filteredTimers.length,
          overdueTimers.length,
          approachingTimers.length,
        ),
        const SizedBox(height: 16),

        // Urgent Banner (when less than 2.5 hours)
        if (urgentTimers.isNotEmpty) _buildUrgentBanner(urgentTimers),

        // Overdue Section
        if (overdueTimers.isNotEmpty) _buildOverdueSection(overdueTimers),

        // Approaching Section
        if (approachingTimers.isNotEmpty)
          _buildApproachingSection(approachingTimers),

        // Quick Actions
        if (overdueTimers.isNotEmpty || approachingTimers.isNotEmpty)
          _buildQuickActions(overdueTimers, approachingTimers),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: AppColors.successGreen,
          ),
          SizedBox(height: 12),
          Text(
            'لا توجد طلبات متأخرة أو مقتربة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'جميع الطلبات تسير وفق الجدول المخطط',
            style: TextStyle(fontSize: 14, color: AppColors.lightGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    int totalCount,
    int overdueCount,
    int approachingCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              child: const Text('عرض الكل'),
            ),
          ],
        ),

        // Statistics
        if (totalCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (overdueCount > 0)
                  _buildCountBadge(
                    count: overdueCount,
                    label: 'متأخر',
                    color: AppColors.errorRed,
                  ),
                if (overdueCount > 0 && approachingCount > 0)
                  const SizedBox(width: 8),
                if (approachingCount > 0)
                  _buildCountBadge(
                    count: approachingCount,
                    label: 'مقترب',
                    color: AppColors.warningOrange,
                  ),
                const SizedBox(width: 8),
                _buildCountBadge(
                  count: totalCount,
                  label: 'إجمالي',
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCountBadge({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentBanner(List<OrderTimer> urgentTimers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.orange.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه عاجل!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                Text(
                  '${urgentTimers.length} طلب سيصل خلال ساعتين ونصف',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.orders,
                arguments: {'showUrgent': true},
              );
            },
            icon: Icon(
              Icons.arrow_forward,
              color: Colors.orange.shade800,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueSection(List<OrderTimer> overdueTimers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الطلبات المتأخرة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: overdueTimers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final timer = overdueTimers[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                color: AppColors.errorRed.withOpacity(0.03),
              ),
              child: CountdownCard(timer: timer, isDesktop: false),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildApproachingSection(List<OrderTimer> approachingTimers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الطلبات المقتربة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.warningOrange,
          ),
        ),
        const SizedBox(height: 8),
        widget.compactView
            ? _buildCompactTimers(approachingTimers)
            : _buildRegularTimers(approachingTimers),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompactTimers(List<OrderTimer> timers) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: timers.length,
      itemBuilder: (context, index) {
        final timer = timers[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
            color: AppColors.warningOrange.withOpacity(0.03),
          ),
          child: CountdownCard(timer: timer, isDesktop: false),
        );
      },
    );
  }

  Widget _buildRegularTimers(List<OrderTimer> timers) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final timer = timers[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
            color: AppColors.warningOrange.withOpacity(0.03),
          ),
          child: CountdownCard(timer: timer, isDesktop: false),
        );
      },
    );
  }

  Widget _buildQuickActions(
    List<OrderTimer> overdueTimers,
    List<OrderTimer> approachingTimers,
  ) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Export action
            OutlinedButton.icon(
              onPressed: () {
                _showExportOptions(context);
              },
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('تصدير القائمة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue),
              ),
            ),

            // Quick actions based on type
            if (overdueTimers.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  _showBulkActions(context, overdueTimers);
                },
                icon: const Icon(
                  Icons.notification_important_outlined,
                  size: 16,
                ),
                label: const Text('إجراءات للمتأخرين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('تصدير كملف Excel'),
                leading: const Icon(
                  Icons.table_chart,
                  color: AppColors.successGreen,
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Call export function
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري تصدير القائمة...'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('تصدير كملف PDF'),
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: AppColors.errorRed,
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Call export function
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري إنشاء ملف PDF...'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('إلغاء'),
                leading: const Icon(Icons.close),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBulkActions(BuildContext context, List<OrderTimer> overdueTimers) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'إجراءات جماعية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.notifications_active,
                  color: AppColors.warningOrange,
                ),
                title: const Text('إرسال تنبيه جماعي'),
                subtitle: const Text('إرسال إشعار لجميع الطلبات المتأخرة'),
                onTap: () {
                  Navigator.pop(context);
                  _sendBulkNotification(overdueTimers);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone, color: AppColors.primaryBlue),
                title: const Text('متابعة جماعية'),
                subtitle: const Text('إنشاء قائمة اتصال بالعملاء/الموردين'),
                onTap: () {
                  Navigator.pop(context);
                  _createCallList(overdueTimers);
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.deepPurple),
                title: const Text('تأجيل جماعي'),
                subtitle: const Text('إعادة جدولة جميع الطلبات المتأخرة'),
                onTap: () {
                  Navigator.pop(context);
                  _rescheduleBulkOrders(overdueTimers);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.assignment,
                  color: AppColors.successGreen,
                ),
                title: const Text('إنشاء تقرير متابعة'),
                subtitle: const Text('تقرير مفصل عن الطلبات المتأخرة'),
                onTap: () {
                  Navigator.pop(context);
                  _generateFollowupReport(overdueTimers);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('إلغاء'),
                leading: const Icon(Icons.close),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendBulkNotification(List<OrderTimer> timers) {
    // Implement bulk notification logic
  }

  void _createCallList(List<OrderTimer> timers) {
    // Implement call list creation logic
  }

  void _rescheduleBulkOrders(List<OrderTimer> timers) {
    // Implement bulk reschedule logic
  }

  void _generateFollowupReport(List<OrderTimer> timers) {
    // Implement report generation logic
  }
}

// Desktop specific countdown section
class DesktopCountdownSection extends StatelessWidget {
  final List<OrderTimer> timers;
  final VoidCallback onViewAll;
  final String title;

  const DesktopCountdownSection({
    super.key,
    required this.timers,
    required this.onViewAll,
    this.title = 'الطلبات المتأخرة والمقتربة',
  });

  @override
  Widget build(BuildContext context) {
    final overdueTimers = timers.where((timer) => timer.isOverdue).toList();
    final approachingTimers = timers
        .where(
          (timer) =>
              !timer.isOverdue &&
              (timer.isApproachingArrival || timer.isApproachingLoading),
        )
        .toList();

    final allTimers = [...overdueTimers, ...approachingTimers];

    if (allTimers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGray),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 60,
              color: AppColors.successGreen,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات متأخرة حالياً',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'جميع الطلبات تسير وفق الجدول المخطط',
              style: TextStyle(fontSize: 14, color: AppColors.lightGray),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorRed,
                  ),
                ),
                if (overdueTimers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        _buildDesktopBadge(
                          count: overdueTimers.length,
                          label: 'متأخر',
                          color: AppColors.errorRed,
                        ),
                        const SizedBox(width: 8),
                        _buildDesktopBadge(
                          count: approachingTimers.length,
                          label: 'مقترب',
                          color: AppColors.warningOrange,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryBlue),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${allTimers.length} طلب يحتاج انتباه',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: onViewAll, child: const Text('عرض الكل')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid layout for desktop
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemCount: allTimers.length,
          itemBuilder: (context, index) {
            final timer = allTimers[index];
            return CountdownCard(timer: timer, isDesktop: true);
          },
        ),
      ],
    );
  }

  Widget _buildDesktopBadge({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}