// customer_order_form_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/saudi_cities.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';

class CustomerOrderFormScreen extends StatefulWidget {
  final Order? orderToEdit;

  const CustomerOrderFormScreen({super.key, this.orderToEdit});

  @override
  State<CustomerOrderFormScreen> createState() =>
      _CustomerOrderFormScreenState();
}

class _CustomerOrderFormScreenState extends State<CustomerOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _customerFilterController =
      TextEditingController();

  DateTime _orderDate = DateTime.now();
  DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1));

  String _status = 'في انتظار إنشاء طلب العميل';
  String _fuelType = 'ديزل';
  String _unit = 'لتر';

  String? _companyLogoPath;
  List<String> _newAttachmentPaths = [];

  Customer? _selectedCustomer;
  String? _selectedCustomerId;

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];

  // إضافة حقلين للمدينة والمنطقة
  String? _selectedCity;
  String? _selectedRegion;

  // إضافة حقول للسائق (لنوع العملية "نقل")
  Driver? _selectedDriver;
  String? _selectedDriverId;
  List<Driver> _drivers = [];
  bool get _isEditMode => widget.orderToEdit != null;

  late final Future<void> _customersFuture;
  late final Future<void> _driversFuture;
  late final Future<void> _initFuture;

  // الكميات المقترحة
  final List<String> _suggestedQuantities = [
    '32000',
    '20000',
    '16000',
    '10000',
    '8000',
    '5000',
    '3000',
    '2000',
    '1000',
  ];

  // أنواع الوقود
  final List<String> _fuelTypes = ['بنزين 91', 'بنزين 95', 'ديزل', 'كيروسين'];

  // حالات الطلب
  // حالات الطلب
  final List<String> _statuses = [
    'في انتظار التخصيص',
    'تم دمجه مع المورد',
    'جاهز للتسليم',
    'قيد التسليم',
    'تم التسليم',
    'ملغى',
  ];

  // للملاحظات
  final List<String> _noteSuggestions = [
    'طلب عادي',
    'طلب عاجل',
    'يوجد دفعة مقدمة',
    'تأكيد من العميل مطلوب',
    'يوجد ملاحظات خاصة',
  ];

  final List<String> _purchaseTypes = ['شراء', 'نقل'];

  String _purchaseType = 'شراء'; // القيمة الافتراضية

  @override
  void initState() {
    super.initState();
    _customersFuture = _loadCustomers();
    _driversFuture = _loadDrivers();
    _initFuture = _initEditMode();
  }

  Future<void> _initEditMode() async {
    await _customersFuture;
    await _driversFuture;

    if (widget.orderToEdit != null) {
      _initializeFormWithOrder();
    }
  }

  PreferredSizeWidget _buildDesktopAppBar() {
    final title = widget.orderToEdit != null
        ? 'تعديل طلب العميل'
        : 'طلب عميل جديد';

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        tooltip: 'رجوع',
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
    );
  }

  void _showCustomerPicker() {
    FocusScope.of(context).unfocus();
    _customerFilterController.clear();

    final Future<void> loadFuture =
        _allCustomers.isNotEmpty ? Future.value() : _customersFuture;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sheetHeight = MediaQuery.of(context).size.height * 0.6;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: sheetHeight,
            child: FutureBuilder<void>(
              future: loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    _allCustomers.isEmpty) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'اختر العميل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const Divider(),
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }

                var modalCustomers = List<Customer>.of(_allCustomers);
                var isRefreshing = false;

                return StatefulBuilder(
                  builder: (context, modalSetState) {
                    void applyFilter(String query) {
                      final value = query.trim().toLowerCase();
                      modalSetState(() {
                        if (value.isEmpty) {
                          modalCustomers = List<Customer>.of(_allCustomers);
                        } else {
                          modalCustomers = _allCustomers.where((customer) {
                            final name = customer.name.toLowerCase();
                            final code = customer.code.toLowerCase();
                            final phone = customer.phone?.toLowerCase() ?? '';
                            return name.contains(value) ||
                                code.contains(value) ||
                                phone.contains(value);
                          }).toList();
                        }
                      });
                    }

                    Future<void> refreshCustomers() async {
                      modalSetState(() => isRefreshing = true);
                      await _loadCustomers();
                      if (!context.mounted) return;
                      modalSetState(() {
                        isRefreshing = false;
                        modalCustomers = List<Customer>.of(_allCustomers);
                      });
                    }

                    return Column(
                      children: [
                        // العنوان
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'اختر العميل',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),

                        const Divider(),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: TextField(
                            controller: _customerFilterController,
                            onChanged: applyFilter,
                            decoration: InputDecoration(
                              hintText: 'بحث عن عميل...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        // القائمة
                        Expanded(
                          child: isRefreshing
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : modalCustomers.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('لا يوجد عملاء'),
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            onPressed: refreshCustomers,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('تحديث'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: modalCustomers.length,
                                      itemBuilder: (context, index) {
                                        final customer = modalCustomers[index];

                                        return ListTile(
                                          leading: CircleAvatar(
                                            child: Text(
                                              customer.name
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                            ),
                                          ),
                                          title: Text(customer.name),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('كود: ${customer.code}'),
                                              if (customer.city != null ||
                                                  customer.area != null)
                                                Text(
                                                  '${customer.city ?? ''} ${customer.area ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.mediumGray,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedCustomer = customer;
                                              _selectedCustomerId = customer.id;
                                              _customerSearchController.text =
                                                  customer.name;

                                              // ✅ تعبئة الموقع تلقائيًا من عنوان العميل
                                              if (customer.area != null &&
                                                  customer.area!.isNotEmpty &&
                                                  customer.city != null &&
                                                  customer.city!.isNotEmpty) {
                                                _selectedRegion = customer.area;
                                                _selectedCity = customer.city;
                                              } else {
                                                // ❗ لو العميل ما عندوش عنوان
                                                _selectedRegion = null;
                                                _selectedCity = null;
                                              }
                                            });

                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _initializeFormWithOrder() {
    final order = widget.orderToEdit!;

    _quantityController.text = order.quantity?.toString() ?? '';
    _notesController.text = order.notes ?? '';

    _orderDate = order.orderDate;
    _arrivalDate =
        order.arrivalDate ?? DateTime.now().add(const Duration(days: 1));

    // ✅ حماية حالة الطلب
    _status = _statuses.contains(order.status) ? order.status : _statuses.first;

    _fuelType = _fuelTypes.contains(order.fuelType) ? order.fuelType! : 'ديزل';

    _unit = order.unit ?? 'لتر';
    _companyLogoPath = order.companyLogo;

    _selectedCustomer = order.customer;
    _selectedCustomerId = order.customer?.id;

    // ✅ حماية نوع العملية
    _purchaseType = _purchaseTypes.contains(order.requestType)
        ? order.requestType!
        : 'شراء';

    // الموقع
    _selectedRegion = order.area;
    _selectedCity = order.city;

    // ✅ السائق (مع حماية)
    _selectedDriverId = order.driverId;
    _selectedDriver = null;

    if (_purchaseType == 'نقل' && order.driverId != null) {
      final exists = _drivers.any((d) => d.id == order.driverId);
      if (exists) {
        _selectedDriver = _drivers.firstWhere((d) => d.id == order.driverId);
      } else {
        _selectedDriverId = null;
      }
    }

    if (_selectedCustomer != null) {
      _customerSearchController.text = _selectedCustomer!.name;
    }

    setState(() {});
  }

  Future<void> _loadCustomers() async {
    try {
      final customerProvider = Provider.of<CustomerProvider>(
        context,
        listen: false,
      );

      await customerProvider.fetchCustomers(fetchAll: true);

      final activeCustomers = customerProvider.customers
          .where((c) => c.isActive)
          .toList();

      if (!mounted) return;
      setState(() {
        _allCustomers = activeCustomers;
        _filteredCustomers = activeCustomers; // في البداية الكل ظاهر
      });
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }
  }

  void _filterCustomers(String query) {
    final value = query.trim().toLowerCase();
    setState(() {
      if (value.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((customer) {
          final name = customer.name.toLowerCase();
          final code = customer.code.toLowerCase();
          final phone = customer.phone?.toLowerCase() ?? '';
          return name.contains(value) ||
              code.contains(value) ||
              phone.contains(value);
        }).toList();
      }
    });
  }

  Future<void> _loadDrivers() async {
    try {
      final driverProvider = Provider.of<DriverProvider>(
        context,
        listen: false,
      );
      await driverProvider.fetchDrivers();

      if (!mounted) return;
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
          case 'arrival':
            _arrivalDate = picked;
            break;
        }
      });
    }
  }

  // void _showRegionPicker(BuildContext context) {
  //   final regions = saudiCities.keys.toList();

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (context) {
  //       return SizedBox(
  //         height: MediaQuery.of(context).size.height * 0.5,
  //         child: Column(
  //           children: [
  //             Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: Text(
  //                 'اختر المنطقة',
  //                 style: TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.bold,
  //                   color: AppColors.primaryBlue,
  //                 ),
  //               ),
  //             ),
  //             const Divider(),

  //             // حقل البحث
  //             Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: TextField(
  //                 decoration: InputDecoration(
  //                   hintText: 'ابحث عن منطقة...',
  //                   prefixIcon: const Icon(Icons.search),
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                 ),
  //                 onChanged: (value) {
  //                   // يمكن إضافة وظيفة البحث هنا إذا لزم
  //                 },
  //               ),
  //             ),

  //             // قائمة المناطق
  //             Expanded(
  //               child: ListView.builder(
  //                 itemCount: regions.length,
  //                 itemBuilder: (context, index) {
  //                   final region = regions[index];
  //                   return ListTile(
  //                     leading: Icon(
  //                       Icons.location_on,
  //                       color: _selectedRegion == region
  //                           ? AppColors.primaryBlue
  //                           : AppColors.mediumGray,
  //                     ),
  //                     title: Text(region),
  //                     trailing: _selectedRegion == region
  //                         ? Icon(Icons.check, color: AppColors.primaryBlue)
  //                         : null,
  //                     onTap: () {
  //                       setState(() {
  //                         _selectedRegion = region;
  //                         _selectedCity =
  //                             null; // إعادة تعيين المدينة عند تغيير المنطقة
  //                       });
  //                       Navigator.pop(context);
  //                     },
  //                   );
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // void _showCityPicker(BuildContext context) {
  //   if (_selectedRegion == null) return;

  //   final cities = saudiCities[_selectedRegion] ?? [];

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (context) {
  //       return SizedBox(
  //         height: MediaQuery.of(context).size.height * 0.5,
  //         child: Column(
  //           children: [
  //             Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: Text(
  //                 'اختر المدينة',
  //                 style: TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.bold,
  //                   color: AppColors.primaryBlue,
  //                 ),
  //               ),
  //             ),
  //             const Divider(),

  //             // حقل البحث
  //             Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: TextField(
  //                 decoration: InputDecoration(
  //                   hintText: 'ابحث عن مدينة...',
  //                   prefixIcon: const Icon(Icons.search),
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                 ),
  //                 onChanged: (value) {
  //                   // يمكن إضافة وظيفة البحث هنا
  //                 },
  //               ),
  //             ),

  //             // قائمة المدن
  //             Expanded(
  //               child: ListView.builder(
  //                 itemCount: cities.length,
  //                 itemBuilder: (context, index) {
  //                   final city = cities[index];
  //                   return ListTile(
  //                     leading: Icon(
  //                       Icons.location_city,
  //                       color: _selectedCity == city
  //                           ? AppColors.primaryBlue
  //                           : AppColors.mediumGray,
  //                     ),
  //                     title: Text(city),
  //                     trailing: _selectedCity == city
  //                         ? Icon(Icons.check, color: AppColors.primaryBlue)
  //                         : null,
  //                     onTap: () {
  //                       setState(() {
  //                         _selectedCity = city;
  //                       });
  //                       Navigator.pop(context);
  //                     },
  //                   );
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

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

    // ===============================
    // ✅ التحقق من اختيار العميل فقط
    // ===============================
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار العميل'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // ===============================
    // ✅ تحديد الموقع بدون أي شرط إجباري
    // ===============================
    final String? finalArea = _selectedCustomer!.area?.isNotEmpty == true
        ? _selectedCustomer!.area
        : _selectedRegion;

    final String? finalCity = _selectedCustomer!.city?.isNotEmpty == true
        ? _selectedCustomer!.city
        : _selectedCity;

    final String customerAddress =
        _selectedCustomer!.address?.isNotEmpty == true
        ? _selectedCustomer!.address!
        : [
            if (finalCity != null) finalCity,
            if (finalArea != null) finalArea,
          ].join(' - ');

    // ===============================
    // ✅ التحقق من السائق فقط لو "نقل"
    // ===============================
    if (_purchaseType == 'نقل' && _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار السائق لنوع العملية "نقل"'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ===============================
    // ✅ إنشاء الطلب (الموقع اختياري)
    // ===============================
    final order = Order(
      id: widget.orderToEdit?.id ?? '',
      orderDate: _orderDate,

      requestType: _purchaseType,
      supplierName: 'طلب عميل',
      orderNumber: widget.orderToEdit?.orderNumber ?? '',
      supplierOrderNumber: null,

      loadingDate: _arrivalDate,
      loadingTime: '08:00',
      arrivalDate: _arrivalDate,
      arrivalTime: '10:00',

      status: _status,

      // 📍 الموقع (بدون إجبار)
      area: finalArea,
      city: finalCity,
      address: customerAddress.isNotEmpty ? customerAddress : null,

      // 🚚 السائق
      driverId: _purchaseType == 'نقل' ? _selectedDriverId : null,
      driverName: _purchaseType == 'نقل' ? _selectedDriver?.name : null,
      driverPhone: _purchaseType == 'نقل' ? _selectedDriver?.phone : null,
      vehicleNumber: _purchaseType == 'نقل'
          ? _selectedDriver?.vehicleNumber
          : null,

      // ⛽ الوقود
      fuelType: _fuelType,
      quantity: _quantityController.text.trim().isNotEmpty
          ? double.tryParse(_quantityController.text.trim())
          : null,
      unit: _unit,

      // 📝 ملاحظات
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,

      companyLogo: _companyLogoPath,
      attachments: [],

      createdById: authProvider.user?.id ?? '',
      createdByName: authProvider.user?.name,
      customer: _selectedCustomer,

      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      orderSource: '',
      mergeStatus: '',
    );

    bool success = false;

    // ===============================
    // ✅ تحديث أو إنشاء
    // ===============================
    if (widget.orderToEdit != null) {
      final updates = order.toJson();

      success = await orderProvider.updateOrderLimited(
        widget.orderToEdit!.id,
        updates,
        _newAttachmentPaths,
      );
    } else {
      success = await orderProvider.createOrder(
        order,
        _newAttachmentPaths,
        _selectedCustomerId,
        _purchaseType == 'نقل' ? _selectedDriverId : null,
      );
    }

    // ===============================
    // ✅ النتيجة
    // ===============================
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.orderToEdit != null
                ? 'تم تحديث طلب العميل بنجاح'
                : 'تم إنشاء طلب العميل بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.error ?? 'حدث خطأ أثناء حفظ الطلب'),
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

  Widget _buildLocationField({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback? onTap,
    bool disabled = false,
    bool isDesktop = false,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: isDesktop
            ? const EdgeInsets.all(16)
            : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.backgroundGray
              : AppColors.secondaryTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? AppColors.lightGray
                : AppColors.secondaryTeal.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isDesktop ? 24 : 20,
              color: disabled ? AppColors.mediumGray : AppColors.secondaryTeal,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      color: disabled
                          ? AppColors.mediumGray
                          : AppColors.secondaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'غير متوفر',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color: value == null
                          ? AppColors.mediumGray
                          : Colors.black,
                      fontWeight: value == null
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!disabled)
              Icon(
                Icons.arrow_drop_down,
                color: AppColors.secondaryTeal,
                size: isDesktop ? 24 : 20,
              ),
          ],
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

  // ============================================
  // مكونات خاصة بالسائق (نوع العملية "نقل")
  // ============================================
  Widget _buildDriverCardMobile(BuildContext context) {
    if (_purchaseType != 'نقل') return const SizedBox();

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
              child: DropdownButtonFormField<String>(
                value:
                    (_purchaseType == 'نقل' &&
                        _selectedDriverId != null &&
                        _drivers.any((d) => d.id == _selectedDriverId))
                    ? _selectedDriverId
                    : null,

                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                hint: const Text('اختر السائق'),

                items: _drivers.map((Driver driver) {
                  return DropdownMenuItem<String>(
                    value: driver.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${driver.phone} - ${driver.vehicleNumber ?? "لا يوجد"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                onChanged: _purchaseType == 'نقل'
                    ? (String? value) {
                        setState(() {
                          _selectedDriverId = value;
                          _selectedDriver = value == null
                              ? null
                              : _drivers.firstWhere(
                                  (d) => d.id == value,
                                  orElse: () => _drivers.first,
                                );
                        });
                      }
                    : null,

                validator: _purchaseType == 'نقل'
                    ? (value) {
                        if (value == null) {
                          return 'يرجى اختيار السائق';
                        }
                        return null;
                      }
                    : null,
              ),
            ),
            if (_selectedDriver != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.infoBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppColors.infoBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDriver!.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.infoBlue,
                            ),
                          ),
                          Text(
                            'هاتف: ${_selectedDriver!.phone}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                          if (_selectedDriver!.vehicleNumber != null)
                            Text(
                              'رقم المركبة: ${_selectedDriver!.vehicleNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGray,
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
                      icon: const Icon(Icons.clear, color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCardDesktop(BuildContext context) {
    if (_purchaseType != 'نقل') return const SizedBox();

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
                value:
                    (_purchaseType == 'نقل' &&
                        _selectedDriverId != null &&
                        _drivers.any((d) => d.id == _selectedDriverId))
                    ? _selectedDriverId
                    : null,

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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

                onChanged: _purchaseType == 'نقل'
                    ? (String? value) {
                        setState(() {
                          _selectedDriverId = value;
                          _selectedDriver = value == null
                              ? null
                              : _drivers.firstWhere(
                                  (d) => d.id == value,
                                  orElse: () => _drivers.first,
                                );
                        });
                      }
                    : null,

                validator: _purchaseType == 'نقل'
                    ? (value) {
                        if (value == null) {
                          return 'يرجى اختيار السائق';
                        }
                        return null;
                      }
                    : null,
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

  // تحديد إذا كان في وضع الويب/كمبيوتر
  bool get _isDesktop => MediaQuery.of(context).size.width > 800;

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final content = _isDesktop
        ? _buildDesktopLayout(context, orderProvider, screenWidth)
        : _buildMobileLayout(context, orderProvider);

    return Scaffold(
      appBar: _buildDesktopAppBar(),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Positioned.fill(child: content),
        ],
      ),
    );
  }

  // ============================================
  // واجهة الجوال
  // ============================================
  Widget _buildMobileLayout(BuildContext context, OrderProvider orderProvider) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1️⃣ اختيار العميل
              _buildCustomerCardMobile(context),
              const SizedBox(height: 16),

              // 2️⃣ نوع عملية العميل (شراء / نقل)
              if (_selectedCustomer != null) ...[
                _buildPurchaseTypeCardMobile(context),
                const SizedBox(height: 16),
              ],

              // 3️⃣ اختيار السائق (يظهر فقط إذا كان النوع "نقل")
              _buildDriverCardMobile(context),
              if (_purchaseType == 'نقل') const SizedBox(height: 16),

              // 4️⃣ موقع العميل
              if (_selectedCustomer != null) ...[
                _buildLocationCardMobile(context),
                const SizedBox(height: 16),
              ],

              // 5️⃣ معلومات الطلب
              _buildOrderInfoCardMobile(context),
              const SizedBox(height: 16),

              // 6️⃣ معلومات الوقود
              _buildFuelInfoCardMobile(context),
              const SizedBox(height: 16),

              // 7️⃣ تاريخ الوصول
              _buildArrivalDateCardMobile(context),
              const SizedBox(height: 16),

              // 8️⃣ الحالة والملاحظات
              _buildStatusNotesCardMobile(context),
              const SizedBox(height: 16),

              // 9️⃣ المرفقات
              _buildAttachmentsCardMobile(context),
              const SizedBox(height: 32),

              // 🔟 زر الحفظ
              _buildSubmitButton(orderProvider),
              const SizedBox(height: 20),
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= LEFT COLUMN =================
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomerCardDesktop(context),
                          const SizedBox(height: 24),

                          if (_selectedCustomer != null) ...[
                            _buildPurchaseTypeCardDesktop(context),
                            const SizedBox(height: 24),
                          ],

                          // ✅ بطاقة السائق تظهر فقط إذا كان النوع "نقل"
                          _buildDriverCardDesktop(context),
                          if (_purchaseType == 'نقل')
                            const SizedBox(height: 24),

                          if (_selectedCustomer != null) ...[
                            _buildLocationCardDesktop(context),
                            const SizedBox(height: 24),
                          ],
                          _buildCustomerAddressPreview(),
                          const SizedBox(height: 12),

                          _buildOrderInfoCardDesktop(context),
                          const SizedBox(height: 24),

                          _buildArrivalDateCardDesktop(context),
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // ================= RIGHT COLUMN =================
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFuelInfoCardDesktop(context),
                          const SizedBox(height: 24),

                          _buildStatusNotesCardDesktop(context),
                          const SizedBox(height: 24),

                          _buildAttachmentsCardDesktop(context),
                          const SizedBox(height: 32),

                          // ✅ زر الحفظ / الإنشاء
                          _buildSubmitButton(orderProvider),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // مكونات الجوال
  // ============================================
  Widget _buildCustomerCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختيار العميل',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_selectedCustomer != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _selectedCustomer!.name
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCustomer!.name,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'كود: ${_selectedCustomer!.code}',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 12,
                                ),
                              ),
                              if (_selectedCustomer!.phone != null)
                                Text(
                                  'هاتف: ${_selectedCustomer!.phone!}',
                                  style: TextStyle(
                                    color: AppColors.mediumGray,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedCustomer = null;
                              _selectedCustomerId = null;
                              _customerSearchController.clear();
                              _customerFilterController.clear();
                              _filteredCustomers = _allCustomers;
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showCustomerPicker,
                icon: const Icon(Icons.people_alt_outlined),
                label: Text(
                  _selectedCustomer == null
                      ? 'عرض العملاء واختيار عميل'
                      : 'تغيير العميل',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCustomer == null
                  ? 'اضغط لعرض قائمة العملاء على الجوال واختيار العميل المطلوب.'
                  : 'يمكنك تغيير العميل الحالي من نفس الزر.',
              style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseTypeCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نوع عملية العميل',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildFieldWithIcon(
              label: 'نوع العملية',
              icon: Icons.swap_horiz,
              color: AppColors.primaryBlue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: DropdownButton<String>(
                  value: _purchaseTypes.contains(_purchaseType)
                      ? _purchaseType
                      : null,

                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('اختر نوع العملية'),

                  items: _purchaseTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            type == 'شراء'
                                ? Icons.shopping_cart
                                : Icons.local_shipping,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 10),
                          Text(type),
                        ],
                      ),
                    );
                  }).toList(),

                  onChanged: (String? value) {
                    if (value == null) return;

                    setState(() {
                      _purchaseType = value;

                      // ✅ عند التحويل إلى "شراء" يتم تصفير السائق بالكامل
                      if (_purchaseType == 'شراء') {
                        _selectedDriverId = null;
                        _selectedDriver = null;
                      }
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

  Widget _buildPurchaseTypeCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نوع عملية العميل',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            _buildFieldWithIcon(
              label: 'نوع العملية',
              icon: Icons.swap_horiz,
              color: AppColors.primaryBlue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _purchaseTypes.contains(_purchaseType)
                      ? _purchaseType
                      : _purchaseTypes.first,

                  isExpanded: true,
                  underline: const SizedBox(),

                  items: _purchaseTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            type == 'شراء'
                                ? Icons.shopping_cart
                                : Icons.local_shipping,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 10),
                          Text(type),
                        ],
                      ),
                    );
                  }).toList(),

                  onChanged: (String? value) {
                    if (value == null) return;

                    setState(() {
                      _purchaseType = value;

                      // ✅ عند التحويل إلى "شراء" نحذف السائق نهائيًا
                      if (_purchaseType == 'شراء') {
                        _selectedDriverId = null;
                        _selectedDriver = null;
                      }
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
    if (_selectedCustomer == null) return const SizedBox();

    final customer = _selectedCustomer!;

    // 🔹 تكوين العنوان التفصيلي
    final List<String> locationParts = [];

    if (customer.city?.isNotEmpty == true) {
      locationParts.add(customer.city!);
    }

    if (customer.area?.isNotEmpty == true) {
      locationParts.add(customer.area!);
    }

    if (customer.address?.isNotEmpty == true) {
      locationParts.add(customer.address!);
    }

    final String fullAddress = locationParts.isNotEmpty
        ? locationParts.join(' - ')
        : 'لا يوجد عنوان مسجل للعميل';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'موقع العميل',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 📍 العنوان التفصيلي (عرض فقط)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondaryTeal.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.secondaryTeal,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fullAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 🛈 توضيح صغير
            Text(
              'العنوان مأخوذ تلقائيًا من ملف العميل',
              style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAddressPreview() {
    if (_selectedCustomer == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.home, color: AppColors.mediumGray),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedCustomer!.address?.isNotEmpty == true
                  ? _selectedCustomer!.address!
                  : 'لا يوجد عنوان مسجل للعميل',
              style: TextStyle(fontSize: 14, color: AppColors.mediumGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCardMobile(BuildContext context) {
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

            // تاريخ الطلب
            _buildFieldWithIcon(
              label: 'تاريخ الطلب',
              icon: Icons.calendar_today,
              color: AppColors.successGreen,
              child: InkWell(
                onTap: () => _pickDate(context, 'order'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGray),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy/MM/dd').format(_orderDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: DropdownButton<String>(
                  value: _fuelTypes.contains(_fuelType) ? _fuelType : null,

                  isExpanded: true,
                  underline: const SizedBox(),

                  hint: const Text('اختر نوع الوقود'),

                  items: _fuelTypes.map((String fuel) {
                    return DropdownMenuItem<String>(
                      value: fuel,
                      child: Text(fuel),
                    );
                  }).toList(),

                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() {
                      _fuelType = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // الكمية
            _buildFieldWithIcon(
              label: 'الكمية (لتر)',
              icon: Icons.scale,
              color: AppColors.warningOrange,
              child: Column(
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

  Widget _buildArrivalDateCardMobile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تاريخ وصول الوقود للعميل',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildFieldWithIcon(
              label: 'تاريخ الوصول المتوقع',
              icon: Icons.date_range,
              color: AppColors.infoBlue,
              child: InkWell(
                onTap: () => _pickDate(context, 'arrival'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGray),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy/MM/dd').format(_arrivalDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'هذا هو التاريخ المتوقع لوصول الوقود للعميل',
              style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
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
                  value: (_status != null && _statuses.contains(_status))
                      ? _status
                      : null,

                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('اختر حالة الطلب'),

                  items: _statuses.map((String value) {
                    Color statusColor;

                    switch (value) {
                      case 'في انتظار التخصيص':
                        statusColor = Colors.orange;
                        break;
                      case 'تم دمجه مع المورد':
                        statusColor = AppColors.infoBlue;
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

                  onChanged: (String? value) {
                    if (value == null) return;

                    setState(() {
                      _status = value;
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

  Widget _buildSubmitButton(OrderProvider orderProvider) {
    return GradientButton(
      onPressed: orderProvider.isLoading ? null : _submitForm,
      text: orderProvider.isLoading
          ? 'جاري الحفظ...'
          : (widget.orderToEdit != null
                ? 'تحديث طلب العميل'
                : 'حفظ طلب العميل'),
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

  Widget _buildCustomerCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختيار العميل',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedCustomer != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _selectedCustomer!.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCustomer!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'كود: ${_selectedCustomer!.code}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          if (_selectedCustomer!.phone != null)
                            Text(
                              'هاتف: ${_selectedCustomer!.phone!}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip: 'إزالة العميل',
                      onPressed: () {
                        setState(() {
                          _selectedCustomer = null;
                          _selectedCustomerId = null;
                          _customerSearchController.clear();
                          _customerFilterController.clear();

                          // 🔑 المهم جدًا
                          _filteredCustomers = _allCustomers;
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

            // قائمة العملاء للاختيار
            if (_selectedCustomer == null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 420),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _customerFilterController,
                        onChanged: _filterCustomers,
                        decoration: InputDecoration(
                          hintText: 'بحث عن عميل...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.appBarWaterBright,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                customer.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                            title: Text(customer.name),
                            subtitle: Text('كود: ${customer.code}'),
                            onTap: () {
                              setState(() {
                                _selectedCustomer = customer;
                                _selectedCustomerId = customer.id;
                                _customerSearchController.text = customer.name;
                              });
                            },
                          );
                        },
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

  Widget _buildLocationCardDesktop(BuildContext context) {
    if (_selectedCustomer == null) return const SizedBox();

    final customer = _selectedCustomer!;

    final List<String> locationParts = [];

    if (customer.city?.isNotEmpty == true) {
      locationParts.add(customer.city!);
    }

    if (customer.area?.isNotEmpty == true) {
      locationParts.add(customer.area!);
    }

    if (customer.address?.isNotEmpty == true) {
      locationParts.add(customer.address!);
    }

    final String fullAddress = locationParts.isNotEmpty
        ? locationParts.join(' - ')
        : 'لا يوجد عنوان مسجل للعميل';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'موقع العميل',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondaryTeal.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.secondaryTeal,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fullAddress,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Text(
              'العنوان مأخوذ تلقائيًا من ملف العميل',
              style: TextStyle(fontSize: 13, color: AppColors.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الطلب',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            // تاريخ الطلب
            _buildFieldWithIcon(
              label: 'تاريخ الطلب',
              icon: Icons.calendar_today,
              color: AppColors.successGreen,
              child: InkWell(
                onTap: () => _pickDate(context, 'order'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.05),
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
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
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
                  value: _fuelTypes.contains(_fuelType) ? _fuelType : null,

                  isExpanded: true,
                  underline: const SizedBox(),

                  hint: const Text('اختر نوع الوقود'),

                  items: _fuelTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),

                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() {
                      _fuelType = value;
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

  Widget _buildArrivalDateCardDesktop(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تاريخ وصول الوقود للعميل',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            _buildFieldWithIcon(
              label: 'تاريخ الوصول المتوقع',
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
            const SizedBox(height: 8),
            Text(
              'هذا هو التاريخ المتوقع لوصول الوقود للعميل',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                  value: _statuses.contains(_status) ? _status : null,

                  isExpanded: true,
                  underline: const SizedBox(),

                  hint: const Text('اختر حالة الطلب'),

                  items: _statuses.map((String value) {
                    Color statusColor;
                    switch (value) {
                      case 'في انتظار التخصيص':
                        statusColor = Colors.orange;
                        break;
                      case 'تم دمجه مع المورد':
                        statusColor = AppColors.infoBlue;
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

                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() {
                      _status = value;
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
