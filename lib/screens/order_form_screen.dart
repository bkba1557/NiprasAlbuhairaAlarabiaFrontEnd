// // ignore_for_file: dead_code

// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:order_tracker/models/customer_model.dart';
// import 'package:order_tracker/models/driver_model.dart';
// import 'package:order_tracker/models/models.dart';
// import 'package:order_tracker/models/order_model.dart';
// import 'package:order_tracker/models/supplier_model.dart';
// import 'package:order_tracker/providers/auth_provider.dart';
// import 'package:order_tracker/providers/order_provider.dart';
// import 'package:order_tracker/providers/driver_provider.dart';
// import 'package:order_tracker/providers/supplier_provider.dart';
// import 'package:order_tracker/utils/api_service.dart';
// import 'package:order_tracker/utils/constants.dart';
// import 'package:order_tracker/widgets/attachment_item.dart';
// import 'package:order_tracker/widgets/custom_text_field.dart';
// import 'package:order_tracker/widgets/gradient_button.dart';
// import 'package:provider/provider.dart';

// class OrderFormScreen extends StatefulWidget {
//   final Order? orderToEdit;

//   const OrderFormScreen({super.key, this.orderToEdit});

//   @override
//   State<OrderFormScreen> createState() => _OrderFormScreenState();
// }

// class _OrderFormScreenState extends State<OrderFormScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _supplierNameController = TextEditingController();
//   final TextEditingController _orderNumberController = TextEditingController();
//   final TextEditingController _driverNameController = TextEditingController();
//   final TextEditingController _driverPhoneController = TextEditingController();
//   final TextEditingController _vehicleNumberController =
//       TextEditingController();
//   final TextEditingController _quantityController = TextEditingController();
//   final TextEditingController _notesController = TextEditingController();
//   final TextEditingController _supplierOrderNumberController =
//       TextEditingController();
//   final TextEditingController _customerSearchController =
//       TextEditingController();
//   final TextEditingController _driverSearchController = TextEditingController();
//   final TextEditingController _loadingTimeController = TextEditingController(
//     text: '08:00',
//   );
//   final TextEditingController _arrivalTimeController = TextEditingController(
//     text: '10:00',
//   );
//   final TextEditingController _actualArrivalTimeController =
//       TextEditingController();
//   final TextEditingController _loadingDurationController =
//       TextEditingController();
//   final TextEditingController _delayReasonController = TextEditingController();

//   DateTime _orderDate = DateTime.now();
//   DateTime _loadingDate = DateTime.now().add(const Duration(days: 1));
//   DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1));
//   String _requestType = 'مورد';
//   String _status = 'قيد الانتظار';
//   String? _fuelType;
//   String? _unit;
//   String? _companyLogoPath;
//   List<String> _attachmentPaths = [];
//   List<String> _newAttachmentPaths = [];
//   String? _selectedCustomerId;
//   Customer? _selectedCustomer;
//   String? _selectedDriverId;
//   Driver? _selectedDriver;

//   // تحديد ما إذا كان في وضع التعديل وما هي الحقول المسموح بها
//   bool get _isEditing => widget.orderToEdit != null;
//   bool get _canEditAllFields {
//     final authProvider = context.read<AuthProvider>();
//     return authProvider.user?.role == 'admin' ||
//         authProvider.user?.role == 'manager' ||
//         !_isEditing;
//   }

//   // الحقول المسموح تعديلها في وضع التعديل للمستخدمين العاديين
//   bool get _canEditCustomer => true;
//   bool get _canEditDriver => true;
//   bool get _canEditStatus => true;
//   bool get _canEditAttachments => true;
//   bool get _canEditNotes => true;
//   bool get _canEditTrackingInfo => true;

//   // القوائم
//   final List<String> _requestTypes = [
//     'تزويد وقود',
//     'صيانة',
//     'خدمات لوجستية',
//     'مورد',
//   ];

//   final List<String> _statuses = [
//     'قيد الانتظار',
//     'مخصص للعميل',
//     'في انتظار التحميل',
//     'جاهز للتحميل',
//     'تم التحميل',
//     'ملغى',
//   ];

//   final List<String> _fuelTypes = [
//     'بنزين 91',
//     'بنزين 95',
//     'ديزل',
//     'كيروسين',
//     'غاز طبيعي',
//   ];

//   final List<String> _units = ['لتر', 'جالون', 'برميل', 'طن'];

//   @override
//   void initState() {
//     super.initState();
//     if (widget.orderToEdit != null) {
//       _initializeFormWithOrder();
//     }
//   }

//   void _initializeFormWithOrder() {
//     final order = widget.orderToEdit!;

//     _supplierNameController.text = order.supplierName;
//     _orderNumberController.text = order.orderNumber;
//     _driverNameController.text = order.driverName ?? '';
//     _driverPhoneController.text = order.driverPhone ?? '';
//     _vehicleNumberController.text = order.vehicleNumber ?? '';
//     _quantityController.text = order.quantity?.toString() ?? '';
//     _notesController.text = order.notes ?? '';
//     _supplierOrderNumberController.text = order.supplierOrderNumber ?? '';
//     _loadingTimeController.text = order.loadingTime ?? '08:00';
//     _arrivalTimeController.text = order.arrivalTime ?? '10:00';
//     _actualArrivalTimeController.text = order.actualArrivalTime ?? '';
//     _loadingDurationController.text = order.loadingDuration?.toString() ?? '';
//     _delayReasonController.text = order.delayReason ?? '';

//     _orderDate = order.orderDate;
//     _loadingDate = order.loadingDate ?? DateTime.now().add(Duration(days: 1));
//     _arrivalDate = order.arrivalDate ?? DateTime.now().add(Duration(days: 1));
//     _requestType = order.requestType;
//     _status = order.status;
//     _fuelType = order.fuelType;
//     _unit = order.unit;
//     _companyLogoPath = order.companyLogo;
//     _selectedCustomerId = order.customer?.id;
//     _selectedCustomer = order.customer;
//     _selectedDriverId = order.driverId;

//     // تحميل بيانات السائق إذا كان موجوداً
//     if (order.driverId != null) {
//       _loadDriverData(order.driverId!);
//     }

//     if (_selectedCustomer != null) {
//       _customerSearchController.text = _selectedCustomer!.displayName;
//     }
//   }

//   Future<void> _loadDriverData(String driverId) async {
//     try {
//       final driverProvider = context.read<DriverProvider>();
//       await driverProvider.fetchDriverById(driverId);

//       final driver = driverProvider.getDriverById(driverId);
//       if (driver != null) {
//         setState(() {
//           _selectedDriver = driver;
//           _driverNameController.text = driver.name;
//           _driverPhoneController.text = driver.phone;
//           _vehicleNumberController.text = driver.vehicleNumber ?? '';
//           _driverSearchController.text = driver.name;
//         });
//       }
//     } catch (e) {
//       debugPrint('❌ Error loading driver: $e');
//     }
//   }

//   Future<List<Customer>> _searchCustomers(String query) async {
//     if (query.trim().isEmpty) return [];

//     try {
//       final url = '${ApiEndpoints.baseUrl}/customers/search?q=$query';

//       debugPrint('🔍 Search customers URL: $url');

//       final response = await http.get(
//         Uri.parse(url),
//         headers: ApiService.headers,
//       );

//       debugPrint('📡 Status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);

//         if (decoded is List) {
//           return decoded.map((e) => Customer.fromJson(e)).toList();
//         }

//         if (decoded is Map && decoded['data'] is List) {
//           return (decoded['data'] as List)
//               .map((e) => Customer.fromJson(e))
//               .toList();
//         }

//         if (decoded is Map && decoded['customers'] is List) {
//           return (decoded['customers'] as List)
//               .map((e) => Customer.fromJson(e))
//               .toList();
//         }
//       }

//       return [];
//     } catch (e) {
//       debugPrint('❌ Exception: $e');
//       return [];
//     }
//   }

//   Future<List<Driver>> _searchDrivers(String query) async {
//     if (query.trim().isEmpty) return [];

//     try {
//       final url = '${ApiEndpoints.baseUrl}/drivers/search?q=$query';

//       debugPrint('🔍 Search drivers URL: $url');

//       final response = await http.get(
//         Uri.parse(url),
//         headers: ApiService.headers,
//       );

//       debugPrint('📡 Status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);

//         if (decoded is List) {
//           return decoded.map((e) => Driver.fromJson(e)).toList();
//         }

//         if (decoded is Map && decoded['data'] is List) {
//           return (decoded['data'] as List)
//               .map((e) => Driver.fromJson(e))
//               .toList();
//         }

//         if (decoded is Map && decoded['drivers'] is List) {
//           return (decoded['drivers'] as List)
//               .map((e) => Driver.fromJson(e))
//               .toList();
//         }
//       }

//       return [];
//     } catch (e) {
//       debugPrint('❌ Exception: $e');
//       return [];
//     }
//   }

//   Future<void> _pickDate(BuildContext context, String type) async {
//     if (!_canEditAllFields) return;

//     DateTime initialDate;
//     switch (type) {
//       case 'order':
//         initialDate = _orderDate;
//         break;
//       case 'loading':
//         initialDate = _loadingDate;
//         break;
//       case 'arrival':
//         initialDate = _arrivalDate;
//         break;
//       default:
//         initialDate = DateTime.now();
//     }

//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initialDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2030),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: AppColors.primaryBlue,
//               onPrimary: Colors.white,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (picked != null) {
//       setState(() {
//         switch (type) {
//           case 'order':
//             _orderDate = picked;
//             break;
//           case 'loading':
//             _loadingDate = picked;
//             break;
//           case 'arrival':
//             _arrivalDate = picked;
//             break;
//         }
//       });
//     }
//   }

//   Future<void> _pickTime(BuildContext context, String type) async {
//     if (!_canEditAllFields && type != 'actualArrival') return;

//     TimeOfDay initialTime;
//     TextEditingController controller;

