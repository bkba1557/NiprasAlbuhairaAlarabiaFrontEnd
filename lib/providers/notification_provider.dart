import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/notification_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _currentUserId;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  // دالة لتحديد المستخدم الحالي
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  Future<void> fetchNotifications({int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/notifications?page=$page'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final fetched = (data['notifications'] as List)
            .map((e) => NotificationModel.fromJson(e))
            .toList();
        if (_currentUserId != null && _currentUserId!.isNotEmpty) {
          _notifications = fetched
              .where((n) => n.getRecipientForUser(_currentUserId!) != null)
              .toList();
          _calculateUnreadCount();
        } else {
          _notifications = fetched;
          _unreadCount = data['unreadCount'] ?? 0;
        }
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['pages'];
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب الإشعارات');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/notifications/$notificationId/read'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        // تحديث حالة الإشعار محلياً
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && _currentUserId != null) {
          // إنشاء نسخة جديدة من الإشعار مع حالة القراءة المحدثة
          final updatedNotification = _notifications[index].markAsReadForUser(
            _currentUserId!,
          );

          // استبدال الإشعار القديم بالجديد
          _notifications[index] = updatedNotification;

          // إعادة حساب الإشعارات غير المقروءة
          _calculateUnreadCount();

          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/notifications/read-all'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        // تحديث جميع الإشعارات محلياً
        if (_currentUserId != null) {
          _notifications = _notifications.map((notification) {
            return notification.markAsReadForUser(_currentUserId!);
          }).toList();

          _unreadCount = 0;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/notifications/$notificationId'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        _notifications.removeWhere((n) => n.id == notificationId);

        // إعادة حساب الإشعارات غير المقروءة
        _calculateUnreadCount();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // دالة لإعادة حساب الإشعارات غير المقروءة
  void _calculateUnreadCount() {
    if (_currentUserId == null) {
      _unreadCount = 0;
      return;
    }

    _unreadCount = _notifications.where((notification) {
      final recipient = notification.getRecipientForUser(_currentUserId!);
      return recipient == null || !recipient.read;
    }).length;
  }

  // دالة للحصول على ID المستخدم الحالي
  String getCurrentUserId() {
    return _currentUserId ?? '';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // دالة لإضافة إشعار جديد (للاستخدام المحلي)
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);

    // إذا كان الإشعار غير مقروء من قبل المستخدم الحالي
    if (_currentUserId != null) {
      final recipient = notification.getRecipientForUser(_currentUserId!);
      if (recipient == null || !recipient.read) {
        _unreadCount++;
      }
    }

    notifyListeners();
  }

  // دالة لتحديث الإشعارات بشكل دوري
  Future<void> refreshNotifications() async {
    await fetchNotifications(page: 1);
  }

  // دالة لتحميل المزيد من الإشعارات (pagination)
  Future<void> loadMoreNotifications() async {
    if (_currentPage >= _totalPages || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/notifications?page=$nextPage'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final newNotifications = (data['notifications'] as List)
            .map((e) => NotificationModel.fromJson(e))
            .toList();

        _notifications.addAll(newNotifications);
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['pages'];

        // إعادة حساب الإشعارات غير المقروءة
        _calculateUnreadCount();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // دالة لتصفية الإشعارات حسب النوع
  List<NotificationModel> getNotificationsByType(String type) {
    return _notifications
        .where((notification) => notification.type == type)
        .toList();
  }

  // دالة للحصول على الإشعارات غير المقروءة فقط
  List<NotificationModel> getUnreadNotifications() {
    if (_currentUserId == null) return [];

    return _notifications.where((notification) {
      final recipient = notification.getRecipientForUser(_currentUserId!);
      return recipient == null || !recipient.read;
    }).toList();
  }

  // دالة للحصول على الإشعارات المقروءة فقط
  List<NotificationModel> getReadNotifications() {
    if (_currentUserId == null) return [];

    return _notifications.where((notification) {
      final recipient = notification.getRecipientForUser(_currentUserId!);
      return recipient != null && recipient.read;
    }).toList();
  }

  // دالة للتحقق مما إذا كان هناك إشعارات جديدة
  bool hasNewNotifications() {
    return _unreadCount > 0;
  }

  // دالة لمسح جميع الإشعارات (للاستخدام المحلي)
  void clearAllNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    _currentPage = 1;
    _totalPages = 1;
    notifyListeners();
  }
}
