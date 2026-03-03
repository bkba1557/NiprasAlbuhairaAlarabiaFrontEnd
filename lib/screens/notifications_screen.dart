import 'package:flutter/material.dart';
import 'package:order_tracker/models/notification_model.dart';
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/screens/tasks/task_detail_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_item.dart';

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
    await Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final bool isMobile = width < 600;
        final bool isDesktop = width >= 1024;

        final double maxWidth = isDesktop ? 1000 : double.infinity;

        return Scaffold(
          appBar: AppBar(
            title: const Text('الإشعارات'),
            actions: [
              if (notificationProvider.unreadCount > 0)
                Badge(
                  label: Text(notificationProvider.unreadCount.toString()),
                  child: IconButton(
                    onPressed: () {
                      notificationProvider.markAllAsRead();
                    },
                    icon: const Icon(Icons.mark_email_read),
                    tooltip: 'تحديد الكل كمقروء',
                  ),
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  /// ===== Statistics =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppColors.backgroundGray,
                    child: isMobile
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'إجمالي الإشعارات',
                                notificationProvider.notifications.length
                                    .toString(),
                                Icons.notifications,
                                AppColors.primaryBlue,
                              ),
                              _buildStatItem(
                                'غير مقروء',
                                notificationProvider.unreadCount.toString(),
                                Icons.markunread,
                                AppColors.warningOrange,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatItem(
                                'إجمالي الإشعارات',
                                notificationProvider.notifications.length
                                    .toString(),
                                Icons.notifications,
                                AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 48),
                              _buildStatItem(
                                'غير مقروء',
                                notificationProvider.unreadCount.toString(),
                                Icons.markunread,
                                AppColors.warningOrange,
                              ),
                            ],
                          ),
                  ),

                  /// ===== Notifications List =====
                  Expanded(
                    child: notificationProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : notificationProvider.notifications.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'لا توجد إشعارات',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount:
                                  notificationProvider.notifications.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final notification =
                                    notificationProvider.notifications[index];
                                return NotificationItem(
                                  notification: notification,
                                  currentUserId: notificationProvider
                                      .getCurrentUserId(),
                                  onTap: () {
                                    _handleNotificationTap(notification);
                                  },
                                  onDelete: () {
                                    notificationProvider.deleteNotification(
                                      notification.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    provider.markAsRead(notification.id);

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
      Navigator.pushNamed(context, AppRoutes.orderDetails, arguments: orderId);
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
        type == 'task_rejected';
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
      title: const Text('تحقق من رقم المهمة'),
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
