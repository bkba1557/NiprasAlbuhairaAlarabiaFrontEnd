// ignore_for_file: dead_code

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/saudi_cities.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';

class SupplierOrderFormScreen extends StatefulWidget {
  final Order? orderToEdit;

  const SupplierOrderFormScreen({super.key, this.orderToEdit});

  @override
  State<SupplierOrderFormScreen> createState() =>
      _SupplierOrderFormScreenState();
}

class _SupplierOrderFormScreenState extends State<SupplierOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _supplierOrderNumberController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _loadingTimeController = TextEditingController(
    text: '08:00',
  );
  final TextEditingController _arrivalTimeController = TextEditingController(
    text: '10:00',
  );

  DateTime _orderDate = DateTime.now();
  DateTime _loadingDate = DateTime.now().add(const Duration(days: 1));
  DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1));

  String _status = 'في انتظار عمل طلب جديد';
  String _fuelType = 'ديزل';
  String _unit = 'لتر';
  String? _selectedCity;
  String? _selectedRegion;

  String? _companyLogoPath;
  List<String> _newAttachmentPaths = [];

  Supplier? _selectedSupplier;
  String? _selectedSupplierId;
  String? _selectedSupplierName;

  Driver? _selectedDriver;
  String? _selectedDriverId;
  String? selectedRegion;
  String? selectedCity;
  String? _supplierAddress;

  String? _selectedArea;
  bool get isEditMode => widget.orderToEdit != null;

  List<Supplier> _suppliers = [];
  List<Driver> _drivers = [];

  // الكميات المقترحة
  final List<String> _suggestedQuantities = [
    '32000',
    '20000',
    '16000',
    '10000',
    '8000',
    '5000',
  ];

  // أنواع الوقود
  final List<String> _fuelTypes = ['بنزين 91', 'بنزين 95', 'ديزل', 'كيروسين'];

  // محافظات السعودية
  final List<String> _saudiCities = [
    'الرياض',
    'جدة',
    'المدينة المنورة',
    'الدمام',
    'الخبر',
    'الطائف',
    'تبوك',
    'الخرج',
    'بريدة',
    'حفر الباطن',
    'حائل',
    'نجران',
    'الجوف',
    'الظهران',
    'القصيم',
  ];

  // مناطق السعودية
  final List<String> _saudiRegions = [
    'الرياض',
    'القصيم',
    'الجوف',
    'المدينة المنورة',
    'جدة',
    'المنطقة الشرقية',
  ];

  // حالات الطلب
  // ✅ حالات المورد (من الداشبورد)
  final List<String> _supplierStatuses = [
    'في المستودع',
    'تم الإنشاء',
    'في انتظار الدمج',
    'تم دمجه مع العميل',
    'جاهز للتحميل',
    'تم التحميل',
    'في الطريق',
    'تم التسليم',
    'ملغى',
  ];

  // للملاحظات
  final List<String> _noteSuggestions = [
    'طلب عادي',
    'طلب عاجل',
    'تأكيد من المورد مطلوب',
    'يوجد ملاحظات خاصة',
  ];

  // Timers للتنبيهات
  Timer? _arrivalAlertTimer;
  Timer? _loadingCancelTimer;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      _initializeFormWithOrder();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSuppliers();
      await _loadDrivers();
    });
  }

  @override
  void dispose() {
    _arrivalAlertTimer?.cancel();
    _loadingCancelTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  PreferredSizeWidget _buildDesktopAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        tooltip: 'رجوع',
        color: AppColors.primaryBlue,
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        widget.orderToEdit != null ? 'تعديل طلب المورد' : 'طلب مورد جديد',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue,
        ),
      ),
      centerTitle: true,
    );
  }

  void _startStatusCheckTimer() {
    _statusCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkOrderStatus();
    });
  }

  void _checkOrderStatus() {
    if (_status == 'في انتظار عمل طلب جديد') {
      _checkArrivalTime();
      _checkLoadingTime();
    }
  }

  void _checkArrivalTime() {
    try {
      final now = DateTime.now();
      final arrivalParts = _arrivalTimeController.text.split(':');

      if (arrivalParts.length == 2) {
        final arrivalDateTime = DateTime(
          _arrivalDate.year,
          _arrivalDate.month,
          _arrivalDate.day,
          int.parse(arrivalParts[0]),
          int.parse(arrivalParts[1]),
        );

        // إذا تجاوز وقت الوصول بساعتين ولم يتم إنشاء طلب جديد
        final twoHoursAfterArrival = arrivalDateTime.add(
          const Duration(hours: 2),
        );

        if (now.isAfter(twoHoursAfterArrival)) {
          _showArrivalDelayAlert();
        }
      }
    } catch (e) {
      debugPrint('Error checking arrival time: $e');
    }
  }

  void _checkLoadingTime() {
    try {
      final now = DateTime.now();
      final loadingParts = _loadingTimeController.text.split(':');

      if (loadingParts.length == 2) {
        final loadingDateTime = DateTime(
          _loadingDate.year,
          _loadingDate.month,
          _loadingDate.day,
          int.parse(loadingParts[0]),
          int.parse(loadingParts[1]),
        );

        // إذا انتهى وقت التحميل بنصف ساعة ولم يكن هناك حركة
        final thirtyMinutesAfterLoading = loadingDateTime.add(
          const Duration(minutes: 30),
        );

        if (now.isAfter(thirtyMinutesAfterLoading) &&
            _status == 'في انتظار عمل طلب جديد') {
          _cancelOrderBySystem();
        }
      }
    } catch (e) {
      debugPrint('Error checking loading time: $e');
    }
  }

  void _showArrivalDelayAlert() {
    // عرض تنبيه في الواجهة
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '⚠️ تنبيه: تم تجاوز وقت الوصول بساعتين ولم يتم إنشاء طلب جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'تجاهل',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }

    // تحديث حالة الطلب
    setState(() {
      _status = 'تأخير في الوصول';
    });

    // إرسال إشعار إلى السيرفر (للتطبيقات الأخرى)
    _sendDelayNotificationToServer();
  }

  void _cancelOrderBySystem() {
    // تحديث حالة الطلب إلى ملغي تلقائياً
    setState(() {
      _status = 'ملغي - تأخر التحميل';
    });

    // عرض رسالة للمستخدم
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '⚠️ تم إلغاء الطلب تلقائياً بسبب عدم وجود حركة بعد انتهاء وقت التحميل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }

    // إرسال تحديث الحالة إلى السيرفر
    _sendAutoCancelToServer();
  }

  Future<void> _sendDelayNotificationToServer() async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}/orders/delay-alert');

      final response = await http.post(
        url,
        headers: ApiService.headers,
        body: json.encode({
          'orderId': widget.orderToEdit?.id,
          'supplierId': _selectedSupplier?.id,
          'supplierName': _selectedSupplier?.name,
          'arrivalTime': _arrivalTimeController.text,
          'arrivalDate': _arrivalDate.toIso8601String(),
          'message': 'تأخير في الوصول بساعتين',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Delay alert sent to server');
      }
    } catch (e) {
      debugPrint('❌ Error sending delay alert: $e');
    }
  }

  Future<void> _sendAutoCancelToServer() async {
    try {
      final url = Uri.parse('${ApiEndpoints.baseUrl}/orders/auto-cancel');

      final response = await http.post(
        url,
        headers: ApiService.headers,
        body: json.encode({
          'orderId': widget.orderToEdit?.id,
          'supplierId': _selectedSupplier?.id,
          'supplierName': _selectedSupplier?.name,
          'loadingTime': _loadingTimeController.text,
          'loadingDate': _loadingDate.toIso8601String(),
          'cancelReason':
              'تم إلغاء الطلب تلقائياً بسبب عدم وجود حركة بعد انتهاء وقت التحميل',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Auto-cancel notification sent to server');
      }
    } catch (e) {
      debugPrint('❌ Error sending auto-cancel: $e');
    }
  }

  void _initializeFormWithOrder() {
    final order = widget.orderToEdit!;

    _supplierOrderNumberController.text = order.supplierOrderNumber ?? '';
    _quantityController.text = order.quantity?.toString() ?? '';
    _notesController.text = order.notes ?? '';

    _loadingTimeController.text = order.loadingTime ?? '08:00';
    _arrivalTimeController.text = order.arrivalTime ?? '10:00';

    _orderDate = order.orderDate;
    _loadingDate =
        order.loadingDate ?? DateTime.now().add(const Duration(days: 1));
    _arrivalDate =
        order.arrivalDate ?? DateTime.now().add(const Duration(days: 1));

    _status = _supplierStatuses.contains(order.status)
        ? order.status
        : _supplierStatuses.first;

    _fuelType = order.fuelType ?? 'ديزل';
    _unit = order.unit ?? 'لتر';

    // ✅ المنطقة
    if (_saudiRegions.contains(order.area)) {
      _selectedRegion = order.area;
    } else {
      _selectedRegion = null;
    }

    // ✅ المدينة (مربوطة بالمنطقة)
    if (_selectedRegion != null &&
        saudiCities[_selectedRegion!] != null &&
        saudiCities[_selectedRegion!]!.contains(order.city)) {
      _selectedCity = order.city;
    } else {
      _selectedCity = null;
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final supplierProvider = Provider.of<SupplierProvider>(
        context,
        listen: false,
      );
      await supplierProvider.fetchSuppliers();

      setState(() {
        _suppliers = supplierProvider.suppliers
            .where((s) => s.isActive)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final driverProvider = Provider.of<DriverProvider>(
        context,
        listen: false,
      );
      await driverProvider.fetchDrivers();

      setState(() {
        _drivers = driverProvider.drivers.where((d) => d.isActive).toList();
      });
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  Future<void> _pickDate(BuildContext context, String type) async {
    DateTime initialDate;
    switch (type) {
      case 'order':
        initialDate = _orderDate;
        break;
      case 'loading':
        initialDate = _loadingDate;
        break;
      case 'arrival':
        initialDate = _arrivalDate;
        break;
      default:
        initialDate = DateTime.now();
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
        switch (type) {
          case 'order':
            _orderDate = picked;
            break;
          case 'loading':
            _loadingDate = picked;
            break;
          case 'arrival':
            _arrivalDate = picked;
            break;
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext context, String type) async {
    TimeOfDay initialTime;
    TextEditingController controller;

    switch (type) {
      case 'loading':
        initialTime = _parseTime(_loadingTimeController.text);
        controller = _loadingTimeController;
        break;
      case 'arrival':
        initialTime = _parseTime(_arrivalTimeController.text);
        controller = _arrivalTimeController;
        break;
      default:
        initialTime = const TimeOfDay(hour: 8, minute: 0);
        controller = _loadingTimeController;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  TimeOfDay _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
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

  void _removeAttachment(int index) {
    setState(() {
      _newAttachmentPaths.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ مورد مطلوب فقط في حالة الإنشاء
    if (!isEditMode && _selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المورد'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // ✅ وقت افتراضي لو فاضي
    if (_loadingTimeController.text.trim().isEmpty) {
      _loadingTimeController.text = '08:00';
    }
    if (_arrivalTimeController.text.trim().isEmpty) {
      _arrivalTimeController.text = '10:00';
    }

    // ✅ التحقق من صحة الأوقات
    try {
      final loadingParts = _loadingTimeController.text.split(':');
      final arrivalParts = _arrivalTimeController.text.split(':');

      if (loadingParts.length < 2 || arrivalParts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تنسيق الوقت غير صحيح'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      final arrivalDateTime = DateTime(
        _arrivalDate.year,
        _arrivalDate.month,
        _arrivalDate.day,
        int.parse(arrivalParts[0]),
        int.parse(arrivalParts[1]),
      );

      final loadingDateTime = DateTime(
        _loadingDate.year,
        _loadingDate.month,
        _loadingDate.day,
        int.parse(loadingParts[0]),
        int.parse(loadingParts[1]),
      );

      if (!loadingDateTime.isAfter(arrivalDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('وقت التحميل يجب أن يكون بعد وقت الوصول'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في معالجة الأوقات: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ✅ المورد: من الطلب الأصلي في التعديل – من القائمة في الإنشاء
    final Supplier supplier = isEditMode
        ? widget.orderToEdit!.supplier!
        : _suppliers.firstWhere((s) => s.id == _selectedSupplierId);

    final order = Order(
      id: widget.orderToEdit?.id ?? '',
      orderDate: _orderDate,

      supplierId: supplier.id,
      supplierName: supplier.name,
      supplierCompany: supplier.company,
      supplierContactPerson: supplier.contactPerson,
      supplierPhone: supplier.phone,

      requestType: null,
      orderNumber: widget.orderToEdit?.orderNumber ?? '',
      supplierOrderNumber: _supplierOrderNumberController.text.trim().isNotEmpty
          ? _supplierOrderNumberController.text.trim()
          : widget.orderToEdit?.supplierOrderNumber,

      // ⏱ المواعيد
      arrivalDate: _arrivalDate,
      arrivalTime: _arrivalTimeController.text,
      loadingDate: _loadingDate,
      loadingTime: _loadingTimeController.text,

      // 📍 الموقع (ثابت في التعديل)
      area: isEditMode ? widget.orderToEdit!.area : _selectedRegion,
      city: isEditMode ? widget.orderToEdit!.city : _selectedCity,
      address: widget.orderToEdit?.address,

      // 🚚 السائق (مسموح تعديله)
      driverId: _selectedDriverId,
      driverName: _selectedDriver?.name,
      driverPhone: _selectedDriver?.phone,
      vehicleNumber: _selectedDriver?.vehicleNumber,

      // ⛽ الوقود (مسموح تعديله)
      fuelType: _fuelType,
      quantity: _quantityController.text.trim().isNotEmpty
          ? double.tryParse(_quantityController.text.trim())
          : widget.orderToEdit?.quantity,
      unit: _unit,

      // 📝 الحالة والملاحظات
      status: _status,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : widget.orderToEdit?.notes,

      attachments: widget.orderToEdit?.attachments ?? [],
      companyLogo: _companyLogoPath,

      createdById: authProvider.user?.id ?? '',
      createdByName: authProvider.user?.name,

      customer: null,
      createdAt: widget.orderToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),

      orderSource: widget.orderToEdit?.orderSource ?? '',
      mergeStatus: widget.orderToEdit?.mergeStatus ?? '',
    );

    bool success;
    if (isEditMode) {
      success = await orderProvider.updateOrderFull(
        widget.orderToEdit!.id,
        order,
        _newAttachmentPaths,
        null,
        _selectedDriverId,
      );
    } else {
      success = await orderProvider.createOrder(
        order,
        _newAttachmentPaths,
        null,
        _selectedDriverId,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'تم تحديث طلب المورد بنجاح'
                : 'تم إنشاء طلب المورد بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.error ?? 'حدث خطأ أثناء حفظ طلب المورد'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildFieldWithIcon({
    required String label,
    required IconData icon,
    required Color color,
    required Widget child,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Opacity(opacity: enabled ? 1.0 : 0.6, child: child),
      ],
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

  // تحديد إذا كان في وضع الويب/كمبيوتر
  bool get _isDesktop => MediaQuery.of(context).size.width > 800;

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: _isDesktop
          ? _buildDesktopAppBar()
          : AppBar(
              title: Text(
                widget.orderToEdit != null
                    ? 'تعديل طلب المورد'
                    : 'طلب مورد جديد',
                style: const TextStyle(color: Colors.white),
              ),
              centerTitle: true,
            ),
      body: _isDesktop
          ? _buildDesktopLayout(context, orderProvider, screenWidth)
          : _buildMobileLayout(context, orderProvider),
    );
  }

  // ============================================
  // واجهة الجوال
  // ============================================
  Widget _buildMobileLayout(BuildContext context, OrderProvider orderProvider) {
    return FutureBuilder(
      future: Future.wait([_loadSuppliers(), _loadDrivers()]),
      builder: (context, snapshot) {
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSupplierCardMobile(context),
              const SizedBox(height: 16),
              _buildLocationCardMobile(context),
              const SizedBox(height: 16),
              _buildDriverCardMobile(context),
              const SizedBox(height: 16),
              _buildBasicInfoCardMobile(context),
              const SizedBox(height: 16),
              _buildTimesCardMobile(context),
              const SizedBox(height: 16),
              _buildFuelInfoCardMobile(context),
              const SizedBox(height: 16),
              _buildStatusNotesCardMobile(context),
              const SizedBox(height: 16),
              _buildAttachmentsCardMobile(context),
              const SizedBox(height: 32),
              _buildSubmitButton(orderProvider),
              const SizedBox(height: 20),
              if (_status == 'في انتظار عمل طلب جديد') _buildAlertInfoCard(),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // واجهة سطح المكتب
  // ============================================
  Widget _buildDesktopLayout(
    BuildContext context,
    OrderProvider orderProvider,
    double screenWidth,
  ) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.orderToEdit != null
                                ? 'تعديل طلب المورد'
                                : 'طلب مورد جديد',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.orderToEdit != null)
                            Text(
                              widget.orderToEdit!.orderNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.mediumGray,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildDesktopNavItem(
                      icon: Icons.business,
                      title: 'اختيار المورد',
                      isSelected: true,
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.location_on,
                      title: 'موقع المورد',
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.directions_car,
                      title: 'اختيار السائق',
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.info_outline,
                      title: 'معلومات الطلب',
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.access_time,
                      title: 'المواعيد',
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.local_gas_station,
                      title: 'معلومات الوقود',
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.note_outlined,
                      title: 'الحالة والملاحظات',
                    ),
                    const SizedBox(height: 8),
                    _buildDesktopNavItem(
                      icon: Icons.attach_file,
                      title: 'المرفقات',
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.orderToEdit != null
                              ? 'تعديل طلب المورد'
                              : 'طلب مورد جديد',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: orderProvider.isLoading
                              ? null
                              : _submitForm,
                          icon: orderProvider.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            orderProvider.isLoading
                                ? 'جاري الحفظ...'
                                : (widget.orderToEdit != null
                                      ? 'تحديث الطلب'
                                      : 'حفظ الطلب'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildSupplierCardDesktop(context),
                              const SizedBox(height: 24),
                              _buildLocationCardDesktop(context),
                              const SizedBox(height: 24),
                              _buildDriverCardDesktop(context),
                              const SizedBox(height: 24),
                              _buildAttachmentsCardDesktop(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            children: [
                              _buildBasicInfoCardDesktop(context),
                              const SizedBox(height: 24),
                              _buildTimesCardDesktop(context),
                              const SizedBox(height: 24),
                              _buildFuelInfoCardDesktop(context),
                              const SizedBox(height: 24),
                              _buildStatusNotesCardDesktop(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // مكونات الجوال
  // ============================================
  Widget _buildSupplierCardMobile(BuildContext context) {
    final bool enabled = !isEditMode; // ❌ يغلق في التعديل

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختيار المورد',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildFieldWithIcon(
              label: 'المورد',
              icon: Icons.business,
              color: AppColors.primaryBlue,
              enabled: enabled,
              child: IgnorePointer(
                ignoring: !enabled,
                child: DropdownButtonFormField<String>(
                  value: _selectedSupplierId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  hint: const Text('اختر المورد'),
                  items: _suppliers.map((supplier) {
                    return DropdownMenuItem<String>(
                      value: supplier.id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplier.name),
                          Text(
                            supplier.company,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (!enabled) return;
                    setState(() {
                      _selectedSupplierId = value;
                      _selectedSupplier = _suppliers.firstWhere(
                        (s) => s.id == value,
                      );
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCardMobile(BuildContext context) {
    final bool enabled = !isEditMode; // 🔒 يقفل في التعديل

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'موقع المورد',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildFieldWithIcon(
              label: 'المنطقة',
              icon: Icons.location_on,
              color: AppColors.secondaryTeal,
              enabled: enabled,
              child: IgnorePointer(
                ignoring: !enabled,
                child: DropdownButton<String>(
                  value: _saudiRegions.contains(_selectedRegion)
                      ? _selectedRegion
                      : null, // 👈 مهم جدًا

                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('اختر المنطقة'),
                  items: _saudiRegions.map((region) {
                    return DropdownMenuItem(value: region, child: Text(region));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRegion = value;
                      _selectedCity = null; // 👈 مهم
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildFieldWithIcon(
              label: 'المدينة',
              icon: Icons.location_city,
              color: AppColors.secondaryTeal,
              enabled: enabled,
              child: IgnorePointer(
                ignoring: !enabled,
                child: DropdownButton<String>(
                  value:
                      (_selectedRegion != null &&
                          saudiCities[_selectedRegion]?.contains(
                                _selectedCity,
                              ) ==
                              true)
                      ? _selectedCity
                      : null,

                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(
                    _selectedRegion == null
                        ? 'اختر المنطقة أولاً'
                        : 'اختر المدينة',
                  ),
                  items:
                      (_selectedRegion != null &&
                          saudiCities.containsKey(_selectedRegion))
                      ? saudiCities[_selectedRegion]!
                            .map(
                              (city) => DropdownMenuItem<String>(
                                value: city,
                                child: Text(city),
                              ),
                            )
                            .toList()
                      : const [],
                  onChanged: enabled
                      ? (value) {
                          setState(() {
                            _selectedCity = value;
                          });
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختيار السائق',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildFieldWithIcon(
              label: 'السائق',
              icon: Icons.directions_car,
              color: AppColors.infoBlue,
              enabled: true, // ✅ مسموح
              child: DropdownButtonFormField<String>(
                value: _selectedDriverId,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                hint: const Text('اختر السائق'),
                items: _drivers.map((driver) {
                  return DropdownMenuItem<String>(
                    value: driver.id,
                    child: Text(driver.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDriverId = value;
                    _selectedDriver = _drivers.firstWhere((d) => d.id == value);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierNameView() {
    if (!isEditMode || _selectedSupplier == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          const Icon(Icons.business, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedSupplier!.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCardMobile(BuildContext context) {
    final bool enabled = !isEditMode; // ❌ يغلق في التعديل

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الطلب',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // =========================
            // رقم طلب المورد (مغلق)
            // =========================
            _buildFieldWithIcon(
              label: 'رقم طلب المورد',
              icon: Icons.confirmation_number,
              color: AppColors.secondaryTeal,
              enabled: enabled,
              child: CustomTextField(
                controller: _supplierOrderNumberController,
                labelText: 'رقم طلب المورد',
                prefixIcon: Icons.numbers,
                enabled: enabled,
                validator: (value) {
                  if (!enabled) return null; // ✅ لا يتحقق في التعديل
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال رقم طلب المورد';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // تاريخ الطلب (مغلق)
            // =========================
            _buildFieldWithIcon(
              label: 'تاريخ الطلب',
              icon: Icons.calendar_today,
              color: AppColors.successGreen,
              enabled: enabled,
              child: IgnorePointer(
                ignoring: !enabled,
                child: InkWell(
                  onTap: enabled ? () => _pickDate(context, 'order') : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.successGreen.withOpacity(0.05)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy/MM/dd').format(_orderDate)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المواعيد',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ======================
            // الوصول
            // ======================
            Row(
              children: [
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'تاريخ الوصول',
                    icon: Icons.date_range,
                    color: AppColors.infoBlue,
                    enabled: true, // ✅ مسموح
                    child: InkWell(
                      onTap: () => _pickDate(context, 'arrival'),
                      child: _dateBox(_arrivalDate),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'وقت الوصول',
                    icon: Icons.access_time,
                    color: AppColors.infoBlue,
                    enabled: true, // ✅ مسموح
                    child: _timeBox(
                      _arrivalTimeController.text,
                      () => _pickTime(context, 'arrival'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ======================
            // التحميل
            // ======================
            Row(
              children: [
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'تاريخ التحميل',
                    icon: Icons.date_range,
                    color: AppColors.warningOrange,
                    enabled: true, // ✅ مسموح
                    child: InkWell(
                      onTap: () => _pickDate(context, 'loading'),
                      child: _dateBox(_loadingDate),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'وقت التحميل',
                    icon: Icons.access_time,
                    color: AppColors.warningOrange,
                    enabled: true, // ✅ مسموح
                    child: _timeBox(
                      _loadingTimeController.text,
                      () => _pickTime(context, 'loading'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  Widget _dateBox(DateTime date) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.lightGray),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(DateFormat('yyyy/MM/dd').format(date)),
        const Icon(Icons.calendar_today, size: 18),
      ],
    ),
  );

  Widget _timeBox(String time, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(time), const Icon(Icons.access_time, size: 18)],
      ),
    ),
  );

  Widget _buildFuelInfoCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الوقود',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // =========================
            // نوع الوقود (مسموح في التعديل)
            // =========================
            _buildFieldWithIcon(
              label: 'نوع الوقود',
              icon: Icons.local_gas_station,
              color: AppColors.warningOrange,
              enabled: true, // ✅ مسموح دائمًا
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: DropdownButton<String>(
                  value: _fuelType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _fuelTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _fuelType = value!;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // الكمية (مسموح في التعديل)
            // =========================
            _buildFieldWithIcon(
              label: 'الكمية (لتر)',
              icon: Icons.scale,
              color: AppColors.warningOrange,
              enabled: true, // ✅ مسموح دائمًا
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: _quantityController,
                    labelText: 'أدخل الكمية باللتر',
                    prefixIcon: Icons.format_list_numbered,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال الكمية';
                      }
                      if (double.tryParse(value) == null) {
                        return 'يرجى إدخال رقم صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // الكميات المقترحة
                  Text(
                    'كميات مقترحة:',
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedQuantities.map((quantity) {
                      return ChoiceChip(
                        label: Text('$quantity لتر'),
                        selected: _quantityController.text == quantity,
                        onSelected: (selected) {
                          setState(() {
                            _quantityController.text = quantity;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: _quantityController.text == quantity
                              ? Colors.white
                              : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusNotesCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الحالة والملاحظات',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // حالة الطلب
            _buildFieldWithIcon(
              label: 'حالة الطلب',
              icon: Icons.stairs,
              color: AppColors.pendingYellow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.pendingYellow.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: DropdownButton<String>(
                  value: _supplierStatuses.contains(_status) ? _status : null,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _supplierStatuses.map((String value) {
                    Color statusColor;
                    switch (value) {
                      case 'في المستودع':
                        statusColor = Colors.grey;
                        break;
                      case 'تم الإنشاء':
                        statusColor = AppColors.infoBlue;
                        break;
                      case 'في انتظار الدمج':
                        statusColor = Colors.orange;
                        break;
                      case 'تم دمجه مع العميل':
                        statusColor = Colors.purple;
                        break;
                      case 'جاهز للتحميل':
                        statusColor = AppColors.successGreen;
                        break;
                      case 'تم التحميل':
                        statusColor = AppColors.successGreen;
                        break;
                      case 'في الطريق':
                        statusColor = Colors.indigo;
                        break;
                      case 'تم التسليم':
                        statusColor = Colors.teal;
                        break;
                      case 'ملغى':
                        statusColor = AppColors.errorRed;
                        break;
                      default:
                        statusColor = AppColors.mediumGray;
                    }

                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
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
            ),
            const SizedBox(height: 16),
            // الملاحظات
            _buildFieldWithIcon(
              label: 'ملاحظات',
              icon: Icons.note,
              color: AppColors.mediumGray,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _notesController,
                    labelText: 'أدخل ملاحظات إضافية',
                    prefixIcon: Icons.note_add,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  // اقتراحات للملاحظات
                  Text(
                    'اقتراحات للملاحظات:',
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _noteSuggestions.map((note) {
                      return ChoiceChip(
                        label: Text(note),
                        selected: _notesController.text.contains(note),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (_notesController.text.isNotEmpty) {
                                _notesController.text =
                                    '${_notesController.text} - $note';
                              } else {
                                _notesController.text = note;
                              }
                            }
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppColors.secondaryTeal,
                        labelStyle: TextStyle(
                          color: _notesController.text.contains(note)
                              ? Colors.white
                              : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المرفقات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة مرفقات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_newAttachmentPaths.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 48,
                      color: AppColors.mediumGray,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد مرفقات',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'انقر على زر "إضافة مرفقات" لرفع الملفات',
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (_newAttachmentPaths.isNotEmpty)
              Column(
                children: _newAttachmentPaths
                    .asMap()
                    .entries
                    .map(
                      (entry) => AttachmentItem(
                        fileName: entry.value.split('/').last,
                        fileSize: _formatFileSize(entry.value),
                        onDelete: () => _removeAttachment(entry.key),
                        canDelete: true,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'تنبيهات النظام:',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• سيتم إرسال تنبيه إذا تأخر الطلب ساعتين عن وقت الوصول المحدد\n'
            '• سيتم إلغاء الطلب تلقائياً إذا لم يكن هناك حركة بعد نصف ساعة من وقت التحميل',
            style: TextStyle(color: Colors.orange.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(OrderProvider orderProvider) {
    return GradientButton(
      onPressed: orderProvider.isLoading ? null : _submitForm,
      text: orderProvider.isLoading
          ? 'جاري الحفظ...'
          : (widget.orderToEdit != null
                ? 'تحديث طلب المورد'
                : 'حفظ طلب المورد'),
      gradient: AppColors.accentGradient,
      isLoading: orderProvider.isLoading,
    );
  }

  // ============================================
  // مكونات سطح المكتب
  // ============================================

  Widget _buildDesktopNavItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBlue.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBlue.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار المورد',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            _buildFieldWithIcon(
              label: 'المورد',
              icon: Icons.business,
              color: AppColors.primaryBlue,

              // 🔥 هنا القرار
              child: isEditMode
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 18, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedSupplier?.name ??
                                  widget.orderToEdit!.supplierName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  // 🟢 إنشاء فقط
                  : DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      hint: const Text('اختر المورد'),
                      items: _suppliers.map((supplier) {
                        return DropdownMenuItem<String>(
                          value: supplier.id,
                          child: Text(supplier.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplierId = value;
                          _selectedSupplier = _suppliers.firstWhere(
                            (s) => s.id == value,
                          );
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'موقع المورد',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'المنطقة',
                    icon: Icons.location_on,
                    color: AppColors.secondaryTeal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryTeal.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedRegion,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('اختر المنطقة'),
                        items: _saudiRegions
                            .map(
                              (region) => DropdownMenuItem<String>(
                                value: region,
                                child: Text(region),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRegion = value;

                            _selectedCity = null;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'المدينة',
                    icon: Icons.location_city,
                    color: AppColors.secondaryTeal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryTeal.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: Text(
                          _selectedRegion == null
                              ? 'اختر المنطقة أولاً'
                              : 'اختر المدينة',
                        ),

                        // 🟢 المدن مرتبطة بالمنطقة المختارة
                        items: _selectedRegion == null
                            ? []
                            : saudiCities[_selectedRegion]!
                                  .map(
                                    (city) => DropdownMenuItem<String>(
                                      value: city,
                                      child: Text(city),
                                    ),
                                  )
                                  .toList(),

                        onChanged: _selectedRegion == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedCity = value;
                                });
                              },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختيار السائق',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            _buildFieldWithIcon(
              label: 'السائق',
              icon: Icons.directions_car,
              color: AppColors.infoBlue,
              child: DropdownButtonFormField<String>(
                value: _selectedDriverId,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                hint: const Text('اختر السائق'),
                items: _drivers.map((Driver driver) {
                  return DropdownMenuItem<String>(
                    value: driver.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.name, style: const TextStyle(fontSize: 16)),
                        Text(
                          '${driver.phone} - ${driver.vehicleNumber ?? "لا يوجد"}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedDriverId = value;
                    if (value != null) {
                      _selectedDriver = _drivers.firstWhere(
                        (d) => d.id == value,
                      );
                    }
                  });
                },
              ),
            ),
            if (_selectedDriver != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.infoBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppColors.infoBlue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDriver!.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.infoBlue,
                            ),
                          ),
                          Text(
                            'هاتف: ${_selectedDriver!.phone}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_selectedDriver!.vehicleNumber != null)
                            Text(
                              'رقم المركبة: ${_selectedDriver!.vehicleNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDriverId = null;
                          _selectedDriver = null;
                        });
                      },
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.red,
                        size: 24,
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

  Widget _buildBasicInfoCardDesktop(BuildContext context) {
    final bool enabled = !isEditMode;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الطلب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            // رقم طلب المورد
            _buildFieldWithIcon(
              label: 'رقم طلب المورد',
              icon: Icons.confirmation_number,
              color: AppColors.secondaryTeal,
              enabled: enabled,
              child: TextFormField(
                controller: _supplierOrderNumberController,
                enabled: enabled,
                decoration: InputDecoration(
                  filled: !enabled,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // تاريخ الطلب
            _buildFieldWithIcon(
              label: 'تاريخ الطلب',
              icon: Icons.calendar_today,
              color: AppColors.successGreen,
              enabled: enabled,
              child: IgnorePointer(
                ignoring: !enabled,
                child: InkWell(
                  onTap: enabled ? () => _pickDate(context, 'order') : null,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.successGreen.withOpacity(0.05)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(_orderDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المواعيد',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            // الوصول
            Row(
              children: [
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'تاريخ الوصول',
                    icon: Icons.date_range,
                    color: AppColors.infoBlue,
                    child: InkWell(
                      onTap: () => _pickDate(context, 'arrival'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.infoBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy/MM/dd').format(_arrivalDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'وقت الوصول',
                    icon: Icons.access_time,
                    color: AppColors.infoBlue,
                    child: InkWell(
                      onTap: () => _pickTime(context, 'arrival'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.infoBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _arrivalTimeController.text,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.access_time, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // التحميل
            Row(
              children: [
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'تاريخ التحميل',
                    icon: Icons.date_range,
                    color: AppColors.warningOrange,
                    child: InkWell(
                      onTap: () => _pickDate(context, 'loading'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy/MM/dd').format(_loadingDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFieldWithIcon(
                    label: 'وقت التحميل',
                    icon: Icons.access_time,
                    color: AppColors.warningOrange,
                    child: InkWell(
                      onTap: () => _pickTime(context, 'loading'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _loadingTimeController.text,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.access_time, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelInfoCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الوقود',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            // نوع الوقود
            _buildFieldWithIcon(
              label: 'نوع الوقود',
              icon: Icons.local_gas_station,
              color: AppColors.warningOrange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _fuelType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _fuelTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _fuelType = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            // الكمية
            _buildFieldWithIcon(
              label: 'الكمية (لتر)',
              icon: Icons.scale,
              color: AppColors.warningOrange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: _quantityController,
                    labelText: '',
                    prefixIcon: null,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال الكمية';
                      }
                      if (double.tryParse(value) == null) {
                        return 'يرجى إدخال رقم صحيح';
                      }
                      return null;
                    },
                    fieldColor: AppColors.warningOrange.withOpacity(0.05),
                  ),
                  const SizedBox(height: 12),
                  // الكميات المقترحة
                  Text(
                    'كميات مقترحة:',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedQuantities.map((quantity) {
                      return ChoiceChip(
                        label: Text('$quantity لتر'),
                        selected: _quantityController.text == quantity,
                        onSelected: (selected) {
                          setState(() {
                            _quantityController.text = quantity;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: _quantityController.text == quantity
                              ? Colors.white
                              : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusNotesCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الحالة والملاحظات',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            // حالة الطلب
            _buildFieldWithIcon(
              label: 'حالة الطلب',
              icon: Icons.stairs,
              color: AppColors.pendingYellow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.pendingYellow.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _supplierStatuses.contains(_status) ? _status : null,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _supplierStatuses.map((String value) {
                    Color statusColor;
                    switch (value) {
                      case 'في المستودع':
                        statusColor = Colors.grey;
                        break;
                      case 'تم الإنشاء':
                        statusColor = AppColors.infoBlue;
                        break;
                      case 'في انتظار الدمج':
                        statusColor = Colors.orange;
                        break;
                      case 'تم دمجه مع العميل':
                        statusColor = Colors.purple;
                        break;
                      case 'جاهز للتحميل':
                        statusColor = AppColors.successGreen;
                        break;
                      case 'تم التحميل':
                        statusColor = AppColors.successGreen;
                        break;
                      case 'في الطريق':
                        statusColor = Colors.indigo;
                        break;
                      case 'تم التسليم':
                        statusColor = Colors.teal;
                        break;
                      case 'ملغى':
                        statusColor = AppColors.errorRed;
                        break;
                      default:
                        statusColor = AppColors.mediumGray;
                    }

                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
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
            ),
            const SizedBox(height: 20),
            // الملاحظات
            _buildFieldWithIcon(
              label: 'ملاحظات',
              icon: Icons.note,
              color: AppColors.mediumGray,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _notesController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: 'أدخل ملاحظات إضافية هنا...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // اقتراحات للملاحظات
                  Text(
                    'اقتراحات للملاحظات:',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _noteSuggestions.map((note) {
                      return ChoiceChip(
                        label: Text(note),
                        selected: _notesController.text.contains(note),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (_notesController.text.isNotEmpty) {
                                _notesController.text =
                                    '${_notesController.text} - $note';
                              } else {
                                _notesController.text = note;
                              }
                            }
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppColors.secondaryTeal,
                        labelStyle: TextStyle(
                          color: _notesController.text.contains(note)
                              ? Colors.white
                              : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المرفقات',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة مرفقات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_newAttachmentPaths.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد مرفقات',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'انقر على زر "إضافة مرفقات" لرفع الملفات',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (_newAttachmentPaths.isNotEmpty)
              Column(
                children: _newAttachmentPaths
                    .asMap()
                    .entries
                    .map(
                      (entry) => AttachmentItem(
                        fileName: entry.value.split('/').last,
                        fileSize: _formatFileSize(entry.value),
                        onDelete: () => _removeAttachment(entry.key),
                        canDelete: true,
                        isDesktop: true,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
