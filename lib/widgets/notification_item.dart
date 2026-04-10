import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

import '../models/notification_model.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showActions;
  final String? currentUserId;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDelete,
    this.showActions = true,
    this.currentUserId,
  });

  bool get isRead =>
      _NotificationUiHelper.isReadForUser(notification, currentUserId);

  @override
  Widget build(BuildContext context) {
    final isUnread = !isRead;
    final typeColor = _NotificationUiHelper.getNotificationColor(notification);
    final typeIcon = _NotificationUiHelper.getNotificationIcon(notification);
    final typeText = _NotificationUiHelper.getNotificationTypeText(
      notification,
    );
    final dataEntries = _NotificationUiHelper.visibleDataEntries(
      notification.data,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.primaryBlue.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? AppColors.primaryBlue.withOpacity(0.3)
              : AppColors.lightGray.withOpacity(0.3),
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(typeIcon, size: 20, color: typeColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    typeText,
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isUnread
                                        ? AppColors.darkGray
                                        : AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _NotificationUiHelper.formatTime(
                            notification.createdAt,
                          ),
                          style: const TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (showActions && onDelete != null)
                              IconButton(
                                onPressed: onDelete,
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.errorRed.withOpacity(0.7),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'حذف الإشعار',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, left: 40),
                  child: Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.darkGray,
                    ),
                  ),
                ),
                if (dataEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, left: 40),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.lightGray.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التفاصيل:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mediumGray,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...dataEntries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ${_NotificationUiHelper.formatDataKey(entry.key)}: ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _NotificationUiHelper.formatDataValue(
                                        entry.value,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.darkGray,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 40),
                  child: Row(
                    children: [
                      if (notification.createdByName != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppColors.lightGray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notification.createdByName!,
                              style: const TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.lightGray,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'yyyy/MM/dd',
                            ).format(notification.createdAt),
                            style: const TextStyle(
                              color: AppColors.lightGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationBadge extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;
  final bool showCount;

  const NotificationBadge({
    super.key,
    required this.count,
    required this.onPressed,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'الإشعارات',
        ),
        if (count > 0 && showCount)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationListTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final bool showTimeAgo;
  final String? currentUserId;

  const NotificationListTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.showTimeAgo = true,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !_NotificationUiHelper.isReadForUser(
      notification,
      currentUserId,
    );
    final typeColor = _NotificationUiHelper.getNotificationColor(notification);
    final typeIcon = _NotificationUiHelper.getNotificationIcon(notification);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: typeColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(typeIcon, size: 20, color: typeColor)),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          if (showTimeAgo)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _NotificationUiHelper.formatTimeShort(notification.createdAt),
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      trailing: isUnread
          ? const SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

class _NotificationUiHelper {
  static const Set<String> _hiddenDataKeys = {
    'reportType',
    'deviceRecordId',
    'periodKey',
    'statsCriteria',
    'sampleOrders',
    'task',
    'voucherPath',
    'voucherUrl',
  };

  static bool isReadForUser(NotificationModel notification, String? userId) {
    final normalized = (userId ?? '').trim();
    if (normalized.isNotEmpty) {
      for (final recipient in notification.recipients) {
        if (recipient.userId == normalized) {
          return recipient.read;
        }
      }
      return true;
    }

    if (notification.recipients.length == 1) {
      return notification.recipients.first.read;
    }
    return true;
  }

  static String _reportType(NotificationModel notification) {
    return notification.data?['reportType']?.toString() ?? '';
  }

  static IconData getNotificationIcon(NotificationModel notification) {
    final type = notification.type;
    final reportType = _reportType(notification);

    switch (type) {
      case 'order_created':
        return Icons.add_circle_outline;
      case 'order_assigned':
        return Icons.person_add_outlined;
      case 'order_overdue':
        return Icons.warning_outlined;
      case 'order_updated':
      case 'order_status_update':
      case 'status_changed':
        return reportType == 'owner_merged_order_completed'
            ? Icons.task_alt_outlined
            : Icons.update_outlined;
      case 'task_assigned':
        return Icons.task_alt;
      case 'task_accepted':
        return Icons.check_circle_outline;
      case 'task_started':
        return Icons.play_circle_outline;
      case 'task_completed':
        return Icons.assignment_turned_in_outlined;
      case 'task_approved':
        return Icons.verified_outlined;
      case 'task_rejected':
        return Icons.cancel_outlined;
      case 'task_extension_requested':
        return Icons.pending_actions_outlined;
      case 'task_extension_approved':
        return Icons.more_time_outlined;
      case 'task_extension_rejected':
        return Icons.event_busy_outlined;
      case 'task_penalty_applied':
        return Icons.receipt_long_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'task_reminder':
      case 'note_reminder':
      case 'loading_reminder':
      case 'arrival_reminder':
      case 'movement_archive_required':
        return Icons.notifications_active_outlined;
      case 'driver_document_expiry':
        return Icons.badge_outlined;
      case 'task_overdue':
        return Icons.warning_amber_outlined;
      case 'loading_completed':
      case 'execution_completed':
        return Icons.done_all_outlined;
      case 'system_alert':
        if (reportType == 'blocked_login_device') {
          return Icons.phonelink_lock_outlined;
        }
        if (reportType == 'owner_weekly_completed_orders') {
          return Icons.view_week_outlined;
        }
        if (reportType == 'owner_monthly_completed_orders') {
          return Icons.bar_chart_outlined;
        }
        return Icons.notifications_outlined;
      default:
        return Icons.info_outline;
    }
  }

  static Color getNotificationColor(NotificationModel notification) {
    final type = notification.type;
    final reportType = _reportType(notification);

    switch (type) {
      case 'order_created':
      case 'task_completed':
      case 'task_approved':
      case 'task_extension_approved':
      case 'loading_completed':
      case 'execution_completed':
        return AppColors.successGreen;
      case 'order_assigned':
      case 'task_assigned':
      case 'task_started':
      case 'order_status_update':
        return AppColors.infoBlue;
      case 'order_overdue':
      case 'task_rejected':
      case 'task_extension_rejected':
      case 'task_overdue':
      case 'task_penalty_applied':
        return AppColors.errorRed;
      case 'order_updated':
      case 'task_reminder':
      case 'note_reminder':
      case 'task_extension_requested':
      case 'loading_reminder':
      case 'arrival_reminder':
      case 'driver_document_expiry':
      case 'movement_archive_required':
        return AppColors.warningOrange;
      case 'chat_message':
        return AppColors.infoBlue;
      case 'status_changed':
        return reportType == 'owner_merged_order_completed'
            ? AppColors.successGreen
            : AppColors.infoBlue;
      case 'system_alert':
        if (reportType == 'blocked_login_device') {
          return AppColors.errorRed;
        }
        if (reportType == 'owner_monthly_completed_orders') {
          return AppColors.primaryBlue;
        }
        if (reportType == 'owner_weekly_completed_orders') {
          return AppColors.warningOrange;
        }
        return AppColors.primaryBlue;
      default:
        return AppColors.mediumGray;
    }
  }

  static String getNotificationTypeText(NotificationModel notification) {
    final type = notification.type;
    final reportType = _reportType(notification);

    switch (type) {
      case 'order_created':
        return 'طلب جديد';
      case 'order_assigned':
        return 'تعيين طلب';
      case 'order_overdue':
        return 'طلب متأخر';
      case 'order_updated':
      case 'order_status_update':
        return 'تحديث طلب';
      case 'status_changed':
        return reportType == 'owner_merged_order_completed'
            ? 'اكتمال طلب مدمج'
            : 'تغيير حالة';
      case 'task_assigned':
        return 'مهمة جديدة';
      case 'task_accepted':
        return 'استلام مهمة';
      case 'task_started':
        return 'بدء مهمة';
      case 'task_completed':
        return 'اكتمال مهمة';
      case 'task_approved':
        return 'اعتماد مهمة';
      case 'task_rejected':
        return 'رفض مهمة';
      case 'task_extension_requested':
        return 'طلب تمديد';
      case 'task_extension_approved':
        return 'اعتماد تمديد';
      case 'task_extension_rejected':
        return 'رفض تمديد';
      case 'task_penalty_applied':
        return 'استقطاع مهمة';
      case 'task_reminder':
        return 'تذكير مهمة';
      case 'note_reminder':
        return 'تذكير مذكرة';
      case 'task_overdue':
        return 'مهمة متأخرة';
      case 'chat_message':
        return 'رسالة محادثة';
      case 'loading_reminder':
        return 'تذكير تحميل';
      case 'arrival_reminder':
        return 'تذكير وصول';
      case 'movement_archive_required':
        return 'أرشفة مطلوبة';
      case 'driver_document_expiry':
        return 'انتهاء وثائق سائق';
      case 'loading_completed':
      case 'execution_completed':
        return 'تم التنفيذ';
      case 'system_alert':
        if (reportType == 'blocked_login_device') {
          return 'جهاز محظور';
        }
        if (reportType == 'owner_weekly_completed_orders') {
          return 'ملخص أسبوعي';
        }
        if (reportType == 'owner_monthly_completed_orders') {
          return 'تقرير شهري';
        }
        return 'تنبيه نظام';
      default:
        return 'إشعار';
    }
  }

  static List<MapEntry<String, dynamic>> visibleDataEntries(
    Map<String, dynamic>? data,
  ) {
    if (data == null || data.isEmpty) {
      return const [];
    }
    return data.entries
        .where((entry) => !_hiddenDataKeys.contains(entry.key))
        .toList();
  }

  static String formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    if (difference.inDays == 1) return 'أمس';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';
    return DateFormat('MM/dd').format(date);
  }

  static String formatTimeShort(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'الآن';
    if (difference.inMinutes < 60) return '${difference.inMinutes} د';
    if (difference.inHours < 24) return '${difference.inHours} س';
    if (difference.inDays == 1) return 'أمس';
    if (difference.inDays < 7) return '${difference.inDays} أيام';
    return DateFormat('MM/dd').format(date);
  }

  static String formatDataKey(String key) {
    const translations = {
      'orderId': 'رقم الطلب',
      'orderNumber': 'رقم الطلب',
      'supplierName': 'اسم المورد',
      'customerName': 'اسم العميل',
      'customerId': 'رقم العميل',
      'loadingDate': 'تاريخ التحميل',
      'createdAt': 'تاريخ الإنشاء',
      'oldStatus': 'الحالة السابقة',
      'newStatus': 'الحالة الجديدة',
      'completedAt': 'تاريخ الاكتمال',
      'completedBy': 'تم بواسطة',
      'fuelType': 'نوع الوقود',
      'quantity': 'الكمية',
      'unit': 'الوحدة',
      'totalPrice': 'إجمالي السعر',
      'trigger': 'مصدر التحديث',
      'reason': 'السبب',
      'periodLabel': 'الفترة',
      'periodStart': 'بداية الفترة',
      'periodEnd': 'نهاية الفترة',
      'completedOrdersCount': 'عدد الطلبات المكتملة',
      'deltaCount': 'الفرق العددي',
      'deltaPercent': 'نسبة التغيير',
      'currentMonth': 'الشهر الحالي',
      'previousMonth': 'الشهر السابق',
      'comparison': 'المقارنة',
      'rating': 'التقييم',
      'score': 'الدرجة',
      'label': 'التصنيف',
      'description': 'الوصف',
      'actorName': 'بواسطة',
      'taskId': 'معرّف المهمة',
      'taskCode': 'رقم المهمة',
      'extensionSeconds': 'مدة التمديد بالثواني',
      'extensionReason': 'سبب التمديد',
      'decisionReason': 'سبب القرار',
      'penaltyAmount': 'قيمة الاستقطاع',
      'penaltyCurrency': 'عملة الاستقطاع',
      'voucherNumber': 'رقم السند',
      'notes': 'ملاحظات',
    };
    return translations[key] ?? key;
  }

  static String formatDataValue(dynamic value) {
    if (value == null) return '-';

    if (value is DateTime) {
      return DateFormat('yyyy/MM/dd HH:mm').format(value);
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('yyyy/MM/dd HH:mm').format(parsed.toLocal());
      }
      return value;
    }

    if (value is bool) {
      return value ? 'نعم' : 'لا';
    }

    if (value is num) {
      return value.toString();
    }

    if (value is List) {
      if (value.isEmpty) return 'لا يوجد';
      return '${value.length} عناصر';
    }

    if (value is Map) {
      final map = value.cast<dynamic, dynamic>();

      if (map.containsKey('deltaCount') || map.containsKey('deltaPercent')) {
        final deltaCount = map['deltaCount'];
        final deltaPercent = map['deltaPercent'];
        final deltaPrefix = (deltaCount is num && deltaCount > 0) ? '+' : '';
        return 'فرق: $deltaPrefix${deltaCount ?? 0} | نسبة: ${deltaPercent ?? 0}%';
      }

      if (map.containsKey('score') && map.containsKey('label')) {
        return '(${map['score']}) ${map['label']}';
      }

      if (map.containsKey('label') && map.containsKey('completedOrdersCount')) {
        return '${map['label']}: ${map['completedOrdersCount']} طلب';
      }

      if (map.containsKey('orderNumber')) {
        return map['orderNumber'].toString();
      }

      final encoded = jsonEncode(map);
      return encoded.length > 120 ? '${encoded.substring(0, 120)}...' : encoded;
    }

    return value.toString();
  }
}