//     switch (type) {
//       case 'loading':
//         initialTime = _parseTime(_loadingTimeController.text);
//         controller = _loadingTimeController;
//         break;
//       case 'arrival':
//         initialTime = _parseTime(_arrivalTimeController.text);
//         controller = _arrivalTimeController;
//         break;
//       case 'actualArrival':
//         initialTime = _parseTime(_actualArrivalTimeController.text);
//         controller = _actualArrivalTimeController;
//         break;
//       default:
//         initialTime = const TimeOfDay(hour: 8, minute: 0);
//         controller = _loadingTimeController;
//     }

//     final picked = await showTimePicker(
//       context: context,
//       initialTime: initialTime,
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: AppColors.primaryBlue,
//               onPrimary: Colors.white,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (picked != null) {
//       setState(() {
//         controller.text =
//             '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
//       });
//     }
//   }

//   TimeOfDay _parseTime(String time) {
//     try {
//       final parts = time.split(':');
//       return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
//     } catch (e) {
//       return const TimeOfDay(hour: 8, minute: 0);
//     }
//   }

//   Future<void> _pickLogo() async {
//     if (!_canEditAllFields) return;

//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(
//       source: ImageSource.gallery,
//       maxWidth: 800,
//       maxHeight: 800,
//       imageQuality: 85,
//     );

//     if (pickedFile != null) {
//       setState(() {
//         _companyLogoPath = pickedFile.path;
//       });
//     }
//   }

//   Future<void> _pickAttachments() async {
//     if (!_canEditAttachments) return;

//     final result = await FilePicker.platform.pickFiles(
//       allowMultiple: true,
//       type: FileType.custom,
//       allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
//     );

//     if (result != null) {
//       setState(() {
//         _newAttachmentPaths.addAll(result.paths.whereType<String>());
//       });
//     }
//   }

//   void _removeAttachment(int index) {
//     if (!_canEditAttachments) return;

//     setState(() {
//       _newAttachmentPaths.removeAt(index);
//     });
//   }

//   Future<void> _selectSupplier() async {
//     final suppliers = await Provider.of<SupplierProvider>(
//       context,
//       listen: false,
//     ).searchSuppliers('');

//     if (suppliers.isNotEmpty) {
//       final result = await showDialog<Supplier>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('اختر مورد'),
//           content: SizedBox(
//             width: 300,
//             height: 400,
//             child: ListView.builder(
//               itemCount: suppliers.length,
//               itemBuilder: (context, index) {
//                 final supplier = suppliers[index];
//                 return ListTile(
//                   title: Text(supplier.name),
//                   subtitle: Text(supplier.company),
//                   trailing: supplier.isActive
//                       ? null
//                       : const Icon(Icons.block, color: Colors.red, size: 16),
//                   onTap: () {
//                     Navigator.pop(context, supplier);
//                   },
//                 );
//               },
//             ),
//           ),
//         ),
//       );

//       if (result != null) {
//         setState(() {
//           _supplierNameController.text = result.name;
//         });
//       }
//     }
//   }

//   Future<void> _submitForm() async {
//     if (!_formKey.currentState!.validate()) return;

//     // التحقق من البيانات المطلوبة
//     if (_supplierNameController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('يرجى إدخال اسم المورد'),
//           backgroundColor: AppColors.errorRed,
//         ),
//       );
//       return;
//     }

//     if (_requestType.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('يرجى اختيار نوع الطلب'),
//           backgroundColor: AppColors.errorRed,
//         ),
//       );
//       return;
//     }

//     // التحقق من صحة الأوقات
//     if (_loadingTimeController.text.isEmpty) {
//       _loadingTimeController.text = '08:00';
//     }

//     if (_arrivalTimeController.text.isEmpty) {
//       _arrivalTimeController.text = '10:00';
//     }

//     // التحقق من وقت التحميل بعد وقت الوصول
//     try {
//       final loadingParts = _loadingTimeController.text.split(':');
//       final arrivalParts = _arrivalTimeController.text.split(':');

//       if (loadingParts.length < 2 || arrivalParts.length < 2) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('تنسيق الوقت غير صحيح'),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//         return;
//       }

//       final arrivalDateTime = DateTime(
//         _arrivalDate.year,
//         _arrivalDate.month,
//         _arrivalDate.day,
//         int.parse(arrivalParts[0]),
//         int.parse(arrivalParts[1]),
//       );

//       final loadingDateTime = DateTime(
//         _loadingDate.year,
//         _loadingDate.month,
//         _loadingDate.day,
//         int.parse(loadingParts[0]),
//         int.parse(loadingParts[1]),
//       );

//       // وقت التحميل يجب أن يكون بعد وقت الوصول
//       if (loadingDateTime.isBefore(arrivalDateTime) ||
//           loadingDateTime.isAtSameMomentAs(arrivalDateTime)) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('وقت التحميل يجب أن يكون بعد وقت الوصول'),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//         return;
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('خطأ في معالجة الأوقات: ${e.toString()}'),
//           backgroundColor: AppColors.errorRed,
//         ),
//       );
//       return;
//     }

//     // التحقق من تنسيق الوقت الفعلي إذا تم إدخاله
//     if (_actualArrivalTimeController.text.trim().isNotEmpty) {
//       final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
//       if (!timeRegex.hasMatch(_actualArrivalTimeController.text.trim())) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('تنسيق وقت الوصول الفعلي غير صحيح. استخدم HH:MM'),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//         return;
//       }
//     }

//     final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     final order = Order(
//       id: widget.orderToEdit?.id ?? '',
//       orderDate: _orderDate,
//       supplierName: _supplierNameController.text.trim(),
//       requestType: _requestType,
//       orderNumber: widget.orderToEdit?.orderNumber ?? '',
//       supplierOrderNumber: _supplierOrderNumberController.text.trim().isNotEmpty
//           ? _supplierOrderNumberController.text.trim()
//           : null,
//       loadingDate: _loadingDate,
//       loadingTime: _loadingTimeController.text,
//       arrivalDate: _arrivalDate,
//       arrivalTime: _arrivalTimeController.text,
//       status: _status,
//       driverName: _selectedDriver?.name ?? _driverNameController.text.trim(),
//       driverPhone: _selectedDriver?.phone ?? _driverPhoneController.text.trim(),
//       vehicleNumber:
//           _selectedDriver?.vehicleNumber ??
//           _vehicleNumberController.text.trim(),
//       fuelType: _fuelType,
//       quantity: _quantityController.text.trim().isNotEmpty
//           ? double.tryParse(_quantityController.text.trim())
//           : null,
//       unit: _unit,
//       notes: _notesController.text.trim().isNotEmpty
//           ? _notesController.text.trim()
//           : null,
//       companyLogo: _companyLogoPath,
//       attachments: [],
//       createdById: authProvider.user?.id ?? '',
//       customer: _selectedCustomer,
//       driverId: _selectedDriver?.id,
//       // الحقول الجديدة من الباك إند
//       notificationSentAt: null,
//       arrivalNotificationSentAt: null,
//       loadingCompletedAt: null,
//       actualArrivalTime: _actualArrivalTimeController.text.trim().isNotEmpty
//           ? _actualArrivalTimeController.text.trim()
//           : null,
//       loadingDuration: _loadingDurationController.text.trim().isNotEmpty
//           ? int.tryParse(_loadingDurationController.text.trim())
//           : null,
//       delayReason: _delayReasonController.text.trim().isNotEmpty
//           ? _delayReasonController.text.trim()
//           : null,
//       createdAt: DateTime.now(),
//       updatedAt: DateTime.now(),
//     );

//     bool success;

//     if (widget.orderToEdit != null) {
//       // تحديد نوع التحديث بناءً على صلاحيات المستخدم
//       if (_canEditAllFields) {
//         // إذا كان مسؤول أو مستخدم جديد، استخدم التحديث الكامل
//         success = await orderProvider.updateOrderFull(
//           widget.orderToEdit!.id,
//           order,
//           _newAttachmentPaths,
//           _selectedCustomer?.id,
//           _selectedDriver?.id,
//         );
//       } else {
//         // إذا كان مستخدم عادي في وضع التعديل، استخدم التحديث المحدود
//         final updates = {
//           if (_canEditCustomer && _selectedCustomer?.id != null)
//             'customer': _selectedCustomer!.id,
//           if (_canEditDriver && _selectedDriver?.id != null)
//             'driverId': _selectedDriver!.id,
//           if (_canEditStatus) 'status': _status,
//           if (_canEditNotes && _notesController.text.trim().isNotEmpty)
//             'notes': _notesController.text.trim(),
//           if (_canEditTrackingInfo &&
//               _actualArrivalTimeController.text.trim().isNotEmpty)
//             'actualArrivalTime': _actualArrivalTimeController.text.trim(),
//           if (_canEditTrackingInfo &&
//               _loadingDurationController.text.trim().isNotEmpty)
//             'loadingDuration': int.tryParse(
//               _loadingDurationController.text.trim(),
//             ),
//           if (_canEditTrackingInfo &&
//               _delayReasonController.text.trim().isNotEmpty)
//             'delayReason': _delayReasonController.text.trim(),
//         };

//         success = await orderProvider.updateOrderLimited(
//           widget.orderToEdit!.id,
//           updates,
//           _newAttachmentPaths,
//         );
//       }
//     } else {
//       // إنشاء طلب جديد
//       success = await orderProvider.createOrder(
//         order,
//         _newAttachmentPaths,
//         _selectedCustomer?.id,
//         _selectedDriver?.id,
//       );
//     }

//     if (success && mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             widget.orderToEdit != null
//                 ? 'تم تحديث الطلب بنجاح'
//                 : 'تم إنشاء الطلب بنجاح',
//           ),
//           backgroundColor: AppColors.successGreen,
//         ),
//       );

//       // إضافة تأخير بسيط قبل الرجوع لضمان تحديث البيانات
//       await Future.delayed(const Duration(milliseconds: 500));

//       Navigator.pop(context, true); // إرجاع true للإشارة إلى نجاح العملية
//     } else if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(orderProvider.error ?? 'حدث خطأ أثناء حفظ الطلب'),
//           backgroundColor: AppColors.errorRed,
//         ),
//       );
//     }
//   }

