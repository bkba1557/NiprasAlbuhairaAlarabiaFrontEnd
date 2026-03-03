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





class ApprovalRequestScreen extends StatefulWidget {

  const ApprovalRequestScreen({super.key});



  @override

  State<ApprovalRequestScreen> createState() => _ApprovalRequestScreenState();

}



class _ApprovalRequestScreenState extends State<ApprovalRequestScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _amountController = TextEditingController();



  String _requestType = 'صيانة';

  String? _selectedStationId;

  String? _selectedStationName;

  String _currency = 'SAR';

  List<String> _attachmentPaths = [];



  final List<String> _requestTypes = [

    'صيانة',

    'شراء',

    'إصلاح',

    'بدل سفر',

    'أخرى',

  ];

  final List<String> _currencies = ['SAR', 'USD', 'EUR'];



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

      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xlsx'],

    );



    if (result != null) {

      setState(() {

        _attachmentPaths.addAll(result.paths.whereType<String>());

      });

    }

  }



  Future<void> _submitRequest() async {

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



    final amount = double.tryParse(_amountController.text) ?? 0;



    final request = ApprovalRequest(

      id: '',

      requestType: _requestType,

      stationId: _selectedStationId!,

      stationName: _selectedStationName!,

      title: _titleController.text.trim(),

      description: _descriptionController.text.trim(),

      amount: amount,

      currency: _currency,

      attachments: [],

      status: 'منتظر',

      requestedBy: authProvider.user?.id ?? '',

      requestedByName: authProvider.user?.name ?? '',

      requestedAt: DateTime.now(),

    );



    final success = await provider.createApprovalRequest(

      request,

      _attachmentPaths,

    );



    if (success && mounted) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('تم إرسال طلب الموافقة بنجاح'),

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

      appBar: AppBar(title: const Text('طلب موافقة')),

      body: Form(

        key: _formKey,

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // Requester Info

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'معلومات مقدم الطلب',

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

                          const Spacer(),

                          Text(

                            DateFormat('yyyy/MM/dd').format(DateTime.now()),

                            style: const TextStyle(

                              fontSize: 12,

                              color: Colors.grey,

                            ),

                          ),

                        ],

                      ),

                    ],

                  ),

                ),

              ),

              const SizedBox(height: 16),

              // Request Details

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'تفاصيل الطلب',

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

                          value: _requestType,

                          isExpanded: true,

                          underline: const SizedBox(),

                          items: _requestTypes.map((String value) {

                            IconData icon;

                            Color color;



                            switch (value) {

                              case 'صيانة':

                                icon = Icons.build;

                                color = Colors.orange;

                                break;

                              case 'شراء':

                                icon = Icons.shopping_cart;

                                color = Colors.green;

                                break;

                              case 'إصلاح':

                                icon = Icons.handyman;

                                color = Colors.blue;

                                break;

                              case 'بدل سفر':

                                icon = Icons.directions_car;

                                color = Colors.purple;

                                break;

                              default:

                                icon = Icons.description;

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

                              _requestType = value!;

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

                      const SizedBox(height: 12),

                      CustomTextField(

                        controller: _titleController,

                        labelText: 'عنوان الطلب',

                        validator: (value) {

                          if (value == null || value.isEmpty) {

                            return 'يرجى إدخال عنوان الطلب';

                          }

                          return null;

                        },

                      ),

                      const SizedBox(height: 12),

                      CustomTextField(

                        controller: _descriptionController,

                        labelText: 'وصف الطلب',

                        maxLines: 4,

                        validator: (value) {

                          if (value == null || value.isEmpty) {

                            return 'يرجى إدخال وصف الطلب';

                          }

                          return null;

                        },

                      ),

                    ],

                  ),

                ),

              ),

              const SizedBox(height: 16),

              // Financial Details

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'التفاصيل المالية',

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

                              controller: _amountController,

                              labelText: 'المبلغ',

                              keyboardType: TextInputType.number,

                              validator: (value) {

                                if (value == null || value.isEmpty) {

                                  return 'يرجى إدخال المبلغ';

                                }

                                if (double.tryParse(value) == null) {

                                  return 'قيمة غير صالحة';

                                }

                                return null;

                              },

                            ),

                          ),

                          const SizedBox(width: 12),

                          Container(

                            width: 100,

                            padding: const EdgeInsets.symmetric(horizontal: 12),

                            decoration: BoxDecoration(

                              border: Border.all(color: Colors.grey),

                              borderRadius: BorderRadius.circular(8),

                            ),

                            child: DropdownButton<String>(

                              value: _currency,

                              underline: const SizedBox(),

                              items: _currencies.map((String value) {

                                return DropdownMenuItem<String>(

                                  value: value,

                                  child: Text(value),

                                );

                              }).toList(),

                              onChanged: (value) {

                                setState(() {

                                  _currency = value!;

                                });

                              },

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      if (_amountController.text.isNotEmpty)

                        Container(

                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(

                            color: AppColors.backgroundGray,

                            borderRadius: BorderRadius.circular(8),

                          ),

                          child: Row(

                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [

                              const Text(

                                'المبلغ كتابة:',

                                style: TextStyle(fontWeight: FontWeight.bold),

                              ),

                              Text(

                                _convertToArabicNumbers(

                                  double.parse(_amountController.text),

                                  _currency,

                                ),

                                style: const TextStyle(

                                  color: AppColors.primaryBlue,

                                  fontWeight: FontWeight.bold,

                                ),

                              ),

                            ],

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

                              Text(

                                'يمكنك إرفاق عروض الأسعار أو الفواتير أو المستندات الداعمة',

                                style: TextStyle(

                                  fontSize: 12,

                                  color: Colors.grey,

                                ),

                                textAlign: TextAlign.center,

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

              const SizedBox(height: 16),

              // Summary

              Card(

                child: Padding(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'ملخص الطلب',

                        style: TextStyle(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                      const SizedBox(height: 12),

                      _buildSummaryItem('نوع الطلب', _requestType),

                      _buildSummaryItem(

                        'المحطة',

                        _selectedStationName ?? 'لم يتم الاختيار',

                      ),

                      if (_titleController.text.isNotEmpty)

                        _buildSummaryItem('العنوان', _titleController.text),

                      if (_amountController.text.isNotEmpty)

                        _buildSummaryItem(

                          'المبلغ',

                          '${_amountController.text} $_currency',

                        ),

                      _buildSummaryItem(

                        'عدد المرفقات',

                        _attachmentPaths.length.toString(),

                      ),

                    ],

                  ),

                ),

              ),

              const SizedBox(height: 32),

              // Submit Button

              GradientButton(

                onPressed: provider.isLoading ? null : _submitRequest,

                text: provider.isLoading

                    ? 'جاري الإرسال...'

                    : 'إرسال طلب الموافقة',

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



  Widget _buildSummaryItem(String label, String value) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 8),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Expanded(

            child: Text(label, style: const TextStyle(color: Colors.grey)),

          ),

          const SizedBox(width: 16),

          Expanded(

            flex: 2,

            child: Text(

              value,

              style: const TextStyle(fontWeight: FontWeight.w500),

            ),

          ),

        ],

      ),

    );

  }



  String _convertToArabicNumbers(double amount, String currency) {

    final arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    final number = amount.toStringAsFixed(2);



    String result = '';

    for (int i = 0; i < number.length; i++) {

      final char = number[i];

      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {

        result += arabicNumbers[int.parse(char)];

      } else {

        result += char;

      }

    }



    String currencyName;

    switch (currency) {

      case 'SAR':

        currencyName = 'ريال سعودي';

        break;

      case 'USD':

        currencyName = 'دولار أمريكي';

        break;

      case 'EUR':

        currencyName = 'يورو';

        break;

      default:

        currencyName = currency;

    }



    return '$result $currencyName';

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

      case 'xlsx':

      case 'xls':

        return Icons.table_chart;

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

