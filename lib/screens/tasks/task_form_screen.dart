import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/providers/user_management_provider.dart';
import 'package:order_tracker/screens/tasks/task_location_picker_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

class _AttachmentDraft {
  final String path;
  final String type;

  _AttachmentDraft(this.path, this.type);
}

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _selectedTitle;
  final _descriptionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _employeeController = TextEditingController();
  DateTime? _dueDate;
  User? _selectedUser;
  final List<_AttachmentDraft> _attachments = [];
  late final UserManagementProvider _userProvider;
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

  @override
  void initState() {
    super.initState();
    _userProvider = UserManagementProvider()..fetchUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _departmentController.dispose();
    _locationAddressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _employeeController.dispose();
    _userProvider.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'pdf', 'jpg', 'png', 'doc', 'docx'],
    );
    if (result == null) return;
    setState(() {
      _attachments.addAll(
        result.paths.whereType<String>().map((path) => _AttachmentDraft(path, 'file')),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الموظف أولاً')),
      );
      return;
    }

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'department': _departmentController.text.trim(),
      'assignedTo': _selectedUser!.id,
      'dueDate': _dueDate?.toIso8601String(),
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
    final created = await taskProvider.createTask(payload);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إنشاء المهمة')),
      );
      return;
    }

    if (_attachments.isNotEmpty) {
      await taskProvider.uploadAttachments(
        created.id,
        _attachments.map((e) => e.path).toList(),
        attachmentType: 'file',
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChangeNotifierProvider.value(
      value: _userProvider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة مهمة'),
          centerTitle: true,
          elevation: 0,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final maxWidth = isWide ? 720.0 : 560.0;
            final horizontalPadding = isWide ? 24.0 : 16.0;
            final viewInsets = MediaQuery.of(context).viewInsets.bottom;
            final inputTheme = theme.inputDecorationTheme.copyWith(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
              ),
            );

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF6F8FF), Color(0xFFFDF7F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + viewInsets),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          outlinedButtonTheme: OutlinedButtonThemeData(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        child: Card(
                          elevation: 6,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 20,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildEmployeeSelector(),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _selectedTitle,
                                    decoration: const InputDecoration(labelText: 'عنوان المهمة'),
                                    items: _taskTitleOptions
                                        .map(
                                          (option) => DropdownMenuItem(
                                            value: option,
                                            child: Text(option),
                                          ),
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
                                      decoration: const InputDecoration(labelText: 'عنوان المهمة (يدوي)'),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'العنوان مطلوب'
                                              : null,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _departmentController,
                                    decoration: const InputDecoration(labelText: 'القسم'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _descriptionController,
                                    decoration: const InputDecoration(labelText: 'وصف المهمة'),
                                    maxLines: 4,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _dueDate == null
                                            ? 'تاريخ الاستحقاق: غير محدد'
                                            : 'تاريخ الاستحقاق: ${_dueDate!.toLocal().toString().split(' ').first}',
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(() => _dueDate = picked);
                                          }
                                        },
                                        child: const Text('اختيار التاريخ'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _locationAddressController,
                                    decoration: const InputDecoration(
                                      labelText: 'عنوان الموقع (اختياري)',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _pickLocation,
                                      icon: const Icon(Icons.map_outlined),
                                      label: const Text('تحديد الموقع على الخريطة'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _latController,
                                          decoration: const InputDecoration(labelText: 'خط العرض'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _lngController,
                                          decoration: const InputDecoration(labelText: 'خط الطول'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.attach_file),
                                    onPressed: _pickAttachments,
                                    label: const Text('إرفاق ملفات/صوت'),
                                  ),
                                  if (_attachments.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('مرفقات: ${_attachments.length}'),
                                    ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _submit,
                                    child: const Text('إنشاء المهمة'),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'يمكن تسجيل الصوت وإرساله من شاشة تفاصيل المهمة.',
                                    style: TextStyle(color: AppColors.mediumGray),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    return Consumer<UserManagementProvider>(
      builder: (context, provider, _) {
        return TypeAheadField<User>(
          controller: _employeeController,
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'الموظف المكلف',
                prefixIcon: Icon(Icons.person),
              ),
            );
          },
          suggestionsCallback: (pattern) async {
            await provider.fetchUsers(search: pattern);
            return provider.users;
          },
          itemBuilder: (context, user) {
            return ListTile(
              title: Text(user.name),
              subtitle: Text(user.email),
            );
          },
          onSelected: (user) {
            _selectedUser = user;
            _employeeController.text = user.name;
          },
          emptyBuilder: (_) => const Padding(
            padding: EdgeInsets.all(12),
            child: Text('لا يوجد نتائج'),
          ),
        );
      },
    );
  }
}