//   Widget _buildFieldWithIcon({
//     required String label,
//     required IconData icon,
//     required Color color,
//     required Widget child,
//     bool enabled = true,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, color: color, size: 20),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: TextStyle(
//                 color: color,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 14,
//               ),
//             ),
//             if (!enabled && _isEditing)
//               Padding(
//                 padding: const EdgeInsets.only(left: 8),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 6,
//                     vertical: 2,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade200,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Text(
//                     'للقراءة فقط',
//                     style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Opacity(opacity: enabled ? 1.0 : 0.6, child: child),
//       ],
//     );
//   }

//   // تحديد إذا كنا في وضع الويب/كمبيوتر
//   bool get _isDesktop => MediaQuery.of(context).size.width > 800;

//   @override
//   Widget build(BuildContext context) {
//     final orderProvider = Provider.of<OrderProvider>(context);
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isAdminOrManager =
//         Provider.of<AuthProvider>(context, listen: false).user?.role ==
//             'admin' ||
//         Provider.of<AuthProvider>(context, listen: false).user?.role ==
//             'manager';

//     return Scaffold(
//       appBar: _isDesktop
//           ? null
//           : AppBar(
//               title: Text(_isEditing ? 'تعديل الطلب' : 'طلب جديد'),
//               actions: [
//                 if (_isEditing && isAdminOrManager)
//                   IconButton(
//                     onPressed: () {
//                       _showDeleteDialog(context);
//                     },
//                     icon: const Icon(Icons.delete_outline, color: Colors.red),
//                   ),
//               ],
//             ),
//       body: _isDesktop
//           ? _buildDesktopLayout(context, orderProvider, screenWidth)
//           : _buildMobileLayout(context, orderProvider),
//     );
//   }

//   // ============================================
//   // واجهة الجوال
//   // ============================================
//   Widget _buildMobileLayout(BuildContext context, OrderProvider orderProvider) {
//     return Form(
//       key: _formKey,
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           if (_canEditAllFields) _buildLogoCard(context),
//           if (_canEditAllFields) const SizedBox(height: 16),

//           _buildBasicInfoCard(context),
//           const SizedBox(height: 16),

//           if (_canEditAllFields) _buildTimesCard(context),
//           if (_canEditAllFields) const SizedBox(height: 16),

//           _buildCustomerCard(context),
//           const SizedBox(height: 16),

//           _buildDriverCard(context), // ✅ TypeAhead للسائقين
//           const SizedBox(height: 16),

//           if (_canEditAllFields) _buildFuelInfoCard(context),
//           if (_canEditAllFields) const SizedBox(height: 16),

//           if (_isEditing) ...[
//             _buildTrackingInfoCard(context),
//             const SizedBox(height: 16),
//           ],

//           _buildNotesCard(context),
//           const SizedBox(height: 16),

//           _buildAttachmentsCard(context),
//           const SizedBox(height: 32),

//           _buildSubmitButton(orderProvider),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }

//   // ============================================
//   // واجهة سطح المكتب
//   // ============================================
//   Widget _buildDesktopLayout(
//     BuildContext context,
//     OrderProvider orderProvider,
//     double screenWidth,
//   ) {
//     final isAdminOrManager =
//         Provider.of<AuthProvider>(context, listen: false).user?.role ==
//             'admin' ||
//         Provider.of<AuthProvider>(context, listen: false).user?.role ==
//             'manager';

//     return Scaffold(
//       body: Form(
//         key: _formKey,
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Sidebar for desktop
//             Container(
//               width: 280,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 border: Border(
//                   right: BorderSide(color: Colors.grey.shade300, width: 1),
//                 ),
//               ),
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   children: [
//                     // Header
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: AppColors.primaryBlue.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Column(
//                         children: [
//                           Text(
//                             _isEditing ? 'تعديل الطلب' : 'طلب جديد',
//                             style: const TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                               color: AppColors.primaryBlue,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           if (_isEditing)
//                             Text(
//                               _orderNumberController.text,
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 color: AppColors.mediumGray,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     // Navigation
//                     Column(
//                       children: [
//                         _buildDesktopNavItem(
//                           icon: Icons.info_outline,
//                           title: 'المعلومات الأساسية',
//                           isSelected: true,
//                         ),
//                         const SizedBox(height: 8),
//                         if (_canEditAllFields)
//                           _buildDesktopNavItem(
//                             icon: Icons.access_time,
//                             title: 'المواعيد',
//                           ),
//                         if (_canEditAllFields) const SizedBox(height: 8),
//                         _buildDesktopNavItem(
//                           icon: Icons.person_outline,
//                           title: 'العميل',
//                         ),
//                         const SizedBox(height: 8),
//                         _buildDesktopNavItem(
//                           icon: Icons.directions_car,
//                           title: 'السائق',
//                         ),
//                         const SizedBox(height: 8),
//                         if (_canEditAllFields)
//                           _buildDesktopNavItem(
//                             icon: Icons.local_gas_station,
//                             title: 'معلومات الوقود',
//                           ),
//                         if (_canEditAllFields) const SizedBox(height: 8),
//                         if (_isEditing)
//                           _buildDesktopNavItem(
//                             icon: Icons.track_changes,
//                             title: 'معلومات التتبع',
//                           ),
//                         if (_isEditing) const SizedBox(height: 8),
//                         _buildDesktopNavItem(
//                           icon: Icons.note_outlined,
//                           title: 'ملاحظات',
//                         ),
//                         const SizedBox(height: 8),
//                         _buildDesktopNavItem(
//                           icon: Icons.attach_file,
//                           title: 'المرفقات',
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 40),

//                     // Quick Actions
//                     if (_isEditing && isAdminOrManager)
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'إجراءات سريعة',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           OutlinedButton.icon(
//                             onPressed: () {
//                               _showDeleteDialog(context);
//                             },
//                             icon: const Icon(Icons.delete_outline, size: 20),
//                             label: const Text('حذف الطلب'),
//                             style: OutlinedButton.styleFrom(
//                               foregroundColor: Colors.red,
//                               side: const BorderSide(color: Colors.red),
//                               minimumSize: const Size(double.infinity, 48),
//                             ),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//               ),
//             ),

//             // Main content for desktop
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(32),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Top bar
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           _isEditing ? 'تعديل الطلب' : 'طلب جديد',
//                           style: const TextStyle(
//                             fontSize: 28,
//                             fontWeight: FontWeight.bold,
//                             color: AppColors.primaryBlue,
//                           ),
//                         ),
//                         // Save button
//                         ElevatedButton.icon(
//                           onPressed: orderProvider.isLoading
//                               ? null
//                               : _submitForm,
//                           icon: orderProvider.isLoading
//                               ? const SizedBox(
//                                   width: 16,
//                                   height: 16,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                   ),
//                                 )
//                               : const Icon(Icons.save_outlined),
//                           label: Text(
//                             orderProvider.isLoading
//                                 ? 'جاري الحفظ...'
//                                 : (_isEditing ? 'تحديث الطلب' : 'حفظ الطلب'),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.primaryBlue,
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 24,
//                               vertical: 16,
//                             ),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 32),

//                     // Logo section for desktop
//                     if (_canEditAllFields) _buildDesktopLogoSection(context),
//                     if (_canEditAllFields) const SizedBox(height: 32),

//                     // Two column layout for desktop
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Left column
//                         Expanded(
//                           child: Column(
//                             children: [
//                               _buildBasicInfoCardDesktop(context),
//                               const SizedBox(height: 24),
//                               if (_canEditAllFields)
//                                 _buildTimesCardDesktop(context),
//                               if (_canEditAllFields) const SizedBox(height: 24),
//                               _buildCustomerCardDesktop(context),
//                               const SizedBox(height: 24),
//                               _buildNotesCardDesktop(context),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 32),

//                         // Right column
//                         Expanded(
//                           child: Column(
//                             children: [
//                               _buildDriverCardDesktop(context),
//                               const SizedBox(height: 24),
//                               if (_canEditAllFields)
//                                 _buildFuelInfoCardDesktop(context),
//                               if (_canEditAllFields) const SizedBox(height: 24),
//                               if (_isEditing)
//                                 _buildTrackingInfoCardDesktop(context),
//                               if (_isEditing) const SizedBox(height: 24),
//                               _buildAttachmentsCardDesktop(context),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 40),

//                     // Bottom actions for desktop
//                     Container(
//                       padding: const EdgeInsets.all(24),
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade50,
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: Colors.grey.shade200),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           if (_isEditing && isAdminOrManager)
//                             OutlinedButton.icon(
//                               onPressed: () {
//                                 _showDeleteDialog(context);
//                               },
//                               icon: const Icon(Icons.delete_outline),
//                               label: const Text('حذف الطلب'),
//                               style: OutlinedButton.styleFrom(
//                                 foregroundColor: Colors.red,
//                                 side: const BorderSide(color: Colors.red),
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 32,
//                                   vertical: 16,
//                                 ),
//                               ),
//                             ),
//                           Row(
//                             children: [
//                               OutlinedButton(
//                                 onPressed: () {
//                                   Navigator.pop(context);
//                                 },
//                                 style: OutlinedButton.styleFrom(
//                                   foregroundColor: AppColors.mediumGray,
//                                   side: BorderSide(color: AppColors.mediumGray),
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 32,
//                                     vertical: 16,
//                                   ),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                                 child: const Text('إلغاء'),
//                               ),
//                               const SizedBox(width: 16),
//                               ElevatedButton.icon(
//                                 onPressed: orderProvider.isLoading
//                                     ? null
//                                     : _submitForm,
//                                 icon: orderProvider.isLoading
//                                     ? const SizedBox(
//                                         width: 20,
//                                         height: 20,
//                                         child: CircularProgressIndicator(
//                                           strokeWidth: 2,
//                                           valueColor:
//                                               AlwaysStoppedAnimation<Color>(
//                                                 Colors.white,
//                                               ),
//                                         ),
//                                       )
//                                     : const Icon(Icons.check_circle_outline),
//                                 label: Text(
//                                   orderProvider.isLoading
//                                       ? 'جاري الحفظ...'
//                                       : (_isEditing ? 'تحديث' : 'إنشاء'),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: AppColors.primaryBlue,
//                                   foregroundColor: Colors.white,
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 32,
//                                     vertical: 16,
//                                   ),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ============================================
//   // مكونات مشتركة
//   // ============================================

//   Widget _buildLogoCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'شعار الشركة',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 if (_companyLogoPath != null)
//                   Container(
//                     width: 100,
//                     height: 100,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: AppColors.lightGray),
//                       image: DecorationImage(
//                         image: FileImage(File(_companyLogoPath!)),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   )
//                 else
//                   Container(
//                     width: 100,
//                     height: 100,
//                     decoration: BoxDecoration(
//                       color: AppColors.backgroundGray,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: AppColors.lightGray),
//                     ),
//                     child: const Icon(
//                       Icons.business,
//                       size: 40,
//                       color: AppColors.mediumGray,
//                     ),
//                   ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'سيظهر الشعار في تقرير الطلب',
//                         style: TextStyle(
//                           color: AppColors.mediumGray,
//                           fontSize: 14,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Row(
//                         children: [
//                           ElevatedButton(
//                             onPressed: _pickLogo,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: AppColors.primaryBlue,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                             ),
//                             child: const Text('رفع شعار'),
//                           ),
//                           if (_companyLogoPath != null)
//                             Padding(
//                               padding: const EdgeInsets.only(left: 8),
//                               child: TextButton(
//                                 onPressed: () {
//                                   setState(() {
//                                     _companyLogoPath = null;
//                                   });
//                                 },
//                                 child: const Text(
//                                   'إزالة',
//                                   style: TextStyle(color: Colors.red),
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTimesCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'المواعيد',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             // Loading Date & Time
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'تاريخ التحميل',
//                     icon: Icons.date_range,
//                     color: AppColors.warningOrange,
//                     child: InkWell(
//                       onTap: () => _pickDate(context, 'loading'),
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: AppColors.warningOrange.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: AppColors.lightGray),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               DateFormat('yyyy/MM/dd').format(_loadingDate),
//                               style: const TextStyle(fontSize: 14),
//                             ),
//                             const Icon(Icons.calendar_today, size: 18),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'وقت التحميل',
//                     icon: Icons.access_time,
//                     color: AppColors.warningOrange,
//                     child: InkWell(
//                       onTap: () => _pickTime(context, 'loading'),
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: AppColors.warningOrange.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: AppColors.lightGray),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               _loadingTimeController.text,
//                               style: const TextStyle(fontSize: 14),
//                             ),
//                             const Icon(Icons.access_time, size: 18),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),

