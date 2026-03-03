import 'package:flutter/material.dart';
import 'package:order_tracker/models/order_timer.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:intl/intl.dart';

class CountdownCard extends StatelessWidget {
  final OrderTimer timer;
  final VoidCallback? onTap;
  final bool isDesktop;

  const CountdownCard({
    super.key,
    required this.timer,
    this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgentArrival =
        timer.remainingTimeToArrival <= const Duration(hours: 2, minutes: 30);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUrgentArrival
              ? Colors.orange.shade400
              : timer.countdownColor.withOpacity(0.3),
          width: isUrgentArrival ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap:
            onTap ??
            () {
              Navigator.pushNamed(
                context,
                AppRoutes.orderDetails,
                arguments: timer.orderId,
              );
            },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: isDesktop
              ? const EdgeInsets.all(20)
              : const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with urgent badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${timer.orderNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 18 : 16,
                            color: isUrgentArrival
                                ? Colors.orange.shade800
                                : AppColors.darkGray,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Order type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: timer.orderSourceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timer.orderSourceText,
                            style: TextStyle(
                              color: timer.orderSourceColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUrgentArrival) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'قريب من وقت الوصول',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    timer.countdownIcon,
                    color: isUrgentArrival
                        ? Colors.orange.shade600
                        : timer.countdownColor,
                    size: isDesktop ? 24 : 20,
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 12 : 8),

              // Supplier and Customer info
              Text(
                timer.supplierName,
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: isDesktop ? 15 : 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (timer.customerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'للعميل: ${timer.customerName!}',
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: isDesktop ? 14 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: isDesktop ? 16 : 12),

              // Countdown Timers
              _buildCountdownRow(
                icon: Icons.flag_outlined,
                label: 'وقت الوصول',
                countdown: timer.formattedArrivalCountdown,
                color: isUrgentArrival ? Colors.orange : Colors.blue,
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 12 : 8),
              _buildCountdownRow(
                icon: Icons.local_shipping_outlined,
                label: 'وقت التحميل',
                countdown: timer.formattedLoadingCountdown,
                color: timer.isApproachingLoading
                    ? Colors.orange
                    : timer.isOverdue
                    ? AppColors.errorRed
                    : Colors.green,
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 16 : 12),

              // Status and Time Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: timer.countdownColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: timer.countdownColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: isDesktop ? 16 : 14,
                          color: timer.countdownColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timer.status,
                          style: TextStyle(
                            color: timer.countdownColor,
                            fontSize: isDesktop ? 13 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Loading time
                  if (!isDesktop)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MM/dd').format(timer.loadingDateTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(timer.loadingDateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.lightGray,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownRow({
    required IconData icon,
    required String label,
    required String countdown,
    required Color color,
    required bool isDesktop,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: isDesktop ? 18 : 16, color: color),
          SizedBox(width: isDesktop ? 12 : 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mediumGray,
                fontSize: isDesktop ? 15 : 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              countdown,
              style: TextStyle(
                color: color,
                fontSize: isDesktop ? 14 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Mobile specific compact version
class CompactCountdownCard extends StatelessWidget {
  final OrderTimer timer;

  const CompactCountdownCard({super.key, required this.timer});

  @override
  Widget build(BuildContext context) {
    final isUrgent = timer.isApproachingArrival || timer.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isUrgent ? Colors.orange.shade300 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.orderDetails,
            arguments: timer.orderId,
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Order number and type
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: timer.orderSourceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timer.orderSourceText,
                            style: TextStyle(
                              color: timer.orderSourceColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: timer.isOverdue
                                  ? AppColors.errorRed.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              timer.isOverdue ? 'متأخر' : 'قريب',
                              style: TextStyle(
                                color: timer.isOverdue
                                    ? AppColors.errorRed
                                    : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'طلب #${timer.orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      timer.supplierName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Countdown and time
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: timer.countdownColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timer.formattedLoadingCountdown,
                        style: TextStyle(
                          color: timer.countdownColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تحميل: ${DateFormat('hh:mm a').format(timer.loadingDateTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),

              // Status icon
              const SizedBox(width: 8),
              Icon(timer.countdownIcon, size: 20, color: timer.countdownColor),
            ],
          ),
        ),
      ),
    );
  }
}

// Horizontal scrollable list of countdown cards
class CountdownCardList extends StatelessWidget {
  final List<OrderTimer> timers;
  final String? title;
  final bool showViewAll;
  final VoidCallback? onViewAll;
  final bool compact;

  const CountdownCardList({
    super.key,
    required this.timers,
    this.title,
    this.showViewAll = false,
    this.onViewAll,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (timers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || showViewAll)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                if (showViewAll && onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text(
                      'عرض الكل',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: compact ? 120 : 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: timers.length,
            itemBuilder: (context, index) {
              final timer = timers[index];
              return Container(
                width: compact ? 280 : 320,
                margin: EdgeInsets.only(
                  right: index < timers.length - 1 ? 12 : 0,
                ),
                child: compact
                    ? CompactCountdownCard(timer: timer)
                    : CountdownCard(timer: timer),
              );
            },
          ),
        ),
      ],
    );
  }
}
