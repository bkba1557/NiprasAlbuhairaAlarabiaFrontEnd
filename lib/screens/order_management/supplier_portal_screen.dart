import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/notification_bell.dart';
import 'package:provider/provider.dart';

class SupplierPortalScreen extends StatefulWidget {
  const SupplierPortalScreen({super.key});

  @override
  State<SupplierPortalScreen> createState() => _SupplierPortalScreenState();
}

class _SupplierPortalScreenState extends State<SupplierPortalScreen> {
  static const String _carrierName = 'شركة البحيرة العربية';
  static const List<String> _fuelTypes = <String>[
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
  ];
  static const Set<String> _reviewRoles = <String>{
    'movement',
    'owner',
    'admin',
    'manager',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _supplierOrderNumberController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _loadingTimeController = TextEditingController(
    text: '08:00',
  );
  final TextEditingController _arrivalTimeController = TextEditingController(
    text: '10:00',
  );

  DateTime _orderDate = DateTime.now();
  DateTime _loadingDate = DateTime.now();
  DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1));
  String _fuelType = 'ديزل';
  String _carrierValue = _carrierName;
  String? _selectedCustomerId;
  String? _selectedStationId;
  PlatformFile? _document;

  bool _booting = true;
  bool _refreshing = false;
  bool _submitting = false;
  bool _autofilling = false;
  bool _actionBusy = false;
  String? _busyOrderId;
  String _busyMessage = 'جاري التحميل...';

  List<Customer> _customers = const <Customer>[];
  List<Station> _stations = const <Station>[];
  List<Driver> _drivers = const <Driver>[];
  List<Order> _orders = const <Order>[];

  bool get _isSupplierRole =>
      context.read<AuthProvider>().user?.role == 'supplier';

  bool get _canReviewSupplierOrders =>
      _reviewRoles.contains(context.read<AuthProvider>().user?.role);

  bool get _canAccessPortal => _isSupplierRole || _canReviewSupplierOrders;

  String? get _linkedSupplierId => context.read<AuthProvider>().supplierId;

  Customer? get _selectedCustomer {
    for (final customer in _customers) {
      if (customer.id == _selectedCustomerId) {
        return customer;
      }
    }
    return null;
  }

  List<Order> get _portalOrders {
    final items = _orders.where((order) => order.isSupplierPortalOrder).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<Order> get _pendingOrders => _portalOrders
      .where(
        (order) =>
            (order.portalStatus == null ||
                order.portalStatus == 'pending_review') &&
            !_isFinalPortalState(order),
      )
      .toList();

  List<Order> get _historyOrders => _portalOrders;

  List<Station> get _availableStationsForCustomer {
    final customer = _selectedCustomer;
    if (customer == null || customer.supplierStationIds.isEmpty) {
      return const <Station>[];
    }
    final allowedIds = customer.supplierStationIds.toSet();
    final stations = _stations
        .where((station) => allowedIds.contains(station.id))
        .toList();
    stations.sort((a, b) => a.stationName.compareTo(b.stationName));
    return stations;
  }

  int get _approvedCount =>
      _portalOrders.where((order) => order.portalStatus == 'approved').length;

  int get _rejectedCount =>
      _portalOrders.where((order) => order.portalStatus == 'rejected').length;

  int get _inTransitCount => _portalOrders
      .where(
        (order) =>
            order.status == 'جاهز للتحميل' ||
            order.status == 'تم التحميل' ||
            order.status == 'في الطريق' ||
            order.status == 'تم التسليم',
      )
      .length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _supplierOrderNumberController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _loadingTimeController.dispose();
    _arrivalTimeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final startedAt = DateTime.now();
    final customerProvider = context.read<CustomerProvider>();
    final stationProvider = context.read<StationProvider>();
    final driverProvider = context.read<DriverProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    await Future.wait<void>(<Future<void>>[
      customerProvider.fetchCustomers(fetchAll: true),
      stationProvider.fetchStations(limit: 0),
      notificationProvider.fetchNotifications(),
    ]);

    final drivers = _canReviewSupplierOrders
        ? await driverProvider.fetchActiveDrivers()
        : const <Driver>[];
    await _loadOrders(showLoader: false);

    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < const Duration(seconds: 3)) {
      await Future<void>.delayed(const Duration(seconds: 3) - elapsed);
    }

    if (!mounted) return;
    setState(() {
      _customers = List<Customer>.from(customerProvider.customers)
        ..sort((a, b) => a.name.compareTo(b.name));
      _stations = List<Station>.from(stationProvider.stations)
        ..sort((a, b) => a.stationName.compareTo(b.stationName));
      _drivers = List<Driver>.from(drivers)
        ..sort((a, b) => a.name.compareTo(b.name));
      _booting = false;
    });
  }

  Future<void> _loadOrders({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _refreshing = true);
    }

    const int pageSize = 100;
    final orders = <Order>[];
    for (var page = 1; page <= 25; page++) {
      final batch = await context.read<OrderProvider>().fetchOrdersSnapshot(
        page: page,
        filters: <String, dynamic>{
          'entryChannel': 'supplier_portal',
          'orderSource': 'مورد',
          'limit': pageSize,
        },
      );
      if (batch.isEmpty) break;
      orders.addAll(batch.where((order) => order.isSupplierPortalOrder));
      if (batch.length < pageSize) break;
    }

    if (!mounted) return;
    setState(() {
      _orders = orders..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _refreshing = false;
    });
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  double? _quantityValue(dynamic value) {
    final raw = _text(value);
    if (raw == null) return null;
    final normalized = raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized);
  }

  DateTime? _dateValue(dynamic value) {
    final raw = _text(value);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  String? _timeValue(dynamic value) {
    final raw = _text(value);
    if (raw == null) return null;
    final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(raw);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null || minutes == null) return null;
    if (hours > 23 || minutes > 59) return null;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه');
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    await _handlePickedFile(result.files.single);
  }

  Future<void> _handlePickedFile(PlatformFile file) async {
    setState(() {
      _document = file;
      _autofilling = true;
      _busyMessage = 'جاري قراءة الملف وتعبئة الطلب تلقائياً...';
    });

    try {
      final data = await context
          .read<OrderProvider>()
          .extractSupplierOrderDraftFromDocument(file: file);
      if (!mounted) return;

      final draft = data?['draft'];
      final suggestedLocation = data?['suggestedLocation'];
      if (draft is! Map) {
        _showSnack(
          context.read<OrderProvider>().error ?? 'تعذر استخراج بيانات الطلب من الملف',
          AppColors.errorRed,
        );
        return;
      }

      final mapDraft = Map<String, dynamic>.from(draft);
      var changed = 0;
      setState(() {
        final supplierOrderNumber = _text(mapDraft['supplierOrderNumber']);
        if (supplierOrderNumber != null) {
          _supplierOrderNumberController.text = supplierOrderNumber;
          changed += 1;
        }

        final quantity = _quantityValue(mapDraft['quantity']);
        if (quantity != null) {
          _quantityController.text = quantity.toStringAsFixed(
            quantity.truncateToDouble() == quantity ? 0 : 2,
          );
          changed += 1;
        }

        final notes = _text(mapDraft['notes']);
        if (notes != null) {
          _notesController.text = notes;
          changed += 1;
        }

        final city = _text(mapDraft['city']) ?? _text(suggestedLocation?['city']);
        if (city != null) {
          _cityController.text = city;
          changed += 1;
        }

        final area = _text(mapDraft['region'] ?? mapDraft['area']) ??
            _text(suggestedLocation?['area']);
        if (area != null) {
          _areaController.text = area;
          changed += 1;
        }

        final orderDate = _dateValue(mapDraft['orderDate']);
        if (orderDate != null) {
          _orderDate = orderDate;
          changed += 1;
        }

        final loadingDate = _dateValue(mapDraft['loadingDate']);
        if (loadingDate != null) {
          _loadingDate = loadingDate;
          changed += 1;
        }

        final arrivalDate = _dateValue(mapDraft['arrivalDate']);
        if (arrivalDate != null) {
          _arrivalDate = arrivalDate;
          changed += 1;
        }

        final loadingTime = _timeValue(mapDraft['loadingTime']);
        if (loadingTime != null) {
          _loadingTimeController.text = loadingTime;
          changed += 1;
        }

        final arrivalTime = _timeValue(mapDraft['arrivalTime']);
        if (arrivalTime != null) {
          _arrivalTimeController.text = arrivalTime;
          changed += 1;
        }

        final normalizedFuel = _normalize(_text(mapDraft['fuelType']) ?? '');
        if (normalizedFuel.isNotEmpty) {
          if (normalizedFuel.contains('95') || normalizedFuel.contains('ممتاز')) {
            _fuelType = 'بنزين 95';
            changed += 1;
          } else if (normalizedFuel.contains('91')) {
            _fuelType = 'بنزين 91';
            changed += 1;
          } else if (normalizedFuel.contains('كيروسين')) {
            _fuelType = 'كيروسين';
            changed += 1;
          } else if (normalizedFuel.contains('ديزل') ||
              normalizedFuel.contains('سولار')) {
            _fuelType = 'ديزل';
            changed += 1;
          }
        }
      });

      _showSnack(
        changed == 0
            ? 'تم رفع الملف لكن لم يتم العثور على بيانات كافية للتعبئة التلقائية'
            : 'تمت تعبئة $changed حقلاً من الملف',
        changed == 0 ? AppColors.warningOrange : AppColors.successGreen,
      );
    } finally {
      if (mounted) {
        setState(() => _autofilling = false);
      }
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final customer = _selectedCustomer;
    final station = _availableStationsForCustomer
        .where((item) => item.id == _selectedStationId)
        .cast<Station?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final quantity = double.tryParse(_quantityController.text.trim());

    if (customer == null) {
      _showSnack('اختر الجهة المرتبطة بالمورد أولاً', AppColors.errorRed);
      return;
    }
    if (station == null) {
      _showSnack('اختر محطة التفريغ الخاصة بهذه الجهة', AppColors.errorRed);
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showSnack('أدخل الكمية بشكل صحيح', AppColors.errorRed);
      return;
    }
    if (_document == null) {
      _showSnack('أرفق ملف الطلب قبل الإرسال', AppColors.errorRed);
      return;
    }

    setState(() {
      _submitting = true;
      _busyMessage = 'جاري إرسال الطلب إلى الحركة للمراجعة...';
    });

    final auth = context.read<AuthProvider>();
    final order = Order(
      id: '',
      orderDate: _orderDate,
      orderSource: 'مورد',
      mergeStatus: 'منفصل',
      entryChannel: 'supplier_portal',
      supplierName: auth.user?.supplierName ?? auth.user?.company ?? '',
      orderNumber: '',
      supplierOrderNumber: _supplierOrderNumberController.text.trim().isEmpty
          ? null
          : _supplierOrderNumberController.text.trim(),
      loadingDate: _loadingDate,
      loadingTime: _loadingTimeController.text.trim(),
      arrivalDate: _arrivalDate,
      arrivalTime: _arrivalTimeController.text.trim(),
      status: 'تم الإنشاء',
      supplierId: auth.supplierId,
      fuelType: _fuelType,
      quantity: quantity,
      unit: 'لتر',
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      city: station.city.isNotEmpty ? station.city : _cityController.text.trim(),
      area: station.stationName.isNotEmpty
          ? station.stationName
          : _areaController.text.trim(),
      address: station.location.isNotEmpty
          ? station.location
          : '${_cityController.text.trim()} - ${_areaController.text.trim()}',
      attachments: const <Attachment>[],
      createdById: auth.user?.id ?? '',
      createdByName: auth.user?.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      portalCustomerId: customer.id,
      portalCustomerName: customer.name,
      destinationStationId: station.id,
      destinationStationName: station.stationName,
      carrierName: _carrierValue,
    );

    final success = await context.read<OrderProvider>().createOrder(
      order,
      <Object>[_document!],
      null,
      null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!success) {
      _showSnack(
        context.read<OrderProvider>().error ?? 'تعذر إرسال الطلب',
        AppColors.errorRed,
      );
      return;
    }

    _resetForm();
    await _loadOrders(showLoader: false);
    _showSnack(
      'تم إرسال الطلب وبقي تحت المراجعة حتى اعتماد الحركة',
      AppColors.successGreen,
    );
  }

  void _resetForm() {
    setState(() {
      _supplierOrderNumberController.clear();
      _quantityController.clear();
      _notesController.clear();
      _cityController.clear();
      _areaController.clear();
      _loadingTimeController.text = '08:00';
      _arrivalTimeController.text = '10:00';
      _orderDate = DateTime.now();
      _loadingDate = DateTime.now();
      _arrivalDate = DateTime.now().add(const Duration(days: 1));
      _fuelType = 'ديزل';
      _carrierValue = _carrierName;
      _selectedCustomerId = null;
      _selectedStationId = null;
      _document = null;
    });
  }

  void _handleCustomerChanged(String? value) {
    setState(() {
      _selectedCustomerId = value;
      _selectedStationId = null;
    });
  }

  void _handleStationChanged(String? value) {
    setState(() {
      _selectedStationId = value;
      final station = _availableStationsForCustomer
          .where((item) => item.id == value)
          .cast<Station?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (station != null) {
        _cityController.text = station.city;
        _areaController.text = station.stationName;
      }
    });
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onChanged,
    DateTime? firstDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ar'),
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onChanged(picked);
  }

  Future<void> _pickTime({required TextEditingController controller}) async {
    final initial = _parseTime(controller.text) ??
        const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    return TimeOfDay(
      hour: int.tryParse(match.group(1)!) ?? 8,
      minute: int.tryParse(match.group(2)!) ?? 0,
    );
  }

  bool _isFinalPortalState(Order order) {
    return order.portalStatus == 'approved' || order.portalStatus == 'rejected';
  }

  String _portalStatusLabel(Order order) {
    switch (order.portalStatus) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'تحت المراجعة';
    }
  }

  Color _portalStatusColor(Order order) {
    switch (order.portalStatus) {
      case 'approved':
        return AppColors.successGreen;
      case 'rejected':
        return AppColors.errorRed;
      default:
        return AppColors.warningOrange;
    }
  }

  Future<void> _showOrderDetails(Order order) async {
    final provider = context.read<OrderProvider>();
    setState(() {
      _busyOrderId = order.id;
      _actionBusy = true;
      _busyMessage = 'جاري تحميل تفاصيل الطلب...';
    });

    await provider.fetchOrderById(order.id, silent: true);

    if (!mounted) return;
    final detailedOrder = provider.selectedOrder ?? order;
    final activities = List<Activity>.from(provider.activities);

    setState(() {
      _actionBusy = false;
      _busyOrderId = null;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.82,
            maxChildSize: 0.94,
            minChildSize: 0.5,
            expand: false,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'تفاصيل الطلب',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _detailChip(
                        label: 'المراجعة',
                        value: _portalStatusLabel(detailedOrder),
                        color: _portalStatusColor(detailedOrder),
                      ),
                      _detailChip(
                        label: 'الناقل',
                        value: detailedOrder.carrierName ?? _carrierName,
                        color: AppColors.primaryBlue,
                      ),
                      if ((detailedOrder.destinationStationName ?? '').isNotEmpty)
                        _detailChip(
                          label: 'المحطة',
                          value: detailedOrder.destinationStationName!,
                          color: AppColors.secondaryTeal,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoSection(
                    title: 'بيانات الطلب',
                    children: <Widget>[
                      _infoRow(
                        'رقم الطلب',
                        detailedOrder.orderNumber.isEmpty
                            ? '-'
                            : detailedOrder.orderNumber,
                      ),
                      _infoRow(
                        'رقم طلب المورد',
                        detailedOrder.supplierOrderNumber ?? '-',
                      ),
                      _infoRow('المورد', detailedOrder.supplierName),
                      _infoRow(
                        'الجهة',
                        detailedOrder.portalCustomerName ?? '-',
                      ),
                      _infoRow('نوع الوقود', detailedOrder.fuelType ?? '-'),
                      _infoRow(
                        'الكمية',
                        detailedOrder.quantity != null
                            ? '${detailedOrder.quantity!.toStringAsFixed(detailedOrder.quantity!.truncateToDouble() == detailedOrder.quantity ? 0 : 2)} ${detailedOrder.unit ?? ''}'
                            : '-',
                      ),
                      _infoRow('تاريخ الطلب', _formatDate(detailedOrder.orderDate)),
                      _infoRow('موعد التحميل', detailedOrder.formattedLoadingDateTime),
                      _infoRow('موعد الوصول', detailedOrder.formattedArrivalDateTime),
                      _infoRow('الحالة التنفيذية', detailedOrder.status),
                      _infoRow('أضيف بواسطة', detailedOrder.createdByName ?? '-'),
                      _infoRow('السائق', detailedOrder.driverName ?? '-'),
                      if ((detailedOrder.portalReviewNotes ?? '').isNotEmpty)
                        _infoRow('ملاحظات الحركة', detailedOrder.portalReviewNotes!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoSection(
                    title: 'حركة الطلب',
                    children: activities.isEmpty
                        ? const <Widget>[
                            Text(
                              'لا توجد إجراءات مسجلة حتى الآن',
                              style: TextStyle(color: AppColors.mediumGray),
                            ),
                          ]
                        : activities.map(_activityTile).toList(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openReviewSheet(Order order) async {
    final noteController = TextEditingController(
      text: order.portalReviewNotes ?? '',
    );
    var action = order.portalStatus == 'approved' ? 'update' : 'approved';
    var customerId = order.portalCustomerId;
    var stationId = order.destinationStationId;
    var driverId = order.driverId;

    final supplierCustomers = _customers
        .where((customer) {
          if (order.supplierId == null || order.supplierId!.isEmpty) {
            return true;
          }
          return customer.supplierId == order.supplierId;
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    List<Station> stationsForCustomer(String? selectedCustomerId) {
      final customer = supplierCustomers.firstWhere(
        (item) => item.id == selectedCustomerId,
        orElse: () => Customer.empty(),
      );
      if (customer.id.isEmpty || customer.supplierStationIds.isEmpty) {
        return const <Station>[];
      }
      final allowedIds = customer.supplierStationIds.toSet();
      final items = _stations
          .where((station) => allowedIds.contains(station.id))
          .toList();
      items.sort((a, b) => a.stationName.compareTo(b.stationName));
      return items;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final stationOptions = stationsForCustomer(customerId);
            if (stationId != null &&
                stationOptions.every((station) => station.id != stationId)) {
              stationId = null;
            }

            Future<void> save() async {
              if (customerId == null || customerId!.trim().isEmpty) {
                _showSnack('اختر الجهة أولاً', AppColors.errorRed);
                return;
              }
              if (stationId == null || stationId!.trim().isEmpty) {
                _showSnack('اختر محطة التفريغ', AppColors.errorRed);
                return;
              }
              if (action == 'approved' &&
                  (driverId == null || driverId!.trim().isEmpty)) {
                _showSnack(
                  'حدد السائق قبل اعتماد الطلب',
                  AppColors.warningOrange,
                );
                return;
              }

              setSheetState(() => saving = true);
              setState(() {
                _actionBusy = true;
                _busyOrderId = order.id;
                _busyMessage = 'جاري تنفيذ المراجعة...';
              });

              final success = await context
                  .read<OrderProvider>()
                  .reviewSupplierPortalOrder(
                    orderId: order.id,
                    decision: action == 'update' ? null : action,
                    note: noteController.text.trim(),
                    destinationStationId: stationId,
                    driverId: action == 'rejected' ? '' : driverId,
                    portalCustomerId: customerId,
                  );

              if (!mounted) return;

              setSheetState(() => saving = false);
              setState(() {
                _actionBusy = false;
                _busyOrderId = null;
              });

              if (!success) {
                _showSnack(
                  context.read<OrderProvider>().error ?? 'تعذرت مراجعة الطلب',
                  AppColors.errorRed,
                );
                return;
              }

              await _loadOrders(showLoader: false);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              _showSnack(
                action == 'approved'
                    ? 'تم اعتماد الطلب وتعيين السائق'
                    : action == 'rejected'
                    ? 'تم رفض الطلب'
                    : 'تم تحديث بيانات الطلب',
                AppColors.successGreen,
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'مراجعة طلب المورد',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.supplierName.isEmpty
                            ? 'طلب مورد'
                            : 'المورد: ${order.supplierName}',
                        style: const TextStyle(color: AppColors.mediumGray),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: action,
                        decoration: const InputDecoration(
                          labelText: 'الإجراء',
                          prefixIcon: Icon(Icons.gavel_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'approved',
                            child: Text('موافقة مع تعيين سائق'),
                          ),
                          DropdownMenuItem(
                            value: 'rejected',
                            child: Text('رفض الطلب'),
                          ),
                          DropdownMenuItem(
                            value: 'update',
                            child: Text('تحديث فقط'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => action = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: supplierCustomers.any((item) => item.id == customerId)
                            ? customerId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'الجهة التابعة للمورد',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                        items: supplierCustomers
                            .map(
                              (customer) => DropdownMenuItem<String>(
                                value: customer.id,
                                child: Text(customer.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            customerId = value;
                            stationId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: stationOptions.any((item) => item.id == stationId)
                            ? stationId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'محطة التفريغ',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                        items: stationOptions
                            .map(
                              (station) => DropdownMenuItem<String>(
                                value: station.id,
                                child: Text(
                                  '${station.stationName} - ${station.city}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() => stationId = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (action == 'approved' || order.portalStatus == 'approved')
                        DropdownButtonFormField<String>(
                          value: _drivers.any((item) => item.id == driverId)
                              ? driverId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'السائق',
                            prefixIcon: Icon(Icons.person_pin_circle_outlined),
                          ),
                          items: _drivers
                              .map(
                                (driver) => DropdownMenuItem<String>(
                                  value: driver.id,
                                  child: Text(driver.displayInfo),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setSheetState(() => driverId = value);
                          },
                        ),
                      if (action == 'approved' || order.portalStatus == 'approved')
                        const SizedBox(height: 14),
                      TextFormField(
                        controller: noteController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الحركة',
                          prefixIcon: Icon(Icons.notes_rounded),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : save,
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  action == 'rejected'
                                      ? Icons.close_rounded
                                      : Icons.check_circle_outline_rounded,
                                ),
                          label: Text(
                            action == 'approved'
                                ? 'اعتماد الطلب'
                                : action == 'rejected'
                                ? 'رفض الطلب'
                                : 'حفظ التحديث',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: action == 'rejected'
                                ? AppColors.errorRed
                                : AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openNotificationsSheet() async {
    final notifications = context.read<NotificationProvider>();
    await notifications.fetchNotifications();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              final items = List.of(provider.notifications)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'الإشعارات',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDarkBlue,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: provider.unreadCount == 0
                              ? null
                              : provider.markAllAsRead,
                          child: const Text('قراءة الكل'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد إشعارات حالياً',
                              style: TextStyle(color: AppColors.mediumGray),
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final currentUserId = provider.getCurrentUserId();
                              final isRead = currentUserId.isEmpty
                                  ? true
                                  : item.isReadByUser(currentUserId);
                              return ListTile(
                                onTap: () {
                                  if (!isRead) {
                                    provider.markAsRead(item.id);
                                  }
                                },
                                leading: CircleAvatar(
                                  backgroundColor: (isRead
                                          ? AppColors.primaryBlue
                                          : AppColors.warningOrange)
                                      .withValues(alpha: 0.12),
                                  child: Icon(
                                    isRead
                                        ? Icons.notifications_none_rounded
                                        : Icons.notifications_active_rounded,
                                    color: isRead
                                        ? AppColors.primaryBlue
                                        : AppColors.warningOrange,
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w900,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const SizedBox(height: 4),
                                    Text(item.message),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'yyyy/MM/dd - HH:mm',
                                      ).format(item.createdAt.toLocal()),
                                      style: const TextStyle(
                                        color: AppColors.mediumGray,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatDate(DateTime value) {
    return DateFormat('yyyy/MM/dd').format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canAccessPortal) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'بوابة الموردين',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text('غير مصرح لك بالدخول إلى هذه الصفحة'),
        ),
      );
    }

    final tabs = _isSupplierRole
        ? const <Tab>[
            Tab(text: 'إدخال', icon: Icon(Icons.add_box_outlined)),
            Tab(text: 'السجل', icon: Icon(Icons.history_rounded)),
          ]
        : const <Tab>[
            Tab(text: 'المراجعة', icon: Icon(Icons.fact_check_outlined)),
            Tab(text: 'السجل', icon: Icon(Icons.history_rounded)),
          ];

    final busy = _booting || _submitting || _autofilling || _actionBusy;

    return DefaultTabController(
      length: tabs.length,
      child: PopScope(
        canPop: !_isSupplierRole,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !_isSupplierRole,
            title: Text(
              _isSupplierRole ? 'بوابة الموردين' : 'طلبات الموردين',
              style: const TextStyle(color: Colors.white),
            ),
            flexibleSpace: const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.appBarGradient),
            ),
            actions: <Widget>[
              IconButton(
                onPressed: _refreshing ? null : () => _loadOrders(),
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث',
              ),
              NotificationBell(
                onPressed: _openNotificationsSheet,
                iconColor: Colors.white,
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'تسجيل الخروج',
              ),
              const SizedBox(width: 6),
            ],
            bottom: TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: tabs,
            ),
          ),
          body: Stack(
            children: <Widget>[
              const AppSoftBackground(),
              if (!_booting)
                TabBarView(
                  children: <Widget>[
                    if (_isSupplierRole) _buildEntryTab() else _buildReviewTab(),
                    _buildHistoryTab(),
                  ],
                ),
              if (busy) _buildBusyOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTab() {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1120;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            children: <Widget>[
              _buildHeroCard(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: isWide ? 860 : double.infinity,
                    child: AppSurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'إضافة طلب مورد',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'أرفق ملف الطلب، سيتم تعبئة البيانات تلقائياً قدر الإمكان ثم اختيار الجهة ومحطة التفريغ وإرساله للحركة للمراجعة.',
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildDocumentPicker(),
                            const SizedBox(height: 18),
                            _buildGrid(
                              children: <Widget>[
                                _buildDropdownField<String>(
                                  label: 'الناقل',
                                  value: _carrierValue,
                                  icon: Icons.local_shipping_rounded,
                                  items: const <DropdownMenuItem<String>>[
                                    DropdownMenuItem(
                                      value: _carrierName,
                                      child: Text(_carrierName),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _carrierValue = value);
                                  },
                                ),
                                DropdownButtonFormField<String>(
                                  value: _customers.any(
                                    (item) => item.id == _selectedCustomerId,
                                  )
                                      ? _selectedCustomerId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'الجهة التابعة للمورد',
                                    prefixIcon: Icon(Icons.apartment_rounded),
                                  ),
                                  items: _customers
                                      .map(
                                        (customer) => DropdownMenuItem<String>(
                                          value: customer.id,
                                          child: Text(customer.name),
                                        ),
                                      )
                                      .toList(),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'اختر الجهة';
                                    }
                                    return null;
                                  },
                                  onChanged: _handleCustomerChanged,
                                ),
                                DropdownButtonFormField<String>(
                                  value: _availableStationsForCustomer.any(
                                    (item) => item.id == _selectedStationId,
                                  )
                                      ? _selectedStationId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'محطة التفريغ',
                                    prefixIcon: Icon(Icons.place_outlined),
                                  ),
                                  items: _availableStationsForCustomer
                                      .map(
                                        (station) => DropdownMenuItem<String>(
                                          value: station.id,
                                          child: Text(
                                            '${station.stationName} - ${station.city}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'اختر محطة التفريغ';
                                    }
                                    return null;
                                  },
                                  onChanged: _handleStationChanged,
                                ),
                                TextFormField(
                                  controller: _supplierOrderNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم طلب المورد',
                                    prefixIcon: Icon(Icons.tag_rounded),
                                  ),
                                ),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية',
                                    prefixIcon: Icon(
                                      Icons.water_drop_outlined,
                                    ),
                                    suffixText: 'لتر',
                                  ),
                                  validator: (value) {
                                    final parsed = double.tryParse(
                                      (value ?? '').trim(),
                                    );
                                    if (parsed == null || parsed <= 0) {
                                      return 'أدخل كمية صحيحة';
                                    }
                                    return null;
                                  },
                                ),
                                _buildDropdownField<String>(
                                  label: 'نوع الوقود',
                                  value: _fuelType,
                                  icon: Icons.local_gas_station_outlined,
                                  items: _fuelTypes
                                      .map(
                                        (fuel) => DropdownMenuItem<String>(
                                          value: fuel,
                                          child: Text(fuel),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _fuelType = value);
                                  },
                                ),
                                _buildDateField(
                                  label: 'تاريخ الطلب',
                                  value: _orderDate,
                                  icon: Icons.event_note_rounded,
                                  onTap: () => _pickDate(
                                    initialDate: _orderDate,
                                    onChanged: (value) {
                                      setState(() => _orderDate = value);
                                    },
                                  ),
                                ),
                                _buildDateField(
                                  label: 'تاريخ التحميل',
                                  value: _loadingDate,
                                  icon: Icons.upload_rounded,
                                  onTap: () => _pickDate(
                                    initialDate: _loadingDate,
                                    onChanged: (value) {
                                      setState(() => _loadingDate = value);
                                    },
                                  ),
                                ),
                                _buildTimeField(
                                  label: 'وقت التحميل',
                                  controller: _loadingTimeController,
                                  icon: Icons.schedule_rounded,
                                  onTap: () => _pickTime(
                                    controller: _loadingTimeController,
                                  ),
                                ),
                                _buildDateField(
                                  label: 'تاريخ الوصول المتوقع',
                                  value: _arrivalDate,
                                  icon: Icons.flag_outlined,
                                  onTap: () => _pickDate(
                                    initialDate: _arrivalDate,
                                    firstDate: _loadingDate,
                                    onChanged: (value) {
                                      setState(() => _arrivalDate = value);
                                    },
                                  ),
                                ),
                                _buildTimeField(
                                  label: 'وقت الوصول المتوقع',
                                  controller: _arrivalTimeController,
                                  icon: Icons.more_time_rounded,
                                  onTap: () => _pickTime(
                                    controller: _arrivalTimeController,
                                  ),
                                ),
                                TextFormField(
                                  controller: _cityController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'المدينة',
                                    prefixIcon: Icon(
                                      Icons.location_city_outlined,
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _areaController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'المحطة المختارة',
                                    prefixIcon: Icon(
                                      Icons.alt_route_outlined,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظات إضافية',
                                prefixIcon: Icon(Icons.notes_rounded),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitting ? null : _submitOrder,
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                                label: Text(
                                  _submitting
                                      ? 'جاري الإرسال...'
                                      : 'إرسال الطلب للمراجعة',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isWide ? 420 : double.infinity,
                    child: Column(
                      children: <Widget>[
                        _buildStatCards(),
                        const SizedBox(height: 16),
                        AppSurfaceCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'متابعة الطلبات',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDarkBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _tipLine(
                                'الطلبات تظل تحت المراجعة حتى تعتمدها الحركة.',
                              ),
                              _tipLine(
                                'المحطات الظاهرة مرتبطة فقط بالجهة المختارة.',
                              ),
                              _tipLine(
                                'كل إجراء من الحركة أو الإدارة يصلك كإشعار وبريد.',
                              ),
                              _tipLine(
                                'افتح السجل لمراجعة كامل الإجراءات التي تمت على طلبك.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewTab() {
    return RefreshIndicator(
      onRefresh: () => _loadOrders(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildStatCards(),
          const SizedBox(height: 16),
          if (_pendingOrders.isEmpty)
            AppSurfaceCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const <Widget>[
                  Icon(
                    Icons.fact_check_outlined,
                    size: 48,
                    color: AppColors.mediumGray,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد طلبات موردين قيد المراجعة حالياً',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._pendingOrders.map((order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _orderCard(
                  order: order,
                  primaryActionLabel: order.portalStatus == 'approved' &&
                          (order.driverId == null || order.driverId!.isEmpty)
                      ? 'تعيين سائق'
                      : 'مراجعة',
                  onPrimaryAction: () => _openReviewSheet(order),
                  onSecondaryAction: () => _showOrderDetails(order),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: () => _loadOrders(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildStatCards(),
          const SizedBox(height: 16),
          if (_historyOrders.isEmpty)
            AppSurfaceCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const <Widget>[
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: AppColors.mediumGray,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد طلبات في السجل حتى الآن',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._historyOrders.map((order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _orderCard(
                  order: order,
                  primaryActionLabel:
                      _canReviewSupplierOrders ? 'تحديث' : 'التفاصيل',
                  onPrimaryAction: _canReviewSupplierOrders
                      ? () => _openReviewSheet(order)
                      : () => _showOrderDetails(order),
                  onSecondaryAction: () => _showOrderDetails(order),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final auth = context.read<AuthProvider>();
    final subtitle = _isSupplierRole
        ? 'ترفع الطلبات هنا باسم المورد فقط، وتُراجع من قسم الحركة قبل التنفيذ.'
        : 'متابعة واعتماد ورفض وتحويل طلبات الموردين مع تعيين السائق وتبديل محطة التفريغ.';

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.primaryDarkBlue.withValues(alpha: 0.96),
              AppColors.primaryBlue.withValues(alpha: 0.94),
              AppColors.secondaryTeal.withValues(alpha: 0.92),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(AppImages.logo, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _isSupplierRole
                            ? 'بوابة الموردين - شركة البحيرة العربية'
                            : 'مراقبة طلبات الموردين - شركة البحيرة العربية',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                _heroPill('المستخدم', auth.user?.name ?? '-'),
                _heroPill(
                  'الدور',
                  _isSupplierRole ? 'مورد' : 'حركة / إدارة',
                ),
                _heroPill('الناقل المعتمد', _carrierName),
              ],
            ),
            if (_isSupplierRole &&
                (_linkedSupplierId == null || _linkedSupplierId!.isEmpty)) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'هذا المستخدم غير مرتبط بسجل مورد بعد. اربطه من إدارة المستخدمين ليتمكن من الإضافة والاطلاع على طلباته فقط.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    final items = <Map<String, dynamic>>[
      <String, dynamic>{
        'label': 'إجمالي الطلبات',
        'value': _portalOrders.length,
        'color': AppColors.primaryBlue,
        'icon': Icons.inventory_2_outlined,
      },
      <String, dynamic>{
        'label': 'تحت المراجعة',
        'value': _pendingOrders.length,
        'color': AppColors.warningOrange,
        'icon': Icons.pending_actions_outlined,
      },
      <String, dynamic>{
        'label': 'معتمدة',
        'value': _approvedCount,
        'color': AppColors.successGreen,
        'icon': Icons.check_circle_outline_rounded,
      },
      <String, dynamic>{
        'label': 'مرفوضة',
        'value': _rejectedCount,
        'color': AppColors.errorRed,
        'icon': Icons.cancel_outlined,
      },
      <String, dynamic>{
        'label': 'جاهزة أو منقولة',
        'value': _inTransitCount,
        'color': AppColors.secondaryTeal,
        'icon': Icons.local_shipping_outlined,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1180
            ? 5
            : width >= 900
            ? 3
            : width >= 620
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: width >= 900 ? 1.55 : 1.85,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final color = item['color'] as Color;
            return AppSurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item['icon'] as IconData, color: color),
                  ),
                  const Spacer(),
                  Text(
                    item['value'].toString(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'].toString(),
                    style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentPicker() {
    return InkWell(
      onTap: _autofilling ? null : _pickDocument,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _document == null
                        ? 'أرفق ملف الطلب ليتم تعبئة الحقول تلقائياً'
                        : _document!.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _document == null ? 'PDF أو صورة فقط' : 'تم إرفاق الملف بنجاح',
                    style: const TextStyle(color: AppColors.mediumGray),
                  ),
                ],
              ),
            ),
            if (_document != null)
              IconButton(
                onPressed: () {
                  setState(() => _document = null);
                },
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 950
            ? 3
            : width >= 620
            ? 2
            : 1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: count == 1 ? 3.6 : 3.2,
          children: children,
        );
      },
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          _formatDate(value),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          controller.text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _orderCard({
    required Order order,
    required String primaryActionLabel,
    required VoidCallback onPrimaryAction,
    required VoidCallback onSecondaryAction,
  }) {
    final statusColor = _portalStatusColor(order);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  order.portalStatus == 'approved'
                      ? Icons.check_circle_outline_rounded
                      : order.portalStatus == 'rejected'
                      ? Icons.cancel_outlined
                      : Icons.pending_actions_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      order.supplierName.isEmpty ? 'مورد' : order.supplierName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الجهة: ${order.portalCustomerName ?? '-'}',
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المحطة: ${order.destinationStationName ?? '-'}',
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _portalStatusLabel(order),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              _smallMeta('رقم المورد', order.supplierOrderNumber ?? '-'),
              _smallMeta('الوقود', order.fuelType ?? '-'),
              _smallMeta(
                'الكمية',
                order.quantity != null
                    ? '${order.quantity!.toStringAsFixed(order.quantity!.truncateToDouble() == order.quantity ? 0 : 2)} ${order.unit ?? ''}'
                    : '-',
              ),
              _smallMeta('الحالة', order.status),
              _smallMeta('الناقل', order.carrierName ?? _carrierName),
              _smallMeta('تاريخ الإضافة', _formatDate(order.createdAt)),
            ],
          ),
          if ((order.portalReviewNotes ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'ملاحظات الحركة: ${order.portalReviewNotes}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _busyOrderId == order.id ? null : onPrimaryAction,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(primaryActionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busyOrderId == order.id ? null : onSecondaryAction,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('التفاصيل'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusyOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: SizedBox(
            width: 320,
            child: AppSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.14),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset(AppImages.logo, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'البحيرة العربية',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _busyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w700,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoSection({
    required String title,
    required List<Widget> children,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryDarkBlue,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityTile(Activity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activity.activityType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              Text(
                DateFormat('yyyy/MM/dd HH:mm').format(activity.createdAt.toLocal()),
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activity.description,
            style: const TextStyle(
              color: AppColors.primaryDarkBlue,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'بواسطة: ${activity.performedByName}',
            style: const TextStyle(color: AppColors.mediumGray),
          ),
          if (activity.changes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ...activity.changes.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallMeta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDarkBlue,
        ),
      ),
    );
  }

  Widget _tipLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.primaryDarkBlue,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
