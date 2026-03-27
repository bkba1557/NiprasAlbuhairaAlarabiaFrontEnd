import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/providers/user_management_provider.dart';
import 'package:order_tracker/screens/tasks/task_location_picker_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

class _AttachmentDraft {
  final String path;
  final String type;

  _AttachmentDraft(this.path, this.type);
}

class TaskFormScreen extends StatefulWidget {
  final TaskModel? task;
  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _employeeSearchController = TextEditingController();
  final _daysController = TextEditingController(text: '0');
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _secondsController = TextEditingController(text: '0');
  final _penaltyAmountController = TextEditingController();

  late final UserManagementProvider _userProvider;

  String? _selectedTitle;
  final Set<String> _selectedUserIds = <String>{};
  final List<_AttachmentDraft> _attachments = [];
  String? _primaryAssigneeId;
  bool _penaltyEnabled = false;

  static const String _manualTitleOption = 'إدخال يدوي';
  static const List<String> _taskTitleOptions = [
    'تسويق المحطات',
    'تشغيل المحطات',
    'الحسابات',
    'الإدارة',
    'صيانة المحطات',
    'صيانة المركبات',
    'المهام التقنية',
    'نقل المحروقات',
    _manualTitleOption,
  ];

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _userProvider = UserManagementProvider()..fetchAllUsers();

    final task = widget.task;
    if (task != null) {
      _hydrateFromTask(task);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _departmentController.dispose();
    _locationAddressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _employeeSearchController.dispose();
    _daysController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _penaltyAmountController.dispose();
    _userProvider.dispose();
    super.dispose();
  }

  void _hydrateFromTask(TaskModel task) {
    final normalizedTitle = task.title.trim();
    if (_taskTitleOptions.contains(normalizedTitle)) {
      _selectedTitle = normalizedTitle;
    } else {
      _selectedTitle = _manualTitleOption;
    }
    _titleController.text = normalizedTitle;
    _descriptionController.text = task.description;
    _departmentController.text = task.department;

    final location = task.location;
    if ((location?.address ?? '').trim().isNotEmpty) {
      _locationAddressController.text = location!.address!.trim();
    }
    if (location?.latitude != null) {
      _latController.text = location!.latitude!.toStringAsFixed(6);
    }
    if (location?.longitude != null) {
      _lngController.text = location!.longitude!.toStringAsFixed(6);
    }

    _selectedUserIds
      ..clear()
      ..add(task.assignedTo)
      ..addAll(
        task.participants
            .map((participant) => participant.userId.trim())
            .where((id) => id.isNotEmpty),
      );
    _primaryAssigneeId = task.assignedTo;

    final totalSeconds = task.countdownDurationSeconds;
    if (totalSeconds > 0) {
      var remaining = totalSeconds;
      final days = remaining ~/ (24 * 60 * 60);
      remaining -= days * 24 * 60 * 60;
      final hours = remaining ~/ (60 * 60);
      remaining -= hours * 60 * 60;
      final minutes = remaining ~/ 60;
      remaining -= minutes * 60;
      final seconds = remaining;

      _daysController.text = days.toString();
      _hoursController.text = hours.toString();
      _minutesController.text = minutes.toString();
      _secondsController.text = seconds.toString();
    }

    final penalty = task.overduePenalty;
    _penaltyEnabled = penalty?.enabled == true;
    if (_penaltyEnabled) {
      _penaltyAmountController.text =
          (penalty?.amount ?? 0).toStringAsFixed(2);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'pdf',
        'jpg',
        'png',
        'doc',
        'docx',
      ],
    );
    if (result == null) return;
    setState(() {
      _attachments.addAll(
        result.paths.whereType<String>().map(
          (path) => _AttachmentDraft(path, 'file'),
        ),
      );
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<TaskLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskLocationPickerScreen(
          initialLat: double.tryParse(_latController.text.trim()),
          initialLng: double.tryParse(_lngController.text.trim()),
          initialAddress: _locationAddressController.text.trim(),
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _latController.text = result.latitude.toStringAsFixed(6);
      _lngController.text = result.longitude.toStringAsFixed(6);
      if (result.address != null && result.address!.isNotEmpty) {
        _locationAddressController.text = result.address!;
      }
    });
  }

