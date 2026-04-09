import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/utils/constants.dart';

class OrderStatusTimeline extends StatelessWidget {
  final Order order;

  const OrderStatusTimeline({super.key, required this.order});

  List<StatusStep> _getStatusSteps() {
    final steps = <StatusStep>[];

    // Step 1: Created
    steps.add(
      StatusStep(
        title: 'تم إنشاء الطلب',
        status: 'تم',
        date: order.createdAt,
        icon: Icons.add_circle_outline,
        color: AppColors.successGreen,
        isActive: true,
        description: 'رقم الطلب: ${order.orderNumber}',
      ),
    );

    // Step 2: Assigned to customer (if applicable)
    if (order.customer != null && order.status != 'قيد الانتظار') {
      steps.add(
        StatusStep(
          title: 'تم تعيينه للعميل',
          status: 'تم',
          date: order.createdAt, // يمكنك استخدام تاريخ التعديل الأخير
          icon: Icons.person_add_outlined,
          color: AppColors.infoBlue,
          isActive: true,
          description: order.customer?.name != null
              ? 'للعميل: ${order.customer!.name}'
              : 'تعيين عميل',
        ),
      );
    } else if (order.status == 'مخصص للعميل') {
      steps.add(
        StatusStep(
          title: 'مخصص للعميل',
          status: 'حالياً',
          date: order.updatedAt,
          icon: Icons.person_outline,
          color: AppColors.infoBlue,
          isActive: true,
          description: order.customer?.name != null
              ? 'للعميل: ${order.customer!.name}'
              : 'في انتظار تعيين عميل',
        ),
      );
    }

    // Step 3: Arrival status (إضافة مرحلة الوصول)
    if (order.status == 'في انتظار التحميل') {
      steps.add(
        StatusStep(
          title: 'في انتظار الوصول',
          status: 'قادم',
          date: order.arrivalDate,
          icon: Icons.flag_outlined,
          color: AppColors.infoBlue,
          isActive: false,
          description: 'الوصول المتوقع: ${order.formattedArrivalDateTime}',
        ),
      );
    } else if (order.status == 'جاهز للتحميل' || order.status == 'تم التحميل') {
      steps.add(
        StatusStep(
          title: 'تم الوصول',
          status: 'تم',
          date: order.arrivalDate,
          icon: Icons.flag_outlined,
          color: AppColors.successGreen.withOpacity(0.8),
          isActive: true,
          description: order.actualArrivalTime != null
              ? 'الوصول الفعلي: ${order.actualArrivalTime}'
              : 'وصل في: ${order.arrivalTime}',
        ),
      );
    }

    // Step 4: Waiting for loading
    if (order.status == 'في انتظار التحميل') {
      steps.add(
        StatusStep(
          title: 'في انتظار التحميل',
          status: 'حالياً',
          date: order.updatedAt,
          icon: Icons.schedule_outlined,
          color: AppColors.warningOrange,
          isActive: true,
          description: 'موعد التحميل: ${order.formattedLoadingDateTime}',
        ),
      );
    } else if (order.status == 'جاهز للتحميل' || order.status == 'تم التحميل') {
      steps.add(
        StatusStep(
          title: 'في انتظار التحميل',
          status: 'تم',
          date: order.updatedAt,
          icon: Icons.schedule_outlined,
          color: AppColors.warningOrange,
          isActive: true,
          description: 'موعد التحميل: ${order.formattedLoadingDateTime}',
        ),
      );
    }

    // Step 5: Ready for loading
    if (order.status == 'جاهز للتحميل') {
      steps.add(
        StatusStep(
          title: 'جاهز للتحميل',
          status: 'حالياً',
          date: order.updatedAt,
          icon: Icons.check_circle_outline,
          color: AppColors.successGreen.withOpacity(0.8),
          isActive: true,
          description: 'بانتظار السائق والمركبة',
        ),
      );
    } else if (order.status == 'تم التحميل') {
      steps.add(
        StatusStep(
          title: 'جاهز للتحميل',
          status: 'تم',
          date: order.updatedAt,
          icon: Icons.check_circle_outline,
          color: AppColors.successGreen.withOpacity(0.8),
          isActive: true,
          description: 'تم تجهيز الطلب للتحميل',
        ),
      );
    }

    // Step 6: Loading information (if driver is assigned)
    if (order.driverName != null || order.vehicleNumber != null) {
      steps.add(
        StatusStep(
          title: 'معلومات التحميل',
          status: order.status == 'تم التحميل' ? 'تم' : 'معلومة',
          date: order.updatedAt,
          icon: Icons.local_shipping_outlined,
          color: AppColors.infoBlue,
          isActive: true,
          description: order.driverName != null && order.vehicleNumber != null
              ? 'السائق: ${order.driverName} - المركبة: ${order.vehicleNumber}'
              : order.driverName != null
              ? 'السائق: ${order.driverName}'
              : order.vehicleNumber != null
              ? 'المركبة: ${order.vehicleNumber}'
              : 'معلومات التحميل',
        ),
      );
    }

    // Step 7: Loading completed
    if (order.status == 'تم التحميل') {
      steps.add(
        StatusStep(
          title: 'تم التحميل',
          status: 'تم',
          date: order.loadingCompletedAt ?? order.updatedAt,
          icon: Icons.done_all_outlined,
          color: AppColors.successGreen,
          isActive: true,
          description: order.loadingDuration != null
              ? 'مدة التحميل: ${order.loadingDuration} دقيقة'
              : 'تم اكتمال التحميل',
        ),
      );
    }

    // Step 8: Arrival notification information
    if (order.arrivalNotificationSentAt != null) {
      steps.add(
        StatusStep(
          title: 'إشعار الوصول',
          status: 'تم الإرسال',
          date: order.arrivalNotificationSentAt,
          icon: Icons.notifications_outlined,
          color: AppColors.infoBlue,
          isActive: true,
          description: 'تم إرسال إشعار قبل الوصول بساعتين ونصف',
        ),
      );
    }

    // Step 9: Cancelled (if applicable)
    if (order.status == 'ملغى') {
      steps.add(
        StatusStep(
          title: 'ملغى',
          status: 'ملغى',
          date: order.updatedAt,
          icon: Icons.cancel_outlined,
          color: AppColors.errorRed,
          isActive: true,
          description: order.delayReason != null
              ? 'سبب الإلغاء: ${order.delayReason}'
              : 'تم إلغاء الطلب',
        ),
      );
    }

    // Add upcoming steps based on current status
    if (order.status == 'قيد الانتظار') {
      steps.add(
        StatusStep(
          title: 'في انتظار التعيين',
          status: 'قادم',
          icon: Icons.pending_outlined,
          color: AppColors.pendingYellow,
          isActive: false,
          description: 'بانتظار تعيين عميل',
        ),
      );
    }

    // ترتيب المواعيد المقررة
    if (order.status != 'تم التحميل' && order.status != 'ملغى') {
      // تاريخ الوصول أولاً
      steps.add(
        StatusStep(
          title: 'موعد الوصول المتوقع',
          status: 'مقرر',
          date: order.arrivalDate,
          icon: Icons.flag_outlined,
          color: AppColors.mediumGray,
          isActive: false,
          description: '${order.formattedArrivalDateTime}',
        ),
      );

      // تاريخ التحميل ثانياً
      steps.add(
        StatusStep(
          title: 'موعد التحميل',
          status: 'مقرر',
          date: order.loadingDate,
          icon: Icons.local_shipping_outlined,
          color: AppColors.mediumGray,
          isActive: false,
          description: '${order.formattedLoadingDateTime}',
        ),
      );
    }

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getStatusSteps();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _getStatusColor(order.status).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(order.status).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.timeline_rounded,
                        color: _getStatusColor(order.status),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'سير حالة الطلب',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _getStatusColor(order.status).withOpacity(0.22),
                    ),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (order.customer != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.infoBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: AppColors.infoBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'العميل: ${order.customer!.name}',
                      style: TextStyle(color: AppColors.darkGray, fontSize: 14),
                    ),
                    if (order.customer?.code != null) ...[
                      const SizedBox(width: 16),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryTeal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sell_outlined,
                          size: 15,
                          color: AppColors.secondaryTeal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'كود: ${order.customer!.code!}',
                        style: TextStyle(
                          color: AppColors.secondaryTeal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // Timeline
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;

              return Column(
                children: [
                  // Step
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline line and icon
                      Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: step.isActive
                                    ? [
                                        step.color.withOpacity(0.16),
                                        step.color.withOpacity(0.05),
                                      ]
                                    : [
                                        AppColors.backgroundGray,
                                        Colors.white,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: step.isActive
                                    ? step.color
                                    : AppColors.lightGray,
                                width: 1.8,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                step.icon,
                                size: 20,
                                color: step.isActive
                                    ? step.color
                                    : AppColors.lightGray,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 3,
                              height: 34,
                              decoration: BoxDecoration(
                                color: steps[index + 1].isActive
                                    ? steps[index + 1].color.withOpacity(0.55)
                                    : AppColors.lightGray.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      // Step details
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: step.isActive
                                ? step.color.withOpacity(0.04)
                                : AppColors.backgroundGray.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: step.isActive
                                  ? step.color.withOpacity(0.10)
                                  : AppColors.lightGray.withOpacity(0.30),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      step.title,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: step.isActive
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: step.isActive
                                            ? AppColors.darkGray
                                            : AppColors.mediumGray,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: step.isActive
                                          ? step.color.withOpacity(0.12)
                                          : AppColors.backgroundGray,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: step.isActive
                                            ? step.color.withOpacity(0.18)
                                            : AppColors.lightGray,
                                      ),
                                    ),
                                    child: Text(
                                      step.status,
                                      style: TextStyle(
                                        color: step.isActive
                                            ? step.color
                                            : AppColors.mediumGray,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (step.description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    step.description!,
                                    style: TextStyle(
                                      color: AppColors.mediumGray,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                ),

                              if (step.date != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: AppColors.silverLight.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.schedule_rounded,
                                          size: 12,
                                          color: AppColors.lightGray,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat(
                                          'yyyy/MM/dd HH:mm',
                                        ).format(step.date!),
                                        style: TextStyle(
                                          color: AppColors.mediumGray,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (step.title == 'في انتظار التعيين' &&
                                  order.notificationSentAt != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorRed.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_outlined,
                                        size: 14,
                                        color: AppColors.errorRed,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'تم إرسال إشعار تأخير للمسؤولين',
                                          style: TextStyle(
                                            color: AppColors.errorRed,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (step.title == 'تم التحميل' &&
                                  order.loadingDuration != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoBlue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: AppColors.infoBlue,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'مدة التحميل: ${order.loadingDuration} دقيقة',
                                        style: TextStyle(
                                          color: AppColors.infoBlue,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!isLast) const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'قيد الانتظار':
        return AppColors.pendingYellow;
      case 'مخصص للعميل':
        return AppColors.infoBlue;
      case 'في انتظار التحميل':
        return AppColors.warningOrange;
      case 'جاهز للتحميل':
        return AppColors.successGreen.withOpacity(0.8);
      case 'تم التحميل':
        return AppColors.successGreen;
      case 'ملغى':
        return AppColors.errorRed;
      default:
        return AppColors.lightGray;
    }
  }
}

class StatusStep {
  final String title;
  final String status;
  final DateTime? date;
  final IconData icon;
  final Color color;
  final bool isActive;
  final String? description;

  StatusStep({
    required this.title,
    required this.status,
    this.date,
    required this.icon,
    required this.color,
    required this.isActive,
    this.description,
  });
}
