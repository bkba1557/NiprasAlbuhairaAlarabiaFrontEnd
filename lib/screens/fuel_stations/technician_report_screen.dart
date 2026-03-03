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





class TechnicianReportScreen extends StatefulWidget {

  const TechnicianReportScreen({super.key});



  @override

  State<TechnicianReportScreen> createState() => _TechnicianReportScreenState();

}



class _TechnicianReportScreenState extends State<TechnicianReportScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _recommendationsController =

      TextEditingController();



  String? _selectedStationId;

  String? _selectedStationName;

  String _reportType = 'يومي';

  List<ReportIssue> _issues = [];

  List<String> _attachmentPaths = [];

  List<String> _newAttachmentPaths = [];



  final List<String> _reportTypes = ['يومي', 'أسبوعي', 'شهري', 'طارئ'];

  final List<String> _issueTypes = [

    'فني',

    'كهربائي',

    'ميكانيكي',

    'أمني',

    'نظافة',

    'أخرى',

  ];

  final List<String> _severities = ['حرج', 'عالي', 'متوسط', 'منخفض'];



  @override

  void initState() {

    super.initState();

    _loadStations();

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

        _newAttachmentPaths.addAll(result.paths.whereType<String>());

      });

    }

  }



  void _addIssue() {

    showDialog(

      context: context,

      builder: (context) => IssueDialog(

        onSave: (issue) {

          setState(() {

            _issues.add(issue);

          });

        },

      ),

    );

  }



  void _editIssue(int index) {

    showDialog(

      context: context,

      builder: (context) => IssueDialog(

        issue: _issues[index],

        onSave: (issue) {

          setState(() {

            _issues[index] = issue;

          });

        },

      ),

    );

  }



  void _removeIssue(int index) {

    setState(() {

      _issues.removeAt(index);

    });

  }



  Future<void> _submitReport() async {

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



    final report = TechnicianReport(

      id: '',

      stationId: _selectedStationId!,

      stationName: _selectedStationName!,

      technicianId: authProvider.user?.id ?? '',

      technicianName: authProvider.user?.name ?? '',

      reportType: _reportType,

      reportTitle: _titleController.text.trim(),

      description: _descriptionController.text.trim(),

      issues: _issues,

      attachments: [],

      recommendations: _recommendationsController.text.trim(),

      status: 'مسودة',

      reportDate: DateTime.now(),

      createdAt: DateTime.now(),

    );



    final success = await provider.createTechnicianReport(

      report,

      _newAttachmentPaths,

    );



    if (success && mounted) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('تم إرسال التقرير بنجاح'),

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

    final authProvider = Provider.of<AuthProvider>(context);



    return Scaffold(

      appBar: AppBar(title: const Text('تقرير الفني')),

      body: Form(

        key: _formKey,

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // Technician Info

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'معلومات الفني',

                        style: TextStyle(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                      const SizedBox(height: 12),

                      Row(

                        children: [

                          const Icon(

                            Icons.person,

                            color: AppColors.primaryBlue,

                          ),

                          const SizedBox(width: 12),

                          Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Text(

                                authProvider.user?.name ?? 'غير معروف',

                                style: const TextStyle(

                                  fontWeight: FontWeight.bold,

                                ),

                              ),

                              Text(

                                authProvider.user?.email ?? '',

                                style: const TextStyle(

                                  fontSize: 12,

                                  color: Colors.grey,

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

              const SizedBox(height: 16),

              // Station Selection

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'اختر المحطة',

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

                      if (_selectedStationId != null) ...[

                        const SizedBox(height: 12),

                        Row(

                          children: [

                            Icon(

                              Icons.location_on,

                              size: 16,

                              color: Colors.grey,

                            ),

                            const SizedBox(width: 4),

                            Expanded(

                              child: Text(

                                provider.stations

                                    .firstWhere(

                                      (s) => s.id == _selectedStationId,

                                    )

                                    .address,

                                style: const TextStyle(fontSize: 12),

                              ),

                            ),

                          ],

                        ),

                      ],

                    ],

                  ),

                ),

              ),

              const SizedBox(height: 16),

              // Report Info

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'معلومات التقرير',

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

                              controller: _titleController,

                              labelText: 'عنوان التقرير',

                              validator: (value) {

                                if (value == null || value.isEmpty) {

                                  return 'يرجى إدخال عنوان التقرير';

                                }

                                return null;

                              },

                            ),

                          ),

                          const SizedBox(width: 12),

                          Container(

                            padding: const EdgeInsets.symmetric(horizontal: 12),

                            decoration: BoxDecoration(

                              border: Border.all(color: Colors.grey),

                              borderRadius: BorderRadius.circular(8),

                            ),

                            child: DropdownButton<String>(

                              value: _reportType,

                              underline: const SizedBox(),

                              items: _reportTypes.map((String value) {

                                return DropdownMenuItem<String>(

                                  value: value,

                                  child: Text(value),

                                );

                              }).toList(),

                              onChanged: (value) {

                                setState(() {

                                  _reportType = value!;

                                });

                              },

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      CustomTextField(

                        controller: _descriptionController,

                        labelText: 'وصف التقرير',

                        maxLines: 4,

                        validator: (value) {

                          if (value == null || value.isEmpty) {

                            return 'يرجى إدخال وصف التقرير';

                          }

                          return null;

                        },

                      ),

                      const SizedBox(height: 12),

                      CustomTextField(

                        controller: _recommendationsController,

                        labelText: 'التوصيات والمقترحات',

                        maxLines: 3,

                      ),

                    ],

                  ),

                ),

              ),

              const SizedBox(height: 16),

              // Issues

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

                            'المشاكل والعيوب',

                            style: TextStyle(

                              fontSize: 16,

                              fontWeight: FontWeight.bold,

                            ),

                          ),

                          ElevatedButton.icon(

                            onPressed: _addIssue,

                            icon: const Icon(Icons.add),

                            label: const Text('إضافة مشكلة'),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      if (_issues.isEmpty)

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

                              Icon(Icons.warning, size: 48, color: Colors.grey),

                              SizedBox(height: 12),

                              Text(

                                'لا توجد مشاكل مضافة',

                                style: TextStyle(color: Colors.grey),

                              ),

                            ],

                          ),

                        )

                      else

                        ..._issues.asMap().entries.map(

                          (entry) => IssueItem(

                            issue: entry.value,

                            onEdit: () => _editIssue(entry.key),

                            onDelete: () => _removeIssue(entry.key),

                          ),

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

                      if (_newAttachmentPaths.isEmpty)

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

                        ..._newAttachmentPaths.map(

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

                                  Icons.attach_file,

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

                                      _newAttachmentPaths.remove(path);

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

                onPressed: provider.isLoading ? null : _submitReport,

                text: provider.isLoading ? 'جاري الإرسال...' : 'إرسال التقرير',

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



// Dialog for adding/editing issues

class IssueDialog extends StatefulWidget {

  final ReportIssue? issue;

  final Function(ReportIssue) onSave;



  const IssueDialog({super.key, this.issue, required this.onSave});



  @override

  State<IssueDialog> createState() => _IssueDialogState();

}



class _IssueDialogState extends State<IssueDialog> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _resolutionNotesController =

      TextEditingController();



  String _type = 'فني';

  String _severity = 'متوسط';

  String _status = 'مكتشف';

  DateTime _discoveryDate = DateTime.now();

  DateTime? _resolutionDate;



  @override

  void initState() {

    super.initState();

    if (widget.issue != null) {

      final issue = widget.issue!;

      _descriptionController.text = issue.description;

      _type = issue.issueType;

      _severity = issue.severity;

      _status = issue.status;

      _discoveryDate = issue.discoveryDate;

      _resolutionDate = issue.resolutionDate;

      _resolutionNotesController.text = issue.resolutionNotes ?? '';

    }

  }



  @override

  Widget build(BuildContext context) {

    return AlertDialog(

      title: Text(widget.issue != null ? 'تعديل المشكلة' : 'إضافة مشكلة'),

      content: SingleChildScrollView(

        child: Form(

          key: _formKey,

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 12),

                decoration: BoxDecoration(

                  border: Border.all(color: Colors.grey),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: DropdownButton<String>(

                  value: _type,

                  isExpanded: true,

                  underline: const SizedBox(),

                  items: const [

                    DropdownMenuItem(value: 'فني', child: Text('فني')),

                    DropdownMenuItem(value: 'كهربائي', child: Text('كهربائي')),

                    DropdownMenuItem(

                      value: 'ميكانيكي',

                      child: Text('ميكانيكي'),

                    ),

                    DropdownMenuItem(value: 'أمني', child: Text('أمني')),

                    DropdownMenuItem(value: 'نظافة', child: Text('نظافة')),

                    DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),

                  ],

                  onChanged: (value) {

                    setState(() {

                      _type = value!;

                    });

                  },

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

                  value: _severity,

                  isExpanded: true,

                  underline: const SizedBox(),

                  items: const [

                    DropdownMenuItem(value: 'حرج', child: Text('حرج')),

                    DropdownMenuItem(value: 'عالي', child: Text('عالي')),

                    DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),

                    DropdownMenuItem(value: 'منخفض', child: Text('منخفض')),

                  ],

                  onChanged: (value) {

                    setState(() {

                      _severity = value!;

                    });

                  },

                ),

              ),

              const SizedBox(height: 12),

              CustomTextField(

                controller: _descriptionController,

                labelText: 'وصف المشكلة',

                maxLines: 3,

                validator: (value) {

                  if (value == null || value.isEmpty) {

                    return 'يرجى إدخال وصف المشكلة';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 12),

              InkWell(

                onTap: () => _pickDate('discovery'),

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

                        'تاريخ الاكتشاف',

                        style: TextStyle(fontSize: 12, color: Colors.grey),

                      ),

                      Text(DateFormat('yyyy/MM/dd').format(_discoveryDate)),

                    ],

                  ),

                ),

              ),

              if (_status == 'مكتمل') ...[

                const SizedBox(height: 12),

                InkWell(

                  onTap: () => _pickDate('resolution'),

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

                          'تاريخ الحل',

                          style: TextStyle(fontSize: 12, color: Colors.grey),

                        ),

                        Text(

                          _resolutionDate != null

                              ? DateFormat(

                                  'yyyy/MM/dd',

                                ).format(_resolutionDate!)

                              : 'اختر التاريخ',

                        ),

                      ],

                    ),

                  ),

                ),

                const SizedBox(height: 12),

                CustomTextField(

                  controller: _resolutionNotesController,

                  labelText: 'ملاحظات الحل',

                  maxLines: 2,

                ),

              ],

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

              final issue = ReportIssue(

                id: widget.issue?.id ?? '',

                issueType: _type,

                severity: _severity,

                description: _descriptionController.text,

                status: _status,

                discoveryDate: _discoveryDate,

                resolutionDate: _resolutionDate,

                resolutionNotes: _resolutionNotesController.text.isNotEmpty

                    ? _resolutionNotesController.text

                    : null,

              );

              widget.onSave(issue);

              Navigator.pop(context);

            }

          },

          child: const Text('حفظ'),

        ),

      ],

    );

  }



  Future<void> _pickDate(String field) async {

    final initialDate = field == 'discovery'

        ? _discoveryDate

        : _resolutionDate ?? DateTime.now();



    final picked = await showDatePicker(

      context: context,

      initialDate: initialDate,

      firstDate: DateTime(2000),

      lastDate: DateTime(2030),

    );



    if (picked != null) {

      setState(() {

        if (field == 'discovery') {

          _discoveryDate = picked;

        } else {

          _resolutionDate = picked;

        }

      });

    }

  }

}