  int _parsePositiveInt(String value) {
    final parsed = int.tryParse(value.trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  int get _days => _parsePositiveInt(_daysController.text);
  int get _hours => _parsePositiveInt(_hoursController.text);
  int get _minutes => _parsePositiveInt(_minutesController.text);
  int get _seconds => _parsePositiveInt(_secondsController.text);

  int get _totalDurationSeconds {
    return (_days * 24 * 60 * 60) +
        (_hours * 60 * 60) +
        (_minutes * 60) +
        _seconds;
  }

  DateTime? get _deadlinePreview {
    if (_totalDurationSeconds <= 0) return null;
    return DateTime.now().add(Duration(seconds: _totalDurationSeconds));
  }

  List<User> _eligibleUsers(UserManagementProvider provider) {
    return provider.users
        .where(
          (user) =>
              user.id.isNotEmpty && !user.isBlocked && user.role != 'owner',
        )
        .toList();
  }

  List<User> _filteredUsers(UserManagementProvider provider) {
    final query = _employeeSearchController.text.trim().toLowerCase();
    final users = _eligibleUsers(provider);
    if (query.isEmpty) return users;
    return users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);
    }).toList();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'manager':
        return 'مدير';
      case 'admin':
        return 'مشرف';
      case 'supervisor':
        return 'مراقب';
      case 'maintenance':
      case 'maintenance_technician':
        return 'صيانة';
      case 'finance_manager':
        return 'مالي';
      default:
        return 'موظف';
    }
  }

  void _toggleUser(User user, bool selected) {
    setState(() {
      if (selected) {
        _selectedUserIds.add(user.id);
        _primaryAssigneeId ??= user.id;
      } else {
        _selectedUserIds.remove(user.id);
        if (_primaryAssigneeId == user.id) {
          _primaryAssigneeId = _selectedUserIds.isEmpty
              ? null
              : _selectedUserIds.first;
        }
      }
    });
  }

  void _selectAllVisible(UserManagementProvider provider, bool selectAll) {
    final users = _filteredUsers(provider);
    setState(() {
      if (selectAll) {
        for (final user in users) {
          _selectedUserIds.add(user.id);
        }
        if (_primaryAssigneeId == null && users.isNotEmpty) {
          _primaryAssigneeId = users.first.id;
        }
      } else {
        for (final user in users) {
          _selectedUserIds.remove(user.id);
        }
        if (_primaryAssigneeId != null &&
            !_selectedUserIds.contains(_primaryAssigneeId)) {
          _primaryAssigneeId = _selectedUserIds.isEmpty
              ? null
              : _selectedUserIds.first;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر موظفاً واحداً على الأقل')),
      );
      return;
    }

    if (_totalDurationSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدد مهلة للمهمة بالأيام أو الساعات أو الدقائق أو الثواني',
          ),
        ),
      );
      return;
    }

    final penaltyAmount =
        double.tryParse(_penaltyAmountController.text.trim()) ?? 0;
    if (_penaltyEnabled && penaltyAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ استقطاع صالح بالريال السعودي')),
      );
      return;
    }

    final users = _eligibleUsers(_userProvider);
    final primaryAssignee = users.cast<User?>().firstWhere(
      (user) => user?.id == _primaryAssigneeId,
      orElse: () => users.isEmpty ? null : users.first,
    );

    if (primaryAssignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المسؤول الأساسي عن المهمة')),
      );
      return;
    }

    final participantIds = _selectedUserIds
        .where((userId) => userId != primaryAssignee.id)
        .toList();

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'department': _departmentController.text.trim(),
      'assignedTo': primaryAssignee.id,
      'participantIds': participantIds,
      'countdown': {
        'days': _days,
        'hours': _hours,
        'minutes': _minutes,
        'seconds': _seconds,
      },
      'overduePenalty': {
        'enabled': _penaltyEnabled,
        'amount': _penaltyEnabled ? penaltyAmount : 0,
        'currency': 'SAR',
      },
      'location': {
        'address': _locationAddressController.text.trim(),
        'latitude': _latController.text.trim().isEmpty
            ? null
            : double.tryParse(_latController.text.trim()),
        'longitude': _lngController.text.trim().isEmpty
            ? null
            : double.tryParse(_lngController.text.trim()),
      },
    };

    final taskProvider = context.read<TaskProvider>();
    final isEditing = _isEditing;
    final saved = isEditing
        ? await taskProvider.updateTask(widget.task!.id, payload)
        : await taskProvider.createTask(payload);

    if (saved == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'فشل حفظ التعديلات' : 'فشل إنشاء المهمة'),
        ),
      );
      return;
    }

    if (_attachments.isNotEmpty) {
      await taskProvider.uploadAttachments(
        saved.id,
        _attachments.map((attachment) => attachment.path).toList(),
        attachmentType: 'file',
      );
    }

    if (!mounted) return;
    Navigator.pop(context, saved);
  }

  String _attachmentLabel(_AttachmentDraft attachment) {
    final parts = attachment.path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? attachment.path : parts.last;
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.appBarWaterBright.withValues(alpha: 0.10),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.appBarWaterBright,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageHero() {
    final preview = _deadlinePreview;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF22C1C3)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إنشاء مهمة جديدة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'كوّن المهمة، حدّد الفريق المسؤول، اضبط المهلة، ثم أرسلها مباشرة بالصياغة الأكثر وضوحًا.',
            style: TextStyle(
              color: Colors.white,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip(
                'الموظفون المحددون: ${_selectedUserIds.length}',
                Icons.groups_rounded,
              ),
              _buildHeroChip(
                'المرفقات: ${_attachments.length}',
                Icons.attach_file_rounded,
              ),
              _buildHeroChip(
                preview == null ? 'المهلة: غير محددة' : 'المهلة: جاهزة',
                Icons.timer_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationField(TextEditingController controller, String label) {
    return SizedBox(
      width: 132,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: _fieldDecoration(label: label, icon: Icons.timer_outlined),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildDurationSection() {
    final preview = _deadlinePreview;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            'مهلة المهمة',
            'حدد الأيام والساعات والدقائق والثواني، وسيبدأ العد التنازلي فور إسناد المهمة.',
            Icons.timer_rounded,
            AppColors.infoBlue,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildDurationField(_daysController, 'أيام'),
              _buildDurationField(_hoursController, 'ساعات'),
              _buildDurationField(_minutesController, 'دقائق'),
              _buildDurationField(_secondsController, 'ثواني'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.infoBlue.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.infoBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview == null
                        ? 'لم يتم تحديد مهلة بعد'
                        : 'الموعد المتوقع للانتهاء: ${preview.toLocal()}',
                    style: TextStyle(
                      color: preview == null
                          ? AppColors.mediumGray
                          : AppColors.darkGray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltySection() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      border: Border.all(
        color: AppColors.warningOrange.withValues(alpha: 0.14),
      ),
      color: const Color(0xFFFFFCF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            'سياسة الاستقطاع',
            'يمكن تجهيز مبلغ استقطاع تلقائي للمهمات المتأخرة بالريال السعودي.',
            Icons.price_change_rounded,
            AppColors.warningOrange,
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            value: _penaltyEnabled,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'تفعيل استقطاع عند انتهاء المهلة',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'لن يتم اعتماد الاستقطاع إلا بعد انتهاء المهلة وحسب صلاحيات الإدارة.',
            ),
            onChanged: (value) {
              setState(() => _penaltyEnabled = value);
            },
          ),
          if (_penaltyEnabled) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _penaltyAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration(
                label: 'مبلغ الاستقطاع (ريال سعودي)',
                icon: Icons.currency_exchange_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    return Consumer<UserManagementProvider>(
      builder: (context, provider, _) {
        final filteredUsers = _filteredUsers(provider);
        final allVisibleSelected =
            filteredUsers.isNotEmpty &&
            filteredUsers.every((user) => _selectedUserIds.contains(user.id));

        final selectedUsers = _eligibleUsers(
          provider,
        ).where((user) => _selectedUserIds.contains(user.id)).toList();
        final primaryUser = selectedUsers.cast<User?>().firstWhere(
          (user) => user?.id == _primaryAssigneeId,
          orElse: () => null,
        );

        return AppSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(
                'الفريق المكلف',
                'اختر الموظفين وحدد المسؤول الأساسي عن المهمة من خلال النجمة.',
                Icons.groups_rounded,
                AppColors.primaryBlue,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _employeeSearchController,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  label: 'بحث عن موظف',
                  hintText: 'اكتب الاسم أو البريد أو الصفة',
                  icon: Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: allVisibleSelected,
                    onChanged: filteredUsers.isEmpty
                        ? null
                        : (value) =>
                              _selectAllVisible(provider, value ?? false),
                  ),
                  const Text('اختيار الكل'),
                  const Spacer(),
                  Text(
                    'المحدد: ${_selectedUserIds.length}',
                    style: TextStyle(color: AppColors.mediumGray),
                  ),
                ],
              ),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: provider.isLoading && provider.users.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredUsers.isEmpty
                    ? const Center(child: Text('لا يوجد موظفون مطابقون'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final selected = _selectedUserIds.contains(user.id);
                          final primary = _primaryAssigneeId == user.id;
                          return ListTile(
                            onTap: () => _toggleUser(user, !selected),
                            leading: Checkbox(
                              value: selected,
                              onChanged: (value) =>
                                  _toggleUser(user, value ?? false),
                            ),
                            title: Text(user.name),
                            subtitle: Text(
                              '${user.email} • ${_roleLabel(user.role)}',
                            ),
                            trailing: selected
                                ? IconButton(
                                    tooltip: 'تعيين كمسؤول أساسي',
                                    onPressed: () {
                                      setState(
                                        () => _primaryAssigneeId = user.id,
                                      );
                                    },
                                    icon: Icon(
                                      primary
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: primary
                                          ? Colors.amber.shade700
                                          : AppColors.mediumGray,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              if (selectedUsers.isEmpty)
                Text(
                  'اختر موظفاً واحداً على الأقل، ويمكنك تحديد الكل ثم اختيار المسؤول الأساسي من النجمة.',
                  style: TextStyle(color: AppColors.mediumGray),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedUsers.map((user) {
                    final isPrimary = primaryUser?.id == user.id;
                    return InputChip(
                      avatar: Icon(
                        isPrimary ? Icons.star_rounded : Icons.person_outline,
                        size: 18,
                        color: isPrimary
                            ? Colors.amber.shade700
                            : AppColors.darkGray,
                      ),
                      label: Text(
                        isPrimary ? '${user.name} (أساسي)' : user.name,
                      ),
                      onDeleted: () => _toggleUser(user, false),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBasicsCard() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            'بيانات المهمة',
            'اختر العنوان، القسم، ووصف المهمة بشكل واضح للفريق المنفذ.',
            Icons.assignment_outlined,
            AppColors.secondaryTeal,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedTitle,
            decoration: _fieldDecoration(
              label: 'عنوان المهمة',
              icon: Icons.title_rounded,
            ),
            items: _taskTitleOptions
                .map(
                  (option) =>
                      DropdownMenuItem(value: option, child: Text(option)),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _selectedTitle = value);
              if (value != null && value != _manualTitleOption) {
                _titleController.text = value;
              } else {
                _titleController.clear();
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'اختر عنوان المهمة';
              }
              return null;
            },
          ),
          if (_selectedTitle == _manualTitleOption) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: _fieldDecoration(
                label: 'عنوان المهمة (يدوي)',
                icon: Icons.edit_note_rounded,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'العنوان مطلوب'
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _departmentController,
            decoration: _fieldDecoration(
              label: 'القسم',
              icon: Icons.apartment_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: _fieldDecoration(
              label: 'وصف المهمة',
              icon: Icons.notes_rounded,
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            'الموقع',
            'أضف عنوانًا تقريبيًا أو التقط الإحداثيات من الخريطة لتسهيل التنفيذ والمتابعة.',
            Icons.location_on_outlined,
            AppColors.infoBlue,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationAddressController,
            decoration: _fieldDecoration(
              label: 'عنوان الموقع (اختياري)',
              icon: Icons.place_outlined,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.map_outlined),
            label: const Text('تحديد الموقع على الخريطة'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latController,
                  decoration: _fieldDecoration(
                    label: 'خط العرض',
                    icon: Icons.my_location_rounded,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lngController,
                  decoration: _fieldDecoration(
                    label: 'خط الطول',
                    icon: Icons.explore_outlined,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            'المرفقات',
            'أرفق ملفات أو صوتيات أو صور مساندة حتى تصل تفاصيل المهمة كاملة للفريق.',
            Icons.attach_file_rounded,
            const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: _pickAttachments,
            label: const Text('إرفاق ملفات أو صوت'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_attachments.isEmpty)
            const Text(
              'لا توجد مرفقات مضافة بعد.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments.map((attachment) {
                return InputChip(
                  avatar: const Icon(Icons.attach_file_rounded, size: 18),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      _attachmentLabel(attachment),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: () {
                    setState(() => _attachments.remove(attachment));
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitCard() {
    final isEditing = _isEditing;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الإرسال',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEditing
                ? 'راجع البيانات الأساسية، الفريق المكلف، والمهلة قبل حفظ التعديلات.'
                : 'راجع البيانات الأساسية، الفريق المكلف، والمهلة قبل إنشاء المهمة.',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(isEditing ? 'حفظ التعديلات' : 'إنشاء المهمة'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = context.watch<AuthProvider>().user;
    final isEditing = _isEditing;
    final canCreateTasks = authUser?.hasPermission('tasks_create') ?? false;
    final canEditTasks = authUser?.hasPermission('tasks_edit') ?? false;
    final canAccess = isEditing ? canEditTasks : canCreateTasks;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'تعديل مهمة' : 'إضافة مهمة')),
        body: const Center(
          child: Text('لا تملك صلاحية إدارة المهام.'),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _userProvider,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(isEditing ? 'تعديل مهمة' : 'إضافة مهمة'),
          centerTitle: true,
          flexibleSpace: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            const AppSoftBackground(),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1080;
                final maxWidth = isWide ? 1280.0 : 760.0;
                final inputTheme = theme.inputDecorationTheme.copyWith(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.92),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: AppColors.appBarWaterBright.withValues(
                        alpha: 0.10,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.appBarWaterBright,
                      width: 1.4,
                    ),
                  ),
                );

                return SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Theme(
                          data: theme.copyWith(
                            inputDecorationTheme: inputTheme,
                            elevatedButtonTheme: ElevatedButtonThemeData(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            outlinedButtonTheme: OutlinedButtonThemeData(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPageHero(),
                                const SizedBox(height: 16),
                                if (isWide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _buildEmployeeSelector(),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          children: [
                                            _buildBasicsCard(),
                                            const SizedBox(height: 16),
                                            _buildDurationSection(),
                                            const SizedBox(height: 16),
                                            _buildPenaltySection(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!isWide) ...[
                                  _buildEmployeeSelector(),
                                  const SizedBox(height: 16),
                                  _buildBasicsCard(),
                                  const SizedBox(height: 16),
                                  _buildDurationSection(),
                                  const SizedBox(height: 16),
                                  _buildPenaltySection(),
                                ],
                                const SizedBox(height: 16),
                                _buildLocationCard(),
                                const SizedBox(height: 16),
                                _buildAttachmentsCard(),
                                const SizedBox(height: 16),
                                _buildSubmitCard(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
