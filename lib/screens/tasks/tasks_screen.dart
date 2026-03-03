import 'package:flutter/material.dart';
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/screens/tasks/task_detail_screen.dart';
import 'package:order_tracker/screens/tasks/task_form_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class TasksScreen extends StatefulWidget {
  final String? initialTaskCode;
  const TasksScreen({super.key, this.initialTaskCode});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String _statusFilter = 'all';
  bool _isLoading = false;
  bool _handledInitialCode = false;
  static const double _maxContentWidth = 1200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTasks();
      await _handleInitialTaskCode();
    });
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final provider = context.read<TaskProvider>();
    final isOwner = auth.user?.role == 'owner';

    final filters = <String, dynamic>{};
    if (_searchController.text.trim().isNotEmpty) {
      filters['search'] = _searchController.text.trim();
    }
    if (_statusFilter != 'all') {
      filters['status'] = _statusFilter;
    }

    await provider.fetchTasks(mine: !isOwner, filters: filters);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleInitialTaskCode() async {
    if (_handledInitialCode) return;
    final code = widget.initialTaskCode?.trim();
    if (code == null || code.isEmpty) return;
    _handledInitialCode = true;

    final provider = context.read<TaskProvider>();
    final task = await provider.lookupTaskByCode(code);
    if (!mounted) return;

    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على المهمة لهذا الرقم')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    ).then((_) => _loadTasks());
  }

  Future<void> _acceptByCode() async {
    final provider = context.read<TaskProvider>();
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final task = await provider.acceptTaskByCode(code);
    if (!mounted) return;

    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر استلام المهمة، تحقق من الرقم')),
      );
      return;
    }

    _codeController.clear();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    ).then((_) => _loadTasks());
  }

  Future<void> _acceptAssignedTaskFromCard(TaskModel task) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController();
    TaskModel? acceptedTask;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        var isSubmitting = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تأكيد استلام المهمة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('أدخل رقم المهمة للتحقق قبل البدء'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'رقم المهمة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = controller.text.trim();
                          if (code.isEmpty) {
                            setState(() => errorText = 'رقم المهمة مطلوب');
                            return;
                          }
                          setState(() {
                            isSubmitting = true;
                            errorText = null;
                          });
                          final result = await provider.acceptTaskByCode(code);
                          if (result == null) {
                            setState(() {
                              isSubmitting = false;
                              errorText = 'رقم المهمة غير صحيح';
                            });
                            return;
                          }
                          acceptedTask = result;
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تحقق'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (confirmed == true && acceptedTask != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: acceptedTask!.id),
        ),
      ).then((_) => _loadTasks());
    }
  }

  void _setStatusFilter(String status) {
    setState(() => _statusFilter = status);
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<TaskProvider>();
    final isOwner = auth.user?.role == 'owner';
    final tasks = isOwner ? provider.tasks : provider.myTasks;
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width >= 900 ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المهام'),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskFormScreen()),
                );
                _loadTasks();
              },
            ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              await authProvider.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
          ),
        ],
      ),
      
      
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F7F9), Color(0xFFF1F2F4)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > _maxContentWidth
                  ? _maxContentWidth
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      24,
                    ),
                    children: [
                      _buildHeader(tasks),
                      const SizedBox(height: 12),
                      _buildDashboardCards(tasks, isOwner, contentWidth),
                      const SizedBox(height: 12),
                      if (!isOwner) _buildCodeEntryCard(),
                      _buildFilters(),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _buildTaskList(tasks, isOwner: isOwner),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<TaskModel> tasks) {
    final total = tasks.length;
    final completedCount = tasks.where((t) => t.status == 'completed').length;
    final activeCount = tasks.where((t) {
      return t.status == 'assigned' ||
          t.status == 'accepted' ||
          t.status == 'in_progress';
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.silverGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.silverDark.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u0644\u0648\u062d\u0629 \u0627\u0644\u0645\u0647\u0627\u0645',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '\u062a\u0627\u0628\u0639 \u0627\u0644\u0645\u0647\u0627\u0645 \u0648\u062d\u0627\u0644\u0627\u062a\u0647\u0627 \u0645\u0646 \u0646\u0641\u0633 \u0627\u0644\u0648\u0627\u062c\u0647\u0629',
            style: TextStyle(color: AppColors.mediumGray),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip(
                label: '\u0625\u062c\u0645\u0627\u0644\u064a',
                value: '$total',
                icon: Icons.list_alt,
                color: AppColors.primaryBlue,
              ),
              _buildStatChip(
                label: '\u0646\u0634\u0637\u0629',
                value: '$activeCount',
                icon: Icons.timelapse,
                color: AppColors.warningOrange,
              ),
              _buildStatChip(
                label: '\u0645\u0643\u062a\u0645\u0644\u0629',
                value: '$completedCount',
                icon: Icons.check_circle,
                color: AppColors.successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards(List<TaskModel> tasks, bool isOwner, double maxWidth) {
    final total = tasks.length;
    final completedCount =
        tasks.where((t) => t.status == 'completed').length;

    final cards = <Widget>[
      _buildDashboardCard(
        title: '\u0633\u062c\u0644 \u0627\u0644\u0645\u0647\u0627\u0645',
        subtitle: '$total \u0645\u0647\u0645\u0629',
        icon: Icons.list_alt,
        color: AppColors.primaryBlue,
        onTap: () => _setStatusFilter('all'),
      ),
      if (isOwner)
        _buildDashboardCard(
          title: '\u0645\u0647\u0645\u0629 \u062c\u062f\u064a\u062f\u0629',
          subtitle: '\u0625\u0646\u0634\u0627\u0621 \u0645\u0647\u0645\u0629',
          icon: Icons.add_task,
          color: AppColors.successGreen,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaskFormScreen()),
            );
            _loadTasks();
          },
        ),
      _buildDashboardCard(
        title: '\u0627\u0644\u0645\u0647\u0627\u0645 \u0627\u0644\u0645\u0646\u062a\u0647\u064a\u0629',
        subtitle: '$completedCount \u0645\u0647\u0645\u0629',
        icon: Icons.done_all,
        color: AppColors.warningOrange,
        onTap: () => _setStatusFilter('completed'),
      ),
    ];

    final baseColumns = maxWidth >= 1000
        ? 3
        : maxWidth >= 680
            ? 2
            : 1;
    final columns = baseColumns > cards.length ? cards.length : baseColumns;
    final cardWidth =
        (maxWidth - ((columns - 1) * 12)) / (columns == 0 ? 1 : columns);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        return SizedBox(
          width: cardWidth,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 320 + (index * 80)),
            curve: Curves.easeOutCubic,
            builder: (context, value, widget) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: widget,
                ),
              );
            },
            child: child,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '\u0628\u062d\u062b (\u0639\u0646\u0648\u0627\u0646 \u0623\u0648 \u0631\u0642\u0645 \u0627\u0644\u0645\u0647\u0645\u0629)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTasks,
                ),
              ),
              onSubmitted: (_) => _loadTasks(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(labelText: '\u0627\u0644\u062d\u0627\u0644\u0629'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('\u0627\u0644\u0643\u0644')),
                DropdownMenuItem(value: 'assigned', child: Text('\u062a\u0645 \u0627\u0644\u0625\u0633\u0646\u0627\u062f')),
                DropdownMenuItem(value: 'accepted', child: Text('\u062a\u0645 \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645')),
                DropdownMenuItem(value: 'in_progress', child: Text('\u0642\u064a\u062f \u0627\u0644\u062a\u0646\u0641\u064a\u0630')),
                DropdownMenuItem(value: 'completed', child: Text('\u0645\u0643\u062a\u0645\u0644\u0629')),
                DropdownMenuItem(value: 'approved', child: Text('\u0645\u0639\u062a\u0645\u062f\u0629')),
                DropdownMenuItem(value: 'rejected', child: Text('\u0645\u0631\u0641\u0648\u0636\u0629')),
                DropdownMenuItem(value: 'overdue', child: Text('\u0645\u062a\u0623\u062e\u0631\u0629')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _statusFilter = value);
                _loadTasks();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEntryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u0627\u0633\u062a\u0644\u0627\u0645 \u0645\u0647\u0645\u0629 \u0639\u0628\u0631 \u0631\u0642\u0645 \u0627\u0644\u0645\u0647\u0645\u0629',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '\u0631\u0642\u0645 \u0627\u0644\u0645\u0647\u0645\u0629 (6 \u0623\u0631\u0642\u0627\u0645)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _acceptByCode,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('\u0627\u0633\u062a\u0644\u0627\u0645 \u0627\u0644\u0645\u0647\u0645\u0629'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks, {required bool isOwner}) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0647\u0627\u0645'),
        ),
      );
    }

    return Column(
      key: ValueKey('${_statusFilter}_${tasks.length}_${_searchController.text}'),
      children: tasks.asMap().entries.map((entry) {
        return _buildAnimatedTaskCard(entry.value, entry.key, isOwner);
      }).toList(),
    );
  }

  Widget _buildAnimatedTaskCard(TaskModel task, int index, bool isOwner) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _buildTaskCard(task, isOwner),
    );
  }

  Widget _buildMetaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mediumGray),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: AppColors.mediumGray),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
      case 'approved':
        return AppColors.successGreen;
      case 'in_progress':
        return AppColors.infoBlue;
      case 'accepted':
        return AppColors.primaryBlue;
      case 'assigned':
        return AppColors.warningOrange;
      case 'rejected':
        return AppColors.errorRed;
      case 'overdue':
        return AppColors.pendingYellow;
      default:
        return AppColors.mediumGray;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'تم الإسناد';
      case 'accepted':
        return 'تم الاستلام';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      case 'approved':
        return 'معتمدة';
      case 'rejected':
        return 'مرفوضة';
      case 'overdue':
        return 'متأخرة';
      default:
        return status;
    }
  }

  Widget _buildTaskCard(TaskModel task, bool isOwner) {
    final statusColor = _statusColor(task.status);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!isOwner && task.status == 'assigned') {
            _acceptAssignedTaskFromCard(task);
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
          ).then((_) => _loadTasks());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      _statusLabel(task.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildMetaItem(Icons.tag, '\u0631\u0642\u0645: ${task.taskCode}'),
                  if (task.assignedToName.isNotEmpty)
                    _buildMetaItem(Icons.person, task.assignedToName),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
