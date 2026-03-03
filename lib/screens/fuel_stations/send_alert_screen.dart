import 'package:flutter/material.dart';
import 'package:order_tracker/models/fuel_station_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';


class SendAlertScreen extends StatefulWidget {
  const SendAlertScreen({super.key});

  @override
  State<SendAlertScreen> createState() => _SendAlertScreenState();
}

class _SendAlertScreenState extends State<SendAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _alertType = 'تحذير';
  String _priority = 'متوسط';
  String _target = 'جميع الفنيين';
  String? _selectedStationId;
  String? _selectedStationName;
  String? _selectedTechnicianId;
  String? _selectedTechnicianName;

  bool _sendEmail = true;
  bool _sendSMS = false;
  bool _sendPush = true;

  final List<String> _alertTypes = ['تحذير', 'إشعار', 'توجيه', 'تنبيه'];
  final List<String> _priorities = ['عالي', 'متوسط', 'منخفض'];
  final List<String> _targets = ['جميع الفنيين', 'فني معين', 'مدير المحطة'];
  final List<String> _technicians = [
    'أحمد محمد - فني كهرباء',
    'علي حسن - فني ميكانيكا',
    'سامي خالد - فني أمن',
    'محمد علي - فني عام',
  ];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final provider = Provider.of<FuelStationProvider>(context, listen: false);
    await provider.fetchStations();
  }

  Future<void> _sendAlert() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<FuelStationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final alert = AlertNotification(
      id: '',
      alertType: _alertType,
      priority: _priority,
      target: _target,
      technicianId: _selectedTechnicianId,
      technicianName: _selectedTechnicianName,
      stationId: _selectedStationId ?? '',
      stationName: _selectedStationName ?? 'جميع المحطات',
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      sendEmail: _sendEmail,
      sendSMS: _sendSMS,
      sendPush: _sendPush,
      status: 'مرسل',
      sentBy: authProvider.user?.id ?? '',
      sentByName: authProvider.user?.name ?? '',
      sentAt: DateTime.now(),
    );

    final success = await provider.sendAlert(alert);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التحذير بنجاح'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال تحذير')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alert Type and Priority
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نوع وأهمية التحذير',
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
                                value: _alertType,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: _alertTypes.map((String value) {
                                  IconData icon;
                                  Color color;

                                  switch (value) {
                                    case 'تحذير':
                                      icon = Icons.warning;
                                      color = Colors.red;
                                      break;
                                    case 'إشعار':
                                      icon = Icons.notifications;
                                      color = Colors.blue;
                                      break;
                                    case 'توجيه':
                                      icon = Icons.directions;
                                      color = Colors.green;
                                      break;
                                    case 'تنبيه':
                                      icon = Icons.info;
                                      color = Colors.orange;
                                      break;
                                    default:
                                      icon = Icons.info;
                                      color = Colors.grey;
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
                                    _alertType = value!;
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
                                          width: 12,
                                          height: 12,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Target Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المستهدف',
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
                          value: _target,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _targets.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _target = value!;
                            });
                          },
                        ),
                      ),
                      if (_target == 'فني معين') ...[
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
                            hint: const Text('اختر الفني'),
                            items: _technicians.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedTechnicianId = value;
                                _selectedTechnicianName = value;
                              });
                            },
                          ),
                        ),
                      ],
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
                          hint: const Text('اختر المحطة (اختياري)'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('جميع المحطات'),
                            ),
                            ...provider.stations.map((station) {
                              return DropdownMenuItem<String>(
                                value: station.id,
                                child: Text(
                                  '${station.stationName} - ${station.city}',
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStationId = value;
                              _selectedStationName = value != null
                                  ? provider.stations
                                        .firstWhere((s) => s.id == value)
                                        .stationName
                                  : null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Alert Content
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'محتوى التحذير',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _titleController,
                        labelText: 'عنوان التحذير',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال عنوان التحذير';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _messageController,
                        labelText: 'نص التحذير',
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال نص التحذير';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Delivery Methods
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'طرق الإرسال',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('البريد الإلكتروني'),
                        subtitle: const Text('إرسال إلى بريد المستخدم'),
                        value: _sendEmail,
                        onChanged: (value) {
                          setState(() {
                            _sendEmail = value;
                          });
                        },
                        activeColor: AppColors.primaryBlue,
                      ),
                      SwitchListTile(
                        title: const Text('رسالة SMS'),
                        subtitle: const Text('إرسال رسالة نصية'),
                        value: _sendSMS,
                        onChanged: (value) {
                          setState(() {
                            _sendSMS = value;
                          });
                        },
                        activeColor: AppColors.primaryBlue,
                      ),
                      SwitchListTile(
                        title: const Text('تنبيه التطبيق'),
                        subtitle: const Text('إرسال تنبيه داخل التطبيق'),
                        value: _sendPush,
                        onChanged: (value) {
                          setState(() {
                            _sendPush = value;
                          });
                        },
                        activeColor: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Preview and Send
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معاينة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(_priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getPriorityColor(_priority),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getAlertIcon(_alertType),
                                  color: _getPriorityColor(_priority),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _titleController.text.isNotEmpty
                                      ? _titleController.text
                                      : 'عنوان التحذير',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getPriorityColor(_priority),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _messageController.text.isNotEmpty
                                  ? _messageController.text
                                  : 'نص التحذير...',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedStationName ?? 'جميع المحطات',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Send Button
              GradientButton(
                onPressed: provider.isLoading ? null : _sendAlert,
                text: provider.isLoading ? 'جاري الإرسال...' : 'إرسال التحذير',
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عالي':
        return Colors.red;
      case 'متوسط':
        return Colors.orange;
      case 'منخفض':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String alertType) {
    switch (alertType) {
      case 'تحذير':
        return Icons.warning;
      case 'إشعار':
        return Icons.notifications;
      case 'توجيه':
        return Icons.directions;
      case 'تنبيه':
        return Icons.info;
      default:
        return Icons.info;
    }
  }
}
