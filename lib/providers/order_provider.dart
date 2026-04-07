import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/services/firebase_storage_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class OrderProvider with ChangeNotifier {
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  Order? _selectedOrder;
  List<Activity> _activities = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _filters = {};
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalOrders = 0;
  Map<String, Order> _ordersCache = {};

  int _intOrFallback(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic>? _extractPagination(dynamic payload) {
    if (payload is! Map) return null;
    final map = Map<String, dynamic>.from(payload as Map);

    final direct = map['pagination'];
    if (direct is Map) {
      return Map<String, dynamic>.from(direct);
    }

    final nested = map['data'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      final nestedPagination = nestedMap['pagination'];
      if (nestedPagination is Map) {
        return Map<String, dynamic>.from(nestedPagination);
      }
    }

    return null;
  }

  String? _serializeFilterValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }

  Map<String, String> _normalizeQueryFilters(Map<String, dynamic>? filters) {
    if (filters == null || filters.isEmpty) return const {};

    final normalized = <String, String>{};
    filters.forEach((key, value) {
      final serialized = _serializeFilterValue(value);
      if (serialized != null) {
        normalized[key] = serialized;
      }
    });
    return normalized;
  }

  Uri _ordersUri({int page = 1, Map<String, dynamic>? filters}) {
    final queryParameters = <String, String>{
      'page': page.toString(),
      ..._normalizeQueryFilters(filters),
    };

    return Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}',
    ).replace(queryParameters: queryParameters);
  }

  DateTime? _coerceDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  DateTime _normalizeDateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Map<String, String> _multipartHeaders() {
    final headers = Map<String, String>.from(ApiService.headers);
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';
    return headers;
  }

  Future<List<Map<String, dynamic>>> _uploadOrderAttachments(
    String orderKey,
    List<PlatformFile> files,
  ) async {
    final attachments = <Map<String, dynamic>>[];
    for (final file in files) {
      attachments.add(
        await FirebaseStorageService.uploadOrderAttachment(
          orderKey: orderKey,
          file: file,
        ),
      );
    }
    return attachments;
  }

  List<PlatformFile> _extractPlatformFiles(List<Object>? attachments) {
    if (attachments == null || attachments.isEmpty) return const [];
    return attachments.whereType<PlatformFile>().toList();
  }

  List<String> _extractLegacyAttachmentPaths(List<Object>? attachments) {
    if (attachments == null || attachments.isEmpty) return const [];
    return attachments
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();
  }

  List<Order> _parseOrdersFromPayload(dynamic payload) {
    final orders = <Order>[];
    final seenIds = <String>{};

    void visit(dynamic value) {
      if (value == null) return;

      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }

      if (value is! Map) return;

      final map = Map<String, dynamic>.from(value as Map);
      final hasOrderShape =
          (map.containsKey('_id') || map.containsKey('id')) &&
          (map.containsKey('orderDate') ||
              map.containsKey('orderSource') ||
              map.containsKey('mergeStatus') ||
              map.containsKey('loadingDate') ||
              map.containsKey('arrivalDate') ||
              map.containsKey('status') ||
              map.containsKey('supplierName') ||
              map.containsKey('customerName'));

      if (hasOrderShape) {
        try {
          final order = Order.fromJson(map);
          if (order.id.isNotEmpty && seenIds.add(order.id)) {
            orders.add(order);
          }
        } catch (_) {
          // Ignore non-order maps.
        }
      }

      for (final key in const [
        'order',
        'mergedOrder',
        'supplierOrder',
        'customerOrder',
        'releasedOrders',
        'orders',
        'data',
      ]) {
        if (map.containsKey(key)) {
          visit(map[key]);
        }
      }
    }

    visit(payload);
    return orders;
  }

  void _upsertOrderLocally(Order order) {
    final index = _orders.indexWhere((existing) => existing.id == order.id);
    if (index == -1) {
      _orders.insert(0, order);
    } else {
      _orders[index] = order;
    }

    if (_selectedOrder?.id == order.id) {
      _selectedOrder = order;
    }

    _ordersCache[order.id] = order;

    if (_filteredOrders.isNotEmpty) {
      final filteredIndex = _filteredOrders.indexWhere(
        (existing) => existing.id == order.id,
      );
      if (filteredIndex != -1) {
        _filteredOrders[filteredIndex] = order;
      }
    }
  }

  List<Order> _syncOrdersFromResponse(dynamic payload) {
    final orders = _parseOrdersFromPayload(payload);
    for (final order in orders) {
      _upsertOrderLocally(order);
    }
    return orders;
  }

  List<Order> get orders => _filters.isNotEmpty ? _filteredOrders : _orders;
  Order? get selectedOrder => _selectedOrder;
  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get filters => _filters;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalOrders => _totalOrders;

  Future<Map<String, dynamic>?> importSupplierOrdersFromDocuments({
    required List<PlatformFile> files,
  }) async {
    _error = null;

    if (files.isEmpty) {
      _error = 'لم يتم اختيار ملفات للاستيراد';
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderImportDocuments}',
        ),
      );

      request.headers.addAll(_multipartHeaders());

      for (final file in files) {
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'documents',
              file.bytes!,
              filename: file.name,
            ),
          );
          continue;
        }

        if (file.path != null && file.path!.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'documents',
              file.path!,
              filename: file.name,
            ),
          );
        }
      }

      if (request.files.isEmpty) {
        _error = 'تعذر تجهيز الملفات للاستيراد';
        return null;
      }

      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 25));
      final dynamic payload = response.bodyBytes.isNotEmpty
          ? json.decode(utf8.decode(response.bodyBytes))
          : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = payload is Map ? payload['data'] : null;
        return data is Map<String, dynamic>
            ? data
            : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
      }

      if (payload is Map) {
        _error =
            payload['error']?.toString() ??
            payload['message']?.toString() ??
            'فشل في استيراد ملفات طلبات المورد';
      } else {
        _error = 'فشل في استيراد ملفات طلبات المورد';
      }
      return null;
    } catch (e) {
      if (e is TimeoutException) {
        _error = 'انتهت مهلة قراءة المستند. حاول مرة أخرى.';
      } else {
        _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      }
      return null;
    }
  }

  // ============================================
  // 📋 جلب الطلبات مع تحسين الدمج
  // ============================================
  Future<void> fetchOrders({
    int page = 1,
    Map<String, dynamic>? filters,
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      _error = null;
    }

    try {
      _filters = filters == null ? {} : {...filters};
      final requestFilters = <String, dynamic>{..._filters};
      String url = _ordersUri(page: page, filters: requestFilters).toString();

      if (requestFilters['forMerge'] == true) {
        requestFilters['mergeStatus'] = 'منفصل';
      }

      // 🔥 إضافة تصفية خاصة للدمج
      if (filters?['forMerge'] == true) {
        url += '&mergeStatus=منفصل';
      }

      url = _ordersUri(page: page, filters: requestFilters).toString();
      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        _orders = _parseOrdersFromPayload(data);

        // تحديث الكاش
        for (var order in _orders) {
          _ordersCache[order.id] = order;
        }

        final pagination = _extractPagination(data);
        _currentPage = _intOrFallback(pagination?['page'], page);
        _totalPages = _intOrFallback(pagination?['pages'], 1);
        _totalOrders = _intOrFallback(pagination?['total'], _orders.length);

        // Apply filters locally if needed
        _applyLocalFilters();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب البيانات');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyLocalFilters() {
    if (_filters.isEmpty) {
      _filteredOrders = _orders;
      return;
    }

    _filteredOrders = _orders.where((order) {
      bool matches = true;
      final orderDate = _normalizeDateOnly(order.orderDate);
      final startDate = _coerceDate(_filters['startDate']);
      final endDate = _coerceDate(_filters['endDate']);

      if (_filters['status'] != null && _filters['status'].isNotEmpty) {
        matches = matches && order.status == _filters['status'];
      }

      if (_filters['supplierName'] != null &&
          _filters['supplierName'].isNotEmpty) {
        matches =
            matches && order.supplierName.contains(_filters['supplierName']);
      }

      if (_filters['orderNumber'] != null &&
          _filters['orderNumber'].isNotEmpty) {
        matches =
            matches && order.orderNumber.contains(_filters['orderNumber']);
      }

      if (_filters['driverName'] != null && _filters['driverName'].isNotEmpty) {
        matches =
            matches &&
            (order.driverName?.contains(_filters['driverName']) ?? false);
      }

      if (_filters['customerName'] != null &&
          _filters['customerName'].isNotEmpty) {
        matches =
            matches &&
            (order.customer?.name.contains(_filters['customerName']) ?? false);
      }

      if (startDate != null) {
        matches = matches && !orderDate.isBefore(_normalizeDateOnly(startDate));
      }

      if (endDate != null) {
        matches = matches && !orderDate.isAfter(_normalizeDateOnly(endDate));
      }

      if (_filters['requestType'] != null &&
          _filters['requestType'].isNotEmpty) {
        matches =
            matches && order.effectiveRequestType == _filters['requestType'];
      }

      // 🔥 فلترة خاصة للدمج
      if (_filters['forMerge'] == true) {
        // طلبات المورد (منفصلة أو تم التحميل) وطلبات العميل (منفصلة)
        matches =
            matches &&
            (order.mergeStatus == 'منفصل') &&
            ((order.orderSource == 'مورد' &&
                    (order.status == 'تم التحميل' ||
                        order.status == 'جاهز للتحميل')) ||
                (order.orderSource == 'عميل' &&
                    order.status == 'في انتظار التخصيص'));
      }

      return matches;
    }).toList();
  }

  Future<int> fetchOrdersCount({Map<String, dynamic>? filters}) async {
    try {
      final requestFilters = <String, dynamic>{...?filters, 'limit': 1};
      final response = await http.get(
        _ordersUri(page: 1, filters: requestFilters),
        headers: ApiService.headers,
      );

      if (response.statusCode != 200) {
        return 0;
      }

      final data = ApiService.decodeJson(response);
      final pagination = _extractPagination(data);

      if (pagination != null) {
        return _intOrFallback(pagination['total'], 0);
      }

      return _parseOrdersFromPayload(data).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Order>> fetchOrdersSnapshot({
    Map<String, dynamic>? filters,
    int page = 1,
  }) async {
    try {
      final response = await http.get(
        _ordersUri(page: page, filters: filters),
        headers: ApiService.headers,
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في جلب البيانات');
      }

      final data = ApiService.decodeJson(response);
      return _parseOrdersFromPayload(data);
    } catch (e) {
      _error = e.toString();
      return const <Order>[];
    }
  }

  // ============================================
  // 📄 جلب طلب محدد
  // ============================================
  Future<void> fetchOrderById(String id, {bool silent = false}) async {
    if (_ordersCache.containsKey(id)) {
      _selectedOrder = _ordersCache[id];
      if (!silent) {
        notifyListeners();
      }
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Order order;
        if (data['order'] != null) {
          order = Order.fromJson(data['order']);
        } else if (data['data'] != null) {
          order = Order.fromJson(data['data']);
        } else {
          order = Order.fromJson(data);
        }

        _selectedOrder = order;
        _ordersCache[id] = order;

        List<dynamic> activitiesData = [];
        if (data['activities'] is List) {
          activitiesData = data['activities'];
        }

        _activities = activitiesData.map((e) => Activity.fromJson(e)).toList();

        if (!silent) {
          _isLoading = false;
          notifyListeners();
        }
      } else {
        throw Exception('فشل في جلب بيانات الطلب');
      }
    } catch (e) {
      _error = e.toString();
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ============================================
  // ✏️ إنشاء طلب جديد
  // ============================================
  Future<bool> createOrder(
    Order order,
    List<Object>? attachments,
    String? customerId,
    String? driverId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orders}'),
      );

      // =========================
      // Headers
      // =========================
      request.headers.addAll(_multipartHeaders());

      // =========================
      // الحقول الأساسية
      // =========================
      if (order.supplierId?.isNotEmpty == true) {
        request.fields['supplier'] = order.supplierId!;
      }

      if (order.supplierName.isNotEmpty) {
        request.fields['supplierName'] = order.supplierName;
      }

      if (order.portalCustomerId?.isNotEmpty == true) {
        request.fields['portalCustomer'] = order.portalCustomerId!;
      }

      if (order.portalCustomerName?.isNotEmpty == true) {
        request.fields['portalCustomerName'] = order.portalCustomerName!;
      }

      if (order.destinationStationId?.isNotEmpty == true) {
        request.fields['destinationStationId'] = order.destinationStationId!;
      }

      if (order.destinationStationName?.isNotEmpty == true) {
        request.fields['destinationStationName'] = order.destinationStationName!;
      }

      if (order.carrierName?.isNotEmpty == true) {
        request.fields['carrierName'] = order.carrierName!;
      }

      if (order.requestType != null) {
        request.fields['requestType'] = order.requestType!;
      }

      request.fields['orderSource'] = order.orderSource;
      request.fields['entryChannel'] = order.entryChannel;
      request.fields['orderDate'] = order.orderDate.toIso8601String();
      request.fields['loadingDate'] = order.loadingDate.toIso8601String();
      request.fields['loadingTime'] = order.loadingTime;
      request.fields['arrivalDate'] = order.arrivalDate.toIso8601String();
      request.fields['arrivalTime'] = order.arrivalTime;

      // =========================
      // 📍 الموقع
      // =========================
      request.fields['city'] = order.city ?? 'غير محدد';
      request.fields['area'] = order.area ?? 'غير محدد';
      request.fields['address'] = order.address?.isNotEmpty == true
          ? order.address!
          : '${order.city ?? ''} - ${order.area ?? ''}';

      // =========================
      // 🔢 رقم طلب المورد (فريد)
      // =========================
      if (order.supplierOrderNumber?.isNotEmpty == true) {
        request.fields['supplierOrderNumber'] = order.supplierOrderNumber!
            .trim();
      }

      // =========================
      // 👤 العميل
      // =========================
      if (customerId?.isNotEmpty == true) {
        request.fields['customer'] = customerId!;
      }

      // =========================
      // 🚚 السائق
      // =========================
      if (driverId?.isNotEmpty == true) {
        request.fields['driver'] = driverId!;
      }

      if (order.driverName?.isNotEmpty == true) {
        request.fields['driverName'] = order.driverName!;
      }

      if (order.driverPhone?.isNotEmpty == true) {
        request.fields['driverPhone'] = order.driverPhone!;
      }

      if (order.vehicleNumber?.isNotEmpty == true) {
        request.fields['vehicleNumber'] = order.vehicleNumber!;
      }

      // =========================
      // ⛽ الوقود
      // =========================
      if (order.fuelType?.isNotEmpty == true) {
        request.fields['fuelType'] = order.fuelType!;
      }

      if (order.quantity != null) {
        request.fields['quantity'] = order.quantity!.toString();
      }

      if (order.unit?.isNotEmpty == true) {
        request.fields['unit'] = order.unit!;
      }

      if (order.unitPrice != null) {
        request.fields['unitPrice'] = order.unitPrice!.toString();
      }

      if (order.totalPrice != null) {
        request.fields['totalPrice'] = order.totalPrice!.toString();
      }

      if (order.vatRate != null) {
        request.fields['vatRate'] = order.vatRate!.toString();
      }

      if (order.vatAmount != null) {
        request.fields['vatAmount'] = order.vatAmount!.toString();
      }

      if (order.totalPriceWithVat != null) {
        request.fields['totalPriceWithVat'] = order.totalPriceWithVat!
            .toString();
      }

      if (order.transportSourceCity?.trim().isNotEmpty == true) {
        request.fields['transportSourceCity'] = order.transportSourceCity!
            .trim();
      }

      if (order.transportCapacityLiters != null) {
        request.fields['transportCapacityLiters'] = order
            .transportCapacityLiters!
            .toString();
      }

      if (order.pricingSnapshot != null) {
        request.fields['pricingSnapshot'] = json.encode(order.pricingSnapshot);
      }

      if (order.transportPricingOverride != null) {
        request.fields['transportPricingOverride'] = json.encode(
          order.transportPricingOverride,
        );
      }

      // =========================
      // 📝 ملاحظات
      // =========================
      if (order.notes?.isNotEmpty == true) {
        request.fields['notes'] = order.notes!;
      }

      final firebaseAttachments = _extractPlatformFiles(attachments);
      if (firebaseAttachments.isNotEmpty) {
        final orderKey = order.id.isNotEmpty
            ? order.id
            : 'order-${DateTime.now().millisecondsSinceEpoch}';
        final uploadedAttachments = await _uploadOrderAttachments(
          orderKey,
          firebaseAttachments,
        );
        request.fields['attachmentUrls'] = json.encode(uploadedAttachments);
      }

      // =========================
      // 🖼️ لوجو الشركة
      // =========================
      if (order.companyLogo?.isNotEmpty == true) {
        try {
          request.files.add(
            await http.MultipartFile.fromPath(
              'companyLogo',
              order.companyLogo!,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Error adding company logo: $e');
        }
      }

      // =========================
      // 📎 المرفقات
      // =========================
      final legacyAttachmentPaths = _extractLegacyAttachmentPaths(attachments);
      if (legacyAttachmentPaths.isNotEmpty) {
        for (final path in legacyAttachmentPaths) {
          try {
            request.files.add(
              await http.MultipartFile.fromPath('attachments', path),
            );
          } catch (e) {
            debugPrint('⚠️ Error adding attachment $path: $e');
          }
        }
      }

      // =========================
      // 🚀 إرسال الطلب
      // =========================
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // =========================
      // ✅ Success
      // =========================
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final newOrder = Order.fromJson(data['order'] ?? data);

        _orders.insert(0, newOrder);
        _ordersCache[newOrder.id] = newOrder;

        _isLoading = false;
        notifyListeners();
        return true;
      }

      // =========================
      // ❌ Error handling
      // =========================
      final errorData = ApiService.decodeJson(response);

      if (errorData['error'] != null &&
          errorData['error'].toString().contains('رقم طلب المورد')) {
        _error = '❌ رقم طلب المورد مستخدم مسبقًا';
      } else {
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل إنشاء الطلب';
      }

      debugPrint('❌ ERROR CREATING ORDER');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, s) {
      debugPrint('❌ EXCEPTION IN CREATE ORDER: $e');
      debugPrintStack(stackTrace: s);
      _error = 'خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOrderLimited(
    String id,
    Map<String, dynamic> updates,
    List<Object>? newAttachments,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ✅ الحقول المسموح بها (أضفنا customer + location اختياري)
      final allowedUpdates = [
        'customer',
        'driver',
        'driverName',
        'driverPhone',
        'vehicleNumber',
        'notes',
        'supplierNotes',
        'customerNotes',
        'internalNotes',
        'actualArrivalTime',
        'loadingDuration',
        'delayReason',
        'quantity',
        'unit',
        'fuelType',
        'productType',
        'unitPrice',
        'totalPrice',
        'vatRate',
        'vatAmount',
        'totalPriceWithVat',
        'orderDate',
        'paymentMethod',
        'paymentStatus',
        'city',
        'area',
        'address',
        'loadingDate',
        'loadingTime',
        'arrivalDate',
        'arrivalTime',
        'status',
        'mergeStatus',
        'requestType',
        'requestAmount',
        'portalCustomer',
        'destinationStationId',
        'destinationStationName',
        'portalCustomerName',
        'driverEarnings',
        'distance',
        'deliveryDuration',
        'transportSourceCity',
        'transportCapacityLiters',
        'pricingSnapshot',
        'transportPricingOverride',
      ];

      final filteredUpdates = <String, dynamic>{};
      updates.forEach((key, value) {
        if (!allowedUpdates.contains(key)) return;
        if (value == null) return;
        if (value.toString().isEmpty) return;
        filteredUpdates[key] = value;
      });

      final firebaseAttachments = _extractPlatformFiles(newAttachments);
      final legacyAttachmentPaths = _extractLegacyAttachmentPaths(
        newAttachments,
      );
      final hasAttachments =
          firebaseAttachments.isNotEmpty || legacyAttachmentPaths.isNotEmpty;

      http.Response response;
      if (hasAttachments) {
        final request = http.MultipartRequest(
          'PUT',
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}'),
        );

        request.headers.addAll(_multipartHeaders());

        filteredUpdates.forEach((key, value) {
          if (value is Map || value is List) {
            request.fields[key] = json.encode(value);
          } else {
            request.fields[key] = value.toString();
          }
        });

        if (firebaseAttachments.isNotEmpty) {
          final uploadedAttachments = await _uploadOrderAttachments(
            id,
            firebaseAttachments,
          );
          request.fields['attachmentUrls'] = json.encode(uploadedAttachments);
        }

        for (final path in legacyAttachmentPaths) {
          try {
            request.files.add(
              await http.MultipartFile.fromPath('attachments', path),
            );
          } catch (e) {
            debugPrint('⚠️ Error adding attachment $path: $e');
          }
        }

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.put(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}'),
          headers: ApiService.headers,
          body: json.encode(filteredUpdates),
        );
      }

      // =========================
      // ✅ Success
      // =========================
      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Order updatedOrder;
        if (data['order'] != null) {
          updatedOrder = Order.fromJson(data['order']);
        } else if (data['data'] != null) {
          updatedOrder = Order.fromJson(data['data']);
        } else {
          updatedOrder = Order.fromJson(data);
        }

        // Update in list
        final index = _orders.indexWhere((o) => o.id == id);
        if (index != -1) {
          _orders[index] = updatedOrder;
        }

        // Update selected order
        if (_selectedOrder?.id == id) {
          _selectedOrder = updatedOrder;
        }

        // Update cache
        _ordersCache[id] = updatedOrder;

        // Update filteredOrders if exists
        if (_filteredOrders.isNotEmpty) {
          final filteredIndex = _filteredOrders.indexWhere((o) => o.id == id);
          if (filteredIndex != -1) {
            _filteredOrders[filteredIndex] = updatedOrder;
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      // =========================
      // ❌ Error
      // =========================
      final errorData = ApiService.decodeJson(response);
      _error =
          errorData['error'] ??
          errorData['message'] ??
          'فشل تحديث الطلب - الرجاء التحقق من البيانات';

      debugPrint('❌ UPDATE LIMITED FAILED: ${response.statusCode}');
      debugPrint('❌ BODY: ${response.body}');

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // 🔗 دمج الطلبات
  // ============================================
  Future<bool> mergeOrders({
    required String supplierOrderId,
    required String customerOrderId,
    String? mergedOrderNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/merge',
      );

      final response = await http.post(
        url,
        headers: ApiService.headers,
        body: jsonEncode({
          'supplierOrderId': supplierOrderId,
          'customerOrderId': customerOrderId,
          if (mergedOrderNumber != null) 'mergedOrderNumber': mergedOrderNumber,
        }),
      );

      final data = ApiService.decodeJson(response);

      if (response.statusCode == 200 && data['success'] == true) {
        // تحديث طلب المورد
        final supplierIndex = _orders.indexWhere(
          (o) => o.id == supplierOrderId,
        );
        if (supplierIndex != -1) {
          _orders[supplierIndex] = _orders[supplierIndex].copyWith(
            status: 'تم دمجه مع العميل',
            mergeStatus: 'مدمج',
            mergedAt: DateTime.now(),
          );
          _ordersCache[supplierOrderId] = _orders[supplierIndex];
        }

        // تحديث طلب العميل
        final customerIndex = _orders.indexWhere(
          (o) => o.id == customerOrderId,
        );
        if (customerIndex != -1) {
          _orders[customerIndex] = _orders[customerIndex].copyWith(
            status: 'تم دمجه مع المورد',
            mergeStatus: 'مدمج',
            mergedAt: DateTime.now(),
          );
          _ordersCache[customerOrderId] = _orders[customerIndex];
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = data['message'] ?? 'فشل في دمج الطلبات';
      }
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> dispatchMovementOrder({
    required String supplierOrderId,
    required String customerId,
    required DateTime customerRequestDate,
    required DateTime expectedArrivalDate,
    String? driverId,
    String? customerOrderId,
    String? requestType,
    double? requestAmount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderMovementDispatch(supplierOrderId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({
          'customerId': customerId,
          'customerRequestDate': customerRequestDate.toIso8601String(),
          'expectedArrivalDate': expectedArrivalDate.toIso8601String(),
          if (driverId != null && driverId.isNotEmpty) 'driverId': driverId,
          if (customerOrderId != null && customerOrderId.isNotEmpty)
            'customerOrderId': customerOrderId,
          if (requestType != null && requestType.isNotEmpty)
            'requestType': requestType,
          if (requestAmount != null) 'requestAmount': requestAmount,
        }),
      );

      final data = ApiService.decodeJson(response);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        _syncOrdersFromResponse(data);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error =
          data['error']?.toString() ??
          data['message']?.toString() ??
          'فشل في توجيه طلب الحركة';
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> createMovementCustomerRequest({
    required String customerId,
    required String fuelType,
    required DateTime requestDate,
    String requestType = 'شراء',
    double? requestAmount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orders}'),
        headers: ApiService.headers,
        body: json.encode({
          'entryChannel': 'movement',
          'orderSource': 'عميل',
          'mergeStatus': 'منفصل',
          'status': 'في انتظار التخصيص',
          'supplierName': 'طلب عميل',
          'customer': customerId,
          'movementCustomerId': customerId,
          'movementCustomer': customerId,
          'fuelType': fuelType,
          'requestType': requestType,
          'requestAmount': requestAmount,
          'quantity': 0,
          'unit': 'لتر',
          'city': 'غير محدد',
          'area': 'غير محدد',
          'address': 'غير محدد',
          'orderDate': requestDate.toIso8601String(),
          'loadingDate': requestDate.toIso8601String(),
          'loadingTime': '08:00',
          'arrivalDate': requestDate
              .add(const Duration(days: 1))
              .toIso8601String(),
          'arrivalTime': '10:00',
        }),
      );

      final data = ApiService.decodeJson(response);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (data['success'] == true || data['order'] != null)) {
        _syncOrdersFromResponse(data);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error =
          data['error']?.toString() ??
          data['message']?.toString() ??
          'فشل في إضافة طلب العميل';
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteMovementCustomerRequest(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderMovementRequestById(id)}',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _orders.removeWhere((order) => order.id == id);
        _filteredOrders.removeWhere((order) => order.id == id);
        _ordersCache.remove(id);
        if (_selectedOrder?.id == id) {
          _selectedOrder = null;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final data = ApiService.decodeJson(response);
      _error =
          data['error']?.toString() ??
          data['message']?.toString() ??
          'فشل في حذف طلب العميل';
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> sendOrderWhatsAppToDriver(String orderId) async {
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        ApiEndpoints.orderWhatsAppDriver(orderId),
        const {},
      );
      final data = ApiService.decodeJson(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (data['success'] == true || data['ok'] == true)) {
        return true;
      }

      _error =
          data['message']?.toString() ??
          data['error']?.toString() ??
          'تعذر إرسال الواتساب للسائق';
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر: $e';
    }

    notifyListeners();
    return false;
  }

  // ============================================
  // 🔄 تحديث حالة الطلب فقط
  // ============================================
  Future<bool> updateOrderStatus(
    String id,
    String status, {
    String? reason,
    List<Map<String, dynamic>>? attachments,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}/status',
        ),
        headers: ApiService.headers,
        body: json.encode({
          'status': status,
          if (reason != null) 'reason': reason,
          if (attachments != null && attachments.isNotEmpty)
            'attachments': attachments,
        }),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Order updatedOrder;
        if (data['order'] != null) {
          updatedOrder = Order.fromJson(data['order']);
        } else if (data['data'] != null) {
          updatedOrder = Order.fromJson(data['data']);
        } else {
          updatedOrder = Order.fromJson(data);
        }

        // Update in list
        final index = _orders.indexWhere((o) => o.id == id);
        if (index != -1) {
          _orders[index] = updatedOrder;
        }

        // Update selected order if it's the same
        if (_selectedOrder?.id == id) {
          _selectedOrder = updatedOrder;
        }

        // Update cache
        _ordersCache[id] = updatedOrder;

        // Update filteredOrders if exists
        if (_filteredOrders.isNotEmpty) {
          final filteredIndex = _filteredOrders.indexWhere((o) => o.id == id);
          if (filteredIndex != -1) {
            _filteredOrders[filteredIndex] = updatedOrder;
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error =
            errorData['error'] ??
            errorData['message'] ??
            'فشل تحديث حالة الطلب';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitDriverLoadingData(
    String id, {
    required String actualFuelType,
    required double actualLoadedLiters,
    String? notes,
    List<Map<String, dynamic>>? attachments,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}/driver-loading',
        ),
        headers: ApiService.headers,
        body: json.encode({
          'actualFuelType': actualFuelType,
          'actualLoadedLiters': actualLoadedLiters,
          'notes': notes,
          if (attachments != null && attachments.isNotEmpty)
            'attachments': attachments,
        }),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final rawOrder = data['order'] ?? data['data'] ?? data;
        final updatedOrder = Order.fromJson(
          Map<String, dynamic>.from(rawOrder as Map),
        );

        _upsertOrderLocally(updatedOrder);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final errorData = ApiService.decodeJson(response);
      _error =
          errorData['error'] ??
          errorData['message'] ??
          'فشل في إرسال بيانات التعبئة';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> extractSupplierOrderDraftFromDocument({
    required PlatformFile file,
    String? extractedText,
  }) async {
    _error = null;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderAutofillDocument}',
        ),
      );

      request.headers.addAll(_multipartHeaders());

      final normalizedText = extractedText?.trim();
      if (normalizedText != null && normalizedText.isNotEmpty) {
        request.fields['extractedText'] = normalizedText.length > 20000
            ? normalizedText.substring(0, 20000)
            : normalizedText;
      }

      if (file.bytes != null && file.bytes!.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'document',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'document',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (normalizedText == null || normalizedText.isEmpty) {
        _error = 'تعذر قراءة الملف محليًا لإرساله إلى الخادم';
        return null;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final dynamic payload = response.body.isNotEmpty
          ? ApiService.decodeJson(response)
          : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = payload is Map ? payload['data'] : null;
        return data is Map<String, dynamic>
            ? data
            : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
      }

      if (payload is Map) {
        _error =
            payload['error']?.toString() ??
            payload['message']?.toString() ??
            'فشل في استخراج بيانات الطلب من الملف';
      } else {
        _error = 'فشل في استخراج بيانات الطلب من الملف';
      }
      return null;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      return null;
    }
  }

  // ============================================
  // ✏️ تحديث الطلب بالكامل (للإداريين فقط)
  // ============================================
  Future<bool> updateOrderFull(
    String id,
    Order order,
    List<Object>? newAttachments,
    String? customerId,
    String? driverId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}'),
      );

      request.headers.addAll(_multipartHeaders());

      // 🔥 الحقول المسموح بها للإداريين فقط
      request.fields['supplierName'] = order.supplierName;
      if (order.requestType != null && order.requestType!.isNotEmpty) {
        request.fields['requestType'] = order.requestType!;
      }
      request.fields['orderDate'] = order.orderDate.toIso8601String();
      request.fields['loadingDate'] = order.loadingDate.toIso8601String();
      request.fields['loadingTime'] = order.loadingTime ?? '08:00';
      request.fields['arrivalDate'] = order.arrivalDate.toIso8601String();
      request.fields['arrivalTime'] = order.arrivalTime ?? '10:00';
      request.fields['status'] = order.status;
      request.fields['orderSource'] = order.orderSource; // 🔥

      if (order.supplierOrderNumber != null &&
          order.supplierOrderNumber!.isNotEmpty) {
        request.fields['supplierOrderNumber'] = order.supplierOrderNumber!;
      }

      if (customerId != null && customerId.isNotEmpty) {
        request.fields['customer'] = customerId;
      }

      if (driverId != null && driverId.isNotEmpty) {
        request.fields['driver'] = driverId;
      }

      // معلومات السائق والمركبة
      if (order.driverName != null && order.driverName!.isNotEmpty) {
        request.fields['driverName'] = order.driverName!;
      }
      if (order.driverPhone != null && order.driverPhone!.isNotEmpty) {
        request.fields['driverPhone'] = order.driverPhone!;
      }
      if (order.vehicleNumber != null && order.vehicleNumber!.isNotEmpty) {
        request.fields['vehicleNumber'] = order.vehicleNumber!;
      }
      if (order.fuelType != null && order.fuelType!.isNotEmpty) {
        request.fields['fuelType'] = order.fuelType!;
      }
      if (order.quantity != null) {
        request.fields['quantity'] = order.quantity!.toString();
      }
      if (order.unit != null && order.unit!.isNotEmpty) {
        request.fields['unit'] = order.unit!;
      }
      if (order.notes != null && order.notes!.isNotEmpty) {
        request.fields['notes'] = order.notes!;
      }

      // إضافة معلومات التتبع
      if (order.actualArrivalTime != null &&
          order.actualArrivalTime!.isNotEmpty) {
        request.fields['actualArrivalTime'] = order.actualArrivalTime!;
      }
      if (order.loadingDuration != null) {
        request.fields['loadingDuration'] = order.loadingDuration!.toString();
      }
      if (order.delayReason != null && order.delayReason!.isNotEmpty) {
        request.fields['delayReason'] = order.delayReason!;
      }

      final firebaseAttachments = _extractPlatformFiles(newAttachments);
      if (firebaseAttachments.isNotEmpty) {
        final uploadedAttachments = await _uploadOrderAttachments(
          id,
          firebaseAttachments,
        );
        request.fields['attachmentUrls'] = json.encode(uploadedAttachments);
      }

      // Add company logo if exists
      if (order.companyLogo != null && order.companyLogo!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('companyLogo', order.companyLogo!),
        );
      }

      // Add new attachments
      final legacyAttachmentPaths = _extractLegacyAttachmentPaths(
        newAttachments,
      );
      if (legacyAttachmentPaths.isNotEmpty) {
        for (final path in legacyAttachmentPaths) {
          request.files.add(
            await http.MultipartFile.fromPath('attachments', path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Order updatedOrder;
        if (data['order'] != null) {
          updatedOrder = Order.fromJson(data['order']);
        } else if (data['data'] != null) {
          updatedOrder = Order.fromJson(data['data']);
        } else {
          updatedOrder = Order.fromJson(data);
        }

        // Update in list
        final index = _orders.indexWhere((o) => o.id == id);
        if (index != -1) {
          _orders[index] = updatedOrder;
        }

        // Update selected order if it's the same
        if (_selectedOrder?.id == id) {
          _selectedOrder = updatedOrder;
        }

        // Update cache
        _ordersCache[id] = updatedOrder;

        if (_filteredOrders.isNotEmpty) {
          final filteredIndex = _filteredOrders.indexWhere((o) => o.id == id);
          if (filteredIndex != -1) {
            _filteredOrders[filteredIndex] = updatedOrder;
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل تحديث الطلب';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // 🗑️ حذف الطلب
  // ============================================
  Future<bool> deleteOrder(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orderById(id)}'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from lists
        _orders.removeWhere((order) => order.id == id);
        _filteredOrders.removeWhere((order) => order.id == id);

        // Remove from cache
        _ordersCache.remove(id);

        if (_selectedOrder?.id == id) {
          _selectedOrder = null;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? errorData['message'] ?? 'فشل حذف الطلب';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // 📎 حذف مرفق
  // ============================================
  Future<bool> deleteAttachment(String orderId, String attachmentId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.deleteAttachment(orderId, attachmentId)}',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        // Remove attachment from order
        final order = _orders.firstWhere((o) => o.id == orderId);
        order.attachments.removeWhere((a) => a.id == attachmentId);

        if (_selectedOrder?.id == orderId) {
          _selectedOrder!.attachments.removeWhere((a) => a.id == attachmentId);
        }

        // Update cache
        if (_ordersCache.containsKey(orderId)) {
          _ordersCache[orderId]!.attachments.removeWhere(
            (a) => a.id == attachmentId,
          );
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // 📋 جلب النشاطات
  // ============================================
  Future<void> fetchActivities({String? orderId, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      String url = '${ApiEndpoints.baseUrl}${ApiEndpoints.activities}';
      if (orderId != null && orderId.isNotEmpty) {
        url += '?orderId=$orderId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> activitiesData = [];
        if (data['activities'] is List) {
          activitiesData = data['activities'];
        } else if (data['data'] is List) {
          activitiesData = data['data'];
        } else if (data is List) {
          activitiesData = data;
        }

        _activities = activitiesData.map((e) => Activity.fromJson(e)).toList();
      } else {
        throw Exception('فشل في جلب سجل الحركات');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ============================================
  // ⚡ وظائف سريعة
  // ============================================

  // جلب طلبات اليوم
  Future<List<Order>> fetchTodayOrders() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/today/orders'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> ordersData = [];
        if (data is List) {
          ordersData = data;
        } else if (data['orders'] is List) {
          ordersData = data['orders'];
        } else if (data['data'] is List) {
          ordersData = data['data'];
        }

        return ordersData.map((e) => Order.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // جلب الطلبات العاجلة
  Future<List<Order>> fetchUrgentLoadingOrders() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/urgent/loading',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> ordersData = [];
        if (data is List) {
          ordersData = data;
        } else if (data['orders'] is List) {
          ordersData = data['orders'];
        } else if (data['data'] is List) {
          ordersData = data['data'];
        }

        return ordersData.map((e) => Order.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // جلب طلبات المورد للدمج (حتى لو كانت تم التحميل)
  Future<List<Order>> fetchSupplierOrdersForMerge() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/for-merge/supplier',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> ordersData = [];
        if (data is List) {
          ordersData = data;
        } else if (data['orders'] is List) {
          ordersData = data['orders'];
        } else if (data['data'] is List) {
          ordersData = data['data'];
        }

        return ordersData.map((e) => Order.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // جلب طلبات العميل للدمج
  Future<List<Order>> fetchCustomerOrdersForMerge() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/for-merge/customer',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> ordersData = [];
        if (data is List) {
          ordersData = data;
        } else if (data['orders'] is List) {
          ordersData = data['orders'];
        } else if (data['data'] is List) {
          ordersData = data['data'];
        }

        return ordersData.map((e) => Order.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // إحصائيات الطلبات حسب الحالة
  Future<Map<String, int>> fetchStatusStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/stats/status'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final Map<String, int> stats = {};

        List<dynamic> statsData = [];
        if (data is List) {
          statsData = data;
        } else if (data['stats'] is List) {
          statsData = data['stats'];
        } else if (data['data'] is List) {
          statsData = data['data'];
        }

        for (var item in statsData) {
          if (item is Map) {
            stats[item['_id'] ?? item['status'] ?? 'غير معروف'] =
                (item['count'] ?? 0).toInt();
          }
        }
        return stats;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<void> markOrderAsCompleted(String orderId) async {
    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index == -1) return;

      final oldOrder = _orders[index];

      // =========================
      // 🧠 تحديد الحالة الصحيحة
      // =========================
      final bool isMergedOrder = oldOrder.orderSource == 'مدمج';

      final String newStatus = isMergedOrder ? 'تم التنفيذ' : 'تم التحميل';

      final Map<String, dynamic> body = {'status': newStatus};

      // وقت التحميل فقط للطلبات غير المدمجة
      if (!isMergedOrder) {
        body['loadingCompletedAt'] = DateTime.now().toIso8601String();
      }

      // =========================
      // 🌐 استدعاء API
      // =========================
      final response = await http.patch(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/$orderId/status',
        ),
        headers: {
          ...ApiService.headers,
          'Content-Type': 'application/json',
          'x-system-auto': 'true', // ⭐ مهم للباك
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '❌ Failed to auto complete order [$orderId]: '
          '${response.statusCode} ${response.body}',
        );
        return;
      }

      // =========================
      // 🧾 تحديث الطلب محليًا
      // =========================
      _orders[index] = oldOrder.copyWith(
        status: newStatus,
        loadingCompletedAt: isMergedOrder
            ? oldOrder.loadingCompletedAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
        mergeStatus: isMergedOrder ? 'مكتمل' : oldOrder.mergeStatus,
      );

      notifyListeners();
    } catch (e, s) {
      debugPrint('❌ Auto complete order failed: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  // تصدير PDF
  Future<Uint8List?> exportOrderToPDF(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/$orderId/export/pdf',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // طريقة للحصول على طلب من الكاش
  Order? getOrderById(String id) {
    if (_ordersCache.containsKey(id)) {
      return _ordersCache[id];
    }

    final order = _orders.firstWhere(
      (order) => order.id == id,
      orElse: () => Order.empty(),
    );

    if (order.id.isNotEmpty) {
      _ordersCache[id] = order;
      return order;
    }

    return null;
  }

  // تحديث طلب محلياً
  void updateOrderLocally(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      _orders[index] = order;
    }

    _ordersCache[order.id] = order;

    if (_selectedOrder?.id == order.id) {
      _selectedOrder = order;
    }

    if (_filteredOrders.isNotEmpty) {
      final filteredIndex = _filteredOrders.indexWhere((o) => o.id == order.id);
      if (filteredIndex != -1) {
        _filteredOrders[filteredIndex] = order;
      }
    }

    notifyListeners();
  }

  void clearFilters() {
    if (_filters.isEmpty) return;
    _filters.clear();
    _filteredOrders = List.from(_orders);
    notifyListeners();
  }

  void setFilters(Map<String, dynamic> filters) {
    _filters = Map.from(filters);
    _applyLocalFilters();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void clearSelectedOrder({bool silent = false}) {
    _selectedOrder = null;
    _activities.clear();

    if (!silent) {
      notifyListeners();
    }
  }

  void clearCache() {
    _ordersCache.clear();
  }

  Future<Order?> loadOrder(String id, {bool silent = false}) async {
    final cachedOrder = getOrderById(id);
    if (cachedOrder != null) {
      return cachedOrder;
    }

    await fetchOrderById(id, silent: silent);
    return _selectedOrder;
  }

  // 🔥 جلب الطلبات القابلة للدمج
  Future<List<Order>> getOrdersForMerge({String? type}) async {
    try {
      String url = '${ApiEndpoints.baseUrl}${ApiEndpoints.orders}/for-merge';
      if (type != null) {
        url += '?type=$type';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> ordersData = [];
        if (data['orders'] is List) {
          ordersData = data['orders'];
        } else if (data['data'] is List) {
          ordersData = data['data'];
        }

        return ordersData.map((e) => Order.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching orders for merge: $e');
      return [];
    }
  }

  Future<bool> updateMergedOrderLinks({
    required String mergedOrderId,
    required String supplierOrderId,
    required String customerOrderId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderMergeLinks(mergedOrderId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({
          'supplierOrderId': supplierOrderId,
          'customerOrderId': customerOrderId,
        }),
      );

      final data = ApiService.decodeJson(response);

      if (response.statusCode == 200 && data['success'] == true) {
        _syncOrdersFromResponse(data);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = data['error'] ?? data['message'] ?? 'فشل تحديث الطلب المدمج';
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> reviewSupplierPortalOrder({
    required String orderId,
    String? decision,
    String? note,
    String? destinationStationId,
    String? driverId,
    String? portalCustomerId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        if (decision != null && decision.trim().isNotEmpty)
          'decision': decision.trim(),
        if (note != null) 'note': note,
        if (destinationStationId != null)
          'destinationStationId': destinationStationId,
        if (driverId != null) 'driverId': driverId,
        if (portalCustomerId != null) 'portalCustomer': portalCustomerId,
      };

      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.orderSupplierReview(orderId)}',
        ),
        headers: ApiService.headers,
        body: json.encode(payload),
      );

      final data = ApiService.decodeJson(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final rawOrder =
            data['order'] ?? data['data'] ?? data['updatedOrder'] ?? data;
        final updatedOrder = Order.fromJson(
          Map<String, dynamic>.from(rawOrder as Map),
        );
        _upsertOrderLocally(updatedOrder);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error =
          data['error']?.toString() ??
          data['message']?.toString() ??
          'تعذر تنفيذ مراجعة طلب المورد';
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // ============================================
  // فك دمج الطلبات
  // ============================================
  Future<bool> unmergeOrder(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.orderUnmerge(id)}'),
        headers: ApiService.headers,
      );

      final data = ApiService.decodeJson(response);

      if (response.statusCode == 200 && data['success'] == true) {
        _syncOrdersFromResponse(data);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = data['error'] ?? data['message'] ?? 'فشل فك الدمج';
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
