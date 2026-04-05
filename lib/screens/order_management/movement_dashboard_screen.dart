import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
  bool _booting = true;
  bool _submitting = false;
  bool _autofilling = false;
  bool _refreshing = false;
  String? _busyOrderId;

  bool get _movementUser =>
      context.read<AuthProvider>().user?.role == 'movement';

  Supplier? get _selectedSupplier {
    for (final supplier in _suppliers) {
      if (supplier.id == _supplierId) return supplier;
    }
    return null;
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
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final suppliers = context.read<SupplierProvider>();
    final customers = context.read<CustomerProvider>();
    final drivers = context.read<DriverProvider>();

    await Future.wait(<Future<void>>[
      suppliers.fetchSuppliers(filters: <String, dynamic>{'isActive': 'true'}),
      customers.fetchCustomers(fetchAll: true),
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
    final orders = await context.read<OrderProvider>().fetchOrdersSnapshot(
      filters: <String, dynamic>{
        'entryChannel': 'movement',
        'orderSource': 'مورد',
      },
    );
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _refreshing = false;
    });
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

  String _normalizeDigits(String value) {
    return value.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (m) => _arabicDigitMap[m.group(0)] ?? m.group(0)!,
    );
  }

  Map<String, String?> _extractTimesFromText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return <String, String?>{'loading': null, 'arrival': null};
    }

    final normalized = _normalizeDigits(text);
    final timeRegex = RegExp(r'\b(\d{1,2}[:.]\d{2})(?::\d{2})?\b');
    final timeWithSecondsRegex =
        RegExp(r'\b(\d{1,2}[:.]\d{2})(?::\d{2})?\b');

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
          } else if (arrival == null) {
            arrival = time;
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
    final targetTokens =
        target.split(' ').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
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
        if (target.length >= 4 && (item.startsWith(target) || target.startsWith(item))) {
          score = score < 80 ? 80 : score;
          continue;
        }
        if (target.length >= 4 && (item.contains(target) || target.contains(item))) {
          score = score < 60 ? 60 : score;
        }
      }

      if (targetDigits.isNotEmpty) {
        final taxDigits = supplier.taxNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
        final commercialDigits =
            supplier.commercialNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
        final displayDigits =
            supplier.displayName.replaceAll(RegExp(r'\D'), '');
        if (taxDigits.isNotEmpty && taxDigits == targetDigits) {
          score = score < 95 ? 95 : score;
        } else if (commercialDigits.isNotEmpty && commercialDigits == targetDigits) {
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
    final normalized = raw.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (m) => _arabicDigitMap[m.group(0)] ?? m.group(0)!,
    );
    final match = RegExp(r'(\\d{1,2})[:.](\\d{1,2})').firstMatch(normalized);
    if (match == null) return null;
    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    if (h == null || m == null) return null;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
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
      final warnings = (response?['warnings'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList();
      if (draft is Map) {
        final mapDraft = Map<String, dynamic>.from(draft);
        final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : null;
        final rawSupplierName =
            _text(mapDraft['supplierName']) ?? _text(meta?['supplierNameFromFile']);
        final supplierCode = _text(meta?['supplierCode']) ?? _text(mapDraft['supplierCode']);
        Supplier? supplier =
            rawSupplierName == null ? null : _matchSupplier(rawSupplierName);
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

          final supplierOrderNumber = _text(mapDraft['supplierOrderNumber']);
          if (supplierOrderNumber != null) {
            _supplierOrderNumber.text = supplierOrderNumber;
            applied += 1;
          }

          final quantityText = _text(mapDraft['quantity']);
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
            final suggestedArea =
                _text(suggestedLocation?['area'] ?? suggestedLocation?['region']);
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
            final fallback = _time(metaMap['deliveryTimes']?['loadingTime'] ??
                metaMap['fallbackTimes']?['loadingTime'] ??
                (candidates.isNotEmpty ? candidates.first : null));
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
            final fallback = _time(metaMap['deliveryTimes']?['arrivalTime'] ??
                metaMap['fallbackTimes']?['arrivalTime'] ??
                (candidates.length > 1 ? candidates[1] : null));
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final supplier = _selectedSupplier;
    final qty = double.tryParse(_quantity.text.trim());
    if (supplier == null || qty == null || qty <= 0) {
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
      supplierOrderNumber: _supplierOrderNumber.text.trim().isEmpty
          ? null
          : _supplierOrderNumber.text.trim(),
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
      fuelType: _fuelType,
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
      _snack(context.read<OrderProvider>().error ?? 'فشل تحديث السائق.', AppColors.errorRed);
      return;
    }
    _snack('تم تحديث السائق.', AppColors.successGreen);
    await _loadOrders(showLoader: false);
  }

  Future<void> _dispatch(
    Order order, {
    required String customerId,
    required DateTime customerRequestDate,
    required DateTime expectedArrivalDate,
    required String driverId,
    required String requestType,
  }) async {
    setState(() => _busyOrderId = order.id);
    final success = await context.read<OrderProvider>().dispatchMovementOrder(
      supplierOrderId: order.id,
      customerId: customerId,
      customerRequestDate: customerRequestDate,
      expectedArrivalDate: expectedArrivalDate,
      driverId: driverId,
      requestType: requestType,
    );
    if (!mounted) return;
    setState(() => _busyOrderId = null);
    if (!success) {
      _snack(context.read<OrderProvider>().error ?? 'فشل توجيه الطلب.', AppColors.errorRed);
      return;
    }
    _snack(
      order.isMovementDirected ? 'تم تعديل التوجيه.' : 'تم توجيه الطلب.',
      AppColors.successGreen,
    );
    await _loadOrders(showLoader: false);
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _fmt(DateTime value) => DateFormat('yyyy/MM/dd').format(value);

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
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اختيار سائق'),
          content: DropdownButtonFormField<String>(
            initialValue: driverId,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
            onChanged: (value) => setDialogState(() => driverId = value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: driverId == null
                  ? null
                  : () => Navigator.pop(dialogContext, driverId),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null || result == order.driverId) return;
    await _updateDriver(order, result);
  }

  Future<void> _dispatchDialog(Order order, {bool edit = false}) async {
    String? customerId = order.movementCustomerId;
    String? driverId = order.driverId;
    String requestType = order.requestType ?? 'شراء';
    DateTime customerRequestDate =
        order.movementCustomerRequestDate ?? DateTime.now();
    DateTime expectedArrivalDate = order.movementExpectedArrivalDate ??
        customerRequestDate.add(const Duration(days: 1));

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

          return AlertDialog(
            title: Text(edit ? 'تعديل التوجيه' : 'توجيه الطلب'),
            content: SizedBox(
              width: 420,
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
                      onChanged: (value) => setDialogState(() => driverId = value),
                    ),
                    const SizedBox(height: 12),
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
                              child: Text('${customer.name} (${customer.code})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => customerId = value),
                    ),
                    if (customerId != null) ...<Widget>[
                      const SizedBox(height: 12),
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
                        onChanged: (value) => setDialogState(
                          () => requestType = value ?? 'شراء',
                        ),
                      ),
                    ],
                    if (!edit) ...<Widget>[
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

    if (!mounted || payload == null) return;
    await _dispatch(
      order,
      customerId: payload['customerId'] as String,
      driverId: payload['driverId'] as String,
      requestType: payload['requestType'] as String? ?? 'شراء',
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
        borderSide: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isWideWeb ? 18 : 20),
        borderSide: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.10)),
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
                        fontWeight: FontWeight.w900,
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
    IconData icon,
  ) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return AppSurfaceCard(
      padding: EdgeInsets.all(isWideWeb ? 12 : 14),
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
            width: isWideWeb ? 42 : 46,
            height: isWideWeb ? 42 : 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(isWideWeb ? 14 : 16),
            ),
            child: Icon(icon, color: color, size: isWideWeb ? 22 : 24),
          ),
          SizedBox(width: isWideWeb ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isWideWeb ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mediumGray,
                  ),
                ),
                SizedBox(height: isWideWeb ? 4 : 6),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: isWideWeb ? 22 : 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    required bool compact,
  }) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(0),
      color: Colors.white.withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(isWideWeb ? 28 : 32),
      border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDarkBlue.withValues(alpha: 0.10),
          blurRadius: 34,
          offset: const Offset(0, 20),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isWideWeb ? 28 : 32),
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
        padding: EdgeInsets.all(compact ? 18 : (isWideWeb ? 20 : 24)),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _heroText(),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _heroChip('إجمالي الطلبات', '$total', Icons.inventory_2_rounded),
                      _heroChip('بانتظار السائق', '$pendingDriver', Icons.drive_eta_rounded),
                      _heroChip('بانتظار التوجيه', '$pendingDispatch', Icons.near_me_rounded),
                      _heroChip('طلبات موجهة', '$directed', Icons.task_alt_rounded),
                    ],
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(flex: 6, child: _heroText()),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: <Widget>[
                        _heroChip('إجمالي الطلبات', '$total', Icons.inventory_2_rounded),
                        _heroChip('بانتظار السائق', '$pendingDriver', Icons.drive_eta_rounded),
                        _heroChip('بانتظار التوجيه', '$pendingDispatch', Icons.near_me_rounded),
                        _heroChip('طلبات موجهة', '$directed', Icons.task_alt_rounded),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _heroText() {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'لوحة حركة الطلبات',
          style: TextStyle(
            color: Colors.white,
            fontSize: isWideWeb ? 22 : 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: isWideWeb ? 6 : 8),
        Text(
          'متابعة طلبات المورد، تعيين السائقين، وتنفيذ التوجيهات من شاشة واحدة بتصميم أوضح وأكثر مهنية.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isWideWeb ? 13 : 14,
            height: 1.7,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _heroChip(String label, String value, IconData icon) {
    final bool isWideWeb = MediaQuery.sizeOf(context).width >= 1100;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWideWeb ? 12 : 14,
        vertical: isWideWeb ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(isWideWeb ? 16 : 18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: isWideWeb ? 17 : 18),
          SizedBox(width: isWideWeb ? 7 : 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isWideWeb ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: isWideWeb ? 8 : 10),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWideWeb ? 15 : 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
                      fontWeight: FontWeight.w900,
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
    final bool isWideWebScreen = screenWidth >= 1100;
    final double pageMaxWidth = screenWidth >= 1700
        ? 1480
        : screenWidth >= 1450
        ? 1380
        : screenWidth >= 1100
        ? 1260
        : screenWidth;
    final pendingDriver = _orders.where((o) => o.isMovementPendingDriver).length;
    final pendingDispatch = _orders.where((o) => o.isMovementPendingDispatch).length;
    final directed = _orders.where((o) => o.isMovementDirected).length;

    return DefaultTabController(
      length: 3,
      child: PopScope(
        canPop: !_movementUser,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: isWideWebScreen ? 78 : kToolbarHeight,
            automaticallyImplyLeading: !_movementUser,
            centerTitle: true,
            title: Text(
              'حركة الطلبات',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isWideWebScreen ? 28 : 21,
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
                  width: isWideWebScreen ? 42 : 38,
                  height: isWideWebScreen ? 42 : 38,
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
                    iconSize: isWideWebScreen ? 20 : 18,
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
                    width: isWideWebScreen ? 42 : 38,
                    height: isWideWebScreen ? 42 : 38,
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
                      iconSize: isWideWebScreen ? 20 : 18,
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
                      maxWidth: isWideWebScreen ? 920 : screenWidth,
                    ),
                    child: Container(
                      height: isWideWebScreen ? 64 : 56,
                      padding: EdgeInsets.all(isWideWebScreen ? 7 : 5),
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
                            height: isWideWebScreen ? 50 : 44,
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.add_box_rounded,
                              size: isWideWebScreen ? 19 : 18,
                            ),
                            text: 'إدخال',
                          ),
                          Tab(
                            height: isWideWebScreen ? 50 : 44,
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.history_rounded,
                              size: isWideWebScreen ? 19 : 18,
                            ),
                            text: 'السجل',
                          ),
                          Tab(
                            height: isWideWebScreen ? 50 : 44,
                            iconMargin: const EdgeInsets.only(bottom: 4),
                            icon: Icon(
                              Icons.route_rounded,
                              size: isWideWebScreen ? 19 : 18,
                            ),
                            text: 'التوجيهات',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Stack(
            children: <Widget>[
              const AppSoftBackground(),
              if (_booting)
                const Center(child: CircularProgressIndicator())
              else
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxWidth < 900;
                    final bool isWideWeb = constraints.maxWidth >= 1100;
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: pageMaxWidth),
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 14 : (isWideWeb ? 16 : 18),
                                compact ? 14 : (isWideWeb ? 16 : 18),
                                compact ? 14 : (isWideWeb ? 16 : 18),
                                10,
                              ),
                              child: Column(
                                children: <Widget>[
                                  _heroSection(
                                    total: _orders.length,
                                    pendingDriver: pendingDriver,
                                    pendingDispatch: pendingDispatch,
                                    directed: directed,
                                    compact: compact,
                                  ),
                                  SizedBox(height: isWideWeb ? 14 : 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      spacing: isWideWeb ? 10 : 12,
                                      runSpacing: isWideWeb ? 10 : 12,
                                      children: <Widget>[
                                        _summary(
                                          'إجمالي',
                                          _orders.length,
                                          AppColors.primaryBlue,
                                          Icons.inventory_2_rounded,
                                        ),
                                        _summary(
                                          'بانتظار سائق',
                                          pendingDriver,
                                          AppColors.warningOrange,
                                          Icons.drive_eta_rounded,
                                        ),
                                        _summary(
                                          'بانتظار التوجيه',
                                          pendingDispatch,
                                          AppColors.infoBlue,
                                          Icons.near_me_rounded,
                                        ),
                                        _summary(
                                          'موجه',
                                          directed,
                                          AppColors.successGreen,
                                          Icons.task_alt_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: <Widget>[
                                  _entryTab(),
                                  _historyTab(),
                                  _dispatchesTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (_autofilling) _autofillLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(String label, int value, Color color, IconData icon) {
    final double width = MediaQuery.sizeOf(context).width;
    final double cardWidth = width >= 1400 ? 198 : width >= 1100 ? 206 : 220;
    return SizedBox(
      width: cardWidth,
      child: _metricCard(label, value, color, icon),
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
                subtitle: 'ارفع ملف المورد لاستخراج البيانات تلقائيًا عند توفرها.',
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
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(isDesktop ? 16 : 18),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: isDesktop ? 40 : 42,
                            height: isDesktop ? 40 : 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.10),
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
                              _document?.name ?? 'لم يتم إرفاق أي ملف بعد',
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
                    const SizedBox(height: 14),
                    Align(
                      alignment: isDesktop
                          ? Alignment.centerRight
                          : Alignment.center,
                      child: GradientButton(
                        width: isDesktop ? 260 : double.infinity,
                        height: isDesktop ? 44 : 50,
                        borderRadius: 18,
                        text: _document == null ? 'إرفاق مستند' : 'تحديث المستند',
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
                          validator: (String? value) =>
                              value == null ? 'اختر المورد' : null,
                        ),
                        TextFormField(
                          controller: _supplierOrderNumber,
                          decoration: _glassInputDecoration(
                            'رقم طلب المورد',
                            icon: Icons.confirmation_number_rounded,
                          ),
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
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: _glassInputDecoration(
                            'الكمية',
                            icon: Icons.scale_rounded,
                            suffixText: 'لتر',
                          ),
                          validator: (String? value) =>
                              (double.tryParse((value ?? '').trim()) ?? 0) <= 0
                              ? 'أدخل كمية صحيحة'
                              : null,
                        ),
                        TextFormField(
                          controller: _city,
                          decoration: _glassInputDecoration(
                            'المدينة',
                            icon: Icons.location_city_rounded,
                          ),
                          validator: (String? value) => (value ?? '').trim().isEmpty
                              ? 'المدينة مطلوبة'
                              : null,
                        ),
                        TextFormField(
                          controller: _area,
                          decoration: _glassInputDecoration(
                            'المنطقة',
                            icon: Icons.map_rounded,
                          ),
                          validator: (String? value) => (value ?? '').trim().isEmpty
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: isDesktop ? 16 : null,
                              color: AppColors.primaryDarkBlue,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _responsiveFields(
                      columns: isDesktop ? 3 : isTablet ? 2 : 1,
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
                        helperText: 'أي تفاصيل إضافية مرتبطة بالطلب أو التوريد.',
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
    if (_orders.isEmpty) {
      return const Center(child: Text('لا توجد طلبات حركة حتى الآن.'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        isWideWeb ? 14 : 16,
        0,
        isWideWeb ? 14 : 16,
        isWideWeb ? 20 : 24,
      ),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index];
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _stateColor(order).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_stateLabel(order), style: TextStyle(color: _stateColor(order), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('المورد: ${order.supplierName}'),
                Text('رقم طلب المورد: ${order.supplierOrderNumber ?? '-'}'),
                Text('الكمية: ${order.quantity ?? 0} ${order.unit ?? ''}'),
                Text('السائق: ${order.driverName ?? 'لم يحدد'}'),
                if (order.movementCustomerName != null) Text('العميل: ${order.movementCustomerName}'),
                if (order.movementMergedOrderNumber != null) Text('رقم الدمج: ${order.movementMergedOrderNumber}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (!order.isMovementDirected)
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _driverDialog(order),
                        icon: const Icon(Icons.drive_eta_outlined),
                        label: Text(order.driverId == null ? 'اختيار سائق' : 'تغيير السائق'),
                      ),
                    if (order.isMovementPendingDispatch)
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _dispatchDialog(order),
                        icon: const Icon(Icons.near_me_outlined),
                        label: const Text('توجيه'),
                      ),
                    if (order.isMovementDirected)
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _dispatchDialog(order, edit: true),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل التوجيه'),
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
    final directed = _orders.where((order) => order.isMovementDirected).toList();
    if (directed.isEmpty) {
      return const Center(child: Text('لا توجد توجيهات مسجلة.'));
    }

    final grouped = <String, List<Order>>{};
    for (final order in directed) {
      final key = order.driverId ?? order.vehicleNumber ?? order.driverName ?? 'unknown';
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
            subtitle: Text('${first.driverName ?? 'بدون سائق'} • ${orders.length} طلبات'),
            children: orders
                .map(
                  (order) => ListTile(
                    title: Text(order.orderNumber),
                    subtitle: Text('العميل: ${order.movementCustomerName ?? 'غير محدد'}'),
                    trailing: Text('${order.quantity ?? 0} ${order.unit ?? ''}'),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
