import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/notification_model.dart';
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/screens/tasks/task_detail_screen.dart';
import 'package:order_tracker/screens/tracking/driver_delivery_tracking_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    await context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;
    final unreadCount = notificationProvider.unreadCount;
    final readCount = (notifications.length - unreadCount).clamp(
      0,
      notifications.length,
    );
    final currentUserId = notificationProvider.getCurrentUserId();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 760;
        final isDesktop = width >= 1180;
        final maxWidth = isDesktop ? 1120.0 : 980.0;
        final horizontalPadding = isMobile ? 12.0 : 24.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('الإشعارات'),
            actions: [
              IconButton(
                onPressed: _loadNotifications,
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: isMobile
                      ? IconButton(
                          onPressed: notificationProvider.markAllAsRead,
                          tooltip: 'قراءة الكل',
                          icon: const Icon(Icons.mark_email_read_outlined),
                        )
                      : TextButton.icon(
                          onPressed: notificationProvider.markAllAsRead,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.white,
                            backgroundColor: AppColors.white.withOpacity(0.08),
                          ),
                          icon: const Icon(
                            Icons.mark_email_read_outlined,
                            size: 18,
                          ),
                          label: const Text('تحديد الكل كمقروء'),
                        ),
                ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F7FC), Color(0xFFF8FAFD), Colors.white],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Builder(
                  builder: (context) {
                    if (notificationProvider.isLoading &&
                        notifications.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (isMobile) {
                      return RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            12,
                            horizontalPadding,
                            20,
                          ),
                          children: [
                            _buildOverviewSection(
                              isMobile: true,
                              totalCount: notifications.length,
                              unreadCount: unreadCount,
                              readCount: readCount,
                            ),
                            const SizedBox(height: 12),
                            if (notificationProvider.error != null &&
                                notifications.isEmpty)
                              _buildErrorState(onRetry: _loadNotifications)
                            else if (notifications.isEmpty)
                              _buildEmptyState(isMobile: true)
                            else
                              ...notifications.map(
                                (notification) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildNotificationCard(
                                    notification: notification,
                                    currentUserId: currentUserId,
                                    isMobile: true,
                                    onTap: () =>
                                        _handleNotificationTap(notification),
                                    onDelete: () => notificationProvider
                                        .deleteNotification(notification.id),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            20,
                            horizontalPadding,
                            10,
                          ),
                          child: _buildOverviewSection(
                            isMobile: false,
                            totalCount: notifications.length,
                            unreadCount: unreadCount,
                            readCount: readCount,
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (notificationProvider.error != null &&
                                  notifications.isEmpty) {
                                return _buildErrorState(
                                  onRetry: _loadNotifications,
                                );
                              }

                              if (notifications.isEmpty) {
                                return _buildEmptyState(isMobile: false);
                              }

                              return RefreshIndicator(
                                onRefresh: _loadNotifications,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    6,
                                    horizontalPadding,
                                    28,
                                  ),
                                  itemCount: notifications.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final notification = notifications[index];
                                    return _buildNotificationCard(
                                      notification: notification,
                                      currentUserId: currentUserId,
                                      isMobile: false,
                                      onTap: () =>
                                          _handleNotificationTap(notification),
                                      onDelete: () => notificationProvider
                                          .deleteNotification(notification.id),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewSection({
    required bool isMobile,
    required int totalCount,
    required int unreadCount,
    required int readCount,
  }) {
    final stats = [
      (
        'إجمالي الإشعارات',
        totalCount.toString(),
        Icons.notifications_active_outlined,
        AppColors.primaryBlue,
      ),
      (
        'غير مقروء',
        unreadCount.toString(),
        Icons.markunread_mailbox_outlined,
        AppColors.warningOrange,
      ),
      (
        'تمت قراءته',
        readCount.toString(),
        Icons.verified_outlined,
        AppColors.successGreen,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 22 : 30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFDFEFF), Color(0xFFF3F7FF)],
        ),
        border: Border.all(color: AppColors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لوحة الإشعارات',
            style: TextStyle(
              fontSize: isMobile ? 17 : 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'واجهة مرتبة وواضحة للتنبيهات بدون أكواد أو معرفات داخل المحتوى.',
            style: TextStyle(
              fontSize: isMobile ? 11.2 : 13.5,
              color: AppColors.mediumGray,
              height: 1.55,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 18),
          if (isMobile)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
              children: stats
                  .map(
                    (stat) => _buildStatCard(
                      stat.$1,
                      stat.$2,
                      stat.$3,
                      stat.$4,
                      true,
                    ),
                  )
                  .toList(),
            )
          else
            Row(
              children: stats.map((stat) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: stat == stats.last ? 0 : 12,
                    ),
                    child: _buildStatCard(
                      stat.$1,
                      stat.$2,
                      stat.$3,
                      stat.$4,
                      false,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required NotificationModel notification,
    required String currentUserId,
    required bool isMobile,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final isRead = currentUserId.isNotEmpty
        ? notification.isReadByUser(currentUserId)
        : false;
    final accent = _notificationColor(notification.type);
    final icon = _notificationIcon(notification.type);
    final typeLabel = _notificationTypeLabel(notification.type);
    final title = _notificationTitle(notification);
    final message = _notificationMessage(notification);
    final fields = _displayFields(notification);
    final actor = _creatorName(notification);
    final timeLabel = _formatRelativeTime(notification.createdAt);
    final dateLabel = DateFormat(
      'yyyy/MM/dd - hh:mm a',
    ).format(notification.createdAt.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white.withOpacity(isRead ? 0.90 : 0.98),
                accent.withOpacity(isRead ? 0.04 : 0.08),
              ],
            ),
            border: Border.all(
              color: isRead
                  ? AppColors.silverLight.withOpacity(0.95)
                  : accent.withOpacity(0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(isRead ? 0.05 : 0.08),
                blurRadius: isMobile ? 16 : 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isMobile ? 40 : 52,
                      height: isMobile ? 40 : 52,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
                      ),
                      child: Icon(
                        icon,
                        color: accent,
                        size: isMobile ? 19 : 24,
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildInfoPill(
                                label: typeLabel,
                                color: accent,
                                icon: Icons.label_important_outline_rounded,
                              ),
                              _buildInfoPill(
                                label: isRead ? 'تمت القراءة' : 'جديد',
                                color: isRead
                                    ? AppColors.successGreen
                                    : AppColors.warningOrange,
                                icon: isRead
                                    ? Icons.done_all_rounded
                                    : Icons.fiber_new_rounded,
                              ),
                              _buildInfoPill(
                                label: timeLabel,
                                color: AppColors.mediumGray,
                                icon: Icons.schedule_rounded,
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDarkBlue,
                            ),
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: isMobile ? 11.5 : 13.5,
                                color: AppColors.darkGray,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'حذف الإشعار',
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.errorRed.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
                if (fields.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 10 : 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      border: Border.all(
                        color: AppColors.silverLight.withOpacity(0.95),
                      ),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: fields
                          .map(
                            (field) => ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: isMobile ? 120 : 180,
                                maxWidth: isMobile ? 260 : 360,
                              ),
                              child: _buildDetailTile(
                                label: field.label,
                                value: field.value,
                                icon: field.icon,
                                isMobile: isMobile,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                SizedBox(height: isMobile ? 10 : 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (actor != null && actor.isNotEmpty)
                      _buildInfoPill(
                        label: actor,
                        color: AppColors.primaryBlue,
                        icon: Icons.person_outline_rounded,
                      ),
                    _buildInfoPill(
                      label: dateLabel,
                      color: AppColors.infoBlue,
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isMobile}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 22 : 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.silverLight.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 72 : 84,
                height: isMobile ? 72 : 84,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 42,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد إشعارات حالياً',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'عند وصول تنبيهات جديدة ستظهر هنا بشكل مرتب وواضح.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 12.5 : 13.5,
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState({required Future<void> Function() onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.errorRed.withOpacity(0.16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.errorRed,
                size: 52,
              ),
              const SizedBox(height: 14),
              const Text(
                'تعذر تحميل الإشعارات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'أعد المحاولة لتحميل آخر التحديثات.',
                style: TextStyle(fontSize: 13.5, color: AppColors.mediumGray),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: isMobile
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray.withOpacity(0.75),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
        border: Border.all(color: AppColors.silverLight.withOpacity(0.80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 30 : 36,
            height: isMobile ? 30 : 36,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlue,
              size: isMobile ? 16 : 18,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDarkBlue,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_NotificationField> _displayFields(NotificationModel notification) {
    final data = _normalizedData(notification);
    final fields = <_NotificationField>[];

    void addField({
      required String label,
      required List<String> aliases,
      required IconData icon,
      String Function(String value)? formatter,
    }) {
      final raw = _pickValue(data, aliases);
      if (raw == null) return;
      var value = _sanitizeText(raw);
      if (value.isEmpty || _looksSensitiveValue(value)) return;
      if (formatter != null) {
        value = formatter(value);
      }
      if (value.isEmpty) return;
      if (fields.any((field) => field.label == label && field.value == value)) {
        return;
      }
      fields.add(_NotificationField(label: label, value: value, icon: icon));
    }

    addField(
      label: 'المحطة',
      aliases: const [
        'stationName',
        'station',
        'stationTitle',
        'اسم المحطة',
        'المحطة',
      ],
      icon: Icons.local_gas_station_outlined,
    );
    addField(
      label: 'العنوان',
      aliases: const [
        'stationAddress',
        'address',
        'location',
        'stationLocation',
        'عنوان',
        'العنوان',
        'الموقع',
      ],
      icon: Icons.location_on_outlined,
    );
    addField(
      label: 'نوع الوقود',
      aliases: const ['fuelType', 'fuel', 'نوع الوقود'],
      icon: Icons.opacity_outlined,
    );
    addField(
      label: 'المخزون الحالي',
      aliases: const [
        'currentBalance',
        'currentStock',
        'currentQuantity',
        'الرصيد الحالي',
        'المخزون الحالي',
      ],
      icon: Icons.inventory_2_outlined,
      formatter: (value) => _formatMetricValue(value, unit: 'لتر'),
    );
    addField(
      label: 'حد التنبيه',
      aliases: const [
        'threshold',
        'limit',
        'warningThreshold',
        'حد التنبيه',
        'الحد الأدنى',
      ],
      icon: Icons.warning_amber_rounded,
      formatter: (value) => _formatMetricValue(value, unit: 'لتر'),
    );
    addField(
      label: 'الكمية',
      aliases: const ['quantity', 'qty', 'الكمية'],
      icon: Icons.straighten_rounded,
      formatter: (value) => _formatMetricValue(value, unit: 'لتر'),
    );
    addField(
      label: 'المبلغ',
      aliases: const ['amount', 'total', 'totalPrice', 'المبلغ', 'الإجمالي'],
      icon: Icons.payments_outlined,
      formatter: (value) => _formatMetricValue(value, unit: 'ر.س'),
    );
    addField(
      label: 'السبب',
      aliases: const ['reason', 'السبب'],
      icon: Icons.help_outline_rounded,
    );
    addField(
      label: 'ملاحظات',
      aliases: const ['note', 'notes', 'details', 'ملاحظات', 'الملاحظات'],
      icon: Icons.notes_rounded,
    );

    return fields.take(6).toList();
  }

  Map<String, dynamic> _normalizedData(NotificationModel notification) {
    final merged = <String, dynamic>{};

    void merge(dynamic raw) {
      final map = _decodeMap(raw);
      if (map == null) return;
      map.forEach((key, value) {
        final cleanKey = key.toString().trim();
        if (cleanKey.isEmpty || value == null) return;
        if (_isSensitiveKey(cleanKey)) return;
        merged[cleanKey] = value;
      });
    }

    merge(notification.data);
    if (notification.data == null) return merged;

    merge(notification.data!['changes']);
    merge(notification.data!['payload']);
    merge(notification.data!['station']);
    merge(notification.data!['order']);
    merge(notification.data!['task']);
    merge(notification.data!['conversation']);

    return merged;
  }

  Map<String, dynamic>? _decodeMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    if (raw is String) {
      final text = raw.trim();
      if (!(text.startsWith('{') && text.endsWith('}'))) return null;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  String? _pickValue(Map<String, dynamic> data, List<String> aliases) {
    for (final alias in aliases) {
      final normalizedAlias = _normalizeKey(alias);
      for (final entry in data.entries) {
        if (_normalizeKey(entry.key) != normalizedAlias) continue;
        final value = _extractReadableValue(entry.value);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  String? _extractReadableValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is Map) {
      final map = value.map((key, val) => MapEntry(key.toString(), val));
      return _pickValue(map, const [
        'name',
        'title',
        'label',
        'address',
        'location',
        'value',
        'اسم',
        'العنوان',
        'الموقع',
      ]);
    }
    return null;
  }

  String _notificationTitle(NotificationModel notification) {
    final fallback = _sanitizeText(notification.title);
    if (fallback.isNotEmpty) return fallback;

    final data = _normalizedData(notification);
    final stationName = _pickValue(data, const [
      'stationName',
      'station',
      'stationTitle',
      'اسم المحطة',
      'المحطة',
    ]);
    if (stationName != null && stationName.isNotEmpty) {
      return '${_notificationTypeLabel(notification.type)} - ${_sanitizeText(stationName)}';
    }

    return _notificationTypeLabel(notification.type);
  }

  String _notificationMessage(NotificationModel notification) {
    final data = _normalizedData(notification);
    final stationName = _pickValue(data, const [
      'stationName',
      'station',
      'اسم المحطة',
      'المحطة',
    ]);
    final address = _pickValue(data, const [
      'stationAddress',
      'address',
      'location',
      'العنوان',
      'الموقع',
    ]);
    final fuelType = _pickValue(data, const ['fuelType', 'fuel', 'نوع الوقود']);
    final currentBalance = _pickValue(data, const [
      'currentBalance',
      'currentStock',
      'الرصيد الحالي',
      'المخزون الحالي',
    ]);
    final threshold = _pickValue(data, const [
      'threshold',
      'warningThreshold',
      'حد التنبيه',
      'الحد الأدنى',
    ]);

    if (currentBalance != null || threshold != null || stationName != null) {
      final parts = <String>[];
      if (stationName != null && stationName.isNotEmpty) {
        parts.add('المحطة: ${_sanitizeText(stationName)}');
      } else if (address != null && address.isNotEmpty) {
        parts.add('الموقع: ${_sanitizeText(address)}');
      }
      if (fuelType != null && fuelType.isNotEmpty) {
        parts.add('الوقود: ${_sanitizeText(fuelType)}');
      }
      if (currentBalance != null && currentBalance.isNotEmpty) {
        parts.add('الحالي: ${_formatMetricValue(currentBalance, unit: 'لتر')}');
      }
      if (threshold != null && threshold.isNotEmpty) {
        parts.add('الحد: ${_formatMetricValue(threshold, unit: 'لتر')}');
      }
      final combined = parts.join(' • ');
      if (combined.isNotEmpty) return combined;
    }

    return _sanitizeText(notification.message);
  }

  String? _creatorName(NotificationModel notification) {
    final data = _normalizedData(notification);
    final name =
        _pickValue(data, const [
          'senderName',
          'actorName',
          'createdByName',
          'userName',
          'name',
          'اسم المستخدم',
          'الاسم',
        ]) ??
        notification.createdByName;
    if (name == null) return null;
    final sanitized = _sanitizeText(name);
    if (sanitized.isEmpty || _looksSensitiveValue(sanitized)) return null;
    return sanitized;
  }

  String _sanitizeText(String text) {
    var result = text.trim();
    if (result.isEmpty) return '';

    result = result.replaceAll(RegExp(r'\b[a-fA-F0-9]{24}\b'), '');
    result = result.replaceAll(
      RegExp(r'\bSTN[\w-]+\b', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\b(id|code)\s*[:=-]?\s*[\w-]+\b', caseSensitive: false),
      '',
    );
    result = result.replaceAll(RegExp(r'[{}\[\]"]'), '');
    result = result.replaceAll(RegExp(r'\(\s*\)'), '');
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    result = result.replaceAll(RegExp(r'^[•،,\-\s]+|[•،,\-\s]+$'), '');

    return result.trim();
  }

  bool _isSensitiveKey(String key) {
    final normalized = _normalizeKey(key);
    const sensitiveTokens = [
      'id',
      'code',
      'userid',
      'senderid',
      'stationid',
      'stationcode',
      'conversationid',
      'taskid',
      'orderid',
      'customerid',
      'supplierid',
      'badge',
      'reporttype',
      'recipient',
      'changes',
      'كود',
      'معرف',
      'رقمالمستخدم',
      'رقمالمحطة',
    ];

    return sensitiveTokens.any(normalized.contains);
  }

  bool _looksSensitiveValue(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(text)) return true;
    if (RegExp(r'^STN[\w-]+$', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    if (RegExp(r'^[A-Z]{2,}[-_]?\d+[A-Z0-9_-]*$').hasMatch(text)) {
      return true;
    }
    return false;
  }

  String _normalizeKey(String key) {
    return key
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-:]'), '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  String _formatMetricValue(String raw, {required String unit}) {
    final number = num.tryParse(raw.replaceAll(',', '').trim());
    if (number == null) return _sanitizeText(raw);
    final formatted = NumberFormat('#,##0.##').format(number);
    return '$formatted $unit';
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inSeconds < 45) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return DateFormat('yyyy/MM/dd').format(date.toLocal());
  }

  Color _notificationColor(String type) {
    if (type.contains('warning') ||
        type.contains('low_stock') ||
        type.contains('alert')) {
      return AppColors.warningOrange;
    }
    if (type.contains('success') ||
        type.contains('approved') ||
        type.contains('completed')) {
      return AppColors.successGreen;
    }
    if (type.contains('task')) {
      return AppColors.accentBlue;
    }
    if (type.contains('driver_document_expiry')) {
      return AppColors.warningOrange;
    }
    if (type.contains('chat') || type.contains('message')) {
      return AppColors.secondaryTeal;
    }
    return AppColors.primaryBlue;
  }

  IconData _notificationIcon(String type) {
    if (type.contains('warning') ||
        type.contains('low_stock') ||
        type.contains('alert')) {
      return Icons.warning_amber_rounded;
    }
    if (type.contains('task')) {
      return Icons.task_alt_rounded;
    }
    if (type.contains('driver_document_expiry')) {
      return Icons.badge_outlined;
    }
    if (type.contains('chat') || type.contains('message')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (type.contains('order')) {
      return Icons.local_shipping_outlined;
    }
    return Icons.notifications_active_outlined;
  }

  String _notificationTypeLabel(String type) {
    switch (type) {
      case 'low_stock_alert':
        return 'تنبيه مخزون';
      case 'task_assigned':
        return 'مهمة جديدة';
      case 'task_reminder':
        return 'تذكير مهمة';
      case 'task_overdue':
        return 'مهمة متأخرة';
      case 'task_completed':
        return 'إنجاز مهمة';
      case 'chat_message':
      case 'message_received':
        return 'رسالة جديدة';
      case 'order_created':
        return 'طلب جديد';
      default:
        return 'إشعار';
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    final provider = context.read<NotificationProvider>();
    provider.markAsRead(notification.id);

    final reportType = notification.data?['reportType']?.toString();
    if (reportType == 'blocked_login_device') {
      Navigator.pushNamed(context, AppRoutes.blockedDevices);
      return;
    }

    final conversationId = _extractConversationId(notification);
    if (conversationId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.chatConversation,
        arguments: {
          'conversationId': conversationId,
          if (notification.data?['senderName'] != null)
            'peer': {'name': notification.data?['senderName'].toString()},
        },
      );
      return;
    }

    final orderId = _extractOrderId(notification);
    if (orderId != null) {
      final auth = context.read<AuthProvider>();
      final isDriverUser =
          auth.user?.role == 'driver' &&
          (auth.user?.driverId?.trim().isNotEmpty ?? false);
      if (isDriverUser) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverDeliveryTrackingScreen(orderId: orderId),
          ),
        );
      } else {
        Navigator.pushNamed(
          context,
          AppRoutes.orderDetails,
          arguments: orderId,
        );
      }
      return;
    }

    final taskId = _extractTaskId(notification);
    if (taskId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
      );
      return;
    }

    if (_isTaskNotification(notification.type)) {
      _promptTaskCodeAndOpen(context);
    }
  }

  bool _isTaskNotification(String type) {
    return type == 'task_assigned' ||
        type == 'task_reminder' ||
        type == 'task_overdue' ||
        type == 'task_accepted' ||
        type == 'task_started' ||
        type == 'task_message' ||
        type == 'task_completed' ||
        type == 'task_approved' ||
        type == 'task_rejected' ||
        type == 'task_extension_requested' ||
        type == 'task_extension_approved' ||
        type == 'task_extension_rejected' ||
        type == 'task_penalty_applied';
  }

  String? _extractTaskId(NotificationModel notification) {
    final data = notification.data;
    if (data == null) return null;
    final direct = _extractEntityId(data['taskId'] ?? data['task_id']);
    if (direct != null) return direct;
    final task = data['task'];
    if (task is Map) {
      final id = _extractEntityId(task['id'] ?? task['_id']);
      if (id != null) return id;
    }
    return null;
  }

  String? _extractConversationId(NotificationModel notification) {
    final data = notification.data;
    if (data == null) return null;
    final direct = _extractEntityId(
      data['conversationId'] ?? data['conversation_id'],
    );
    if (direct != null) return direct;
    final conversation = data['conversation'];
    if (conversation is Map) {
      final id = _extractEntityId(conversation['id'] ?? conversation['_id']);
      if (id != null) return id;
    }
    return null;
  }

  String? _extractOrderId(NotificationModel notification) {
    final data = notification.data;
    if (data == null) return null;
    final direct = _extractEntityId(data['orderId'] ?? data['order_id']);
    if (direct != null) return direct;
    final order = data['order'];
    if (order is Map) {
      final id = _extractEntityId(order['id'] ?? order['_id']);
      if (id != null) return id;
    }
    return null;
  }

  String? _extractEntityId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final value = raw.trim();
      return value.isEmpty ? null : value;
    }
    if (raw is Map) {
      final map = raw.cast<dynamic, dynamic>();
      final nested =
          map['_id'] ?? map['id'] ?? map[r'$oid'] ?? map['oid'] ?? map['value'];
      if (nested != null) {
        final value = nested.toString().trim();
        return value.isEmpty ? null : value;
      }
    }
    final fallback = raw.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  Future<void> _promptTaskCodeAndOpen(BuildContext context) async {
    final task = await showGeneralDialog<TaskModel?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'task-code',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => const Material(
        type: MaterialType.transparency,
        child: Center(child: _TaskCodeDialog()),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (task != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
      );
    }
  }
}

class _TaskCodeDialog extends StatefulWidget {
  const _TaskCodeDialog();

  @override
  State<_TaskCodeDialog> createState() => _TaskCodeDialogState();
}

class _TaskCodeDialogState extends State<_TaskCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'رقم المهمة مطلوب');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final taskProvider = context.read<TaskProvider>();
    final task = await taskProvider.lookupTaskByCode(code);
    if (task == null) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = 'رقم المهمة غير صحيح';
      });
      return;
    }
    if (mounted) {
      Navigator.pop(context, task);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('التحقق من رقم المهمة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رقم المهمة للمتابعة'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'رقم المهمة',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _errorText,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('تحقق'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationField {
  const _NotificationField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
