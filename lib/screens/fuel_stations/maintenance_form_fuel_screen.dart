import 'package:flutter/material.dart';
import 'package:order_tracker/models/fuel_station_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class MaintenanceFuelFormScreen extends StatefulWidget {
  final MaintenanceRecord? recordToEdit;

  const MaintenanceFuelFormScreen({super.key, this.recordToEdit});

  @override
  State<MaintenanceFuelFormScreen> createState() =>
      _MaintenanceFuelFormScreenState();
}

class _MaintenanceFuelFormScreenState extends State<MaintenanceFuelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _estimatedCostController =
      TextEditingController();
  final TextEditingController _actualCostController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedStationId;
  String? _selectedStationName;
  String _maintenanceType = 'وقائية';
  String _priority = 'متوسط';
  String _status = 'مطلوب';
  String? _selectedTechnicianId;
  String? _selectedTechnicianName;
  DateTime _scheduledDate = DateTime.now();
  DateTime? _completedDate;
  List<MaintenanceTask> _tasks = [];
  List<String> _attachmentPaths = [];

  final List<String> _maintenanceTypes = [
    'وقائية',
    'طارئة',
    'روتينية',
    'تطويرية',
  ];
  final List<String> _priorities = ['عالي', 'متوسط', 'منخفض'];
  final List<String> _statuses = [
    'مطلوب',
    'قيد المراجعة',
    'مجدول',
    'تحت التنفيذ',
    'مكتمل',
    'ملغى',
  ];
  final List<String> _technicians = [
    'أحمد محمد - فني كهرباء',
    'علي حسن - فني ميكانيكا',
    'سامي خالد - فني مضخات',
    'محمد علي - فني عام',
  ];

  @override
  void initState() {
    super.initState();
    _loadStations();
    if (widget.recordToEdit != null) {
      _initializeFormWithRecord();
    }
  }

  void _initializeFormWithRecord() {
    final record = widget.recordToEdit!;

    _selectedStationId = record.stationId;
    _selectedStationName = record.stationName;
    _maintenanceType = record.maintenanceType;
    _priority = record.priority;
    _status = record.status;
    _descriptionController.text = record.description;
    _selectedTechnicianId = record.technicianId;
    _selectedTechnicianName = record.technicianName;
    _scheduledDate = record.scheduledDate;
    _completedDate = record.completedDate;
    _estimatedCostController.text = record.estimatedCost.toString();
    _actualCostController.text = record.actualCost.toString();
    _tasks = List.from(record.tasks);
    _notesController.text = record.notes ?? '';
  }

  Future<void> _loadStations() async {
    final provider = Provider.of<FuelStationProvider>(context, listen: false);
    await provider.fetchStations();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _attachmentPaths.addAll(result.paths.whereType<String>());
      });
    }
  }

  Future<void> _pickDate(String field) async {
    DateTime initialDate;
    if (field == 'scheduled') {
      initialDate = _scheduledDate;
    } else {
      initialDate = _completedDate ?? DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (field == 'scheduled') {
          _scheduledDate = picked;
        } else {
          _completedDate = picked;
        }
      });
    }
  }

  void _addTask() {
    showDialog(
      context: context,
      builder: (context) => TaskDialog(
        onSave: (task) {
          setState(() {
            _tasks.add(task);
          });
        },
      ),
    );
  }

  void _editTask(int index) {
    showDialog(
      context: context,
      builder: (context) => TaskDialog(
        task: _tasks[index],
        onSave: (task) {
          setState(() {
            _tasks[index] = task;
          });
        },
      ),
    );
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  Future<void> _submitMaintenance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المحطة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = Provider.of<FuelStationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final record = MaintenanceRecord(
      id: widget.recordToEdit?.id ?? '',
      stationId: _selectedStationId!,
      stationName: _selectedStationName!,
      maintenanceType: _maintenanceType,
      priority: _priority,
      status: _status,
      description: _descriptionController.text.trim(),
      technicianId: _selectedTechnicianId,
      technicianName: _selectedTechnicianName,
      scheduledDate: _scheduledDate,
      completedDate: _completedDate,
      estimatedCost: double.tryParse(_estimatedCostController.text) ?? 0,
      actualCost: double.tryParse(_actualCostController.text) ?? 0,
      tasks: _tasks,
      attachments: [],
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      createdBy: authProvider.user?.id ?? '',
      createdByName: authProvider.user?.name ?? '',
      createdAt: DateTime.now(),
    );

    bool success;
    if (widget.recordToEdit != null) {
      // TODO: Implement update maintenance record
      success = await provider.createMaintenanceRecord(record);
    } else {
      success = await provider.createMaintenanceRecord(record);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.recordToEdit != null
                ? 'تم تحديث سجل الصيانة بنجاح'
                : 'تم إنشاء سجل الصيانة بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FuelStationProvider>(context);
    final isEditing = widget.recordToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل سجل الصيانة' : 'طلب صيانة جديد'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Station Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المحطة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStationId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('اختر المحطة'),
                          items: provider.stations.map((station) {
                            return DropdownMenuItem<String>(
                              value: station.id,
                              child: Text(
                                '${station.stationName} - ${station.city}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStationId = value;
                              _selectedStationName = provider.stations
                                  .firstWhere((s) => s.id == value)
                                  .stationName;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Maintenance Details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل الصيانة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _maintenanceType,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: _maintenanceTypes.map((String value) {
                                  IconData icon;
                                  switch (value) {
                                    case 'وقائية':
                                      icon = Icons.health_and_safety;
                                      break;
                                    case 'طارئة':
                                      icon = Icons.warning;
                                      break;
                                    case 'روتينية':
                                      icon = Icons.settings;
                                      break;
                                    case 'تطويرية':
                                      icon = Icons.upgrade;
                                      break;
                                    default:
                                      icon = Icons.build;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Icon(icon, size: 16),
                                        const SizedBox(width: 8),
                                        Text(value),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _maintenanceType = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _priority,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: _priorities.map((String value) {
                                  Color color;
                                  switch (value) {
                                    case 'عالي':
                                      color = Colors.red;
                                      break;
                                    case 'متوسط':
                                      color = Colors.orange;
                                      break;
                                    case 'منخفض':
                                      color = Colors.green;
                                      break;
                                    default:
                                      color = Colors.grey;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(value),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _priority = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _status,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _statuses.map((String value) {
                            Color color;
                            IconData icon;

                            switch (value) {
                              case 'مطلوب':
                                color = Colors.orange;
                                icon = Icons.pending;
                                break;
                              case 'قيد المراجعة':
                                color = Colors.blue;
                                icon = Icons.reviews;
                                break;
                              case 'مجدول':
                                color = Colors.purple;
                                icon = Icons.schedule;
                                break;
                              case 'تحت التنفيذ':
                                color = Colors.yellow;
                                icon = Icons.build;
                                break;
                              case 'مكتمل':
                                color = Colors.green;
                                icon = Icons.check_circle;
                                break;
                              case 'ملغى':
                                color = Colors.red;
                                icon = Icons.cancel;
                                break;
                              default:
                                color = Colors.grey;
                                icon = Icons.info;
                            }

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 16),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _status = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _descriptionController,
                        labelText: 'وصف الصيانة',
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال وصف الصيانة';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Dates and Technician
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التواريخ والفني',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('scheduled'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'التاريخ المقرر',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'yyyy/MM/dd',
                                      ).format(_scheduledDate),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('completed'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'تاريخ الإكمال',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _completedDate != null
                                          ? DateFormat(
                                              'yyyy/MM/dd',
                                            ).format(_completedDate!)
                                          : 'لم يكتمل',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedTechnicianId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('اختر الفني (اختياري)'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('غير محدد'),
                            ),
                            ..._technicians.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedTechnicianId = value;
                              _selectedTechnicianName = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Costs
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التكاليف',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _estimatedCostController,
                              labelText: 'التكلفة المتوقعة',
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.attach_money,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال التكلفة المتوقعة';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'قيمة غير صالحة';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _actualCostController,
                              labelText: 'التكلفة الفعلية',
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.money,
                            ),
                          ),
                        ],
                      ),
                      if (_estimatedCostController.text.isNotEmpty &&
                          _actualCostController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الفرق:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _calculateDifference(),
                                  style: TextStyle(
                                    color: _getDifferenceColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tasks
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المهام',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة مهمة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_tasks.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey,
                              // style: BorderStyle.dashed,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.task, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد مهام',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._tasks.asMap().entries.map(
                          (entry) => TaskItem(
                            task: entry.value,
                            onEdit: () => _editTask(entry.key),
                            onDelete: () => _removeTask(entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Notes
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملاحظات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _notesController,
                        labelText: 'ملاحظات إضافية',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Attachments
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المرفقات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickAttachments,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('إضافة مرفقات'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_attachmentPaths.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey,
                              // style: BorderStyle.dashed,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد مرفقات',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._attachmentPaths.map(
                          (path) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getFileIcon(path),
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        path.split('/').last,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _formatFileSize(path),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _attachmentPaths.remove(path);
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Submit Button
              GradientButton(
                onPressed: provider.isLoading ? null : _submitMaintenance,
                text: provider.isLoading
                    ? 'جاري الحفظ...'
                    : (isEditing ? 'تحديث سجل الصيانة' : 'إنشاء طلب صيانة'),
                gradient: AppColors.accentGradient,
                isLoading: provider.isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateDifference() {
    final estimated = double.tryParse(_estimatedCostController.text) ?? 0;
    final actual = double.tryParse(_actualCostController.text) ?? 0;
    final difference = actual - estimated;

    if (difference > 0) {
      return '+${difference.toStringAsFixed(2)} (زيادة)';
    } else if (difference < 0) {
      return '${difference.toStringAsFixed(2)} (توفير)';
    } else {
      return '0.00 (مطابق)';
    }
  }

  Color _getDifferenceColor() {
    final estimated = double.tryParse(_estimatedCostController.text) ?? 0;
    final actual = double.tryParse(_actualCostController.text) ?? 0;
    final difference = actual - estimated;

    if (difference > 0) {
      return Colors.red; // زيادة في التكلفة
    } else if (difference < 0) {
      return Colors.green; // توفير في التكلفة
    } else {
      return Colors.blue; // مطابقة
    }
  }

  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();

    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(String path) {
    try {
      final file = File(path);
      final size = file.lengthSync();
      if (size < 1024) {
        return '${size} B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'غير معروف';
    }
  }
}

// Dialog for adding/editing tasks
class TaskDialog extends StatefulWidget {
  final MaintenanceTask? task;
  final Function(MaintenanceTask) onSave;

  const TaskDialog({super.key, this.task, required this.onSave});

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _estimatedHoursController =
      TextEditingController();
  final TextEditingController _actualHoursController = TextEditingController();

  String _status = 'منتظر';
  DateTime? _startTime;
  DateTime? _endTime;

  final List<String> _statuses = ['منتظر', 'قيد التنفيذ', 'مكتمل'];

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      final task = widget.task!;
      _nameController.text = task.taskName;
      _descriptionController.text = task.description;
      _status = task.status;
      _startTime = task.startTime;
      _endTime = task.endTime;
      _estimatedHoursController.text = task.estimatedHours.toString();
      _actualHoursController.text = task.actualHours.toString();
      _notesController.text = task.notes ?? '';
    } else {
      _estimatedHoursController.text = '1';
    }
  }

  Future<void> _pickTime(String field) async {
    final initialTime = field == 'start'
        ? _startTime ?? DateTime.now()
        : _endTime ?? DateTime.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );

    if (picked != null) {
      final now = DateTime.now();
      final dateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      setState(() {
        if (field == 'start') {
          _startTime = dateTime;
        } else {
          _endTime = dateTime;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task != null ? 'تعديل المهمة' : 'إضافة مهمة جديدة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _nameController,
                labelText: 'اسم المهمة',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم المهمة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _descriptionController,
                labelText: 'وصف المهمة',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال وصف المهمة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _status,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _statuses.map((String value) {
                    Color color;
                    IconData icon;

                    switch (value) {
                      case 'منتظر':
                        color = Colors.grey;
                        icon = Icons.pending;
                        break;
                      case 'قيد التنفيذ':
                        color = Colors.blue;
                        icon = Icons.play_arrow;
                        break;
                      case 'مكتمل':
                        color = Colors.green;
                        icon = Icons.check_circle;
                        break;
                      default:
                        color = Colors.grey;
                        icon = Icons.info;
                    }

                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 16),
                          const SizedBox(width: 8),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _status = value!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime('start'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'وقت البدء',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _startTime != null
                                  ? DateFormat('HH:mm').format(_startTime!)
                                  : 'اختر الوقت',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime('end'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'وقت الانتهاء',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _endTime != null
                                  ? DateFormat('HH:mm').format(_endTime!)
                                  : 'اختر الوقت',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _estimatedHoursController,
                      labelText: 'الساعات المتوقعة',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال الساعات المتوقعة';
                        }
                        if (int.tryParse(value) == null) {
                          return 'قيمة غير صالحة';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _actualHoursController,
                      labelText: 'الساعات الفعلية',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _notesController,
                labelText: 'ملاحظات',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final task = MaintenanceTask(
                id: widget.task?.id ?? '',
                taskName: _nameController.text,
                description: _descriptionController.text,
                status: _status,
                technicianId: null,
                technicianName: null,
                startTime: _startTime,
                endTime: _endTime,
                estimatedHours:
                    int.tryParse(_estimatedHoursController.text) ?? 1,
                actualHours: int.tryParse(_actualHoursController.text) ?? 0,
                notes: _notesController.text.isNotEmpty
                    ? _notesController.text
                    : null,
              );
              widget.onSave(task);
              Navigator.pop(context);
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

// Widget for displaying task item
class TaskItem extends StatelessWidget {
  final MaintenanceTask task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskItem({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (task.status) {
      case 'منتظر':
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
        break;
      case 'قيد التنفيذ':
        statusColor = Colors.blue;
        statusIcon = Icons.play_arrow;
        break;
      case 'مكتمل':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, size: 16, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(fontSize: 10, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.timer, size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      '${task.estimatedHours} ساعة',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (task.actualHours > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined, size: 12, color: Colors.green),
                      const SizedBox(width: 2),
                      Text(
                        '${task.actualHours} ساعة',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
                if (task.startTime != null || task.endTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (task.startTime != null) ...[
                          Icon(Icons.play_arrow, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            DateFormat('HH:mm').format(task.startTime!),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        if (task.endTime != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.stop, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            DateFormat('HH:mm').format(task.endTime!),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
