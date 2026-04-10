import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/statement_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/services/movement_orders_report_pdf_service.dart';
import 'package:order_tracker/screens/order_details_screen.dart';
import 'package:order_tracker/screens/order_management/statement_tab.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:order_tracker/widgets/web_dropzone.dart';

class MovementDashboardScreen extends StatefulWidget {
  const MovementDashboardScreen({super.key});

  @override
  State<MovementDashboardScreen> createState() =>
      _MovementDashboardScreenState();
}

class _MovementDashboardScreenState extends State<MovementDashboardScreen> {
  static const List<String> _fuelTypes = <String>[
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
  ];

  static const Map<String, String> _arabicDigitMap = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',

    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _supplierOrderNumber = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _loadingTime = TextEditingController(
    text: '08:00',
  );
  final TextEditingController _arrivalTime = TextEditingController(
    text: '10:00',
  );
  final TextEditingController _historySearchController =
      TextEditingController();
  final TextEditingController _customerRequestsSearchController =
      TextEditingController();

  DateTime _orderDate = DateTime.now();
  DateTime _loadingDate = DateTime.now();
  DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1));
  String _fuelType = 'ديزل';
  String? _supplierId;
  PlatformFile? _document;
  List<Supplier> _suppliers = const <Supplier>[];
  List<Customer> _customers = const <Customer>[];
  List<Driver> _drivers = const <Driver>[];
  List<Order> _orders = const <Order>[];
  List<Order> _customerRequests = const <Order>[];
  bool _booting = true;
  bool _submitting = false;
  bool _autofilling = false;
  bool _refreshing = false;
  bool _exportingReport = false;
  String? _busyOrderId;
  dynamic _dropzoneController;
  bool _dropActive = false;

  String? _newCustomerRequestCustomerId;
  String _newCustomerRequestFuelType =
      _fuelTypes.contains('ديزل') ? 'ديزل' : _fuelTypes.first;
  DateTime _newCustomerRequestDate = DateTime.now();
  bool _creatingCustomerRequest = false;
  TextEditingController? _newCustomerRequestCustomerFieldController;

  late final Stream<DateTime> _statementCountdownTicker =
      Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ).asBroadcastStream();

  bool get _movementUser =>
      context.read<AuthProvider>().user?.role == 'movement';

  bool get _ownerApprovalUser {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'owner' || role == 'admin';
  }

  Supplier? get _selectedSupplier {
    for (final supplier in _suppliers) {
      if (supplier.id == _supplierId) return supplier;
    }
    return null;
  }

  List<Order> get _cancelledMovementOrders {
    final items = <Order>[..._orders, ..._customerRequests]
        .where((order) => order.status == 'ملغى')
        .toList()
      ..sort((a, b) {
        final aDate = a.cancelledAt ?? a.updatedAt;
        final bDate = b.cancelledAt ?? b.updatedAt;
        return bDate.compareTo(aDate);
      });
    return items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _supplierOrderNumber.dispose();
    _quantity.dispose();
    _notes.dispose();
    _city.dispose();
    _area.dispose();
    _loadingTime.dispose();
    _arrivalTime.dispose();
    _historySearchController.dispose();
    _customerRequestsSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final suppliers = context.read<SupplierProvider>();
    final customers = context.read<CustomerProvider>();
    final drivers = context.read<DriverProvider>();
    final statements = context.read<StatementProvider>();

    await Future.wait(<Future<void>>[
      suppliers.fetchSuppliers(filters: <String, dynamic>{'isActive': 'true'}),
      customers.fetchCustomers(fetchAll: true),
      statements.fetchStatement(silent: true),
    ]);
    final activeDrivers = await drivers.fetchActiveDrivers();
    await _loadOrders(showLoader: false);

    if (!mounted) return;
    setState(() {
      _suppliers = List<Supplier>.from(suppliers.suppliers);
      _customers = List<Customer>.from(customers.customers);
      _drivers = activeDrivers.isNotEmpty
          ? activeDrivers
          : List<Driver>.from(drivers.drivers);
      _booting = false;
    });
  }

  Future<void> _loadOrders({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _refreshing = true);
    }
    final provider = context.read<OrderProvider>();
    final responses = await Future.wait<List<Order>>(<Future<List<Order>>>[
      provider.fetchOrdersSnapshot(
        filters: <String, dynamic>{
          'entryChannel': 'movement',
          'orderSource': 'مورد',
        },
      ),
      provider.fetchOrdersSnapshot(
        filters: <String, dynamic>{
          'entryChannel': 'movement',
          'orderSource': 'عميل',
        },
      ),
    ]);
    final orders = responses.first.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final customerRequests = responses.last.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _customerRequests = customerRequests;
      _refreshing = false;
    });
  }

  String _normalizeSearchText(String value) {
    var normalized = value.trim().toLowerCase();
    _arabicDigitMap.forEach((arabicDigit, latinDigit) {
      normalized = normalized.replaceAll(arabicDigit, latinDigit);
    });
    return normalized;
  }

  String _normalizeDigits(String value) {
    var normalized = value;
    _arabicDigitMap.forEach((arabicDigit, latinDigit) {
      normalized = normalized.replaceAll(arabicDigit, latinDigit);
    });
    return normalized;
  }

  String? _normalizeSupplierOrderNumber(String? value) {
    if (value == null) return null;
    var normalized = _normalizeDigits(value);
    normalized = normalized.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E]'),
      '',
    );
    normalized = normalized
        .replaceAll(RegExp(r'[^A-Za-z0-9\-_\/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }

  double? _parseQuantityValue(String? value) {
    if (value == null) return null;
    var normalized = _normalizeDigits(value).trim().toLowerCase();
    if (normalized.isEmpty) return null;
    normalized = normalized
        .replaceAll('لتر', '')
        .replaceAll('لترات', '')
        .replaceAll('liter', '')
        .replaceAll('liters', '')
        .replaceAll('ltr', '')
        .replaceAll('،', '')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _normalizedQuantityText(String? value) {
    final parsed = _parseQuantityValue(value);
    if (parsed == null || parsed <= 0) return null;
    final isWholeNumber = parsed.truncateToDouble() == parsed;
    return isWholeNumber ? parsed.toStringAsFixed(0) : parsed.toString();
  }

  String? _normalizeFuelType(String? value) {
    if (value == null) return null;
    var normalized = value;
    normalized = normalized.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E]'),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _fuelKey(String? value) {
    final normalized = _normalizeFuelType(value);
    if (normalized == null) return null;
    final lower = normalized.toLowerCase();

    if (lower.contains('ديزل') || lower.contains('diesel')) return 'diesel';
    if (lower.contains('كيروسين') || lower.contains('kerosene')) {
      return 'kerosene';
    }

    if (lower.contains('بنزين') ||
        lower.contains('gasoline') ||
        lower.contains('petrol')) {
      if (lower.contains('95')) return 'gas95';
      if (lower.contains('91')) return 'gas91';
      return 'gasoline';
    }

    return lower;
  }

  String? _resolveFuelType(String? value) {
    final normalized = _normalize(value ?? '');
    if (normalized.contains('ممتاز')) {
      return 'بنزين 95';
    }
    if (normalized.contains('سولار')) {
      return 'ديزل';
    }

    final key = _fuelKey(value);
    switch (key) {
      case 'gas95':
        return 'بنزين 95';
      case 'gas91':
      case 'gasoline':
        return 'بنزين 91';
      case 'diesel':
        return 'ديزل';
      case 'kerosene':
        return 'كيروسين';
      default:
        return null;
    }
  }

  bool _matchesOrderSearch(Order order, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return true;

    final tokens = <String>[
      order.orderNumber,
      order.supplierOrderNumber ?? '',
      order.movementMergedOrderNumber ?? '',
      order.movementCustomerName ?? '',
      order.customer?.name ?? '',
      order.customer?.code ?? '',
      order.driverName ?? '',
      order.vehicleNumber ?? '',
      order.supplierName,
      order.fuelType ?? '',
    ].map(_normalizeSearchText);

    return tokens.any((token) => token.contains(normalizedQuery));
  }

  bool _isPendingCustomerRequest(Order order) {
    if (!order.isMovementOrder || !order.isCustomerOrder) return false;
    if (_isOrderCompleted(order)) return false;
    if (order.status == 'ملغى') return false;
    const pendingStatuses = <String>{
      'في انتظار التخصيص',
      'في انتظار الدمج',
      'في انتظار إنشاء طلب العميل',
    };
    return (order.mergedWithOrderId ?? '').trim().isEmpty &&
        order.mergeStatus != 'مدمج' &&
        pendingStatuses.contains(order.status);
  }

  String? _customerIdFromRequest(Order order) {
    final fromCustomer = order.customer?.id;
    if (fromCustomer != null && fromCustomer.trim().isNotEmpty) {
      return fromCustomer;
    }
    final fromMovement = order.movementCustomerId;
    if (fromMovement != null && fromMovement.trim().isNotEmpty) {
      return fromMovement;
    }
    final fromPortal = order.portalCustomerId;
    if (fromPortal != null && fromPortal.trim().isNotEmpty) {
      return fromPortal;
    }
    return null;
  }

  String? _customerCodeFromRequest(Order order) {
    return _normalizeCustomerCode(order.customer?.code);
  }

  String? _normalizeCustomerCode(String? value) {
    if (value == null) return null;
    var normalized = value;
    normalized = normalized.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E]'),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Order? _pendingRequestForCustomer(String? customerId, {String? fuelType}) {
    if (customerId == null || customerId.trim().isEmpty) {
      return null;
    }

    final requestedFuelKey = _fuelKey(fuelType);
    var matchingRequests =
        _customerRequests
            .where((order) => _isPendingCustomerRequest(order))
            .where((order) => _customerIdFromRequest(order) == customerId)
            .where(
              (order) => requestedFuelKey == null
                  ? true
                  : _fuelKey(order.fuelType) == requestedFuelKey,
            )
            .toList()
          ..sort((a, b) {
            final byOrderDate = b.orderDate.compareTo(a.orderDate);
            if (byOrderDate != 0) return byOrderDate;
            return b.createdAt.compareTo(a.createdAt);
          });

    if (matchingRequests.isEmpty) {
      final customer = _findCustomerById(customerId);
      final customerCode = customer?.code.trim();
      final normalizedCustomerCode = _normalizeCustomerCode(customerCode);
      if (normalizedCustomerCode != null && normalizedCustomerCode.isNotEmpty) {
        matchingRequests =
            _customerRequests
                .where((order) => _isPendingCustomerRequest(order))
                .where(
                  (order) =>
                      _customerCodeFromRequest(order) == normalizedCustomerCode,
                )
                .where(
                  (order) => requestedFuelKey == null
                      ? true
                      : _fuelKey(order.fuelType) == requestedFuelKey,
                 )
                 .toList()
               ..sort((a, b) {
                 final byOrderDate = b.orderDate.compareTo(a.orderDate);
                 if (byOrderDate != 0) return byOrderDate;
                 return b.createdAt.compareTo(a.createdAt);
               });
      }
    }

    if (matchingRequests.isNotEmpty) {
      return matchingRequests.first;
    }

    return null;
  }

  List<Customer> _dispatchCustomers({
    required bool onlyCustomersWithRequests,
    String? fuelType,
  }) {
    if (!onlyCustomersWithRequests) {
      return _customers;
    }

    final requestedFuelKey = _fuelKey(fuelType);
    final customerIds = <String>{};
    final customerCodes = <String>{};

    for (final order in _customerRequests) {
      if (!_isPendingCustomerRequest(order)) continue;
      if (requestedFuelKey != null &&
          _fuelKey(order.fuelType) != requestedFuelKey) {
        continue;
      }
      final id = _customerIdFromRequest(order);
      if (id != null && id.trim().isNotEmpty) {
        customerIds.add(id.trim());
      }
      final code = _customerCodeFromRequest(order);
      if (code != null && code.isNotEmpty) {
        customerCodes.add(code);
      }
    }

    if (customerIds.isEmpty && customerCodes.isEmpty) {
      return const <Customer>[];
    }

    return _customers
        .where((customer) {
          if (customerIds.contains(customer.id)) return true;
          return customerCodes.contains(
            _normalizeCustomerCode(customer.code) ?? customer.code.trim(),
          );
        })
        .toList(growable: false);
  }

  bool _hasMovementArrived(Order order) {
    final arrivalDateTime = _combineDateAndTime(
      order.movementExpectedArrivalDate ?? order.arrivalDate,
      order.arrivalTime,
    );
    if (arrivalDateTime == null) return false;
    return !arrivalDateTime.isAfter(DateTime.now());
  }

  bool _hasMovementExpiredFromHistory(Order order) {
    final arrivalDateTime = _combineDateAndTime(
      order.movementExpectedArrivalDate ?? order.arrivalDate,
      order.arrivalTime,
    );
    if (arrivalDateTime == null) return false;
    final hideAfter = arrivalDateTime.add(const Duration(days: 1));
    return !hideAfter.isAfter(DateTime.now());
  }

  int _historyOrderPriority(Order order) {
    switch (order.movementState) {
      case 'pending_driver':
        return 0;
      case 'pending_dispatch':
        return 1;
      case 'directed':
        return 2;
      default:
        return 3;
    }
  }

  List<Order> get _historyOrders {
    final query = _historySearchController.text;
    final items =
        _orders
            .where(
              (order) =>
                  order.status != 'ملغى' &&
                  (!order.isMovementDirected ||
                      !_hasMovementExpiredFromHistory(order)) &&
                  _matchesOrderSearch(order, query),
            )
            .toList()
          ..sort((a, b) {
            final byPriority = _historyOrderPriority(a).compareTo(
              _historyOrderPriority(b),
            );
            if (byPriority != 0) return byPriority;
            return b.createdAt.compareTo(a.createdAt);
          });
    return items;
  }

  List<Order> get _dispatchOrders {
    final query = _historySearchController.text;
    final items =
        _orders
            .where((order) => order.isMovementDirected)
            .where((order) => _matchesOrderSearch(order, query))
            .toList()
          ..sort((a, b) {
            final aArrival = a.movementExpectedArrivalDate ?? a.arrivalDate;
            final bArrival = b.movementExpectedArrivalDate ?? b.arrivalDate;
            return aArrival.compareTo(bArrival);
          });
    return items;
  }

  bool _canCancelMovementOrder(Order order) {
    if (!order.isMovementOrder || _isOrderCompleted(order)) {
      return false;
    }
    if (order.isMovementDirected) {
      return false;
    }
    return (order.mergedWithOrderId ?? '').trim().isEmpty &&
        order.mergeStatus != 'مدمج';
  }

  bool _canCancelMovementAction(Order order) {
    if (!order.isMovementOrder || _isOrderCompleted(order)) {
      return false;
    }
    if (_ownerApprovalUser) {
      return true;
    }
    if (!_movementUser) {
      return false;
    }
    if (order.isMovementDirected) {
      return false;
    }
    return (order.mergedWithOrderId ?? '').trim().isEmpty &&
        order.mergeStatus != 'مدمج';
  }

  bool _canUndispatchMovementOrder(Order order) {
    return _ownerApprovalUser &&
        order.isMovementOrder &&
        order.orderSource == 'مورد' &&
        order.isMovementDirected &&
        !_isOrderCompleted(order);
  }

  String _cancellationApprovalLabel(Order order) {
    if (order.isCancellationPendingOwnerApproval) {
      return 'بانتظار اعتماد المالك';
    }
    if (order.isCancellationApproved) {
      return 'تم اعتماد الإلغاء';
    }
    return 'تم الإلغاء';
  }

  Color _cancellationApprovalColor(Order order) {
    if (order.isCancellationPendingOwnerApproval) {
      return AppColors.warningOrange;
    }
    if (order.isCancellationApproved) {
      return AppColors.successGreen;
    }
    return AppColors.errorRed;
  }

  bool _isCustomerRequestOpen(Order order) {
    if (!order.isMovementOrder || !order.isCustomerOrder) {
      return false;
    }
    if (_isPendingCustomerRequest(order)) {
      return true;
    }
    if (_isOrderCompleted(order) || order.status == 'ملغى') {
      return false;
    }
    final arrivalDateTime = _combineDateAndTime(
      order.arrivalDate,
      order.arrivalTime,
    );
    if (arrivalDateTime == null) return true;
    return arrivalDateTime.isAfter(DateTime.now());
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _startOfMonth(DateTime value) => DateTime(value.year, value.month);

  bool _isCustomerRelatedOrder(Order order) {
    final movementCustomerName = (order.movementCustomerName ?? '').trim();
    final customerName = (order.customer?.name ?? '').trim();
    return order.orderSource == 'عميل' ||
        movementCustomerName.isNotEmpty ||
        customerName.isNotEmpty;
  }

  bool _matchesReportAudience(Order order, _MovementReportAudience audience) {
    switch (audience) {
      case _MovementReportAudience.supplier:
        return order.orderSource == 'مورد';
      case _MovementReportAudience.customer:
        return _isCustomerRelatedOrder(order);
      case _MovementReportAudience.completed:
        return _isOrderCompleted(order) && order.status != 'ملغى';
    }
  }

  Future<List<Order>> _fetchMovementOrdersForReport() async {
    final provider = context.read<OrderProvider>();
    const int pageSize = 100;
    final aggregated = <String, Order>{};

    Future<void> collectPages({String? orderSource}) async {
      for (var page = 1; page <= 40; page++) {
        final batch = await provider.fetchOrdersSnapshot(
          filters: <String, dynamic>{
            'entryChannel': 'movement',
            'limit': pageSize,
            if (orderSource != null) 'orderSource': orderSource,
          },
          page: page,
        );

        if (batch.isEmpty) break;

        var newItems = 0;
        for (final order in batch) {
          if (!order.isMovementOrder || order.id.isEmpty) continue;
          if (aggregated.containsKey(order.id)) continue;
          aggregated[order.id] = order;
          newItems += 1;
        }

        if (batch.length < pageSize || newItems == 0) break;
      }
    }

    await collectPages();
    await collectPages(orderSource: 'مورد');
    await collectPages(orderSource: 'عميل');
    await collectPages(orderSource: 'مدمج');

    for (final order in _orders) {
      if (!order.isMovementOrder || order.id.isEmpty) continue;
      aggregated.putIfAbsent(order.id, () => order);
    }

    return aggregated.values.toList();
  }

  List<Order> _filterOrdersForReport(
    List<Order> orders,
    _MovementReportDialogResult config,
  ) {
    final startDate = _dateOnly(config.startDate);
    final endDate = _dateOnly(config.endDate);

    final filtered = orders.where((order) {
      if (!order.isMovementOrder) return false;
      if (!_matchesReportAudience(order, config.audience)) return false;

      final orderDate = _dateOnly(order.orderDate);
      return !orderDate.isBefore(startDate) && !orderDate.isAfter(endDate);
    }).toList();

    filtered.sort((a, b) {
      final byOrderDate = a.orderDate.compareTo(b.orderDate);
      if (byOrderDate != 0) return byOrderDate;
      return a.createdAt.compareTo(b.createdAt);
    });

    return filtered;
  }

  Future<void> _exportMovementReport(_MovementReportDialogResult config) async {
    if (_exportingReport) return;

    setState(() => _exportingReport = true);
    try {
      final allMovementOrders = await _fetchMovementOrdersForReport();
      final filteredOrders = _filterOrdersForReport(allMovementOrders, config);

      if (!mounted) return;
      if (filteredOrders.isEmpty) {
        _snack(
          'لا توجد طلبات حركة مطابقة للفلاتر المحددة.',
          AppColors.warningOrange,
        );
        return;
      }

      final auth = context.read<AuthProvider>();
      final bytes = await MovementOrdersReportPdfService.buildPdfBytes(
        MovementOrdersReportPdfRequest(
          title: config.reportTitle,
          periodLabel: config.periodLabel,
          scopeLabel: config.audienceLabel,
          orders: filteredOrders,
          generatedAt: DateTime.now(),
          generatedByName: auth.user?.name,
        ),
      );

      final fileName =
          'تقرير_حركة_${config.fileStamp}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      await saveAndLaunchFile(bytes, fileName);

      if (!mounted) return;
      _snack('تم تصدير تقرير الحركة بنجاح.', AppColors.successGreen);
    } catch (e) {
      if (!mounted) return;
      _snack('تعذر تصدير التقرير: $e', AppColors.errorRed);
    } finally {
      if (mounted) {
        setState(() => _exportingReport = false);
      }
    }
  }

  Future<void> _openMovementReportDialog() async {
    final now = _dateOnly(DateTime.now());
    var periodType = _MovementReportPeriodType.today;
    var audience = _MovementReportAudience.completed;
    var selectedDay = now;
    var rangeStart = now;
    var rangeEnd = now;
    var selectedMonth = _startOfMonth(now);

    Future<DateTime?> pickDate(
      BuildContext dialogContext,
      DateTime initialDate,
    ) {
      return showDatePicker(
        context: dialogContext,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
    }

    final config = await showDialog<_MovementReportDialogResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickAndSetDay() async {
            final picked = await pickDate(dialogContext, selectedDay);
            if (picked == null) return;
            setDialogState(() => selectedDay = _dateOnly(picked));
          }

          Future<void> pickAndSetRangeStart() async {
            final picked = await pickDate(dialogContext, rangeStart);
            if (picked == null) return;
            setDialogState(() {
              rangeStart = _dateOnly(picked);
              if (rangeEnd.isBefore(rangeStart)) {
                rangeEnd = rangeStart;
              }
            });
          }

          Future<void> pickAndSetRangeEnd() async {
            final picked = await pickDate(dialogContext, rangeEnd);
            if (picked == null) return;
            setDialogState(() {
              rangeEnd = _dateOnly(picked);
              if (rangeEnd.isBefore(rangeStart)) {
                rangeStart = rangeEnd;
              }
            });
          }

          Future<void> pickAndSetMonth() async {
            final picked = await pickDate(dialogContext, selectedMonth);
            if (picked == null) return;
            setDialogState(() {
              selectedMonth = DateTime(picked.year, picked.month);
            });
          }

          return AlertDialog(
            title: const Text('تصدير تقرير الحركة PDF'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DropdownButtonFormField<_MovementReportPeriodType>(
                      initialValue: periodType,
                      decoration: const InputDecoration(
                        labelText: 'نوع التقرير',
                        border: OutlineInputBorder(),
                      ),
                      items: _MovementReportPeriodType.values
                          .map(
                            (type) =>
                                DropdownMenuItem<_MovementReportPeriodType>(
                                  value: type,
                                  child: Text(type.label),
                                ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => periodType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_MovementReportAudience>(
                      initialValue: audience,
                      decoration: const InputDecoration(
                        labelText: 'نوع الطلبات',
                        border: OutlineInputBorder(),
                      ),
                      items: _MovementReportAudience.values
                          .map(
                            (item) => DropdownMenuItem<_MovementReportAudience>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => audience = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Text(
                        'سيتم إعداد التقرير بناءً على تاريخ الطلب مع نفس هوية المشروع داخل ملف PDF.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (periodType == _MovementReportPeriodType.today)
                      _reportDateTile(
                        title: 'اليوم الحالي',
                        subtitle: _fmt(now),
                        icon: Icons.today_rounded,
                        onTap: null,
                      ),
                    if (periodType == _MovementReportPeriodType.day)
                      _reportDateTile(
                        title: 'اليوم المحدد',
                        subtitle: _fmt(selectedDay),
                        icon: Icons.calendar_month_rounded,
                        onTap: pickAndSetDay,
                      ),
                    if (periodType ==
                        _MovementReportPeriodType.range) ...<Widget>[
                      _reportDateTile(
                        title: 'من تاريخ',
                        subtitle: _fmt(rangeStart),
                        icon: Icons.event_available_rounded,
                        onTap: pickAndSetRangeStart,
                      ),
                      const SizedBox(height: 10),
                      _reportDateTile(
                        title: 'إلى تاريخ',
                        subtitle: _fmt(rangeEnd),
                        icon: Icons.event_repeat_rounded,
                        onTap: pickAndSetRangeEnd,
                      ),
                    ],
                    if (periodType == _MovementReportPeriodType.month)
                      _reportDateTile(
                        title: 'الشهر',
                        subtitle: DateFormat('yyyy/MM').format(selectedMonth),
                        icon: Icons.calendar_view_month_rounded,
                        onTap: pickAndSetMonth,
                      ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final result = _MovementReportDialogResult(
                    periodType: periodType,
                    audience: audience,
                    selectedDay: selectedDay,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    selectedMonth: selectedMonth,
                  );
                  Navigator.pop(dialogContext, result);
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('تصدير'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || config == null) return;
    await _exportMovementReport(config);
  }

  String _pdfText(PlatformFile file) {
    if (file.bytes == null || file.bytes!.isEmpty) return '';
    final document = PdfDocument(inputBytes: file.bytes!);
    try {
      return PdfTextExtractor(document).extractText().trim();
    } catch (_) {
      return '';
    } finally {
      document.dispose();
    }
  }

  Map<String, String?> _extractTimesFromText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return <String, String?>{'loading': null, 'arrival': null};
    }

    final normalized = _normalizeDigits(text);
    final timeRegex = RegExp(r'\b(\d{1,2}[:.]\d{2})(?::\d{2})?\b');
    final timeWithSecondsRegex = RegExp(r'\b(\d{1,2}[:.]\d{2})(?::\d{2})?\b');

    List<String> extractTimes(String source) {
      return timeWithSecondsRegex
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();
    }

    String? loading;
    String? arrival;

    final deliveryIndex = normalized.indexOf('معلومات التسليم');
    if (deliveryIndex >= 0) {
      final block = normalized.substring(deliveryIndex);
      final times = extractTimes(block);
      if (times.isNotEmpty) {
        loading ??= times.first;
        if (times.length > 1) arrival ??= times[1];
      }
    }

    if (loading == null || arrival == null) {
      final lines = normalized.split(RegExp(r'[\r\n]+'));
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();

        if (lower.contains('time:')) {
          continue;
        }

        final match = timeRegex.firstMatch(line);
        final timeFromLine = match?.group(1);
        final nextLine = i + 1 < lines.length ? lines[i + 1] : '';
        final timeFromNext = timeRegex.firstMatch(nextLine)?.group(1);

        if (loading == null &&
            (line.contains('تحميل') ||
                line.contains('التحميل') ||
                line.contains('تاريخ التحميل'))) {
          loading = timeFromLine ?? timeFromNext;
          if (loading != null) continue;
        }

        if (arrival == null &&
            (line.contains('وصول') ||
                line.contains('الوصول') ||
                line.contains('تاريخ الوصول'))) {
          arrival = timeFromLine ?? timeFromNext;
          if (arrival != null) continue;
        }

        if (line.contains('الوقت') || line.contains('وقت')) {
          final time = timeFromLine ?? timeFromNext;
          if (loading == null) {
            loading = time;
            if (loading != null) continue;
          } else {
            arrival ??= time;
          }
        }
      }
    }

    if (loading == null || arrival == null) {
      final allLines = normalized.split(RegExp(r'[\r\n]+'));
      final allTimes = <String>[];
      for (final line in allLines) {
        if (line.toLowerCase().contains('time:')) continue;
        allTimes.addAll(extractTimes(line));
      }
      if (allTimes.length >= 2) {
        loading ??= allTimes[allTimes.length - 2];
        arrival ??= allTimes[allTimes.length - 1];
      } else if (allTimes.isNotEmpty) {
        loading ??= allTimes.first;
      }
    }

    if (loading == null || arrival == null) {
      final rawLines = text.split(RegExp(r'[\r\n]+'));
      final fallbackTimes = <String>[];
      for (final rawLine in rawLines) {
        final line = _normalizeDigits(rawLine);
        final lower = line.toLowerCase();
        if (lower.contains('time:')) continue;
        fallbackTimes.addAll(
          timeWithSecondsRegex
              .allMatches(line)
              .map((m) => m.group(1)!)
              .toList(),
        );

        if (loading == null &&
            (line.contains('تحميل') || line.contains('التحميل'))) {
          final match = timeRegex.firstMatch(line);
          if (match != null) loading = match.group(1);
        }

        if (arrival == null &&
            (line.contains('وصول') || line.contains('الوصول'))) {
          final match = timeRegex.firstMatch(line);
          if (match != null) arrival = match.group(1);
        }

        if (line.contains('الوقت') || line.contains('وقت')) {
          final match = timeRegex.firstMatch(line);
          final value = match?.group(1);
          if (value != null) {
            if (loading == null) {
              loading = value;
            } else {
              arrival ??= value;
            }
          }
        }
      }

      if (loading == null && fallbackTimes.isNotEmpty) {
        loading = fallbackTimes.first;
      }
      if (arrival == null && fallbackTimes.length > 1) {
        arrival = fallbackTimes.last;
      }
    }

    return <String, String?>{'loading': loading, 'arrival': arrival};
  }

  String _normalize(String value) {
    final western = value.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (m) => _arabicDigitMap[m.group(0)] ?? m.group(0)!,
    );
    return western
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^ء-يa-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Supplier? _matchSupplier(String raw) {
    final target = _normalize(raw);
    if (target.isEmpty) return null;

    final targetDigits = raw.replaceAll(RegExp(r'\D'), '');
    final targetTokens = target
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet();
    var bestScore = 0;
    Supplier? bestSupplier;
    var tied = false;

    for (final supplier in _suppliers) {
      var score = 0;
      final items = <String>[
        supplier.name,
        supplier.company,
        supplier.displayName,
        supplier.contactPerson,
      ].map(_normalize);

      final candidateTokens = items
          .expand((item) => item.split(' '))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toSet();

      for (final item in items) {
        if (item.isEmpty) continue;
        if (item == target) {
          score = 100;
          break;
        }
        if (target.length >= 4 &&
            (item.startsWith(target) || target.startsWith(item))) {
          score = score < 80 ? 80 : score;
          continue;
        }
        if (target.length >= 4 &&
            (item.contains(target) || target.contains(item))) {
          score = score < 60 ? 60 : score;
        }
      }

      if (targetDigits.isNotEmpty) {
        final taxDigits =
            supplier.taxNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
        final commercialDigits =
            supplier.commercialNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
        final displayDigits = supplier.displayName.replaceAll(
          RegExp(r'\D'),
          '',
        );
        if (taxDigits.isNotEmpty && taxDigits == targetDigits) {
          score = score < 95 ? 95 : score;
        } else if (commercialDigits.isNotEmpty &&
            commercialDigits == targetDigits) {
          score = score < 92 ? 92 : score;
        } else if (displayDigits.isNotEmpty && displayDigits == targetDigits) {
          score = score < 90 ? 90 : score;
        }
      }

      if (score < 90 && targetTokens.isNotEmpty && candidateTokens.isNotEmpty) {
        final overlap = targetTokens.intersection(candidateTokens).length;
        if (overlap >= 2) {
          score = score < 75 ? 75 : score;
        } else if (overlap == 1) {
          score = score < 55 ? 55 : score;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestSupplier = supplier;
        tied = false;
      } else if (score == bestScore && score > 0) {
        tied = true;
      }
    }

    if (tied) return null;
    return bestScore >= 50 ? bestSupplier : null;
  }

  DateTime? _date(dynamic value) {
    final raw = _text(value);
    if (raw == null) return null;
    return DateTime.tryParse(raw) ??
        _tryFormat(raw, 'yyyy-MM-dd') ??
        _tryFormat(raw, 'yyyy/MM/dd') ??
        _tryFormat(raw, 'dd/MM/yyyy') ??
        _tryFormat(raw, 'dd-MM-yyyy');
  }

  DateTime? _tryFormat(String value, String pattern) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  String? _time(dynamic value) {
    final raw = _text(value);
    if (raw == null) return null;

    // تحويل الأرقام العربية
    final normalized = raw.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (m) => _arabicDigitMap[m.group(0)] ?? m.group(0)!,
    );

    // استخراج كل الأوقات
    final matches = RegExp(
      r'(\d{1,2})[:.](\d{2})(?::\d{2})?',
    ).allMatches(normalized).toList();

    if (matches.isEmpty) return null;

    for (final match in matches) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);

      if (h == null || m == null) continue;

      // فلترة القيم الغلط
      if (h > 23 || m > 59) continue;

      // رجّع أول وقت منطقي
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    return null;
  }

  Future<void> _handlePickedFile(PlatformFile file) async {
    setState(() {
      _document = file;
      _autofilling = true;
    });
    try {
      final extractedText = (file.extension ?? '').toLowerCase() == 'pdf'
          ? _pdfText(file)
          : null;
      final localTimes = _extractTimesFromText(extractedText);
      final response = await context
          .read<OrderProvider>()
          .extractSupplierOrderDraftFromDocument(
            file: file,
            extractedText: extractedText,
          );

      if (!mounted) return;
      final draft = response?['draft'];
      final meta = response?['meta'];
      final suggestedLocation = response?['suggestedLocation'];
      final warnings =
          (response?['warnings'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList();
      if (draft is Map) {
        final mapDraft = Map<String, dynamic>.from(draft);
        final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : null;
        final rawSupplierName =
            _text(mapDraft['supplierName']) ??
            _text(meta?['supplierNameFromFile']);
        final supplierCode =
            _text(meta?['supplierCode']) ?? _text(mapDraft['supplierCode']);
        Supplier? supplier = rawSupplierName == null
            ? null
            : _matchSupplier(rawSupplierName);
        if (supplier == null && supplierCode != null) {
          supplier = _suppliers.firstWhere(
            (item) =>
                item.displayName.contains(supplierCode) ||
                (item.taxNumber?.contains(supplierCode) ?? false) ||
                (item.commercialNumber?.contains(supplierCode) ?? false),
            orElse: () => Supplier.empty(),
          );
          if (supplier.id.isEmpty) {
            supplier = null;
          }
        }
        var applied = 0;

        setState(() {
          if (supplier != null) {
            _supplierId = supplier.id;
            applied += 1;
          }

          final supplierOrderNumber = _normalizeSupplierOrderNumber(
            _text(mapDraft['supplierOrderNumber']),
          );
          if (supplierOrderNumber != null) {
            _supplierOrderNumber.text = supplierOrderNumber;
            applied += 1;
          }

          final quantityText = _normalizedQuantityText(
            _text(mapDraft['quantity']),
          );
          if (quantityText != null) {
            _quantity.text = quantityText;
            applied += 1;
          }

          final notes = _text(mapDraft['notes']);
          if (notes != null) {
            _notes.text = notes;
            applied += 1;
          }

          final city = _text(mapDraft['city']);
          if (city != null) {
            _city.text = city;
            applied += 1;
          } else {
            final suggestedCity = _text(suggestedLocation?['city']);
            if (suggestedCity != null) {
              _city.text = suggestedCity;
              applied += 1;
            }
          }

          final area = _text(mapDraft['region'] ?? mapDraft['area']);
          if (area != null) {
            _area.text = area;
            applied += 1;
          } else {
            final suggestedArea = _text(
              suggestedLocation?['area'] ?? suggestedLocation?['region'],
            );
            if (suggestedArea != null) {
              _area.text = suggestedArea;
              applied += 1;
            }
          }

          final orderDate = _date(mapDraft['orderDate']);
          if (orderDate != null) {
            _orderDate = orderDate;
            applied += 1;
          }

          final loadingDate = _date(mapDraft['loadingDate']);
          if (loadingDate != null) {
            _loadingDate = loadingDate;
            applied += 1;
          }

          final arrivalDate = _date(mapDraft['arrivalDate']);
          if (arrivalDate != null) {
            _arrivalDate = arrivalDate;
            applied += 1;
          }

          final loadingTime = _time(mapDraft['loadingTime']);
          if (loadingTime != null) {
            _loadingTime.text = loadingTime;
            applied += 1;
          } else if (metaMap != null) {
            final candidates = metaMap['timeCandidates'] is List
                ? (metaMap['timeCandidates'] as List)
                : const [];
            final fallback = _time(
              metaMap['deliveryTimes']?['loadingTime'] ??
                  metaMap['fallbackTimes']?['loadingTime'] ??
                  (candidates.isNotEmpty ? candidates.first : null),
            );
            if (fallback != null) {
              _loadingTime.text = fallback;
              applied += 1;
            }
          } else if (localTimes['loading'] != null) {
            final fallback = _time(localTimes['loading']);
            if (fallback != null) {
              _loadingTime.text = fallback;
              applied += 1;
            }
          }

          final arrivalTime = _time(mapDraft['arrivalTime']);
          if (arrivalTime != null) {
            _arrivalTime.text = arrivalTime;
            applied += 1;
          } else if (metaMap != null) {
            final candidates = metaMap['timeCandidates'] is List
                ? (metaMap['timeCandidates'] as List)
                : const [];
            final fallback = _time(
              metaMap['deliveryTimes']?['arrivalTime'] ??
                  metaMap['fallbackTimes']?['arrivalTime'] ??
                  (candidates.length > 1 ? candidates[1] : null),
            );
            if (fallback != null) {
              _arrivalTime.text = fallback;
              applied += 1;
            }
          } else if (localTimes['arrival'] != null) {
            final fallback = _time(localTimes['arrival']);
            if (fallback != null) {
              _arrivalTime.text = fallback;
              applied += 1;
            }
          }

          final normalizedFuel = _normalize(_text(mapDraft['fuelType']) ?? '');
          if (normalizedFuel.isNotEmpty) {
            if (normalizedFuel.contains('95')) {
              _fuelType = 'بنزين 95';
              applied += 1;
            } else if (normalizedFuel.contains('91')) {
              _fuelType = 'بنزين 91';
              applied += 1;
            } else if (normalizedFuel.contains('ممتاز')) {
              _fuelType = 'بنزين 95';
              applied += 1;
            } else if (normalizedFuel.contains('سولار')) {
              _fuelType = 'ديزل';
              applied += 1;
            } else if (normalizedFuel.contains('ديزل')) {
              _fuelType = 'ديزل';
              applied += 1;
            } else if (normalizedFuel.contains('كيروسين')) {
              _fuelType = 'كيروسين';
              applied += 1;
            }
          }
          final resolvedFuelType = _resolveFuelType(_text(mapDraft['fuelType']));
          if (resolvedFuelType != null) {
            if (_fuelType != resolvedFuelType) {
              applied += 1;
            }
            _fuelType = resolvedFuelType;
          }
        });

        if (applied == 0) {
          _snack(
            'تمت قراءة المستند لكن لم يتم العثور على بيانات قابلة للتعبئة.',
            AppColors.warningOrange,
          );
        } else {
          final warningSuffix = [
            if (warnings.isNotEmpty) 'راجع الحقول غير الواضحة يدوياً.',
            if (rawSupplierName != null && supplier == null)
              'تعذر تحديد المورد تلقائياً.',
          ].join(' ');
          _snack(
            warningSuffix.isEmpty
                ? 'تم تعبئة $applied حقلاً من المستند.'
                : 'تم تعبئة $applied حقلاً من المستند. $warningSuffix',
            warnings.isNotEmpty || (rawSupplierName != null && supplier == null)
                ? AppColors.warningOrange
                : AppColors.successGreen,
          );
        }
      } else {
        _snack(
          context.read<OrderProvider>().error ?? 'تعذر استخراج البيانات.',
          AppColors.errorRed,
        );
      }
    } catch (_) {
      if (mounted) {
        _snack('تعذر قراءة الملف أو استخراج البيانات منه.', AppColors.errorRed);
      }
    } finally {
      if (mounted) {
        setState(() => _autofilling = false);
      }
    }
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

  Future<void> _handleDrop(dynamic event) async {
    final controller = _dropzoneController;
    if (controller == null) return;
    final name = await controller.getFilename(event);
    final data = await controller.getFileData(event);
    final file = PlatformFile(name: name, size: data.length, bytes: data);
    await _handlePickedFile(file);
  }

  Future<void> _handleDesktopDrop(List<XFile> files) async {
    if (files.isEmpty) return;
    final file = files.first;
    final data = await file.readAsBytes();
    final platformFile = PlatformFile(
      name: file.name,
      size: data.length,
      bytes: data,
    );
    await _handlePickedFile(platformFile);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final supplier = _selectedSupplier;
    final supplierOrderNumber = _normalizeSupplierOrderNumber(
      _supplierOrderNumber.text,
    );
    final normalizedQuantity = _normalizedQuantityText(_quantity.text);
    final qty = _parseQuantityValue(_quantity.text);
    if (supplierOrderNumber != null) {
      _supplierOrderNumber.text = supplierOrderNumber;
    }
    if (normalizedQuantity != null) {
      _quantity.text = normalizedQuantity;
    }
    if (supplier == null ||
        supplierOrderNumber == null ||
        qty == null ||
        qty <= 0) {
      _snack('أكمل بيانات الطلب بشكل صحيح.', AppColors.errorRed);
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _submitting = true);
    final order = Order(
      id: '',
      orderDate: _orderDate,
      orderSource: 'مورد',
      mergeStatus: 'منفصل',
      entryChannel: 'movement',
      supplierName: supplier.name,
      orderNumber: '',
      supplierOrderNumber: supplierOrderNumber,
      loadingDate: _loadingDate,
      loadingTime: _loadingTime.text,
      arrivalDate: _arrivalDate,
      arrivalTime: _arrivalTime.text,
      status: 'تم الإنشاء',
      supplierId: supplier.id,
      supplierContactPerson: supplier.contactPerson,
      supplierPhone: supplier.phone,
      supplierAddress: supplier.address,
      supplierCompany: supplier.company,
      city: _city.text.trim(),
      area: _area.text.trim(),
      address: '${_city.text.trim()} - ${_area.text.trim()}',
      fuelType: _resolveFuelType(_fuelType) ?? _fuelType,
      quantity: qty,
      unit: 'لتر',
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      attachments: const <Attachment>[],
      createdById: auth.user?.id ?? '',
      createdByName: auth.user?.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await context.read<OrderProvider>().createOrder(
      order,
      <Object>[if (_document != null) _document!],
      null,
      null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'فشل حفظ طلب الحركة.',
        AppColors.errorRed,
      );
      return;
    }
    _resetForm();
    _snack('تم إدخال طلب الحركة.', AppColors.successGreen);
    await _loadOrders(showLoader: false);
  }

  Future<void> _updateDriver(Order order, String driverId) async {
    setState(() => _busyOrderId = order.id);
    final success = await context.read<OrderProvider>().updateOrderLimited(
      order.id,
      <String, dynamic>{'driver': driverId},
      null,
    );
    if (!mounted) return;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'فشل تحديث السائق.',
        AppColors.errorRed,
      );
      return;
    }
    _snack('تم تحديث السائق.', AppColors.successGreen);
    await _loadOrders(showLoader: false);
  }

  Future<void> _setDriverReminder(Order order) async {
    final daysController = TextEditingController(
      text: (order.driverAssignmentReminderDays ?? 0) > 0
          ? '${order.driverAssignmentReminderDays}'
          : '',
    );
    final hoursController = TextEditingController(
      text: (order.driverAssignmentReminderHours ?? 0) > 0
          ? '${order.driverAssignmentReminderHours}'
          : '',
    );

    final payload = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int parse(String value) => int.tryParse(value.trim()) ?? 0;

            final days = parse(daysController.text);
            final hours = parse(hoursController.text);
            final totalHours = (days * 24) + hours;
            final reminderAt = totalHours > 0
                ? DateTime.now().add(Duration(hours: totalHours))
                : null;

            return AlertDialog(
              title: const Text('تذكير بتعيين السائق'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'حدد متى تريد تذكيرًا إذا بقي الطلب بانتظار السائق.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: daysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'أيام',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: hoursController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ساعات',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reminderAt == null
                          ? 'أدخل مدة أكبر من صفر.'
                          : 'سيتم التذكير في ${_formatScheduleLabel(reminderAt, DateFormat('HH:mm').format(reminderAt))}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: reminderAt == null
                            ? AppColors.errorRed
                            : AppColors.primaryDarkBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: reminderAt == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, <String, int>{
                            'days': days,
                            'hours': hours,
                          });
                        },
                  child: Text(
                    order.hasActiveDriverAssignmentReminder
                        ? 'تحديث التذكير'
                        : 'حفظ التذكير',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    daysController.dispose();
    hoursController.dispose();

    if (payload == null) return;

    setState(() => _busyOrderId = order.id);
    final updatedOrder = await context.read<OrderProvider>()
        .setDriverAssignmentReminder(
          order.id,
          days: payload['days'] ?? 0,
          hours: payload['hours'] ?? 0,
        );
    if (!mounted) return;
    setState(() => _busyOrderId = null);

    if (updatedOrder == null) {
      _snack(
        context.read<OrderProvider>().error ?? 'تعذر حفظ التذكير.',
        AppColors.errorRed,
      );
      return;
    }

    _replaceOrderLocally(updatedOrder);
    _snack('تم حفظ تذكير تعيين السائق.', AppColors.successGreen);
  }

  Future<void> _dispatch(
    Order order, {
    required String customerId,
    required DateTime customerRequestDate,
    required DateTime expectedArrivalDate,
    required String driverId,
    required String requestType,
    String? customerOrderId,
    double? requestAmount,
  }) async {
    setState(() => _busyOrderId = order.id);
    final success = await context.read<OrderProvider>().dispatchMovementOrder(
      supplierOrderId: order.id,
      customerId: customerId,
      customerRequestDate: customerRequestDate,
      expectedArrivalDate: expectedArrivalDate,
      driverId: driverId,
      customerOrderId: customerOrderId,
      requestType: requestType,
      requestAmount: requestAmount,
    );
    if (!mounted) return;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'فشل توجيه الطلب.',
        AppColors.errorRed,
      );
      return;
    }
    _snack(
      order.isMovementDirected ? 'تم تعديل التوجيه.' : 'تم توجيه الطلب.',
      AppColors.successGreen,
    );
    await _loadOrders(showLoader: false);
  }

  double? _parseOptionalAmount(String rawValue) {
    final normalized = _normalizeSearchText(
      rawValue.replaceAll(',', '').replaceAll('،', ''),
    );
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _requestAmountLabel(String requestType) {
    return requestType == 'نقل' ? 'قيمة النقل' : 'مبلغ الشراء';
  }

  String _formatCurrency(double? value) {
    if (value == null) return 'غير محدد';
    final isWholeNumber = value.truncateToDouble() == value;
    return '${value.toStringAsFixed(isWholeNumber ? 0 : 2)} ريال';
  }

  Future<String?> _promptForCancellationReason({
    required String title,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogContext, reason);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _cancelMovementOrder(
    Order order, {
    required String reason,
  }) async {
    setState(() => _busyOrderId = order.id);
    final success = await context.read<OrderProvider>().updateOrderStatus(
      order.id,
      'ملغى',
      reason: reason,
    );
    if (!mounted) return false;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'تعذر إلغاء الطلب.',
        AppColors.errorRed,
      );
      return false;
    }
    _snack(
      _movementUser
          ? 'تم إلغاء الطلب وإرساله بانتظار اعتماد المالك.'
          : 'تم إلغاء الطلب.',
      AppColors.successGreen,
    );
    await _loadOrders(showLoader: false);
    return true;
  }

  Future<bool> _approveCancellation(Order order) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اعتماد الإلغاء'),
        content: Text('هل تريد اعتماد إلغاء الطلب #${order.orderNumber}؟'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );

    if (approved != true) {
      return false;
    }

    setState(() => _busyOrderId = order.id);
    final success = await context.read<OrderProvider>().approveOrderCancellation(
      order.id,
    );
    if (!mounted) return false;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'تعذر اعتماد إلغاء الطلب.',
        AppColors.errorRed,
      );
      return false;
    }

    _snack('تم اعتماد إلغاء الطلب.', AppColors.successGreen);
    await _loadOrders(showLoader: false);
    return true;
  }

  Future<bool> _undispatchMovementOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('فك التوجيه'),
        content: Text(
          'هل تريد فك توجيه الطلب #${order.orderNumber} وإعادته إلى انتظار التوجيه؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('فك التوجيه'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false;
    }

    setState(() => _busyOrderId = order.id);
    final success = await context.read<OrderProvider>().undispatchMovementOrder(
      order.id,
    );
    if (!mounted) return false;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'تعذر فك توجيه الطلب.',
        AppColors.errorRed,
      );
      return false;
    }

    _snack(
      'تم فك التوجيه وإعادة الطلب إلى انتظار التوجيه.',
      AppColors.successGreen,
    );
    await _loadOrders(showLoader: false);
    return true;
  }

  Future<void> _showCancelledOrdersDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cancelledOrders = _cancelledMovementOrders;
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 28,
              ),
              title: Text('سجل الطلبات الملغية (${cancelledOrders.length})'),
              content: SizedBox(
                width: 680,
                height: 540,
                child: cancelledOrders.isEmpty
                    ? const Text('لا توجد طلبات ملغية حالياً.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: cancelledOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final order = cancelledOrders[index];
                          final busy = _busyOrderId == order.id;
                          final approvalColor = _cancellationApprovalColor(order);
                          return AppSurfaceCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: BorderRadius.circular(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      order.orderNumber,
                                      style: const TextStyle(
                                        color: AppColors.primaryDarkBlue,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: approvalColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: approvalColor.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Text(
                                      _cancellationApprovalLabel(order),
                                      style: TextStyle(
                                        color: approvalColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildCancelledOrderDetails(order),
                              const SizedBox(height: 10),
                              if (_ownerApprovalUser &&
                                  order.isCancellationPendingOwnerApproval)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final success =
                                                await _approveCancellation(order);
                                            if (success && mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                    icon: busy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.verified_rounded),
                                    label: const Text('اعتماد الإلغاء'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _deleteCustomerRequest(Order order) async {
    setState(() => _busyOrderId = order.id);
    final success = await context
        .read<OrderProvider>()
        .deleteMovementCustomerRequest(order.id);
    if (!mounted) return false;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(
        context.read<OrderProvider>().error ?? 'تعذر حذف طلب العميل.',
        AppColors.errorRed,
      );
      return false;
    }
    _snack('تم حذف طلب العميل.', AppColors.successGreen);
    await _loadOrders(showLoader: false);
    return true;
  }

  Future<void> _openCustomerRequestsDialog() async {
    String? customerId;
    String fuelType = _fuelTypes.contains('ديزل') ? 'ديزل' : _fuelTypes.first;
    DateTime requestDate = DateTime.now();
    bool creating = false;
    TextEditingController? customerSearchController;
    final searchController = TextEditingController();

    Future<void> submitRequest(StateSetter setDialogState) async {
      if (customerId == null) return;

      setDialogState(() => creating = true);
      final success = await context
          .read<OrderProvider>()
          .createMovementCustomerRequest(
            customerId: customerId!,
            fuelType: fuelType,
            requestDate: requestDate,
          );
      if (!mounted) return;
      setDialogState(() => creating = false);
      if (!success) {
        _snack(
          context.read<OrderProvider>().error ?? 'تعذر إضافة طلب العميل.',
          AppColors.errorRed,
        );
        return;
      }

      customerId = null;
      requestDate = DateTime.now();
      fuelType = _fuelTypes.contains('ديزل') ? 'ديزل' : _fuelTypes.first;
      customerSearchController?.clear();

      await _loadOrders(showLoader: false);
      if (!mounted) return;
      _snack('تمت إضافة طلب العميل.', AppColors.successGreen);
      setDialogState(() {});
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final searchQuery = searchController.text.trim();
          final visibleRequests =
              _customerRequests
                  .where((order) => _isPendingCustomerRequest(order))
                  .where((order) => _matchesOrderSearch(order, searchQuery))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980, maxHeight: 700),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'طلبات العملاء',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'إضافة طلب جديد',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              SizedBox(
                                width: 320,
                                child: Autocomplete<Customer>(
                                  displayStringForOption: (customer) =>
                                      customer.displayName,
                                  optionsBuilder: (value) =>
                                      _customerSearchOptions(value.text),
                                  onSelected: (customer) {
                                    setDialogState(
                                      () => customerId = customer.id,
                                    );
                                  },
                                  fieldViewBuilder:
                                      (
                                        BuildContext context,
                                        TextEditingController textController,
                                        FocusNode focusNode,
                                        VoidCallback onFieldSubmitted,
                                      ) {
                                        customerSearchController =
                                            textController;
                                        return TextFormField(
                                          controller: textController,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                            labelText: 'العميل',
                                            border: const OutlineInputBorder(),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                            ),
                                            suffixIcon: customerId == null
                                                ? null
                                                : IconButton(
                                                    onPressed: () {
                                                      textController.clear();
                                                      setDialogState(
                                                        () => customerId = null,
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.clear,
                                                    ),
                                                  ),
                                          ),
                                          onChanged: (value) {
                                            final selected = _findCustomerById(
                                              customerId,
                                            );
                                            if (selected != null &&
                                                value.trim() !=
                                                    selected.displayName) {
                                              setDialogState(
                                                () => customerId = null,
                                              );
                                            }
                                          },
                                          onFieldSubmitted: (_) =>
                                              onFieldSubmitted(),
                                        );
                                      },
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  initialValue: fuelType,
                                  decoration: const InputDecoration(
                                    labelText: 'نوع الوقود',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _fuelTypes
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setDialogState(
                                    () => fuelType = value ?? fuelType,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: requestDate,
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 365),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365 * 3),
                                      ),
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                        () => requestDate = picked,
                                      );
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'تاريخ الطلب',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(
                                        Icons.calendar_month_outlined,
                                      ),
                                    ),
                                    child: Text(_fmt(requestDate)),
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: creating || customerId == null
                                    ? null
                                    : () => submitRequest(setDialogState),
                                icon: creating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded),
                                label: Text(
                                  creating ? 'جاري الإضافة...' : 'إضافة',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالعميل أو رقم الطلب أو السائق',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visibleRequests.isEmpty
                          ? const Center(
                              child: Text('لا توجد طلبات عملاء مطابقة حاليًا.'),
                            )
                          : ListView.separated(
                              itemCount: visibleRequests.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final request = visibleRequests[index];
                                final busy = _busyOrderId == request.id;
                                final isPending = _isPendingCustomerRequest(
                                  request,
                                );
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.silverDark.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              request.orderNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (isPending
                                                          ? AppColors
                                                                .successGreen
                                                          : AppColors.infoBlue)
                                                      .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              isPending
                                                  ? 'بانتظار الدمج'
                                                  : request.status,
                                              style: TextStyle(
                                                color: isPending
                                                    ? AppColors.successGreen
                                                    : AppColors.infoBlue,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'العميل: ${request.customer?.displayName ?? request.customer?.name ?? '-'}',
                                      ),
                                      Text(
                                        'نوع الوقود: ${request.fuelType ?? '-'}',
                                      ),
                                      Text(
                                        'تاريخ الطلب: ${_fmt(request.orderDate)}',
                                      ),
                                      if ((request.driverName ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Text('السائق: ${request.driverName}'),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: <Widget>[
                                          if (_canCancelMovementAction(request))
                                            OutlinedButton.icon(
                                              onPressed: busy
                                                  ? null
                                                  : () async {
                                                      final reason =
                                                          await _promptForCancellationReason(
                                                            title:
                                                                'إلغاء الطلب',
                                                            actionLabel:
                                                                'تأكيد الإلغاء',
                                                          );
                                                      if (reason == null ||
                                                          reason
                                                              .trim()
                                                              .isEmpty) {
                                                        return;
                                                      }
                                                      final success =
                                                          await _cancelMovementOrder(
                                                            request,
                                                            reason: reason,
                                                          );
                                                      if (success && mounted) {
                                                        setDialogState(() {});
                                                      }
                                                    },
                                              icon: const Icon(
                                                Icons.cancel_outlined,
                                              ),
                                              label: const Text('إلغاء'),
                                            ),
                                          if ((request.mergedWithOrderId ?? '')
                                              .trim()
                                              .isEmpty)
                                            OutlinedButton.icon(
                                              onPressed: busy
                                                  ? null
                                                  : () async {
                                                      final confirmed = await showDialog<bool>(
                                                        context: dialogContext,
                                                        builder: (confirmContext) => AlertDialog(
                                                          title: const Text(
                                                            'حذف طلب العميل',
                                                          ),
                                                          content: const Text(
                                                            'سيتم حذف الطلب نهائيًا. هل تريد المتابعة؟',
                                                          ),
                                                          actions: <Widget>[
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    confirmContext,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'إلغاء',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    confirmContext,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                'حذف',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirmed != true) {
                                                        return;
                                                      }
                                                      final success =
                                                          await _deleteCustomerRequest(
                                                            request,
                                                          );
                                                      if (success && mounted) {
                                                        setDialogState(() {});
                                                      }
                                                    },
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              label: const Text('حذف'),
                                            ),
                                          if (busy)
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    searchController.dispose();
  }



  Customer? _findCustomerById(String? customerId) {
    if (customerId == null || customerId.trim().isEmpty) {
      return null;
    }
    for (final customer in _customers) {
      if (customer.id == customerId) {
        return customer;
      }
    }
    return null;
  }

  Iterable<Customer> _customerSearchOptions(
    String query, {
    bool onlyCustomersWithRequests = false,
    String? fuelType,
  }) {
    final source = _dispatchCustomers(
      onlyCustomersWithRequests: onlyCustomersWithRequests,
      fuelType: fuelType,
    );
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isEmpty) {
      return source.take(20);
    }
    return source
        .where((customer) {
          final phone = customer.phone?.toLowerCase() ?? '';
          return customer.name.toLowerCase().contains(trimmedQuery) ||
              customer.code.toLowerCase().contains(trimmedQuery) ||
              phone.contains(trimmedQuery);
        })
        .take(25);
  }

  void _upsertLocalCustomer(Customer customer) {
    final nextCustomers = List<Customer>.from(_customers);
    final customerIndex = nextCustomers.indexWhere(
      (item) => item.id == customer.id,
    );
    if (customerIndex == -1) {
      nextCustomers.insert(0, customer);
    } else {
      nextCustomers[customerIndex] = customer;
    }
    setState(() => _customers = nextCustomers);
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String _fmt(DateTime value) => DateFormat('yyyy/MM/dd').format(value);

  Widget _appBarActionButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required bool isMobile,
    required bool isWideWebScreen,
    String? tooltip,
    EdgeInsetsGeometry padding = const EdgeInsetsDirectional.only(end: 8),
  }) {
    return Padding(
      padding: padding,
      child: Container(
        width: isWideWebScreen ? 38 : 34,
        height: isWideWebScreen ? 38 : 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: IconButton(
          onPressed: onPressed,
          splashRadius: 20,
          tooltip: tooltip,
          color: Colors.white,
          iconSize: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildTabBar({
    required bool isMobile,
    required bool isWideWebScreen,
    required double screenWidth,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isWideWebScreen ? 16 : 12,
          isWideWebScreen ? 8 : 6,
          isWideWebScreen ? 16 : 12,
          isWideWebScreen ? 12 : 10,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? 320 : (isWideWebScreen ? 920 : screenWidth),
            ),
            child: Container(
              height: isMobile ? 56 : (isWideWebScreen ? 64 : 56),
              padding: EdgeInsets.all(isMobile ? 6 : (isWideWebScreen ? 8 : 6)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: TabBar(
                isScrollable: !isWideWebScreen,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isWideWebScreen ? 13 : 12,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isWideWebScreen ? 12 : 11,
                ),
                tabs: <Tab>[
                  Tab(
                    height: isMobile ? 48 : (isWideWebScreen ? 54 : 48),
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    icon: Icon(
                      Icons.add_box_rounded,
                      size: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
                    ),
                    text: 'إدخال',
                  ),
                  Tab(
                    height: isMobile ? 48 : (isWideWebScreen ? 54 : 48),
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    icon: Icon(
                      Icons.history_rounded,
                      size: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
                    ),
                    text: 'السجل',
                  ),

                  Tab(
                    height: isMobile ? 48 : (isWideWebScreen ? 54 : 48),
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    icon: Icon(
                      Icons.assignment_turned_in_outlined,
                      size: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
                    ),
                    text: 'طلبات العملاء',
                  ),
                  Tab(
                    height: isMobile ? 48 : (isWideWebScreen ? 54 : 48),
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    icon: Icon(
                      Icons.route_rounded,
                      size: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
                    ),
                    text: 'التوجيهات',
                  ),
                  Tab(
                    height: isMobile ? 48 : (isWideWebScreen ? 54 : 48),
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    icon: Icon(
                      Icons.local_shipping_rounded,
                      size: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
                    ),
                    text: 'متابعة السائقين',
                  ),
                  Tab(
                    height: isMobile ? 48 : (isWideWebScreen ? 54 : 48),
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    icon: Icon(
                      Icons.description_outlined,
                      size: isMobile ? 14 : (isWideWebScreen ? 18 : 16),
                    ),
                    text: 'بيان النقل',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime? _combineDateAndTime(DateTime? date, String? time) {
    if (date == null) return null;
    if (time == null || time.trim().isEmpty) {
      return DateTime(date.year, date.month, date.day);
    }
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _formatRemainingTime(DateTime? target) {
    if (target == null) return 'غير محدد';
    final now = DateTime.now();
    final diff = target.difference(now);
    final totalMinutes = diff.inMinutes.abs();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final formatted =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    return diff.isNegative ? 'متأخر $formatted' : 'متبقي $formatted';
  }

  String _formatDateLabel(DateTime value) {
    return DateFormat('yyyy/MM/dd').format(value);
  }

  String _formatScheduleLabel(DateTime date, String? time) {
    final normalizedTime = (time ?? '').trim();
    if (normalizedTime.isEmpty) {
      return _formatDateLabel(date);
    }
    return '${_formatDateLabel(date)} - $normalizedTime';
  }

  String _formatReminderDuration(Order order) {
    final parts = <String>[];
    final days = order.driverAssignmentReminderDays ?? 0;
    final hours = order.driverAssignmentReminderHours ?? 0;
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours ساعة');
    return parts.isEmpty ? 'مرة واحدة' : parts.join(' و ');
  }

  void _replaceOrderLocally(Order updatedOrder) {
    Order patch(Order order) =>
        order.id == updatedOrder.id ? updatedOrder : order;
    setState(() {
      _orders = _orders.map(patch).toList(growable: false);
      _customerRequests = _customerRequests
          .map(patch)
          .toList(growable: false);
    });
  }

  bool _isOrderCompleted(Order order) {
    const completedStatuses = <String>{
      'تم التسليم',
      'تم التنفيذ',
      'مكتمل',
      'ملغى',
    };
    return completedStatuses.contains(order.status);
  }

  List<Order> _activeOrdersForDriver(
    String? driverId, {
    String? excludeOrderId,
  }) {
    if (driverId == null) return const <Order>[];
    return _orders
        .where(
          (order) =>
              order.driverId == driverId &&
              order.id != excludeOrderId &&
              order.isMovementDirected &&
              !_isOrderCompleted(order) &&
              !_hasMovementArrived(order),
        )
        .toList();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _supplierOrderNumber.clear();
    _quantity.clear();
    _notes.clear();
    _city.clear();
    _area.clear();
    _loadingTime.text = '08:00';
    _arrivalTime.text = '10:00';
    setState(() {
      _orderDate = DateTime.now();
      _loadingDate = DateTime.now();
      _arrivalDate = DateTime.now().add(const Duration(days: 1));
      _fuelType = 'ديزل';
      _supplierId = null;
      _document = null;
    });
  }

  Future<void> _pickDate(
    DateTime current,
    ValueChanged<DateTime> onSelected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _driverDialog(Order order) async {
    String? driverId = order.driverId;
    bool sendingWhatsapp = false;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasDriver = driverId != null;
          final activeOrders = _activeOrdersForDriver(
            driverId,
            excludeOrderId: order.id,
          );
          final isBusy = hasDriver && activeOrders.isNotEmpty;
          return AlertDialog(
            title: const Text('اختيار سائق'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: driverId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _drivers
                          .map(
                            (driver) => DropdownMenuItem<String>(
                              value: driver.id,
                              child: Text(
                                driver.vehicleNumber?.trim().isNotEmpty == true
                                    ? '${driver.name} - ${driver.vehicleNumber}'
                                    : driver.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => driverId = value),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (isBusy
                                    ? AppColors.warningOrange
                                    : AppColors.successGreen)
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              (isBusy
                                      ? AppColors.warningOrange
                                      : AppColors.successGreen)
                                  .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (!hasDriver)
                            const Text('اختر سائق لعرض الحالة.')
                          else ...<Widget>[
                            Text(
                              'الحالة: ${isBusy ? 'مشغول' : 'متاح'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isBusy
                                    ? AppColors.warningOrange
                                    : AppColors.successGreen,
                              ),
                            ),
                            if (isBusy) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                'عدد الطلبات الحالية: ${activeOrders.length}',
                              ),
                              const SizedBox(height: 8),
                              for (final active in activeOrders)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.silverDark.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'العميل: ${active.movementCustomerName ?? 'غير محدد'}',
                                      ),
                                      Text('المورد: ${active.supplierName}'),
                                      Text(
                                        'رقم طلب المورد: ${active.supplierOrderNumber ?? '-'}',
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              OutlinedButton.icon(
                onPressed: sendingWhatsapp
                    ? null
                    : () async {
                        setDialogState(() => sendingWhatsapp = true);
                        final success = await context
                            .read<OrderProvider>()
                            .sendOrderWhatsAppToDriver(order.id);
                        if (mounted) {
                          _snack(
                            success
                                ? 'تم إرسال الواتساب للسائق.'
                                : (context.read<OrderProvider>().error ??
                                      'تعذر إرسال الواتساب للسائق.'),
                            success
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                          );
                        }
                        setDialogState(() => sendingWhatsapp = false);
                      },
                icon: sendingWhatsapp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat),
                label: const Text('واتساب'),
              ),
              ElevatedButton(
                onPressed: driverId == null
                    ? null
                    : () => Navigator.pop(dialogContext, driverId),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || result == null || result == order.driverId) return;
    await _updateDriver(order, result);
  }

  Future<void> _dispatchDialog(Order order, {bool edit = false}) async {
    String? customerId = order.movementCustomerId;
    String? driverId = order.driverId;
    String requestType = order.requestType ?? 'شراء';
    String? customerOrderId = order.movementCustomerOrderId;
    DateTime customerRequestDate =
        order.movementCustomerRequestDate ?? DateTime.now();
    DateTime expectedArrivalDate =
        order.movementExpectedArrivalDate ??
        customerRequestDate.add(const Duration(days: 1));
    bool onlyCustomersWithRequests = true;
    TextEditingController? customerSearchController;
    final amountController = TextEditingController(
      text: order.requestAmount?.toString() ?? '',
    );

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickLocalDate(
            DateTime current,
            ValueChanged<DateTime> onSelected,
          ) async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: current,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
            );
            if (picked != null) {
              onSelected(picked);
              setDialogState(() {});
            }
          }

          Order? selectedCustomerRequest() {
            if (customerOrderId == null || customerOrderId!.trim().isEmpty) {
              return null;
            }
            for (final request in _customerRequests) {
              if (request.id == customerOrderId) {
                return request;
              }
            }
            return null;
          }

          void applySelectedCustomerRequest(Order request) {
            customerOrderId = request.id;
            customerId = _customerIdFromRequest(request);

            requestType = request.requestType ?? 'شراء';
            customerRequestDate = request.orderDate;
            expectedArrivalDate = request.arrivalDate;
            amountController.text = request.requestAmount?.toString() ?? '';
            setDialogState(() {});
          }

          void applySelectedCustomer(Customer customer) {
            customerId = customer.id;
            final pendingRequest =
                _pendingRequestForCustomer(
                  customer.id,
                  fuelType: order.fuelType,
                ) ??
                _pendingRequestForCustomer(customer.id);
            final isCurrentLinkedCustomer =
                customer.id == order.movementCustomerId &&
                (order.movementCustomerOrderId ?? '').trim().isNotEmpty;
            if (pendingRequest != null) {
              customerOrderId = pendingRequest.id;
              requestType = pendingRequest.requestType ?? 'شراء';
              customerRequestDate = pendingRequest.orderDate;
              expectedArrivalDate = pendingRequest.arrivalDate;
              amountController.text =
                  pendingRequest.requestAmount?.toString() ?? '';
            } else {
              customerOrderId = isCurrentLinkedCustomer
                  ? order.movementCustomerOrderId
                  : null;
              if (!edit || !isCurrentLinkedCustomer) {
                requestType = 'شراء';
                customerRequestDate = DateTime.now();
                expectedArrivalDate = customerRequestDate.add(
                  const Duration(days: 1),
                );
                amountController.clear();
              }
            }
            setDialogState(() {});
          }

          final selectedRequest = selectedCustomerRequest();
          final pendingRequests =
              _customerRequests.where(_isPendingCustomerRequest).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final pendingRequestsTotal = pendingRequests.length;

          return AlertDialog(
            title: Text(edit ? 'تعديل التوجيه' : 'توجيه الطلب'),
            content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: driverId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'السائق',
                        border: OutlineInputBorder(),
                      ),
                      items: _drivers
                          .map(
                            (driver) => DropdownMenuItem<String>(
                              value: driver.id,
                              child: Text(
                                driver.vehicleNumber?.trim().isNotEmpty == true
                                    ? '${driver.name} - ${driver.vehicleNumber}'
                                    : driver.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => driverId = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          label: Text(
                            'عملاء لهم طلبات ($pendingRequestsTotal)',
                          ),
                          selected: onlyCustomersWithRequests,
                          selectedColor: AppColors.successGreen.withValues(
                            alpha: 0.16,
                          ),
                          labelStyle: TextStyle(
                            color: onlyCustomersWithRequests
                                ? AppColors.successGreen
                                : AppColors.primaryDarkBlue,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setDialogState(() {
                            onlyCustomersWithRequests = true;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('عملاء فقط'),
                          selected: !onlyCustomersWithRequests,
                          onSelected: (_) => setDialogState(() {
                            onlyCustomersWithRequests = false;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (onlyCustomersWithRequests) ...<Widget>[
                      if (pendingRequests.isEmpty)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('لا توجد طلبات عملاء مؤقتة حالياً.'),
                        ),
                      if (pendingRequests.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 240),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: pendingRequests.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final request = pendingRequests[index];
                              final customer =
                                  request.customer ??
                                  _findCustomerById(
                                    _customerIdFromRequest(request),
                                  );
                              final customerLabel =
                                  customer?.displayName ??
                                  customer?.name ??
                                  request.movementCustomerName ??
                                  request.portalCustomerName ??
                                  '';
                              final resolvedCustomerLabel =
                                  customerLabel.trim().isNotEmpty
                                      ? customerLabel.trim()
                                      : 'عميل غير محدد';

                              return ListTile(
                                dense: true,
                                title: Text(
                                  request.orderNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '$resolvedCustomerLabel • ${request.fuelType ?? '-'} • ${_fmt(request.orderDate)}',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 14,
                                ),
                                onTap: () =>
                                    applySelectedCustomerRequest(request),
                              );
                            },
                          ),
                        ),
                    ] else ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Autocomplete<Customer>(
                              initialValue: TextEditingValue(
                                text:
                                    _findCustomerById(
                                      customerId,
                                    )?.displayName ??
                                    '',
                              ),
                              displayStringForOption: (Customer customer) =>
                                  customer.displayName,
                              optionsBuilder: (TextEditingValue value) {
                                return _customerSearchOptions(
                                  value.text,
                                  onlyCustomersWithRequests: false,
                                  fuelType: order.fuelType,
                                );
                              },
                              onSelected: applySelectedCustomer,
                              fieldViewBuilder:
                                  (
                                    BuildContext context,
                                    TextEditingController textController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    customerSearchController = textController;
                                    return TextFormField(
                                      controller: textController,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: 'العميل',
                                        hintText:
                                            'ابحث بالاسم أو الكود أو الجوال',
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: customerId == null
                                            ? null
                                            : IconButton(
                                                onPressed: () {
                                                  textController.clear();
                                                  setDialogState(() {
                                                    customerId = null;
                                                    customerOrderId = null;
                                                  });
                                                },
                                                icon: const Icon(Icons.clear),
                                              ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final selectedCustomer =
                                            _findCustomerById(customerId);
                                        if (selectedCustomer != null &&
                                            value.trim() !=
                                                selectedCustomer.displayName) {
                                          setDialogState(() {
                                            customerId = null;
                                            customerOrderId = null;
                                          });
                                        }
                                      },
                                      onFieldSubmitted: (_) =>
                                          onFieldSubmitted(),
                                    );
                                  },
                              optionsViewBuilder:
                                  (
                                    BuildContext context,
                                    AutocompleteOnSelected<Customer> onSelected,
                                    Iterable<Customer> options,
                                  ) {
                                    final matches = options.toList(
                                      growable: false,
                                    );
                                    return Align(
                                      alignment: Alignment.topRight,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 280,
                                            maxWidth: 360,
                                          ),
                                          child: ListView.separated(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: matches.length,
                                            separatorBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) => const Divider(height: 1),
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final customer =
                                                      matches[index];
                                                  final phone = customer.phone
                                                      ?.trim();
                                                  return ListTile(
                                                    dense: true,
                                                    title: Text(customer.name),
                                                    subtitle: Text(
                                                      phone?.isNotEmpty == true
                                                          ? '${customer.code} - $phone'
                                                          : customer.code,
                                                    ),
                                                    onTap: () =>
                                                        onSelected(customer),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Tooltip(
                              message: 'إضافة عميل جديد',
                              child: OutlinedButton(
                                onPressed: () async {
                                  final result = await Navigator.of(
                                    dialogContext,
                                  ).pushNamed(AppRoutes.customerForm);
                                  if (!mounted || result is! Customer) {
                                    return;
                                  }
                                  _upsertLocalCustomer(result);
                                  customerSearchController?.value =
                                      TextEditingValue(
                                        text: result.displayName,
                                        selection: TextSelection.collapsed(
                                          offset: result.displayName.length,
                                        ),
                                      );
                                  applySelectedCustomer(result);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Icon(Icons.person_add_alt_1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_customers.isEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: customerId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'العميل',
                            border: OutlineInputBorder(),
                          ),
                          items: _customers
                              .map(
                                (customer) => DropdownMenuItem<String>(
                                  value: customer.id,
                                  child: Text(
                                    '${customer.name} (${customer.code})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            final customer = _findCustomerById(value);
                            if (customer == null) {
                              setDialogState(() => customerId = value);
                              return;
                            }
                            applySelectedCustomer(customer);
                          },
                        ),
                    ],
                    if (customerId != null) ...<Widget>[
                      const SizedBox(height: 12),
                      if (selectedRequest != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.successGreen.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'تم ربط طلب عميل',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('رقم الطلب: ${selectedRequest.orderNumber}'),
                              Text(
                                'تاريخ الطلب: ${_fmt(selectedRequest.orderDate)}',
                              ),
                            ],
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: requestType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع الطلب',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'شراء',
                            child: Text('شراء'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'نقل',
                            child: Text('نقل'),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => requestType = value ?? 'شراء'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _requestAmountLabel(requestType),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ طلب العميل'),
                      subtitle: Text(_fmt(customerRequestDate)),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () => pickLocalDate(
                        customerRequestDate,
                        (value) => customerRequestDate = value,
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ الوصول'),
                      subtitle: Text(_fmt(expectedArrivalDate)),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () => pickLocalDate(
                        expectedArrivalDate,
                        (value) => expectedArrivalDate = value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: customerId == null || driverId == null
                    ? null
                    : () => Navigator.pop(dialogContext, <String, dynamic>{
                        'customerId': customerId,
                        'driverId': driverId,
                        'requestType': requestType,
                        'customerOrderId': customerOrderId,
                        'requestAmount': _parseOptionalAmount(
                          amountController.text,
                        ),
                        'customerRequestDate': customerRequestDate,
                        'expectedArrivalDate': expectedArrivalDate,
                      }),
                child: Text(edit ? 'تحديث' : 'توجيه'),
              ),
            ],
          );
        },
      ),
    );

    amountController.dispose();
    if (!mounted || payload == null) return;
    await _dispatch(
      order,
      customerId: payload['customerId'] as String,
      driverId: payload['driverId'] as String,
      requestType: payload['requestType'] as String? ?? 'شراء',
      customerOrderId: payload['customerOrderId'] as String?,
      requestAmount: payload['requestAmount'] as double?,
      customerRequestDate: payload['customerRequestDate'] as DateTime,
      expectedArrivalDate: payload['expectedArrivalDate'] as DateTime,
    );
  }

  String _stateLabel(Order order) {
    switch (order.movementState) {
      case 'pending_driver':
        return 'بانتظار السائق';
      case 'pending_dispatch':
        return 'بانتظار التوجيه';
      case 'directed':
        return 'موجه';
      default:
        return 'جديد';
    }
  }

  Color _stateColor(Order order) {
    switch (order.movementState) {
      case 'pending_driver':
        return AppColors.warningOrange;
      case 'pending_dispatch':
        return AppColors.infoBlue;
      case 'directed':
        return AppColors.successGreen;
      default:
        return AppColors.mediumGray;
    }
  }

  Widget _buildScheduleChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSchedule(Order order) {
    final hasLoadingSchedule =
        order.loadingTime != null &&
        order.loadingTime!.trim().isNotEmpty;
    final arrivalDate = order.movementExpectedArrivalDate ?? order.arrivalDate;
    final hasArrivalSchedule =
        order.arrivalTime != null &&
        order.arrivalTime!.trim().isNotEmpty;

    if (!hasLoadingSchedule && !hasArrivalSchedule) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (hasLoadingSchedule)
          _buildScheduleChip(
            icon: Icons.schedule_rounded,
            label: 'موعد التحميل',
            value: _formatScheduleLabel(order.loadingDate, order.loadingTime),
            color: AppColors.infoBlue,
          ),
        if (hasArrivalSchedule)
          _buildScheduleChip(
            icon: Icons.flag_outlined,
            label: 'موعد الوصول',
            value: _formatScheduleLabel(arrivalDate, order.arrivalTime),
            color: AppColors.successGreen,
          ),
      ],
    );
  }

  Future<void> _openMovementOrderForEdit(Order order) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.supplierOrderForm,
      arguments: order,
    );
    if (!mounted) return;
    await _loadOrders(showLoader: false);
  }

  Widget _buildDriverReminderBanner(Order order) {
    if (!order.hasActiveDriverAssignmentReminder) {
      return const SizedBox.shrink();
    }

    final reminderAt = order.driverAssignmentReminderAt;
    if (reminderAt == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DateTime>(
      stream: _statementCountdownTicker,
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final label = _formatRemainingTime(reminderAt);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warningOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.warningOrange.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: AppColors.warningOrange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'تذكير تعيين السائق',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.warningOrange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$label • ${_formatReminderDuration(order)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryDarkBlue.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCancelledOrderDetails(Order order) {
    final bool hasMovementParties =
        order.isMovementDirected ||
        (order.movementCustomerName ?? '').trim().isNotEmpty ||
        (order.movementMergedOrderNumber ?? '').trim().isNotEmpty ||
        (order.driverName ?? '').trim().isNotEmpty ||
        (order.vehicleNumber ?? '').trim().isNotEmpty;

    final arrivalDate = order.movementExpectedArrivalDate ?? order.arrivalDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildCancelledOrderInfoLine('النوع', order.orderSource),
        if (order.supplierName.trim().isNotEmpty)
          _buildCancelledOrderInfoLine('المورد', order.supplierName),
        if ((order.supplierOrderNumber ?? '').trim().isNotEmpty)
          _buildCancelledOrderInfoLine(
            'رقم طلب المورد الخارجي',
            order.supplierOrderNumber!,
          ),
        if ((order.fuelType ?? '').trim().isNotEmpty)
          _buildCancelledOrderInfoLine('الوقود', order.fuelType!),
        if (order.quantity != null)
          _buildCancelledOrderInfoLine(
            'الكمية',
            '${order.quantity!.toStringAsFixed(order.quantity! % 1 == 0 ? 0 : 2)} ${order.unit ?? ''}'
                .trim(),
          ),
        _buildCancelledOrderInfoLine(
          'موعد التحميل',
          _formatScheduleLabel(order.loadingDate, order.loadingTime),
        ),
        _buildCancelledOrderInfoLine(
          'موعد الوصول',
          _formatScheduleLabel(arrivalDate, order.arrivalTime),
        ),
        if (hasMovementParties) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'بيانات الأطراف',
            style: TextStyle(
              color: AppColors.primaryDarkBlue,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if ((order.movementCustomerName ?? '').trim().isNotEmpty)
            _buildCancelledOrderInfoLine('العميل', order.movementCustomerName!),
          if ((order.movementMergedOrderNumber ?? '').trim().isNotEmpty)
            _buildCancelledOrderInfoLine(
              'رقم الدمج',
              order.movementMergedOrderNumber!,
            ),
          if ((order.driverName ?? '').trim().isNotEmpty)
            _buildCancelledOrderInfoLine('السائق', order.driverName!),
          if ((order.vehicleNumber ?? '').trim().isNotEmpty)
            _buildCancelledOrderInfoLine('رقم المركبة', order.vehicleNumber!),
          if ((order.movementDirectedByName ?? '').trim().isNotEmpty)
            _buildCancelledOrderInfoLine(
              'تم التوجيه بواسطة',
              order.movementDirectedByName!,
            ),
        ],
        if ((order.cancellationReason ?? '').trim().isNotEmpty)
          _buildCancelledOrderInfoLine('سبب الإلغاء', order.cancellationReason!),
        if ((order.cancellationApprovalRequestedByName ?? '').trim().isNotEmpty)
          _buildCancelledOrderInfoLine(
            'طلب الإلغاء',
            order.cancellationApprovalRequestedByName!,
          ),
        if ((order.cancellationApprovalApprovedByName ?? '').trim().isNotEmpty)
          _buildCancelledOrderInfoLine(
            'تم الاعتماد بواسطة',
            order.cancellationApprovalApprovedByName!,
          ),
        if (order.cancelledAt != null)
          _buildCancelledOrderInfoLine(
            'تاريخ الإلغاء',
            _fmt(order.cancelledAt!),
          ),
        if (order.cancellationApprovalApprovedAt != null)
          _buildCancelledOrderInfoLine(
            'تاريخ الاعتماد',
            _fmt(order.cancellationApprovalApprovedAt!),
          ),
      ],
    );
  }

  Widget _buildCancelledOrderInfoLine(String label, String value) {
    final normalizedValue = value.trim().isEmpty ? '-' : value.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            normalizedValue,
            style: const TextStyle(
              color: AppColors.primaryDarkBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _glassInputDecoration(
    String label, {
    IconData? icon,
    String? suffixText,
    String? helperText,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.78),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isWideWeb ? 14 : 16,
        vertical: isWideWeb ? 14 : 16,
      ),
      prefixIcon: icon == null
          ? null
          : Container(
              margin: EdgeInsets.all(isWideWeb ? 8 : 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(isWideWeb ? 12 : 14),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryBlue,
                size: isWideWeb ? 18 : 20,
              ),
            ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
        borderSide: BorderSide(
          color: AppColors.primaryBlue.withValues(alpha: 0.10),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
        borderSide: BorderSide(
          color: AppColors.primaryBlue.withValues(alpha: 0.10),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
    Widget? trailing,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return AppSurfaceCard(
      color: Colors.white.withValues(alpha: 0.80),
      padding: EdgeInsets.all(isWideWeb ? 16 : 18),
      borderRadius: BorderRadius.circular(isWideWeb ? 24 : 28),
      border: Border.all(color: accent.withValues(alpha: 0.14)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDarkBlue.withValues(alpha: 0.05),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: isWideWeb ? 44 : 48,
                height: isWideWeb ? 44 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: <Color>[
                      accent.withValues(alpha: 0.20),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isWideWeb ? 14 : 16),
                ),
                child: Icon(icon, color: accent, size: isWideWeb ? 22 : 24),
              ),
              SizedBox(width: isWideWeb ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isWideWeb ? 16 : 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                    SizedBox(height: isWideWeb ? 3 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isWideWeb ? 12 : 13,
                        height: 1.5,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
          SizedBox(height: isWideWeb ? 16 : 18),
          child,
        ],
      ),
    );
  }

  Widget _metricCard(
    String label,
    int value,
    Color color,
    IconData icon, {
    bool dense = false,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return AppSurfaceCard(
      padding: EdgeInsets.all(
        dense
            ? 10
            : isWideWeb
            ? 12
            : 14,
      ),
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(isWideWeb ? 20 : 24),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      child: Row(
        children: <Widget>[
          Container(
            width: dense
                ? 34
                : isWideWeb
                ? 42
                : 46,
            height: dense
                ? 34
                : isWideWeb
                ? 42
                : 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(
                dense
                    ? 12
                    : isWideWeb
                    ? 14
                    : 16,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: dense
                  ? 18
                  : isWideWeb
                  ? 22
                  : 24,
            ),
          ),
          SizedBox(
            width: dense
                ? 8
                : isWideWeb
                ? 10
                : 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: dense ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense
                        ? 10
                        : isWideWeb
                        ? 12
                        : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mediumGray,
                    height: dense ? 1.15 : null,
                  ),
                ),
                SizedBox(
                  height: dense
                      ? 4
                      : isWideWeb
                      ? 4
                      : 6,
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: dense
                        ? 17
                        : isWideWeb
                        ? 22
                        : 26,
                    fontWeight: FontWeight.w500,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCardText(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool dense = false,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return AppSurfaceCard(
      padding: EdgeInsets.all(
        dense
            ? 10
            : isWideWeb
            ? 12
            : 14,
      ),
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(isWideWeb ? 20 : 24),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      child: Row(
        children: <Widget>[
          Container(
            width: dense
                ? 34
                : isWideWeb
                ? 42
                : 46,
            height: dense
                ? 34
                : isWideWeb
                ? 42
                : 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(
                dense
                    ? 12
                    : isWideWeb
                    ? 14
                    : 16,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: dense
                  ? 18
                  : isWideWeb
                  ? 22
                  : 24,
            ),
          ),
          SizedBox(
            width: dense
                ? 8
                : isWideWeb
                ? 10
                : 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: dense ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense
                        ? 10
                        : isWideWeb
                        ? 12
                        : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mediumGray,
                    height: dense ? 1.15 : null,
                  ),
                ),
                SizedBox(
                  height: dense
                      ? 4
                      : isWideWeb
                      ? 4
                      : 6,
                ),
                Text(
                  value,
                  maxLines: dense ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense
                        ? 12
                        : isWideWeb
                        ? 16
                        : 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime _statementExpiryDeadline(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  String _formatStatementCountdown(Duration remaining) {
    final totalSeconds = remaining.inSeconds;
    if (totalSeconds <= 0) return 'منتهي';

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (days > 0) return '$days يوم $hh:$mm:$ss';
    return '$hh:$mm:$ss';
  }

  Widget _statementCountdownSummary({
    required DateTime? expiryDate,
    double? width,
    bool dense = false,
  }) {
    final double cardWidth = width ?? _defaultSummaryCardWidth();

    return SizedBox(
      width: cardWidth,
      child: StreamBuilder<DateTime>(
        stream: _statementCountdownTicker,
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final expiry = expiryDate;

          if (expiry == null) {
            return _metricCardText(
              'بيان النقل',
              'غير مسجل',
              AppColors.warningOrange,
              Icons.description_outlined,
              dense: dense,
            );
          }

          final remaining = _statementExpiryDeadline(expiry).difference(now);
          final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
          final formatted = _formatStatementCountdown(safeRemaining);

          final Color color = safeRemaining == Duration.zero
              ? AppColors.errorRed
              : safeRemaining.inDays <= 2
              ? AppColors.warningOrange
              : AppColors.primaryBlue;

          return _metricCardText(
            'بيان النقل',
            formatted,
            color,
            Icons.description_outlined,
            dense: dense,
          );
        },
      ),
    );
  }

  Widget _dateSelectorCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required Color accent,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return InkWell(
      borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWideWeb ? 14 : 16,
            vertical: isWideWeb ? 12 : 14,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: isWideWeb ? 38 : 40,
                height: isWideWeb ? 38 : 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(isWideWeb ? 12 : 14),
                ),
                child: Icon(icon, color: accent, size: isWideWeb ? 18 : 20),
              ),
              SizedBox(width: isWideWeb ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isWideWeb ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mediumGray,
                      ),
                    ),
                    SizedBox(height: isWideWeb ? 4 : 5),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isWideWeb ? 14 : 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: isWideWeb ? 13 : 14,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _responsiveFields({
    required int columns,
    required List<Widget> children,
    double spacing = 14,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int safeColumns = columns < 1 ? 1 : columns;
        final double itemWidth = safeColumns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (safeColumns - 1))) /
                  safeColumns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((Widget child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _heroSection({
    required int total,
    required int pendingDriver,
    required int pendingDispatch,
    required int directed,
    required int cancelled,
    required bool compact,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    final bool isMobile = MediaQuery.sizeOf(context).width < 600;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(0),
      color: Colors.white.withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(
        isMobile
            ? 26
            : isWideWeb
            ? 28
            : 32,
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDarkBlue.withValues(alpha: 0.10),
          blurRadius: isMobile ? 24 : 34,
          offset: Offset(0, isMobile ? 14 : 20),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            isMobile
                ? 26
                : isWideWeb
                ? 28
                : 32,
          ),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[
              AppColors.primaryDarkBlue.withValues(alpha: 0.96),
              AppColors.primaryBlue.withValues(alpha: 0.92),
              AppColors.secondaryTeal.withValues(alpha: 0.82),
            ],
          ),
        ),
        padding: EdgeInsets.all(
          isMobile
              ? 14
              : compact
              ? 18
              : (isWideWeb ? 20 : 24),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _heroText(isMobile: isMobile),
                  SizedBox(height: isMobile ? 12 : 18),
                  Wrap(
                    spacing: isMobile ? 8 : 10,
                    runSpacing: isMobile ? 8 : 10,
                    children: <Widget>[
                      _heroChip(
                        'إجمالي الطلبات',
                        '$total',
                        Icons.inventory_2_rounded,
                        compact: isMobile,
                      ),
                      _heroChip(
                        'بانتظار السائق',
                        '$pendingDriver',
                        Icons.drive_eta_rounded,
                        compact: isMobile,
                      ),
                      _heroChip(
                        'بانتظار التوجيه',
                        '$pendingDispatch',
                        Icons.near_me_rounded,
                        compact: isMobile,
                      ),
                      _heroChip(
                        'طلبات موجهة',
                        '$directed',
                        Icons.task_alt_rounded,
                        compact: isMobile,
                      ),
                      _heroChip(
                        'الملغاة',
                        '$cancelled',
                        Icons.cancel_outlined,
                        onTap: _showCancelledOrdersDialog,
                        compact: isMobile,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(flex: 6, child: _heroText(isMobile: false)),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: <Widget>[
                        _heroChip(
                          'إجمالي الطلبات',
                          '$total',
                          Icons.inventory_2_rounded,
                        ),
                        _heroChip(
                          'بانتظار السائق',
                          '$pendingDriver',
                          Icons.drive_eta_rounded,
                        ),
                        _heroChip(
                          'بانتظار التوجيه',
                          '$pendingDispatch',
                          Icons.near_me_rounded,
                        ),
                        _heroChip(
                          'طلبات موجهة',
                          '$directed',
                          Icons.task_alt_rounded,
                        ),
                        _heroChip(
                          'الملغاة',
                          '$cancelled',
                          Icons.cancel_outlined,
                          onTap: _showCancelledOrdersDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _heroText({required bool isMobile}) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'حركة الطلبات',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile
                ? 20
                : isWideWeb
                ? 22
                : 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isMobile ? 4 : (isWideWeb ? 6 : 8)),
        Text(
          'متابعة طلبات المورد، تعيين السائقين، وتنفيذ التوجيهات.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isMobile
                ? 12
                : isWideWeb
                ? 13
                : 14,
            height: isMobile ? 1.5 : 1.7,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _heroChip(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
    bool compact = false,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact
              ? 10
              : isWideWeb
              ? 12
              : 14,
          vertical: compact
              ? 8
              : isWideWeb
              ? 10
              : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(
            compact
                ? 14
                : isWideWeb
                ? 16
                : 18,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: Colors.white,
              size: compact
                  ? 15
                  : isWideWeb
                  ? 17
                  : 18,
            ),
            SizedBox(width: compact ? 6 : (isWideWeb ? 7 : 8)),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact
                    ? 10
                    : isWideWeb
                    ? 11
                    : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: compact ? 7 : (isWideWeb ? 8 : 10)),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact
                    ? 13
                    : isWideWeb
                    ? 15
                    : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _autofillLoadingOverlay() {
    final bool isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: SizedBox(
            width: isDesktop ? 360 : 300,
            child: AppSurfaceCard(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : 22,
                vertical: isDesktop ? 24 : 20,
              ),
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDarkBlue.withValues(alpha: 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 20),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: isDesktop ? 92 : 82,
                    height: isDesktop ? 92 : 82,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(AppImages.logo, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'البحيرة العربية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'جاري قراءة الملف وتعبئة بيانات الطلب تلقائيًا...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 13,
                      height: 1.7,
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 28,
                    height: 28,
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    // Mobile screens are those with width < 600 px
    final bool isMobile = screenWidth < 600;
    final bool compact = screenWidth < 900;
    final bool isWideWebScreen = screenWidth >= 1100;
    final int unreadChat = context.watch<ChatProvider>().totalUnread;
    final int unreadNotifications =
        context.watch<NotificationProvider>().unreadCount;
    final statementExpiryDate = context
        .watch<StatementProvider>()
        .statement
        ?.latestRenewal
        ?.expiryDate;
    final double pageMaxWidth = screenWidth >= 1700
        ? 1480
        : screenWidth >= 1450
        ? 1380
        : screenWidth >= 1100
        ? 1260
        : screenWidth;
    final pendingDriver = _orders
        .where((o) => o.isMovementPendingDriver && !_isOrderCompleted(o))
        .length;
    final pendingDispatch = _orders
        .where((o) => o.isMovementPendingDispatch && !_isOrderCompleted(o))
        .length;
    final directed = _orders
        .where(
          (o) =>
              o.isMovementDirected &&
              !_isOrderCompleted(o) &&
              !_hasMovementArrived(o),
        )
        .length;
    final cancelled = _cancelledMovementOrders.length;
    final pendingCustomerRequests = _customerRequests
        .where((o) => _isPendingCustomerRequest(o))
        .length;
    final double tabBarContainerHeight = isMobile
        ? 56
        : (isWideWebScreen ? 64 : 56);
    final double tabBarHeaderHeight =
        tabBarContainerHeight +
        (isMobile ? 6 + 8 : (isWideWebScreen ? 8 + 12 : 6 + 10));

    return DefaultTabController(
      length: 6,
      child: PopScope(
        canPop: !_movementUser,
        child: Scaffold(
          appBar: null,
          /*
            toolbarheight: isMobile ? 56 : (isWideWebScreen ? 64 : 56),
            automaticallyImplyLeading: !_movementUser,
            centerTitle: true,
            title: Text(
              'حركة الطلبات',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 18 : (isWideWebScreen ? 22 : 18),
                letterSpacing: -0.3,
              ),
            ),
            flexibleSpace: const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.appBarGradient),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Container(
                  width: isMobile ? 34 : (isWideWebScreen ? 42 : 38),
                  height: isMobile ? 34 : (isWideWebScreen ? 42 : 38),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: IconButton(
                    onPressed: _refreshing ? null : () => _loadOrders(),
                    splashRadius: 22,
                    color: Colors.white,
                    iconSize: isMobile ? 16 : (isWideWebScreen ? 20 : 18),
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
                  ),
                ),
              ),
              if (_movementUser)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 14),
                  child: Container(
                    width: isMobile ? 34 : (isWideWebScreen ? 42 : 38),
                    height: isMobile ? 34 : (isWideWebScreen ? 42 : 38),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: IconButton(
                      onPressed: _logout,
                      splashRadius: 22,
                      color: Colors.white,
                      iconSize: isMobile ? 16 : (isWideWebScreen ? 20 : 18),
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(isWideWebScreen ? 96 : 72),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWideWebScreen ? 18 : 12,
                  0,
                  isWideWebScreen ? 18 : 12,
                  isWideWebScreen ? 18 : 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 320 : (isWideWebScreen ? 920 : screenWidth),
                    ),
                    child: Container(
                      height: isMobile ? 56 : (isWideWebScreen ? 64 : 56),
                      padding: EdgeInsets.all(isMobile ? 5 : (isWideWebScreen ? 7 : 5)),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: isWideWebScreen ? 14 : 13,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isWideWebScreen ? 13 : 12,
                        ),
                        tabs: <Tab>[
                          Tab(
                            height: isMobile ? 44 : (isWideWebScreen ? 50 : 44),
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.add_box_rounded,
                              size: isMobile ? 16 : (isWideWebScreen ? 19 : 18),
                            ),
                            text: 'إدخال',
                          ),
                          Tab(
                            height: isMobile ? 44 : (isWideWebScreen ? 50 : 44),
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.history_rounded,
                              size: isMobile ? 16 : (isWideWebScreen ? 19 : 18),
                            ),
                            text: 'السجل',
                          ),
                          Tab(
                            height: isMobile ? 44 : (isWideWebScreen ? 50 : 44),
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.route_rounded,
                              size: isMobile ? 16 : (isWideWebScreen ? 19 : 18),
                            ),
                            text: 'التوجيهات',
                          ),
                          Tab(
                            height: isMobile ? 44 : (isWideWebScreen ? 50 : 44),
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.local_shipping_rounded,
                              size: isMobile ? 16 : (isWideWebScreen ? 19 : 18),
                            ),
                            text: 'متابعة السائقين',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          */
          body: Stack(
            children: <Widget>[
              const AppSoftBackground(),
              if (_booting)
                const Center(child: CircularProgressIndicator())
              else
                NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return <Widget>[
                      SliverAppBar(
                        toolbarHeight: isMobile
                            ? 48
                            : (isWideWebScreen ? 54 : 48),
                        automaticallyImplyLeading: !_movementUser,
                        centerTitle: true,
                        title: Text(
                          'شركة البحيرة العربية - ALBUHAIRA ALARABIA CO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile
                                ? 16
                                : (isWideWebScreen ? 20 : 16),
                            letterSpacing: -0.2,
                          ),
                        ),
                        backgroundColor: AppColors.primaryBlue,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        actions: <Widget>[
                          _appBarActionButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pushNamed(AppRoutes.chat),
                            icon: Badge(
                              isLabelVisible: unreadChat > 0,
                              label: Text(unreadChat > 99 ? '99+' : '$unreadChat'),
                              child: const Icon(Icons.chat_bubble_outline),
                            ),
                            isMobile: isMobile,
                            isWideWebScreen: isWideWebScreen,
                            tooltip: 'الدردشة',
                          ),
                          _appBarActionButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pushNamed(AppRoutes.tasks),
                            icon: const Icon(Icons.task_alt_outlined),
                            isMobile: isMobile,
                            isWideWebScreen: isWideWebScreen,
                            tooltip: 'المهام',
                          ),
                          _appBarActionButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pushNamed(AppRoutes.notifications),
                            icon: Badge(
                              isLabelVisible: unreadNotifications > 0,
                              label: Text(
                                unreadNotifications > 99
                                    ? '99+'
                                    : '$unreadNotifications',
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                              ),
                            ),
                            isMobile: isMobile,
                            isWideWebScreen: isWideWebScreen,
                            tooltip: 'الإشعارات',
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Container(
                              width: isWideWebScreen ? 38 : 34,
                              height: isWideWebScreen ? 38 : 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: IconButton(
                                onPressed: _refreshing
                                    ? null
                                    : () => _loadOrders(),
                                splashRadius: 20,
                                color: Colors.white,
                                iconSize: isMobile
                                    ? 14
                                    : (isWideWebScreen ? 18 : 16),
                                icon: _refreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                              ),
                            ),
                          ),
                          if (_movementUser)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 12,
                              ),
                              child: Container(
                                width: isWideWebScreen ? 38 : 34,
                                height: isWideWebScreen ? 38 : 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _logout,
                                  splashRadius: 20,
                                  color: Colors.white,
                                  iconSize: isMobile
                                      ? 14
                                      : (isWideWebScreen ? 18 : 16),
                                  icon: const Icon(Icons.logout_rounded),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _MovementTabBarHeader(
                          height: tabBarHeaderHeight,
                          child: _buildTabBar(
                            isMobile: isMobile,
                            isWideWebScreen: isWideWebScreen,
                            screenWidth: screenWidth,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: pageMaxWidth),
                            child: _dashboardScrollHeader(
                              compact: compact,
                              isMobile: isMobile,
                              isWideWeb: isWideWebScreen,
                              pendingDriver: pendingDriver,
                              pendingDispatch: pendingDispatch,
                              directed: directed,
                              cancelled: cancelled,
                              pendingCustomerRequests:
                                  pendingCustomerRequests,
                              statementExpiryDate: statementExpiryDate,
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: pageMaxWidth),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: TabBarView(
                              children: <Widget>[
                                _entryTab(),
                                _historyTab(),
                                _customerRequestsTab(),
                                _dispatchesTab(),
                                _driversTrackingTab(),
                                const StatementTab(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_autofilling) _autofillLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(
    String label,
    int value,
    Color color,
    IconData icon, {
    double? width,
    bool dense = false,
  }) {
    final double cardWidth = width ?? _defaultSummaryCardWidth();
    return SizedBox(
      width: cardWidth,
      child: _metricCard(label, value, color, icon, dense: dense),
    );
  }

  Widget _summaryAction(
    String label,
    int value,
    Color color,
    IconData icon,
    VoidCallback onTap, {
    double? width,
    bool dense = false,
  }) {
    final double cardWidth = width ?? _defaultSummaryCardWidth();
    return SizedBox(
      width: cardWidth,
      child: GestureDetector(
        onTap: onTap,
        child: _metricCard(label, value, color, icon, dense: dense),
      ),
    );
  }

  double _defaultSummaryCardWidth() {
    final double width = MediaQuery.sizeOf(context).width;
    return width >= 1400
        ? 198
        : width >= 1100
        ? 206
        : 220;
  }

  Widget _summaryMetricsSection({
    required bool isMobile,
    required bool isWideWeb,
    required int pendingCustomerRequests,
    required int pendingDriver,
    required int pendingDispatch,
    required int directed,
    required DateTime? statementExpiryDate,
  }) {
    final double spacing = isMobile ? 8 : (isWideWeb ? 10 : 12);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth;
        if (isMobile) {
          final double availableWidth =
              constraints.maxWidth - (spacing * 2);
          cardWidth = availableWidth > 0
              ? availableWidth / 3
              : constraints.maxWidth / 3;
        } else {
          cardWidth = _defaultSummaryCardWidth();
        }

        return Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.end,
            children: <Widget>[
              _summaryAction(
                'طلبات العملاء',
                pendingCustomerRequests,
                AppColors.secondaryTeal,
                Icons.assignment_turned_in_outlined,
                _openCustomerRequestsDialog,
                width: cardWidth,
                dense: isMobile,
              ),
              _summary(
                'إجمالي',
                _orders.length,
                AppColors.primaryBlue,
                Icons.inventory_2_rounded,
                width: cardWidth,
                dense: isMobile,
              ),
              _summary(
                'بانتظار سائق',
                pendingDriver,
                AppColors.warningOrange,
                Icons.drive_eta_rounded,
                width: cardWidth,
                dense: isMobile,
              ),
              _summary(
                'بانتظار التوجيه',
                pendingDispatch,
                AppColors.infoBlue,
                Icons.near_me_rounded,
                width: cardWidth,
                dense: isMobile,
              ),
              _summary(
                'موجه',
                directed,
                AppColors.successGreen,
                Icons.task_alt_rounded,
                width: cardWidth,
                dense: isMobile,
              ),
              _statementCountdownSummary(
                expiryDate: statementExpiryDate,
                width: cardWidth,
                dense: isMobile,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dashboardScrollHeader({
    required bool compact,
    required bool isMobile,
    required bool isWideWeb,
    required int pendingDriver,
    required int pendingDispatch,
    required int directed,
    required int cancelled,
    required int pendingCustomerRequests,
    required DateTime? statementExpiryDate,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : (isWideWeb ? 16 : 18),
        compact ? 14 : (isWideWeb ? 16 : 18),
        compact ? 14 : (isWideWeb ? 16 : 18),
        isMobile ? 8 : 10,
      ),
      child: Column(
        children: <Widget>[
          _heroSection(
            total: _orders.length,
            pendingDriver: pendingDriver,
            pendingDispatch: pendingDispatch,
            directed: directed,
            cancelled: cancelled,
            compact: compact,
          ),
          SizedBox(height: isWideWeb ? 14 : 16),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _customerRequestsButton(isWideWeb: isWideWeb),
                _exportReportButton(isWideWeb: isWideWeb),
              ],
            ),
          ),
          SizedBox(height: isWideWeb ? 12 : 14),
          _summaryMetricsSection(
            isMobile: isMobile,
            isWideWeb: isWideWeb,
            pendingCustomerRequests: pendingCustomerRequests,
            pendingDriver: pendingDriver,
            pendingDispatch: pendingDispatch,
            directed: directed,
            statementExpiryDate: statementExpiryDate,
          ),
          SizedBox(height: isWideWeb ? 12 : 14),
          _historySearchField(isWideWeb: isWideWeb),
        ],
      ),
    );
  }

  Widget _exportReportButton({required bool isWideWeb}) {
    final buttonChild = _exportingReport
        ? SizedBox(
            width: isWideWeb ? 18 : 16,
            height: isWideWeb ? 18 : 16,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(Icons.picture_as_pdf_outlined, size: isWideWeb ? 20 : 18);

    return FilledButton.icon(
      onPressed: _exportingReport ? null : _openMovementReportDialog,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isWideWeb ? 18 : 16,
          vertical: isWideWeb ? 14 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: buttonChild,
      label: Text(
        _exportingReport ? 'جاري التصدير...' : 'تصدير تقرير الحركة PDF',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: isWideWeb ? 14 : 13,
        ),
      ),
    );
  }

  Widget _customerRequestsButton({required bool isWideWeb}) {
    final pendingCount = _customerRequests
        .where((order) => _isPendingCustomerRequest(order))
        .length;

    return OutlinedButton.icon(
      onPressed: _openCustomerRequestsDialog,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.successGreen,
        side: BorderSide(color: AppColors.successGreen.withValues(alpha: 0.35)),
        padding: EdgeInsets.symmetric(
          horizontal: isWideWeb ? 18 : 16,
          vertical: isWideWeb ? 14 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(
        Icons.assignment_turned_in_outlined,
        size: isWideWeb ? 20 : 18,
      ),
      label: Text(
        pendingCount > 0 ? 'طلبات العملاء ($pendingCount)' : 'طلبات العملاء',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: isWideWeb ? 14 : 13,
        ),
      ),
    );
  }

  Widget _historySearchField({required bool isWideWeb}) {
    return TextField(
      controller: _historySearchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'فلترة السجل والتوجيهات',
        hintText: 'ابحث برقم الطلب أو العميل أو السائق',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _historySearchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _historySearchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.82),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
          borderSide: BorderSide(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _reportDateTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap == null
            ? const SizedBox.shrink()
            : const Icon(Icons.edit_calendar_rounded),
      ),
    );
  }

  Widget _entryTab() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= 1100;
        final bool isTablet = constraints.maxWidth >= 720;

        return Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 14 : 16,
              0,
              isDesktop ? 14 : 16,
              isDesktop ? 24 : 28,
            ),
            children: <Widget>[
              _sectionCard(
                title: 'المستند المصدر',
                subtitle:
                    'ارفع ملف المورد لاستخراج البيانات تلقائيًا عند توفرها.',
                icon: Icons.file_present_rounded,
                accent: AppColors.primaryBlue,
                trailing: _document == null
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'تم الرفع',
                          style: TextStyle(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Builder(
                      builder: (context) {
                        final content = Stack(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(isDesktop ? 12 : 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.68),
                                borderRadius: BorderRadius.circular(
                                  isDesktop ? 16 : 18,
                                ),
                                border: Border.all(
                                  color: _dropActive
                                      ? AppColors.primaryBlue
                                      : AppColors.primaryBlue.withValues(
                                          alpha: 0.10,
                                        ),
                                  width: _dropActive ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: isDesktop ? 40 : 42,
                                    height: isDesktop ? 40 : 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        isDesktop ? 12 : 14,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.description_rounded,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _document?.name ??
                                          'لم يتم إرفاق أي ملف بعد',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 13 : 14,
                                        fontWeight: FontWeight.w700,
                                        color: _document == null
                                            ? AppColors.mediumGray
                                            : AppColors.primaryDarkBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// ✅ هنا الحل الحقيقي
                            if (kIsWeb)
                              Positioned.fill(
                                child: WebDropzone(
                                  onCreated: (controller) =>
                                      _dropzoneController = controller,
                                  onHover: () =>
                                      setState(() => _dropActive = true),
                                  onLeave: () =>
                                      setState(() => _dropActive = false),
                                  onDrop: (event) async {
                                    if (mounted) {
                                      setState(() => _dropActive = false);
                                    }
                                    await _handleDrop(event);
                                  },
                                ),
                              ),

                            if (_dropActive)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      isDesktop ? 16 : 18,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'اسحب الملف وأفلته للرفع',
                                      style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w800,
                                        fontSize: isDesktop ? 13 : 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );

                        /// ✅ Desktop فقط
                        if (!kIsWeb) {
                          return DropTarget(
                            onDragEntered: (_) =>
                                setState(() => _dropActive = true),
                            onDragExited: (_) =>
                                setState(() => _dropActive = false),
                            onDragDone: (details) async {
                              if (mounted) {
                                setState(() => _dropActive = false);
                              }
                              await _handleDesktopDrop(details.files);
                            },
                            child: content,
                          );
                        }

                        return content;
                      },
                    ),

                    const SizedBox(height: 14),
                    Align(
                      alignment: isDesktop
                          ? Alignment.centerRight
                          : Alignment.center,
                      child: GradientButton(
                        width: isDesktop ? 260 : double.infinity,
                        height: isDesktop ? 44 : 50,
                        borderRadius: 18,
                        text: _document == null
                            ? 'إرفاق مستند'
                            : 'تحديث المستند',
                        isLoading: _autofilling,
                        onPressed: _autofilling ? null : _pickDocument,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'بيانات الطلب',
                subtitle: 'أدخل بيانات المورد والكمية والوجهة ومواعيد الحركة.',
                icon: Icons.inventory_2_rounded,
                accent: AppColors.secondaryTeal,
                child: Column(
                  children: <Widget>[
                    _responsiveFields(
                      columns: isDesktop ? 2 : 1,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          initialValue: _supplierId,
                          isExpanded: true,
                          decoration: _glassInputDecoration(
                            'المورد',
                            icon: Icons.factory_rounded,
                          ),
                          items: _suppliers
                              .map(
                                (Supplier s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text(s.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) =>
                              setState(() => _supplierId = value),
                          validator: (String? value) {
                            return value == null ? 'اختر المورد' : null;
                          },
                        ),
                        TextFormField(
                          controller: _supplierOrderNumber,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(
                                r'[A-Za-z0-9\u0660-\u0669\u06F0-\u06F9\-_\/ ]',
                              ),
                            ),
                          ],
                          decoration: _glassInputDecoration(
                            'رقم طلب المورد',
                            icon: Icons.confirmation_number_rounded,
                          ),
                          onChanged: (String value) {
                            final normalized = _normalizeSupplierOrderNumber(
                              value,
                            );
                            if (normalized == null || normalized == value) {
                              return;
                            }
                            _supplierOrderNumber.value = TextEditingValue(
                              text: normalized,
                              selection: TextSelection.collapsed(
                                offset: normalized.length,
                              ),
                            );
                          },
                          validator: (String? value) {
                            final normalized = _normalizeSupplierOrderNumber(
                              value,
                            );
                            if (normalized == null) {
                              return 'أدخل رقم طلب المورد بشكل صحيح';
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _fuelType,
                          decoration: _glassInputDecoration(
                            'الوقود',
                            icon: Icons.local_gas_station_rounded,
                          ),
                          items: _fuelTypes
                              .map(
                                (String f) => DropdownMenuItem<String>(
                                  value: f,
                                  child: Text(f),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) =>
                              setState(() => _fuelType = value ?? _fuelType),
                        ),
                        TextFormField(
                          controller: _quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9.,، ]'),
                            ),
                          ],
                          decoration: _glassInputDecoration(
                            'الكمية',
                            icon: Icons.scale_rounded,
                            suffixText: 'لتر',
                          ),
                          onChanged: (String value) {
                            final normalized = _normalizedQuantityText(value);
                            if (normalized == null || normalized == value) {
                              return;
                            }
                            _quantity.value = TextEditingValue(
                              text: normalized,
                              selection: TextSelection.collapsed(
                                offset: normalized.length,
                              ),
                            );
                          },
                          validator: (String? value) {
                            final parsed = _parseQuantityValue(value);
                            if (parsed == null || parsed <= 0) {
                              return 'أدخل كمية صحيحة';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _city,
                          decoration: _glassInputDecoration(
                            'المدينة',
                            icon: Icons.location_city_rounded,
                          ),
                          validator: (String? value) =>
                              (value ?? '').trim().isEmpty
                              ? 'المدينة مطلوبة'
                              : null,
                        ),
                        TextFormField(
                          controller: _area,
                          decoration: _glassInputDecoration(
                            'المنطقة',
                            icon: Icons.map_rounded,
                          ),
                          validator: (String? value) =>
                              (value ?? '').trim().isEmpty
                              ? 'المنطقة مطلوبة'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'المواعيد',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: isDesktop ? 16 : null,
                              color: AppColors.primaryDarkBlue,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _responsiveFields(
                      columns: isDesktop
                          ? 3
                          : isTablet
                          ? 2
                          : 1,
                      children: <Widget>[
                        _dateSelectorCard(
                          label: 'تاريخ الطلب',
                          value: _fmt(_orderDate),
                          icon: Icons.event_note_rounded,
                          accent: AppColors.primaryBlue,
                          onTap: () => _pickDate(
                            _orderDate,
                            (DateTime value) => _orderDate = value,
                          ),
                        ),
                        _dateSelectorCard(
                          label: 'تاريخ التحميل',
                          value: _fmt(_loadingDate),
                          icon: Icons.inventory_rounded,
                          accent: AppColors.warningOrange,
                          onTap: () => _pickDate(
                            _loadingDate,
                            (DateTime value) => _loadingDate = value,
                          ),
                        ),
                        TextFormField(
                          readOnly: true,
                          controller: _loadingTime,
                          decoration: _glassInputDecoration(
                            'وقت التحميل',
                            icon: Icons.schedule_rounded,
                          ),
                          onTap: () => _pickTime(_loadingTime),
                        ),
                        _dateSelectorCard(
                          label: 'تاريخ الوصول',
                          value: _fmt(_arrivalDate),
                          icon: Icons.flag_circle_rounded,
                          accent: AppColors.successGreen,
                          onTap: () => _pickDate(
                            _arrivalDate,
                            (DateTime value) => _arrivalDate = value,
                          ),
                        ),
                        TextFormField(
                          readOnly: true,
                          controller: _arrivalTime,
                          decoration: _glassInputDecoration(
                            'وقت الوصول',
                            icon: Icons.av_timer_rounded,
                          ),
                          onTap: () => _pickTime(_arrivalTime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notes,
                      maxLines: 5,
                      decoration: _glassInputDecoration(
                        'ملاحظات',
                        icon: Icons.edit_note_rounded,
                        helperText:
                            'أي تفاصيل إضافية مرتبطة بالطلب أو التوريد.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: isDesktop
                          ? Alignment.centerRight
                          : Alignment.center,
                      child: GradientButton(
                        width: isDesktop ? 300 : double.infinity,
                        height: isDesktop ? 46 : 52,
                        borderRadius: 18,
                        text: 'حفظ طلب الحركة',
                        isLoading: _submitting,
                        onPressed: _submitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyTab() {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    final orders = _historyOrders;
    if (orders.isEmpty) {
      return const Center(child: Text('لا توجد طلبات مطابقة حاليًا.'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        isWideWeb ? 14 : 16,
        0,
        isWideWeb ? 14 : 16,
        isWideWeb ? 20 : 24,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final busy = _busyOrderId == order.id;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(isWideWeb ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        style: TextStyle(
                          fontSize: isWideWeb ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _stateColor(order).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _stateLabel(order),
                        style: TextStyle(
                          color: _stateColor(order),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('المورد: ${order.supplierName}'),
                Text('رقم طلب المورد: ${order.supplierOrderNumber ?? '-'}'),
                Text('الكمية: ${order.quantity ?? 0} ${order.unit ?? ''}'),
                Text('النوع: ${order.fuelType ?? 'لم يحدد'}'),
                Text('السائق: ${order.driverName ?? 'لم يحدد'}'),
                if (order.movementCustomerName != null)
                  Text('العميل: ${order.movementCustomerName}'),
                if (order.movementMergedOrderNumber != null)
                  Text('رقم الدمج: ${order.movementMergedOrderNumber}'),
                Text('رقم المركبة: ${order.vehicleNumber ?? '-'}'),
                if ((order.loadingTime != null &&
                        order.loadingTime!.trim().isNotEmpty) ||
                    (order.arrivalTime != null &&
                        order.arrivalTime!.trim().isNotEmpty)) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildOrderSchedule(order),
                ],
                if (order.hasActiveDriverAssignmentReminder) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildDriverReminderBanner(order),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (!order.isMovementDirected)
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _driverDialog(order),
                        icon: const Icon(Icons.drive_eta_outlined),
                        label: Text(
                          order.driverId == null
                              ? 'اختيار سائق'
                              : 'تغيير السائق',
                        ),
                      ),
                    if (_ownerApprovalUser)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _openMovementOrderForEdit(order),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('تعديل الطلب'),
                      ),
                    if (order.isMovementPendingDriver)
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _setDriverReminder(order),
                        icon: const Icon(Icons.alarm_add_rounded),
                        label: Text(
                          order.hasActiveDriverAssignmentReminder
                              ? 'تحديث التذكير'
                              : 'تذكير',
                        ),
                      ),
                    if (order.isMovementPendingDispatch)
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _dispatchDialog(order),
                        icon: const Icon(Icons.near_me_outlined),
                        label: const Text('توجيه'),
                      ),
                    if (order.isMovementDirected)
                      ElevatedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _dispatchDialog(order, edit: true),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل التوجيه'),
                      ),
                    if (_canUndispatchMovementOrder(order))
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _undispatchMovementOrder(order),
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('فك التوجيه'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsScreen(
                              orderId: order.id,
                              screenTitle: 'متابعة الحركة',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.timeline_rounded),
                      label: const Text('متابعة الحركة'),
                    ),
                    if (_canCancelMovementAction(order))
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final reason =
                                    await _promptForCancellationReason(
                                      title: 'إلغاء الطلب',
                                      actionLabel: 'تأكيد الإلغاء',
                                    );
                                if (reason == null || reason.trim().isEmpty) {
                                  return;
                                }
                                await _cancelMovementOrder(
                                  order,
                                  reason: reason,
                                );
                              },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('إلغاء الطلب'),
                      ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dispatchesTab() {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    final directed = _dispatchOrders;
    if (directed.isEmpty) {
      return const Center(child: Text('لا توجد توجيهات مطابقة حاليًا.'));
    }

    final grouped = <String, List<Order>>{};
    for (final order in directed) {
      final key =
          order.driverId ??
          order.vehicleNumber ??
          order.driverName ??
          'unknown';
      grouped.putIfAbsent(key, () => <Order>[]).add(order);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        isWideWeb ? 14 : 16,
        0,
        isWideWeb ? 14 : 16,
        isWideWeb ? 20 : 24,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final orders = entries[index].value;
        final first = orders.first;
        final title = first.vehicleNumber?.trim().isNotEmpty == true
            ? first.vehicleNumber!
            : (first.driverName ?? 'سيارة');
        return Card(
          child: ExpansionTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isWideWeb ? 15 : 16,
              ),
            ),
            subtitle: Text(
              '${first.driverName ?? 'بدون سائق'} • ${orders.length} طلبات',
            ),
            children: orders
                .map(
                  (order) => ListTile(
                    title: Text(order.orderNumber),
                    subtitle: Text(
                      'العميل: ${order.movementCustomerName ?? 'غير محدد'}',
                    ),
                    trailing: Text(
                      '${order.quantity ?? 0} ${order.unit ?? ''}',
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _customerRequestsTab() {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    final pendingRequests =
        _customerRequests
            .where(_isPendingCustomerRequest)
            .where(
              (order) => _matchesOrderSearch(
                order,
                _customerRequestsSearchController.text.trim(),
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Future<void> submitRequest() async {
      final customerId = _newCustomerRequestCustomerId;
      if (customerId == null || customerId.trim().isEmpty) return;

      setState(() => _creatingCustomerRequest = true);
      final provider = context.read<OrderProvider>();
      final success = await provider.createMovementCustomerRequest(
        customerId: customerId,
        fuelType: _newCustomerRequestFuelType,
        requestDate: _newCustomerRequestDate,
      );
      if (!mounted) return;
      setState(() => _creatingCustomerRequest = false);

      if (!success) {
        _snack(provider.error ?? 'تعذر إضافة طلب العميل.', AppColors.errorRed);
        return;
      }

      _newCustomerRequestCustomerId = null;
      _newCustomerRequestDate = DateTime.now();
      _newCustomerRequestFuelType =
          _fuelTypes.contains('ديزل') ? 'ديزل' : _fuelTypes.first;
      _newCustomerRequestCustomerFieldController?.clear();

      await _loadOrders(showLoader: false);
      if (!mounted) return;
      _snack('تمت إضافة طلب العميل.', AppColors.successGreen);
      setState(() {});
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWideWeb ? 14 : 16,
        12,
        isWideWeb ? 14 : 16,
        isWideWeb ? 18 : 20,
      ),
      child: Column(
        children: <Widget>[
          AppSurfaceCard(
            padding: EdgeInsets.all(isWideWeb ? 16 : 14),
            borderRadius: BorderRadius.circular(isWideWeb ? 20 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'إضافة طلب عميل مؤقت',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isWideWeb ? 16 : 15,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 320,
                      child: Autocomplete<Customer>(
                        displayStringForOption: (customer) =>
                            customer.displayName,
                        optionsBuilder: (value) =>
                            _customerSearchOptions(value.text),
                        onSelected: (customer) {
                          setState(() => _newCustomerRequestCustomerId = customer.id);
                        },
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController textController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              _newCustomerRequestCustomerFieldController =
                                  textController;
                              return TextFormField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'العميل',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon:
                                      _newCustomerRequestCustomerId == null
                                          ? null
                                          : IconButton(
                                              onPressed: () {
                                                textController.clear();
                                                setState(() => _newCustomerRequestCustomerId = null);
                                              },
                                              icon: const Icon(Icons.clear),
                                            ),
                                ),
                                onFieldSubmitted: (_) => onFieldSubmitted(),
                              );
                            },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: _newCustomerRequestFuelType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الوقود',
                          border: OutlineInputBorder(),
                        ),
                        items: _fuelTypes
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _newCustomerRequestFuelType =
                              value ?? _newCustomerRequestFuelType,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: InkWell(
                        onTap: _creatingCustomerRequest
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _newCustomerRequestDate,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 3),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _newCustomerRequestDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الطلب',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                          child: Text(_fmt(_newCustomerRequestDate)),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _creatingCustomerRequest ||
                                  _newCustomerRequestCustomerId == null
                              ? null
                              : submitRequest,
                      icon: _creatingCustomerRequest
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(
                        _creatingCustomerRequest ? 'جاري الإضافة...' : 'إضافة',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customerRequestsSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'بحث في طلبات العملاء',
              hintText: 'ابحث بالعميل أو رقم الطلب أو السائق',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _customerRequestsSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _customerRequestsSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.82),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
                borderSide: BorderSide(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
                borderSide: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: pendingRequests.isEmpty
                ? const Center(
                    child: Text('لا توجد طلبات عملاء مؤقتة مطابقة حالياً.'),
                  )
                : ListView.separated(
                    itemCount: pendingRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = pendingRequests[index];
                      final busy = _busyOrderId == request.id;
                      final customerLabel =
                          request.customer?.displayName ??
                          request.customer?.name ??
                          request.movementCustomerName ??
                          request.portalCustomerName ??
                          'عميل غير محدد';

                      return AppSurfaceCard(
                        padding: EdgeInsets.all(isWideWeb ? 14 : 14),
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    request.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'بانتظار الدمج',
                                    style: TextStyle(
                                      color: AppColors.successGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('العميل: $customerLabel'),
                            Text('نوع الوقود: ${request.fuelType ?? '-'}'),
                            Text('تاريخ الطلب: ${_fmt(request.orderDate)}'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                if (_canCancelMovementAction(request))
                                  OutlinedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final reason =
                                                await _promptForCancellationReason(
                                              title: 'إلغاء الطلب',
                                              actionLabel: 'تأكيد الإلغاء',
                                            );
                                            if (reason == null ||
                                                reason.trim().isEmpty) {
                                              return;
                                            }
                                            await _cancelMovementOrder(
                                              request,
                                              reason: reason,
                                            );
                                          },
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('إلغاء'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (confirmContext) =>
                                                AlertDialog(
                                              title: const Text(
                                                'حذف طلب العميل',
                                              ),
                                              content: const Text(
                                                'سيتم حذف الطلب نهائيًا. هل تريد المتابعة؟',
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    confirmContext,
                                                    false,
                                                  ),
                                                  child: const Text('إلغاء'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    confirmContext,
                                                    true,
                                                  ),
                                                  child: const Text('حذف'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true) return;
                                          await _deleteCustomerRequest(request);
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('حذف'),
                                ),
                                if (busy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _driversTrackingTab() {
    final activeOrders = _orders
        .where(
          (order) =>
              order.isMovementDirected &&
              (order.driverId != null || order.driverName != null) &&
              !_isOrderCompleted(order) &&
              !_hasMovementArrived(order),
        )
        .toList();

    final ordersByDriver = <String, List<Order>>{};
    for (final order in activeOrders) {
      final key =
          order.driverId ??
          order.vehicleNumber ??
          order.driverName ??
          'unknown';
      ordersByDriver.putIfAbsent(key, () => <Order>[]).add(order);
    }

    final drivers = _drivers.toList()..sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final key = driver.id.isNotEmpty
            ? driver.id
            : (driver.vehicleNumber ?? driver.name);
        final driverOrders = ordersByDriver[key] ?? const <Order>[];
        final isBusy = driverOrders.isNotEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            title: Text(
              driver.vehicleNumber?.trim().isNotEmpty == true
                  ? '${driver.name} - ${driver.vehicleNumber}'
                  : driver.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'عدد الطلبات: ${driverOrders.length} • ${isBusy ? 'مشغول' : 'متاح'}',
              style: TextStyle(
                color: isBusy
                    ? AppColors.warningOrange
                    : AppColors.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              isBusy ? Icons.timelapse_rounded : Icons.check_circle_rounded,
              color: isBusy ? AppColors.warningOrange : AppColors.successGreen,
            ),
            children: <Widget>[
              if (driverOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('لا توجد طلبات نشطة حالياً.'),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: driverOrders.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, orderIndex) {
                    final order = driverOrders[orderIndex];
                    final arrivalDate =
                        order.movementExpectedArrivalDate ?? order.arrivalDate;
                    final arrivalDateTime = _combineDateAndTime(
                      arrivalDate,
                      order.arrivalTime,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('تفاصيل الطلب'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('المورد: ${order.supplierName}'),
                                Text(
                                  'رقم طلب المورد: ${order.supplierOrderNumber ?? '-'}',
                                ),
                                Text(
                                  'العميل: ${order.movementCustomerName ?? '-'}',
                                ),
                              ],
                            ),
                            actions: <Widget>[
                              if (_ownerApprovalUser)
                                TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    await _openMovementOrderForEdit(order);
                                  },
                                  icon: const Icon(Icons.edit_note_rounded),
                                  label: const Text('تعديل الطلب'),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('إلغاء'),
                              ),
                            ],
                          ),
                        );
                      },
                      title: Text(
                        order.orderNumber.isNotEmpty
                            ? order.orderNumber
                            : order.supplierOrderNumber ?? 'طلب بدون رقم',
                      ),
                      subtitle: Text('تاريخ الوصول: ${_fmt(arrivalDate)}'),
                      trailing: Text(
                        _formatRemainingTime(arrivalDateTime),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MovementTabBarHeader extends SliverPersistentHeaderDelegate {
  _MovementTabBarHeader({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(color: Colors.transparent, child: child);
  }

  @override
  bool shouldRebuild(covariant _MovementTabBarHeader oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

enum _MovementReportPeriodType { today, day, range, month }

extension _MovementReportPeriodTypeLabel on _MovementReportPeriodType {
  String get label {
    switch (this) {
      case _MovementReportPeriodType.today:
        return 'طلبات اليوم الحالي';
      case _MovementReportPeriodType.day:
        return 'يومي بتاريخ محدد';
      case _MovementReportPeriodType.range:
        return 'فترة من إلى';
      case _MovementReportPeriodType.month:
        return 'شهري';
    }
  }
}

enum _MovementReportAudience { supplier, customer, completed }

extension _MovementReportAudienceLabel on _MovementReportAudience {
  String get label {
    switch (this) {
      case _MovementReportAudience.supplier:
        return 'طلبات مورد';
      case _MovementReportAudience.customer:
        return 'طلبات عميل';
      case _MovementReportAudience.completed:
        return 'طلبات مكتملة';
    }
  }
}

class _MovementReportDialogResult {
  const _MovementReportDialogResult({
    required this.periodType,
    required this.audience,
    required this.selectedDay,
    required this.rangeStart,
    required this.rangeEnd,
    required this.selectedMonth,
  });

  final _MovementReportPeriodType periodType;
  final _MovementReportAudience audience;
  final DateTime selectedDay;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime selectedMonth;

  DateTime get startDate {
    switch (periodType) {
      case _MovementReportPeriodType.today:
      case _MovementReportPeriodType.day:
        return DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      case _MovementReportPeriodType.range:
        return DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      case _MovementReportPeriodType.month:
        return DateTime(selectedMonth.year, selectedMonth.month);
    }
  }

  DateTime get endDate {
    switch (periodType) {
      case _MovementReportPeriodType.today:
      case _MovementReportPeriodType.day:
        return DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      case _MovementReportPeriodType.range:
        return DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      case _MovementReportPeriodType.month:
        return DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    }
  }

  String get reportTitle {
    switch (periodType) {
      case _MovementReportPeriodType.today:
        return 'تقرير حركة طلبات اليوم';
      case _MovementReportPeriodType.day:
        return 'التقرير اليومي لحركة الطلبات';
      case _MovementReportPeriodType.range:
        return 'تقرير فترة لحركة الطلبات';
      case _MovementReportPeriodType.month:
        return 'التقرير الشهري لحركة الطلبات';
    }
  }

  String get audienceLabel => audience.label;

  String get periodLabel {
    switch (periodType) {
      case _MovementReportPeriodType.today:
      case _MovementReportPeriodType.day:
        return DateFormat('yyyy/MM/dd').format(selectedDay);
      case _MovementReportPeriodType.range:
        return '${DateFormat('yyyy/MM/dd').format(startDate)} - ${DateFormat('yyyy/MM/dd').format(endDate)}';
      case _MovementReportPeriodType.month:
        return DateFormat('yyyy/MM').format(selectedMonth);
    }
  }

  String get fileStamp {
    switch (periodType) {
      case _MovementReportPeriodType.today:
      case _MovementReportPeriodType.day:
        return DateFormat('yyyyMMdd').format(selectedDay);
      case _MovementReportPeriodType.range:
        return '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      case _MovementReportPeriodType.month:
        return DateFormat('yyyyMM').format(selectedMonth);
    }
  }
}