// Widget for displaying issue item

class IssueItem extends StatelessWidget {

  final ReportIssue issue;

  final VoidCallback onEdit;

  final VoidCallback onDelete;



  const IssueItem({

    super.key,

    required this.issue,

    required this.onEdit,

    required this.onDelete,

  });



  @override

  Widget build(BuildContext context) {

    Color severityColor;

    switch (issue.severity) {

      case 'حرج':

        severityColor = Colors.red;

        break;

      case 'عالي':

        severityColor = Colors.orange;

        break;

      case 'متوسط':

        severityColor = Colors.yellow;

        break;

      case 'منخفض':

        severityColor = Colors.green;

        break;

      default:

        severityColor = Colors.grey;

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

              color: severityColor.withOpacity(0.1),

              shape: BoxShape.circle,

            ),

            child: Icon(Icons.warning, color: severityColor, size: 16),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  issue.issueType,

                  style: const TextStyle(fontWeight: FontWeight.bold),

                ),

                const SizedBox(height: 4),

                Text(

                  issue.description,

                  style: const TextStyle(fontSize: 12),

                  maxLines: 2,

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

                        color: severityColor.withOpacity(0.1),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(color: severityColor),

                      ),

                      child: Text(

                        issue.severity,

                        style: TextStyle(fontSize: 10, color: severityColor),

                      ),

                    ),

                    const SizedBox(width: 8),

                    Icon(Icons.calendar_today, size: 12, color: Colors.grey),

                    const SizedBox(width: 2),

                    Text(

                      DateFormat('MM/dd').format(issue.discoveryDate),

                      style: const TextStyle(fontSize: 10, color: Colors.grey),

                    ),

                  ],

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