//             // Arrival Date & Time
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'تاريخ الوصول',
//                     icon: Icons.date_range,
//                     color: AppColors.infoBlue,
//                     child: InkWell(
//                       onTap: () => _pickDate(context, 'arrival'),
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: AppColors.infoBlue.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: AppColors.lightGray),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               DateFormat('yyyy/MM/dd').format(_arrivalDate),
//                               style: const TextStyle(fontSize: 14),
//                             ),
//                             const Icon(Icons.calendar_today, size: 18),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'وقت الوصول المتوقع',
//                     icon: Icons.access_time,
//                     color: AppColors.infoBlue,
//                     child: InkWell(
//                       onTap: () => _pickTime(context, 'arrival'),
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: AppColors.infoBlue.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: AppColors.lightGray),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               _arrivalTimeController.text,
//                               style: const TextStyle(fontSize: 14),
//                             ),
//                             const Icon(Icons.access_time, size: 18),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTrackingInfoCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'معلومات التتبع',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             // Actual Arrival Time
//             _buildFieldWithIcon(
//               label: 'وقت الوصول الفعلي',
//               icon: Icons.access_time_filled,
//               color: AppColors.successGreen,
//               child: InkWell(
//                 onTap: () => _pickTime(context, 'actualArrival'),
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: AppColors.successGreen.withOpacity(0.05),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: AppColors.lightGray),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         _actualArrivalTimeController.text.isNotEmpty
//                             ? _actualArrivalTimeController.text
//                             : 'اختر الوقت',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: _actualArrivalTimeController.text.isNotEmpty
//                               ? Colors.black
//                               : AppColors.mediumGray,
//                         ),
//                       ),
//                       const Icon(Icons.access_time, size: 18),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Loading Duration
//             _buildFieldWithIcon(
//               label: 'مدة التحميل (دقيقة)',
//               icon: Icons.timer,
//               color: AppColors.infoBlue,
//               child: CustomTextField(
//                 controller: _loadingDurationController,
//                 labelText: '',
//                 prefixIcon: null,
//                 keyboardType: TextInputType.number,
//                 fieldColor: AppColors.infoBlue.withOpacity(0.05),
//                 enabled: _canEditTrackingInfo,
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Delay Reason
//             _buildFieldWithIcon(
//               label: 'سبب التأخير',
//               icon: Icons.warning,
//               color: AppColors.errorRed,
//               child: CustomTextField(
//                 controller: _delayReasonController,
//                 labelText: '',
//                 prefixIcon: null,
//                 maxLines: 2,
//                 fieldColor: AppColors.errorRed.withOpacity(0.05),
//                 enabled: _canEditTrackingInfo,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBasicInfoCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'المعلومات الأساسية',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             if (_isEditing)
//               Column(
//                 children: [
//                   _buildFieldWithIcon(
//                     label: 'رقم الطلب',
//                     icon: Icons.numbers,
//                     color: AppColors.infoBlue,
//                     child: CustomTextField(
//                       controller: _orderNumberController,
//                       labelText: '',
//                       prefixIcon: null,
//                       enabled: false,
//                       fieldColor: AppColors.infoBlue.withOpacity(0.05),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),

//             // Order Date
//             _buildFieldWithIcon(
//               label: 'تاريخ الطلب',
//               icon: Icons.calendar_today,
//               color: AppColors.successGreen,
//               enabled: _canEditAllFields,
//               child: InkWell(
//                 onTap: _canEditAllFields
//                     ? () => _pickDate(context, 'order')
//                     : null,
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: AppColors.successGreen.withOpacity(0.05),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: AppColors.lightGray),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         DateFormat('yyyy/MM/dd').format(_orderDate),
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                       const Icon(Icons.calendar_today, size: 18),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Supplier Name
//             _buildFieldWithIcon(
//               label: 'اسم المورد',
//               icon: Icons.business,
//               color: AppColors.primaryBlue,
//               enabled: _canEditAllFields,
//               child: CustomTextField(
//                 controller: _supplierNameController,
//                 labelText: '',
//                 prefixIcon: null,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'يرجى إدخال اسم المورد';
//                   }
//                   return null;
//                 },
//                 fieldColor: AppColors.primaryBlue.withOpacity(0.05),
//                 enabled: _canEditAllFields,
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Request Type
//             _buildFieldWithIcon(
//               label: 'نوع الطلب',
//               icon: Icons.category,
//               color: AppColors.secondaryTeal,
//               enabled: _canEditAllFields,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 decoration: BoxDecoration(
//                   color: AppColors.secondaryTeal.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.lightGray),
//                 ),
//                 child: DropdownButton<String>(
//                   value: _requestType,
//                   isExpanded: true,
//                   underline: const SizedBox(),
//                   items: _requestTypes.map((String value) {
//                     return DropdownMenuItem<String>(
//                       value: value,
//                       child: Text(value),
//                     );
//                   }).toList(),
//                   onChanged: _canEditAllFields
//                       ? (value) {
//                           setState(() {
//                             _requestType = value!;
//                           });
//                         }
//                       : null,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Supplier Order Number
//             if (_requestType == 'مورد')
//               Column(
//                 children: [
//                   _buildFieldWithIcon(
//                     label: 'رقم طلب المورد',
//                     icon: Icons.confirmation_number,
//                     color: AppColors.warningOrange,
//                     enabled: _canEditAllFields,
//                     child: CustomTextField(
//                       controller: _supplierOrderNumberController,
//                       labelText: '',
//                       prefixIcon: null,
//                       fieldColor: AppColors.warningOrange.withOpacity(0.05),
//                       enabled: _canEditAllFields,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),

