import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';

class OrderTimer {
  final String orderId;
  final DateTime arrivalDateTime;
  final DateTime loadingDateTime;
  final String orderNumber;
  final String? supplierOrderNumber;
  final String supplierName;
  final String? customerName;
  final String? driverName;
  final String status;
  final String orderSource;

  OrderTimer({
    required this.orderId,
    required this.arrivalDateTime,
    required this.loadingDateTime,
    required this.orderNumber,
    required this.supplierName,
    this.customerName,
    this.driverName,
    required this.status,
    required this.orderSource,
    this.supplierOrderNumber,
  });

  factory OrderTimer.fromOrder(Order order) {
    final arrivalDateTime = DateTime(
      order.arrivalDate.year,
      order.arrivalDate.month,
      order.arrivalDate.day,
      int.parse(order.arrivalTime.split(':')[0]),
      int.parse(order.arrivalTime.split(':')[1]),
    );

    final loadingDateTime = DateTime(
      order.loadingDate.year,
      order.loadingDate.month,
      order.loadingDate.day,
      int.parse(order.loadingTime.split(':')[0]),
      int.parse(order.loadingTime.split(':')[1]),
    );

    return OrderTimer(
      orderId: order.id,
      arrivalDateTime: arrivalDateTime,
      loadingDateTime: loadingDateTime,
      orderNumber: order.orderNumber,
      supplierName: order.supplierName ?? order.supplier?.name ?? 'غير محدد',
      customerName: order.customer!.name ?? order.customer?.name,
      driverName: order.driverName ?? order.driver?.name,
      status: order.status,
      orderSource: order.orderSource,
      supplierOrderNumber: order.supplierOrderNumber,
    );
  }

  Duration get remainingTimeToArrival {
    final now = DateTime.now();
    return arrivalDateTime.difference(now);
  }

  Duration get remainingTimeToLoading {
    final now = DateTime.now();
    return loadingDateTime.difference(now);
  }

  bool get shouldShowCountdown {
    final finalStatuses = ['تم التسليم', 'تم التنفيذ', 'مكتمل', 'ملغى'];
    return !finalStatuses.contains(status);
  }

  bool get isApproachingArrival {
    return remainingTimeToArrival <= const Duration(hours: 2, minutes: 30) &&
        remainingTimeToArrival > Duration.zero;
  }

  bool get isApproachingLoading {
    return remainingTimeToLoading <= const Duration(hours: 2, minutes: 30) &&
        remainingTimeToLoading > Duration.zero;
  }

  bool get isOverdue {
    return remainingTimeToLoading < Duration.zero;
  }

  String get formattedArrivalCountdown {
    if (!shouldShowCountdown || remainingTimeToArrival < Duration.zero) {
      return 'تأخر';
    }

    if (remainingTimeToArrival <= Duration.zero) {
      return 'حان وقت الوصول';
    }

    return _formatDuration(remainingTimeToArrival);
  }

  String get formattedLoadingCountdown {
    if (!shouldShowCountdown || remainingTimeToLoading < Duration.zero) {
      return 'تأخر';
    }

    if (remainingTimeToLoading <= Duration.zero) {
      return 'حان وقت التحميل';
    }

    return _formatDuration(remainingTimeToLoading);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;

    if (totalSeconds <= 0) {
      return '0 ثانية';
    }

    final days = totalSeconds ~/ (24 * 3600);
    final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final parts = <String>[];

    if (days > 0) parts.add('$days يوم');
    if (hours > 0 || days > 0) parts.add('$hours ساعة');
    if (minutes > 0 || hours > 0 || days > 0) parts.add('$minutes دقيقة');
    parts.add('$seconds ثانية');

    return parts.join(' ');
  }

  Color get countdownColor {
    if (isOverdue) return const Color(0xFFF44336); // AppColors.errorRed
    if (isApproachingArrival || isApproachingLoading) {
      return const Color(0xFFFF9800); // Colors.orange
    }
    return const Color(0xFF4CAF50); // AppColors.successGreen
  }

  IconData get countdownIcon {
    if (isOverdue) return Icons.warning;
    if (isApproachingArrival || isApproachingLoading) {
      return Icons.access_time_filled;
    }
    return Icons.check_circle_outline;
  }

  String get orderSourceText {
    switch (orderSource) {
      case 'مورد':
        return 'طلب مورد';
      case 'عميل':
        return 'طلب عميل';
      case 'مدمج':
        return 'طلب مدمج';
      default:
        return orderSource;
    }
  }

  Color get orderSourceColor {
    switch (orderSource) {
      case 'مورد':
        return Colors.blue;
      case 'عميل':
        return Colors.orange;
      case 'مدمج':
        return Colors.purple;
      default:
        return const Color(0xFF2196F3); // AppColors.primaryBlue
    }
  }
}