//             // Status
//             _buildFieldWithIcon(
//               label: 'حالة الطلب',
//               icon: Icons.stairs,
//               color: AppColors.pendingYellow,
//               enabled: _canEditStatus,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 decoration: BoxDecoration(
//                   color: AppColors.pendingYellow.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.lightGray),
//                 ),
//                 child: DropdownButton<String>(
//                   value: _status,
//                   isExpanded: true,
//                   underline: const SizedBox(),
//                   items: _statuses.map((String value) {
//                     Color statusColor;
//                     switch (value) {
//                       case 'قيد الانتظار':
//                         statusColor = AppColors.pendingYellow;
//                         break;
//                       case 'مخصص للعميل':
//                         statusColor = AppColors.infoBlue;
//                         break;
//                       case 'في انتظار التحميل':
//                         statusColor = AppColors.warningOrange;
//                         break;
//                       case 'جاهز للتحميل':
//                         statusColor = AppColors.infoBlue;
//                         break;
//                       case 'تم التحميل':
//                         statusColor = AppColors.successGreen;
//                         break;
//                       case 'ملغى':
//                         statusColor = AppColors.errorRed;
//                         break;
//                       default:
//                         statusColor = AppColors.lightGray;
//                     }
//                     return DropdownMenuItem<String>(
//                       value: value,
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 12,
//                             height: 12,
//                             decoration: BoxDecoration(
//                               color: statusColor,
//                               shape: BoxShape.circle,
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Text(value),
//                         ],
//                       ),
//                     );
//                   }).toList(),
//                   onChanged: _canEditStatus
//                       ? (value) {
//                           setState(() {
//                             _status = value!;
//                           });
//                         }
//                       : null,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCustomerCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'تعيين العميل',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             _buildFieldWithIcon(
//               label: 'العميل',
//               icon: Icons.person_outline,
//               color: AppColors.secondaryTeal,
//               enabled: _canEditCustomer,
//               child: Column(
//                 children: [
//                   if (_selectedCustomer != null)
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       margin: const EdgeInsets.only(bottom: 12),
//                       decoration: BoxDecoration(
//                         color: AppColors.primaryBlue.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: AppColors.primaryBlue),
//                       ),
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 40,
//                             height: 40,
//                             decoration: BoxDecoration(
//                               color: AppColors.primaryBlue.withOpacity(0.2),
//                               shape: BoxShape.circle,
//                             ),
//                             child: Center(
//                               child: Text(
//                                 _selectedCustomer!.name
//                                     .substring(0, 1)
//                                     .toUpperCase(),
//                                 style: TextStyle(
//                                   color: AppColors.primaryBlue,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   _selectedCustomer!.name,
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 Text(
//                                   'كود: ${_selectedCustomer!.code}',
//                                   style: TextStyle(
//                                     color: AppColors.mediumGray,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 if (_selectedCustomer!.phone != null)
//                                   Text(
//                                     'هاتف: ${_selectedCustomer!.phone!}',
//                                     style: TextStyle(
//                                       color: AppColors.mediumGray,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                           if (_canEditCustomer)
//                             IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   _selectedCustomer = null;
//                                   _selectedCustomerId = null;
//                                   _customerSearchController.clear();
//                                 });
//                               },
//                               icon: const Icon(Icons.clear, color: Colors.red),
//                             ),
//                         ],
//                       ),
//                     ),

//                   if (_canEditCustomer)
//                     Autocomplete<Customer>(
//                       displayStringForOption: (customer) =>
//                           customer.displayName,

//                       optionsBuilder: (TextEditingValue value) async {
//                         if (value.text.trim().isEmpty) {
//                           return const Iterable<Customer>.empty();
//                         }
//                         return await _searchCustomers(value.text);
//                       },

//                       fieldViewBuilder:
//                           (
//                             context,
//                             textController,
//                             focusNode,
//                             onFieldSubmitted,
//                           ) {
//                             return TextField(
//                               controller: textController,
//                               focusNode: focusNode,
//                               enabled: _canEditCustomer,
//                               decoration: InputDecoration(
//                                 hintText: 'ابحث عن عميل...',
//                                 prefixIcon: const Icon(Icons.search),
//                                 suffixIcon: _selectedCustomer == null
//                                     ? null
//                                     : IconButton(
//                                         icon: const Icon(Icons.clear),
//                                         onPressed: () {
//                                           setState(() {
//                                             _selectedCustomer = null;
//                                             textController.clear();
//                                           });
//                                         },
//                                       ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                             );
//                           },

//                       optionsViewBuilder: (context, onSelected, options) {
//                         return Align(
//                           alignment: Alignment.topLeft,
//                           child: Material(
//                             elevation: 6,
//                             borderRadius: BorderRadius.circular(12),
//                             child: ConstrainedBox(
//                               constraints: const BoxConstraints(maxHeight: 300),
//                               child: ListView.builder(
//                                 padding: EdgeInsets.zero,
//                                 itemCount: options.length,
//                                 itemBuilder: (context, index) {
//                                   final customer = options.elementAt(index);
//                                   return ListTile(
//                                     leading: CircleAvatar(
//                                       child: Text(customer.name[0]),
//                                     ),
//                                     title: Text(customer.name),
//                                     subtitle: Text('كود: ${customer.code}'),
//                                     onTap: () => onSelected(customer),
//                                   );
//                                 },
//                               ),
//                             ),
//                           ),
//                         );
//                       },

//                       onSelected: (Customer customer) {
//                         setState(() {
//                           _selectedCustomer = customer;
//                           _selectedCustomerId = customer.id;
//                         });
//                       },
//                     ),

//                   if (_canEditCustomer)
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: TextButton.icon(
//                         onPressed: () {
//                           Navigator.pushNamed(context, '/customer/form').then((
//                             value,
//                           ) {
//                             if (value != null && value is Customer) {
//                               setState(() {
//                                 _selectedCustomer = value;
//                                 _selectedCustomerId = value.id;
//                                 _customerSearchController.text =
//                                     value.displayName;
//                               });
//                             }
//                           });
//                         },
//                         icon: const Icon(Icons.add),
//                         label: const Text('إضافة عميل جديد'),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDriverCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'تعيين السائق',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             _buildFieldWithIcon(
//               label: 'السائق',
//               icon: Icons.directions_car,
//               color: AppColors.infoBlue,
//               enabled: _canEditDriver,
//               child: Column(
//                 children: [
//                   if (_selectedDriver != null)
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       margin: const EdgeInsets.only(bottom: 12),
//                       decoration: BoxDecoration(
//                         color: AppColors.infoBlue.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: AppColors.infoBlue),
//                       ),
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 40,
//                             height: 40,
//                             decoration: BoxDecoration(
//                               color: AppColors.infoBlue.withOpacity(0.2),
//                               shape: BoxShape.circle,
//                             ),
//                             child: Center(
//                               child: Text(
//                                 _selectedDriver!.name
//                                     .substring(0, 1)
//                                     .toUpperCase(),
//                                 style: TextStyle(
//                                   color: AppColors.infoBlue,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   _selectedDriver!.name,
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 Text(
//                                   'رخصة: ${_selectedDriver!.licenseNumber}',
//                                   style: TextStyle(
//                                     color: AppColors.mediumGray,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 Text(
//                                   'هاتف: ${_selectedDriver!.phone}',
//                                   style: TextStyle(
//                                     color: AppColors.mediumGray,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 if (_selectedDriver!.vehicleNumber != null)
//                                   Text(
//                                     'مركبة: ${_selectedDriver!.vehicleNumber!}',
//                                     style: TextStyle(
//                                       color: AppColors.mediumGray,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                           if (_canEditDriver)
//                             IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   _selectedDriver = null;
//                                   _selectedDriverId = null;
//                                   _driverNameController.clear();
//                                   _driverPhoneController.clear();
//                                   _vehicleNumberController.clear();
//                                   _driverSearchController.clear();
//                                 });
//                               },
//                               icon: const Icon(Icons.clear, color: Colors.red),
//                             ),
//                         ],
//                       ),
//                     ),

//                   if (_canEditDriver)
//                     Autocomplete<Driver>(
//                       displayStringForOption: (driver) => driver.name,

//                       optionsBuilder: (TextEditingValue value) async {
//                         if (value.text.trim().isEmpty) {
//                           return const Iterable<Driver>.empty();
//                         }
//                         return await _searchDrivers(value.text);
//                       },

//                       fieldViewBuilder:
//                           (
//                             context,
//                             textController,
//                             focusNode,
//                             onFieldSubmitted,
//                           ) {
//                             return TextField(
//                               controller: textController,
//                               focusNode: focusNode,
//                               enabled: _canEditDriver,
//                               decoration: InputDecoration(
//                                 hintText: 'ابحث عن سائق...',
//                                 prefixIcon: const Icon(Icons.search),
//                                 suffixIcon: _selectedDriver == null
//                                     ? null
//                                     : IconButton(
//                                         icon: const Icon(Icons.clear),
//                                         onPressed: () {
//                                           setState(() {
//                                             _selectedDriver = null;
//                                             textController.clear();
//                                           });
//                                         },
//                                       ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                             );
//                           },

//                       optionsViewBuilder: (context, onSelected, options) {
//                         return Align(
//                           alignment: Alignment.topLeft,
//                           child: Material(
//                             elevation: 6,
//                             borderRadius: BorderRadius.circular(12),
//                             child: ConstrainedBox(
//                               constraints: const BoxConstraints(maxHeight: 300),
//                               child: ListView.builder(
//                                 padding: EdgeInsets.zero,
//                                 itemCount: options.length,
//                                 itemBuilder: (context, index) {
//                                   final driver = options.elementAt(index);
//                                   return ListTile(
//                                     leading: CircleAvatar(
//                                       child: Text(driver.name[0]),
//                                     ),
//                                     title: Text(driver.name),
//                                     subtitle: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text('رخصة: ${driver.licenseNumber}'),
//                                         Text('هاتف: ${driver.phone}'),
//                                         if (driver.vehicleNumber != null)
//                                           Text(
//                                             'مركبة: ${driver.vehicleNumber!}',
//                                           ),
//                                       ],
//                                     ),
//                                     onTap: () => onSelected(driver),
//                                   );
//                                 },
//                               ),
//                             ),
//                           ),
//                         );
//                       },

//                       onSelected: (Driver driver) {
//                         setState(() {
//                           _selectedDriver = driver;
//                           _selectedDriverId = driver.id;
//                           _driverNameController.text = driver.name;
//                           _driverPhoneController.text = driver.phone;
//                           _vehicleNumberController.text =
//                               driver.vehicleNumber ?? '';
//                         });
//                       },
//                     ),

//                   if (_canEditDriver && !_canEditAllFields)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           CustomTextField(
//                             controller: _driverNameController,
//                             labelText: 'اسم السائق',
//                             prefixIcon: Icons.person,
//                             enabled: false,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _driverPhoneController,
//                             labelText: 'هاتف السائق',
//                             prefixIcon: Icons.phone,
//                             enabled: false,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _vehicleNumberController,
//                             labelText: 'رقم المركبة',
//                             prefixIcon: Icons.directions_car,
//                             enabled: false,
//                           ),
//                         ],
//                       ),
//                     ),

//                   if (_canEditDriver)
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: TextButton.icon(
//                         onPressed: () {
//                           Navigator.pushNamed(context, '/driver/form').then((
//                             value,
//                           ) {
//                             if (value != null && value is Driver) {
//                               setState(() {
//                                 _selectedDriver = value;
//                                 _selectedDriverId = value.id;
//                                 _driverNameController.text = value.name;
//                                 _driverPhoneController.text = value.phone;
//                                 _vehicleNumberController.text =
//                                     value.vehicleNumber ?? '';
//                               });
//                             }
//                           });
//                         },
//                         icon: const Icon(Icons.add),
//                         label: const Text('إضافة سائق جديد'),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFuelInfoCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'معلومات الوقود',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'نوع الوقود',
//                     icon: Icons.local_gas_station,
//                     color: AppColors.warningOrange,
//                     enabled: _canEditAllFields,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       decoration: BoxDecoration(
//                         color: AppColors.warningOrange.withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: AppColors.lightGray),
//                       ),
//                       child: DropdownButton<String>(
//                         value: _fuelType,
//                         isExpanded: true,
//                         underline: const SizedBox(),
//                         hint: const Text('اختر نوع الوقود'),
//                         items: _fuelTypes.map((String value) {
//                           return DropdownMenuItem<String>(
//                             value: value,
//                             child: Text(value),
//                           );
//                         }).toList(),
//                         onChanged: _canEditAllFields
//                             ? (value) {
//                                 setState(() {
//                                   _fuelType = value;
//                                 });
//                               }
//                             : null,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: _buildFieldWithIcon(
//                           label: 'الكمية',
//                           icon: Icons.scale,
//                           color: AppColors.warningOrange,
//                           enabled: _canEditAllFields,
//                           child: CustomTextField(
//                             controller: _quantityController,
//                             labelText: '',
//                             prefixIcon: null,
//                             keyboardType: TextInputType.number,
//                             fieldColor: AppColors.warningOrange.withOpacity(
//                               0.05,
//                             ),
//                             enabled: _canEditAllFields,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: _buildFieldWithIcon(
//                           label: 'الوحدة',
//                           icon: Icons.square_foot,
//                           color: AppColors.warningOrange,
//                           enabled: _canEditAllFields,
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 12),
//                             decoration: BoxDecoration(
//                               color: AppColors.warningOrange.withOpacity(0.05),
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(color: AppColors.lightGray),
//                             ),
//                             child: DropdownButton<String>(
//                               value: _unit,
//                               isExpanded: true,
//                               underline: const SizedBox(),
//                               hint: const Text('الوحدة'),
//                               items: _units.map((String value) {
//                                 return DropdownMenuItem<String>(
//                                   value: value,
//                                   child: Text(value),
//                                 );
//                               }).toList(),
//                               onChanged: _canEditAllFields
//                                   ? (value) {
//                                       setState(() {
//                                         _unit = value;
//                                       });
//                                     }
//                                   : null,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNotesCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'ملاحظات',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             _buildFieldWithIcon(
//               label: 'ملاحظات إضافية',
//               icon: Icons.note,
//               color: AppColors.mediumGray,
//               enabled: _canEditNotes,
//               child: CustomTextField(
//                 controller: _notesController,
//                 labelText: '',
//                 prefixIcon: null,
//                 maxLines: 4,
//                 fieldColor: AppColors.backgroundGray,
//                 enabled: _canEditNotes,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAttachmentsCard(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'المرفقات',
//                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 if (_canEditAttachments)
//                   ElevatedButton.icon(
//                     onPressed: _pickAttachments,
//                     icon: const Icon(Icons.attach_file),
//                     label: const Text('إضافة مرفقات'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.primaryBlue,
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             if (_newAttachmentPaths.isEmpty &&
//                 (widget.orderToEdit?.attachments.isEmpty ?? true))
//               Container(
//                 padding: const EdgeInsets.all(32),
//                 decoration: BoxDecoration(
//                   color: AppColors.backgroundGray,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.lightGray),
//                 ),
//                 child: Column(
//                   children: [
//                     Icon(
//                       Icons.attach_file,
//                       size: 48,
//                       color: AppColors.mediumGray,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'لا توجد مرفقات',
//                       style: TextStyle(
//                         color: AppColors.mediumGray,
//                         fontSize: 16,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'انقر على زر "إضافة مرفقات" لرفع الملفات',
//                       style: TextStyle(
//                         color: AppColors.lightGray,
//                         fontSize: 14,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//             if (_newAttachmentPaths.isNotEmpty ||
//                 (widget.orderToEdit?.attachments.isNotEmpty ?? false))
//               Column(
//                 children: [
//                   if (widget.orderToEdit != null)
//                     ...widget.orderToEdit!.attachments.map(
//                       (attachment) => AttachmentItem(
//                         fileName: attachment.filename,
//                         fileSize: 'موجود على السيرفر',
//                         onDelete: () {},
//                         canDelete: false,
//                       ),
//                     ),
//                   ..._newAttachmentPaths.asMap().entries.map(
//                     (entry) => AttachmentItem(
//                       fileName: entry.value.split('/').last,
//                       fileSize: _formatFileSize(entry.value),
//                       onDelete: () => _removeAttachment(entry.key),
//                       canDelete: _canEditAttachments,
//                     ),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSubmitButton(OrderProvider orderProvider) {
//     return GradientButton(
//       onPressed: orderProvider.isLoading ? null : _submitForm,
//       text: orderProvider.isLoading
//           ? 'جاري الحفظ...'
//           : (_isEditing ? 'تحديث الطلب' : 'إنشاء الطلب'),
//       gradient: AppColors.accentGradient,
//       isLoading: orderProvider.isLoading,
//     );
//   }

//   // ============================================
//   // مكونات سطح المكتب
//   // ============================================

//   Widget _buildDesktopNavItem({
//     required IconData icon,
//     required String title,
//     bool isSelected = false,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         color: isSelected
//             ? AppColors.primaryBlue.withOpacity(0.1)
//             : Colors.transparent,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: isSelected
//               ? AppColors.primaryBlue.withOpacity(0.3)
//               : Colors.transparent,
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             icon,
//             size: 20,
//             color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
//           ),
//           const SizedBox(width: 12),
//           Text(
//             title,
//             style: TextStyle(
//               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//               color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDesktopLogoSection(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'شعار الشركة',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 if (_companyLogoPath != null)
//                   Container(
//                     width: 150,
//                     height: 150,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.grey.shade300),
//                       image: DecorationImage(
//                         image: FileImage(File(_companyLogoPath!)),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   )
//                 else
//                   Container(
//                     width: 150,
//                     height: 150,
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade100,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.grey.shade300),
//                     ),
//                     child: const Icon(
//                       Icons.business,
//                       size: 60,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 const SizedBox(width: 24),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'شعار الشركة',
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'سيظهر الشعار في تقرير الطلب والمستندات الرسمية',
//                         style: TextStyle(
//                           color: Colors.grey.shade600,
//                           fontSize: 14,
//                         ),
//                       ),
//                       const SizedBox(height: 24),
//                       Row(
//                         children: [
//                           ElevatedButton.icon(
//                             onPressed: _pickLogo,
//                             icon: const Icon(Icons.upload),
//                             label: const Text('رفع شعار'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: AppColors.primaryBlue,
//                               foregroundColor: Colors.white,
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                                 vertical: 12,
//                               ),
//                             ),
//                           ),
//                           if (_companyLogoPath != null)
//                             Padding(
//                               padding: const EdgeInsets.only(left: 12),
//                               child: OutlinedButton.icon(
//                                 onPressed: () {
//                                   setState(() {
//                                     _companyLogoPath = null;
//                                   });
//                                 },
//                                 icon: const Icon(Icons.delete_outline),
//                                 label: const Text('إزالة'),
//                                 style: OutlinedButton.styleFrom(
//                                   foregroundColor: Colors.red,
//                                   side: const BorderSide(color: Colors.red),
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTimesCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'المواعيد',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Loading Date & Time
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'تاريخ التحميل',
//                     icon: Icons.date_range,
//                     color: AppColors.warningOrange,
//                     child: InkWell(
//                       onTap: () => _pickDate(context, 'loading'),
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.warningOrange.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               DateFormat('yyyy/MM/dd').format(_loadingDate),
//                               style: const TextStyle(fontSize: 16),
//                             ),
//                             const Icon(Icons.calendar_today, size: 20),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 20),
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'وقت التحميل',
//                     icon: Icons.access_time,
//                     color: AppColors.warningOrange,
//                     child: InkWell(
//                       onTap: () => _pickTime(context, 'loading'),
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.warningOrange.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               _loadingTimeController.text,
//                               style: const TextStyle(fontSize: 16),
//                             ),
//                             const Icon(Icons.access_time, size: 20),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             // Arrival Date & Time
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'تاريخ الوصول',
//                     icon: Icons.date_range,
//                     color: AppColors.infoBlue,
//                     child: InkWell(
//                       onTap: () => _pickDate(context, 'arrival'),
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.infoBlue.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               DateFormat('yyyy/MM/dd').format(_arrivalDate),
//                               style: const TextStyle(fontSize: 16),
//                             ),
//                             const Icon(Icons.calendar_today, size: 20),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 20),
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'وقت الوصول المتوقع',
//                     icon: Icons.access_time,
//                     color: AppColors.infoBlue,
//                     child: InkWell(
//                       onTap: () => _pickTime(context, 'arrival'),
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.infoBlue.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               _arrivalTimeController.text,
//                               style: const TextStyle(fontSize: 16),
//                             ),
//                             const Icon(Icons.access_time, size: 20),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTrackingInfoCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'معلومات التتبع',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Actual Arrival Time
//             _buildFieldWithIcon(
//               label: 'وقت الوصول الفعلي',
//               icon: Icons.access_time_filled,
//               color: AppColors.successGreen,
//               child: InkWell(
//                 onTap: () => _pickTime(context, 'actualArrival'),
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: AppColors.successGreen.withOpacity(0.05),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         _actualArrivalTimeController.text.isNotEmpty
//                             ? _actualArrivalTimeController.text
//                             : 'اختر الوقت',
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: _actualArrivalTimeController.text.isNotEmpty
//                               ? Colors.black
//                               : Colors.grey,
//                         ),
//                       ),
//                       const Icon(Icons.access_time, size: 20),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),

//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'مدة التحميل (دقيقة)',
//                     icon: Icons.timer,
//                     color: AppColors.infoBlue,
//                     child: CustomTextField(
//                       controller: _loadingDurationController,
//                       labelText: '',
//                       prefixIcon: null,
//                       keyboardType: TextInputType.number,
//                       fieldColor: AppColors.infoBlue.withOpacity(0.05),
//                       enabled: _canEditTrackingInfo,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 20),
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'سبب التأخير',
//                     icon: Icons.warning,
//                     color: AppColors.errorRed,
//                     child: CustomTextField(
//                       controller: _delayReasonController,
//                       labelText: '',
//                       prefixIcon: null,
//                       fieldColor: AppColors.errorRed.withOpacity(0.05),
//                       enabled: _canEditTrackingInfo,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBasicInfoCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'المعلومات الأساسية',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),

//             if (_isEditing)
//               Column(
//                 children: [
//                   _buildFieldWithIcon(
//                     label: 'رقم الطلب',
//                     icon: Icons.numbers,
//                     color: AppColors.infoBlue,
//                     child: CustomTextField(
//                       controller: _orderNumberController,
//                       labelText: '',
//                       prefixIcon: null,
//                       enabled: false,
//                       fieldColor: AppColors.infoBlue.withOpacity(0.05),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                 ],
//               ),

//             // Order Date
//             _buildFieldWithIcon(
//               label: 'تاريخ الطلب',
//               icon: Icons.calendar_today,
//               color: AppColors.successGreen,
//               enabled: _canEditAllFields,
//               child: InkWell(
//                 onTap: _canEditAllFields
//                     ? () => _pickDate(context, 'order')
//                     : null,
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: AppColors.successGreen.withOpacity(0.05),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         DateFormat('yyyy/MM/dd').format(_orderDate),
//                         style: const TextStyle(fontSize: 16),
//                       ),
//                       const Icon(Icons.calendar_today, size: 20),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Supplier Name
//             _buildFieldWithIcon(
//               label: 'اسم المورد',
//               icon: Icons.business,
//               color: AppColors.primaryBlue,
//               enabled: _canEditAllFields,
//               child: CustomTextField(
//                 controller: _supplierNameController,
//                 labelText: '',
//                 prefixIcon: null,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'يرجى إدخال اسم المورد';
//                   }
//                   return null;
//                 },
//                 fieldColor: AppColors.primaryBlue.withOpacity(0.05),
//                 enabled: _canEditAllFields,
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Request Type
//             _buildFieldWithIcon(
//               label: 'نوع الطلب',
//               icon: Icons.category,
//               color: AppColors.secondaryTeal,
//               enabled: _canEditAllFields,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 decoration: BoxDecoration(
//                   color: AppColors.secondaryTeal.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//                 child: DropdownButton<String>(
//                   value: _requestType,
//                   isExpanded: true,
//                   underline: const SizedBox(),
//                   items: _requestTypes.map((String value) {
//                     return DropdownMenuItem<String>(
//                       value: value,
//                       child: Text(value),
//                     );
//                   }).toList(),
//                   onChanged: _canEditAllFields
//                       ? (value) {
//                           setState(() {
//                             _requestType = value!;
//                           });
//                         }
//                       : null,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Status
//             _buildFieldWithIcon(
//               label: 'حالة الطلب',
//               icon: Icons.stairs,
//               color: AppColors.pendingYellow,
//               enabled: _canEditStatus,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 decoration: BoxDecoration(
//                   color: AppColors.pendingYellow.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//                 child: DropdownButton<String>(
//                   value: _status,
//                   isExpanded: true,
//                   underline: const SizedBox(),
//                   items: _statuses.map((String value) {
//                     return DropdownMenuItem<String>(
//                       value: value,
//                       child: Text(value),
//                     );
//                   }).toList(),
//                   onChanged: _canEditStatus
//                       ? (value) {
//                           setState(() {
//                             _status = value!;
//                           });
//                         }
//                       : null,
//                 ),
//               ),
//             ),

//             // Supplier Order Number
//             if (_requestType == 'مورد') ...[
//               const SizedBox(height: 20),
//               _buildFieldWithIcon(
//                 label: 'رقم طلب المورد',
//                 icon: Icons.confirmation_number,
//                 color: AppColors.warningOrange,
//                 enabled: _canEditAllFields,
//                 child: CustomTextField(
//                   controller: _supplierOrderNumberController,
//                   labelText: '',
//                   prefixIcon: null,
//                   fieldColor: AppColors.warningOrange.withOpacity(0.05),
//                   enabled: _canEditAllFields,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCustomerCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'تعيين العميل',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),

//             if (_selectedCustomer != null)
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 margin: const EdgeInsets.only(bottom: 20),
//                 decoration: BoxDecoration(
//                   color: AppColors.primaryBlue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.primaryBlue),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 50,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         color: AppColors.primaryBlue.withOpacity(0.2),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Center(
//                         child: Text(
//                           _selectedCustomer!.name.substring(0, 1).toUpperCase(),
//                           style: TextStyle(
//                             color: AppColors.primaryBlue,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             _selectedCustomer!.name,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           Text(
//                             'كود: ${_selectedCustomer!.code}',
//                             style: TextStyle(
//                               color: Colors.grey.shade600,
//                               fontSize: 14,
//                             ),
//                           ),
//                           if (_selectedCustomer!.phone != null)
//                             Text(
//                               'هاتف: ${_selectedCustomer!.phone!}',
//                               style: TextStyle(
//                                 color: Colors.grey.shade600,
//                                 fontSize: 14,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                     if (_canEditCustomer)
//                       IconButton(
//                         onPressed: () {
//                           setState(() {
//                             _selectedCustomer = null;
//                             _selectedCustomerId = null;
//                             _customerSearchController.clear();
//                           });
//                         },
//                         icon: const Icon(
//                           Icons.clear,
//                           color: Colors.red,
//                           size: 24,
//                         ),
//                       ),
//                   ],
//                 ),
//               ),

//             if (_canEditCustomer)
//               Autocomplete<Customer>(
//                 displayStringForOption: (customer) => customer.displayName,

//                 optionsBuilder: (TextEditingValue value) async {
//                   if (value.text.trim().isEmpty) {
//                     return const Iterable<Customer>.empty();
//                   }
//                   return await _searchCustomers(value.text);
//                 },

//                 fieldViewBuilder:
//                     (context, textController, focusNode, onFieldSubmitted) {
//                       return TextField(
//                         controller: textController,
//                         focusNode: focusNode,
//                         enabled: _canEditCustomer,
//                         decoration: InputDecoration(
//                           hintText: 'ابحث عن عميل...',
//                           prefixIcon: const Icon(Icons.search),
//                           suffixIcon: _selectedCustomer == null
//                               ? null
//                               : IconButton(
//                                   icon: const Icon(Icons.clear),
//                                   onPressed: () {
//                                     setState(() {
//                                       _selectedCustomer = null;
//                                       textController.clear();
//                                     });
//                                   },
//                                 ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       );
//                     },

//                 optionsViewBuilder: (context, onSelected, options) {
//                   return Align(
//                     alignment: Alignment.topLeft,
//                     child: Material(
//                       elevation: 6,
//                       borderRadius: BorderRadius.circular(12),
//                       child: ConstrainedBox(
//                         constraints: const BoxConstraints(maxHeight: 300),
//                         child: ListView.builder(
//                           padding: EdgeInsets.zero,
//                           itemCount: options.length,
//                           itemBuilder: (context, index) {
//                             final customer = options.elementAt(index);
//                             return ListTile(
//                               leading: CircleAvatar(
//                                 child: Text(customer.name[0]),
//                               ),
//                               title: Text(customer.name),
//                               subtitle: Text('كود: ${customer.code}'),
//                               onTap: () => onSelected(customer),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   );
//                 },

//                 onSelected: (Customer customer) {
//                   setState(() {
//                     _selectedCustomer = customer;
//                     _selectedCustomerId = customer.id;
//                   });
//                 },
//               ),

//             if (_canEditCustomer) ...[
//               const SizedBox(height: 16),

//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: OutlinedButton.icon(
//                   onPressed: () {
//                     Navigator.pushNamed(context, '/customer/form').then((
//                       value,
//                     ) {
//                       if (value != null && value is Customer) {
//                         setState(() {
//                           _selectedCustomer = value;
//                           _selectedCustomerId = value.id;
//                           _customerSearchController.text = value.displayName;
//                         });
//                       }
//                     });
//                   },
//                   icon: const Icon(Icons.add, size: 18),
//                   label: const Text('إضافة عميل جديد'),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: AppColors.primaryBlue,
//                     side: BorderSide(color: AppColors.primaryBlue),
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDriverCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'تعيين السائق',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),

//             if (_selectedDriver != null)
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 margin: const EdgeInsets.only(bottom: 20),
//                 decoration: BoxDecoration(
//                   color: AppColors.infoBlue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.infoBlue),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 50,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         color: AppColors.infoBlue.withOpacity(0.2),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Center(
//                         child: Text(
//                           _selectedDriver!.name.substring(0, 1).toUpperCase(),
//                           style: TextStyle(
//                             color: AppColors.infoBlue,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             _selectedDriver!.name,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           Text(
//                             'رخصة: ${_selectedDriver!.licenseNumber}',
//                             style: TextStyle(
//                               color: Colors.grey.shade600,
//                               fontSize: 14,
//                             ),
//                           ),
//                           Text(
//                             'هاتف: ${_selectedDriver!.phone}',
//                             style: TextStyle(
//                               color: Colors.grey.shade600,
//                               fontSize: 14,
//                             ),
//                           ),
//                           if (_selectedDriver!.vehicleNumber != null)
//                             Text(
//                               'مركبة: ${_selectedDriver!.vehicleNumber!}',
//                               style: TextStyle(
//                                 color: Colors.grey.shade600,
//                                 fontSize: 14,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                     if (_canEditDriver)
//                       IconButton(
//                         onPressed: () {
//                           setState(() {
//                             _selectedDriver = null;
//                             _selectedDriverId = null;
//                             _driverNameController.clear();
//                             _driverPhoneController.clear();
//                             _vehicleNumberController.clear();
//                             _driverSearchController.clear();
//                           });
//                         },
//                         icon: const Icon(
//                           Icons.clear,
//                           color: Colors.red,
//                           size: 24,
//                         ),
//                       ),
//                   ],
//                 ),
//               ),

//             if (_canEditDriver)
//               Autocomplete<Driver>(
//                 displayStringForOption: (driver) => driver.name,

//                 optionsBuilder: (TextEditingValue value) async {
//                   if (value.text.trim().isEmpty) {
//                     return const Iterable<Driver>.empty();
//                   }
//                   return await _searchDrivers(value.text);
//                 },

//                 fieldViewBuilder:
//                     (context, textController, focusNode, onFieldSubmitted) {
//                       return TextField(
//                         controller: textController,
//                         focusNode: focusNode,
//                         enabled: _canEditDriver,
//                         decoration: InputDecoration(
//                           hintText: 'ابحث عن سائق...',
//                           prefixIcon: const Icon(Icons.search),
//                           suffixIcon: _selectedDriver == null
//                               ? null
//                               : IconButton(
//                                   icon: const Icon(Icons.clear),
//                                   onPressed: () {
//                                     setState(() {
//                                       _selectedDriver = null;
//                                       textController.clear();
//                                     });
//                                   },
//                                 ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       );
//                     },

//                 optionsViewBuilder: (context, onSelected, options) {
//                   return Align(
//                     alignment: Alignment.topLeft,
//                     child: Material(
//                       elevation: 6,
//                       borderRadius: BorderRadius.circular(12),
//                       child: ConstrainedBox(
//                         constraints: const BoxConstraints(maxHeight: 300),
//                         child: ListView.builder(
//                           padding: EdgeInsets.zero,
//                           itemCount: options.length,
//                           itemBuilder: (context, index) {
//                             final driver = options.elementAt(index);
//                             return ListTile(
//                               leading: CircleAvatar(
//                                 child: Text(driver.name[0]),
//                               ),
//                               title: Text(driver.name),
//                               subtitle: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('رخصة: ${driver.licenseNumber}'),
//                                   Text('هاتف: ${driver.phone}'),
//                                   if (driver.vehicleNumber != null)
//                                     Text('مركبة: ${driver.vehicleNumber!}'),
//                                 ],
//                               ),
//                               onTap: () => onSelected(driver),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   );
//                 },

//                 onSelected: (Driver driver) {
//                   setState(() {
//                     _selectedDriver = driver;
//                     _selectedDriverId = driver.id;
//                     _driverNameController.text = driver.name;
//                     _driverPhoneController.text = driver.phone;
//                     _vehicleNumberController.text = driver.vehicleNumber ?? '';
//                   });
//                 },
//               ),

//             if (_canEditDriver && !_canEditAllFields) ...[
//               const SizedBox(height: 20),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildFieldWithIcon(
//                     label: 'اسم السائق',
//                     icon: Icons.person,
//                     color: AppColors.mediumGray,
//                     enabled: false,
//                     child: CustomTextField(
//                       controller: _driverNameController,
//                       labelText: '',
//                       prefixIcon: null,
//                       enabled: false,
//                       fieldColor: Colors.grey.shade100,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _buildFieldWithIcon(
//                           label: 'هاتف السائق',
//                           icon: Icons.phone,
//                           color: AppColors.mediumGray,
//                           enabled: false,
//                           child: CustomTextField(
//                             controller: _driverPhoneController,
//                             labelText: '',
//                             prefixIcon: null,
//                             enabled: false,
//                             fieldColor: Colors.grey.shade100,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 20),
//                       Expanded(
//                         child: _buildFieldWithIcon(
//                           label: 'رقم المركبة',
//                           icon: Icons.directions_car,
//                           color: AppColors.mediumGray,
//                           enabled: false,
//                           child: CustomTextField(
//                             controller: _vehicleNumberController,
//                             labelText: '',
//                             prefixIcon: null,
//                             enabled: false,
//                             fieldColor: Colors.grey.shade100,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],

//             if (_canEditDriver) ...[
//               const SizedBox(height: 16),
//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: OutlinedButton.icon(
//                   onPressed: () {
//                     Navigator.pushNamed(context, '/driver/form').then((value) {
//                       if (value != null && value is Driver) {
//                         setState(() {
//                           _selectedDriver = value;
//                           _selectedDriverId = value.id;
//                           _driverNameController.text = value.name;
//                           _driverPhoneController.text = value.phone;
//                           _vehicleNumberController.text =
//                               value.vehicleNumber ?? '';
//                         });
//                       }
//                     });
//                   },
//                   icon: const Icon(Icons.add, size: 18),
//                   label: const Text('إضافة سائق جديد'),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: AppColors.infoBlue,
//                     side: BorderSide(color: AppColors.infoBlue),
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFuelInfoCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'معلومات الوقود',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),

//             Row(
//               children: [
//                 Expanded(
//                   child: _buildFieldWithIcon(
//                     label: 'نوع الوقود',
//                     icon: Icons.local_gas_station,
//                     color: AppColors.warningOrange,
//                     enabled: _canEditAllFields,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       decoration: BoxDecoration(
//                         color: AppColors.warningOrange.withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: Colors.grey.shade300),
//                       ),
//                       child: DropdownButton<String>(
//                         value: _fuelType,
//                         isExpanded: true,
//                         underline: const SizedBox(),
//                         hint: const Text('اختر نوع الوقود'),
//                         items: _fuelTypes.map((String value) {
//                           return DropdownMenuItem<String>(
//                             value: value,
//                             child: Text(value),
//                           );
//                         }).toList(),
//                         onChanged: _canEditAllFields
//                             ? (value) {
//                                 setState(() {
//                                   _fuelType = value;
//                                 });
//                               }
//                             : null,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 20),
//                 Expanded(
//                   child: Column(
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _buildFieldWithIcon(
//                               label: 'الكمية',
//                               icon: Icons.scale,
//                               color: AppColors.warningOrange,
//                               enabled: _canEditAllFields,
//                               child: CustomTextField(
//                                 controller: _quantityController,
//                                 labelText: '',
//                                 prefixIcon: null,
//                                 keyboardType: TextInputType.number,
//                                 fieldColor: AppColors.warningOrange.withOpacity(
//                                   0.05,
//                                 ),
//                                 enabled: _canEditAllFields,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 20),
//                           Expanded(
//                             child: _buildFieldWithIcon(
//                               label: 'الوحدة',
//                               icon: Icons.square_foot,
//                               color: AppColors.warningOrange,
//                               enabled: _canEditAllFields,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.warningOrange.withOpacity(
//                                     0.05,
//                                   ),
//                                   borderRadius: BorderRadius.circular(12),
//                                   border: Border.all(
//                                     color: Colors.grey.shade300,
//                                   ),
//                                 ),
//                                 child: DropdownButton<String>(
//                                   value: _unit,
//                                   isExpanded: true,
//                                   underline: const SizedBox(),
//                                   hint: const Text('الوحدة'),
//                                   items: _units.map((String value) {
//                                     return DropdownMenuItem<String>(
//                                       value: value,
//                                       child: Text(value),
//                                     );
//                                   }).toList(),
//                                   onChanged: _canEditAllFields
//                                       ? (value) {
//                                           setState(() {
//                                             _unit = value;
//                                           });
//                                         }
//                                       : null,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNotesCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'ملاحظات',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Container(
//               height: 200,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: TextField(
//                 controller: _notesController,
//                 maxLines: null,
//                 expands: true,
//                 enabled: _canEditNotes,
//                 decoration: InputDecoration(
//                   hintText: _canEditNotes
//                       ? 'أدخل ملاحظات إضافية هنا...'
//                       : 'ملاحظات (للقراءة فقط)',
//                   border: InputBorder.none,
//                   contentPadding: const EdgeInsets.all(16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAttachmentsCardDesktop(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'المرفقات',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.primaryBlue,
//                   ),
//                 ),
//                 if (_canEditAttachments)
//                   ElevatedButton.icon(
//                     onPressed: _pickAttachments,
//                     icon: const Icon(Icons.attach_file),
//                     label: const Text('إضافة مرفقات'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppColors.primaryBlue,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 12,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             if (_newAttachmentPaths.isEmpty &&
//                 (widget.orderToEdit?.attachments.isEmpty ?? true))
//               Container(
//                 padding: const EdgeInsets.all(40),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//                 child: Column(
//                   children: [
//                     Icon(
//                       Icons.attach_file,
//                       size: 60,
//                       color: Colors.grey.shade400,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'لا توجد مرفقات',
//                       style: TextStyle(
//                         color: Colors.grey.shade600,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       _canEditAttachments
//                           ? 'انقر على زر "إضافة مرفقات" لرفع الملفات'
//                           : 'المرفقات للقراءة فقط',
//                       style: TextStyle(
//                         color: Colors.grey.shade500,
//                         fontSize: 14,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),

//             if (_newAttachmentPaths.isNotEmpty ||
//                 (widget.orderToEdit?.attachments.isNotEmpty ?? false))
//               Column(
//                 children: [
//                   if (widget.orderToEdit != null)
//                     ...widget.orderToEdit!.attachments.map(
//                       (attachment) => AttachmentItem(
//                         fileName: attachment.filename,
//                         fileSize: 'موجود على السيرفر',
//                         onDelete: () {},
//                         canDelete: false,
//                         isDesktop: true,
//                       ),
//                     ),
//                   ..._newAttachmentPaths.asMap().entries.map(
//                     (entry) => AttachmentItem(
//                       fileName: entry.value.split('/').last,
//                       fileSize: _formatFileSize(entry.value),
//                       onDelete: () => _removeAttachment(entry.key),
//                       canDelete: _canEditAttachments,
//                       isDesktop: true,
//                     ),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _formatFileSize(String path) {
//     try {
//       final file = File(path);
//       final size = file.lengthSync();
//       if (size < 1024) {
//         return '${size} B';
//       } else if (size < 1024 * 1024) {
//         return '${(size / 1024).toStringAsFixed(1)} KB';
//       } else {
//         return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
//       }
//     } catch (e) {
//       return 'غير معروف';
//     }
//   }

//   void _showDeleteDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('حذف الطلب'),
//         content: const Text(
//           'هل أنت متأكد من حذف هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('إلغاء'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               final orderProvider = Provider.of<OrderProvider>(
//                 context,
//                 listen: false,
//               );
//               final success = await orderProvider.deleteOrder(
//                 widget.orderToEdit!.id,
//               );
//               if (success && mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('تم حذف الطلب بنجاح'),
//                     backgroundColor: AppColors.successGreen,
//                   ),
//                 );
//                 Navigator.pop(context);
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.errorRed,
//             ),
//             child: const Text('حذف'),
//           ),
//         ],
//       ),
//     );
//   }
// }
