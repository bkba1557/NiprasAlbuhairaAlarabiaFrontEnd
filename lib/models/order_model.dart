import 'dart:convert';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:order_tracker/models/models.dart';
import 'customer_model.dart';
import 'driver_model.dart';
import 'supplier_model.dart';

Map<String, dynamic>? _asOrderMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
    );
  }
  return null;
}

class Order {
  final String id;
  final DateTime orderDate;

  /// ⭐ مصدر الطلب (مورد | عميل | مدمج)
  final String orderSource;

  /// ⭐ حالة الدمج (منفصل | في انتظار الدمج | مدمج | مكتمل)
  final String mergeStatus;
  final String entryChannel;
  final String? movementState;
  final String? movementCustomerId;
  final String? movementCustomerName;
  final DateTime? movementCustomerRequestDate;
  final DateTime? movementExpectedArrivalDate;
  final String? movementCustomerOrderId;
  final String? movementMergedOrderId;
  final String? movementMergedOrderNumber;
  final DateTime? movementDirectedAt;
  final String? movementDirectedByName;
  final String? portalStatus;
  final String? portalReviewNotes;
  final DateTime? portalReviewedAt;
  final String? portalReviewedByName;
  final String? portalCustomerId;
  final String? portalCustomerName;
  final String? destinationStationId;
  final String? destinationStationName;
  final String? carrierName;

  final String supplierName;

  /// ⭐ نوع العملية (شراء | نقل) - للطلبات العميل فقط
  final String? requestType;
  final double? requestAmount;

  final String orderNumber;
  final String? supplierOrderNumber;

  final DateTime loadingDate;
  final String loadingTime;
  final DateTime arrivalDate;
  final String arrivalTime;
  final String status;

  // ===== بيانات المورد =====
  final String? supplierId;
  final String? supplierContactPerson;
  final String? supplierPhone;
  final String? supplierAddress;
  final String? supplierCompany;
  final String? customerAddress;

  // ===== 📍 موقع الطلب =====
  final String? city;
  final String? area;
  final String? address;

  // ===== بيانات السائق =====
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;

  // ===== بيانات الطلب =====
  final String? fuelType;
  final double? quantity;
  final String? unit;
  final String? notes;
  final String? companyLogo;

  final List<Attachment> attachments;

  final String createdById;
  final String? createdByName;

  final Customer? customer;
  final Supplier? supplier;
  final Driver? driver;

  // ⭐ معلومات الدمج
  final String? mergedWithOrderId;
  final Map<String, dynamic>? mergedWithInfo;

  final DateTime? notificationSentAt;
  final DateTime? arrivalNotificationSentAt;
  final DateTime? driverAssignmentReminderAt;
  final int? driverAssignmentReminderDays;
  final int? driverAssignmentReminderHours;
  final bool driverAssignmentReminderActive;
  final String? driverAssignmentReminderCreatedById;
  final String? driverAssignmentReminderCreatedByName;
  final DateTime? driverAssignmentReminderNotifiedAt;
  final DateTime? loadingCompletedAt;
  final String? actualFuelType;
  final double? actualLoadedLiters;
  final String? loadingStationName;
  final String? driverLoadingNotes;
  final DateTime? driverLoadingSubmittedAt;
  final String? actualArrivalTime;
  final int? loadingDuration;
  final String? delayReason;

  // ⭐ معلومات إضافية
  final double? unitPrice;
  final double? totalPrice;
  final double? vatRate;
  final double? vatAmount;
  final double? totalPriceWithVat;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? productType;
  final double? driverEarnings;
  final double? distance;
  final int? deliveryDuration;
  final String? transportSourceCity;
  final int? transportCapacityLiters;
  final Map<String, dynamic>? pricingSnapshot;
  final Map<String, dynamic>? transportPricingOverride;

  final DateTime? mergedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancellationApprovalStatus;
  final DateTime? cancellationApprovalRequestedAt;
  final String? cancellationApprovalRequestedByName;
  final DateTime? cancellationApprovalApprovedAt;
  final String? cancellationApprovalApprovedByName;
  final String? cancellationApprovalNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  // =========================
  // Constructor
  // =========================
  const Order({
    required this.id,
    required this.orderDate,
    required this.orderSource,
    required this.mergeStatus,
    this.entryChannel = 'manual',
    this.movementState,
    this.movementCustomerId,
    this.movementCustomerName,
    this.movementCustomerRequestDate,
    this.movementExpectedArrivalDate,
    this.movementCustomerOrderId,
    this.movementMergedOrderId,
    this.movementMergedOrderNumber,
    this.movementDirectedAt,
    this.movementDirectedByName,
    this.portalStatus,
    this.portalReviewNotes,
    this.portalReviewedAt,
    this.portalReviewedByName,
    this.portalCustomerId,
    this.portalCustomerName,
    this.destinationStationId,
    this.destinationStationName,
    this.carrierName,
    required this.supplierName,
    this.requestType,
    this.requestAmount,
    required this.orderNumber,
    this.supplierOrderNumber,
    required this.loadingDate,
    required this.loadingTime,
    required this.arrivalDate,
    required this.arrivalTime,
    required this.status,

    // المورد
    this.supplierId,
    this.supplierContactPerson,
    this.supplierPhone,
    this.supplierAddress,
    this.supplierCompany,
    this.customerAddress,

    // الموقع
    this.city,
    this.area,
    this.address,

    // السائق
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,

    // الطلب
    this.fuelType,
    this.quantity,
    this.unit,
    this.notes,
    this.companyLogo,

    required this.attachments,
    required this.createdById,
    this.createdByName,
    this.customer,
    this.supplier,
    this.driver,

    // الدمج
    this.mergedWithOrderId,
    this.mergedWithInfo,

    this.notificationSentAt,
    this.arrivalNotificationSentAt,
    this.driverAssignmentReminderAt,
    this.driverAssignmentReminderDays,
    this.driverAssignmentReminderHours,
    this.driverAssignmentReminderActive = false,
    this.driverAssignmentReminderCreatedById,
    this.driverAssignmentReminderCreatedByName,
    this.driverAssignmentReminderNotifiedAt,
    this.loadingCompletedAt,
    this.actualFuelType,
    this.actualLoadedLiters,
    this.loadingStationName,
    this.driverLoadingNotes,
    this.driverLoadingSubmittedAt,
    this.actualArrivalTime,
    this.loadingDuration,
    this.delayReason,

    // معلومات إضافية
    this.unitPrice,
    this.totalPrice,
    this.vatRate,
    this.vatAmount,
    this.totalPriceWithVat,
    this.paymentMethod,
    this.paymentStatus,
    this.productType,
    this.driverEarnings,
    this.distance,
    this.deliveryDuration,
    this.transportSourceCity,
    this.transportCapacityLiters,
    this.pricingSnapshot,
    this.transportPricingOverride,

    this.mergedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancellationApprovalStatus,
    this.cancellationApprovalRequestedAt,
    this.cancellationApprovalRequestedByName,
    this.cancellationApprovalApprovedAt,
    this.cancellationApprovalApprovedByName,
    this.cancellationApprovalNotes,

    required this.createdAt,
    required this.updatedAt,
  });

  // =========================
  // 🧪 Order فارغ
  // =========================
  factory Order.empty() {
    return Order(
      id: '',
      orderDate: DateTime.now(),
      orderSource: 'مورد', // ⭐ قيمة افتراضية
      mergeStatus: 'منفصل',
      entryChannel: 'manual',
      supplierName: '',
      orderNumber: '',
      loadingDate: DateTime.now(),
      loadingTime: '08:00',
      arrivalDate: DateTime.now(),
      arrivalTime: '10:00',
      status: 'في المستودع', // ⭐ الحالة الجديدة
      attachments: const [],
      createdById: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // =========================
  // fromJson
  // =========================
  factory Order.fromJson(Map<String, dynamic> json) {
    final parsedOrderSource = json['orderSource']?.toString() ?? 'مورد';
    final parsedEntryChannel = json['entryChannel']?.toString() ?? 'manual';
    final bool treatCustomerFieldAsMovementCustomer =
        parsedEntryChannel == 'movement' && parsedOrderSource == 'عميل';

    final String? fallbackCustomerId = json['customer'] is Map
        ? (json['customer']['_id'] ?? json['customer']['id'])?.toString()
        : json['customer']?.toString();
    final String? fallbackCustomerName = json['customer'] is Map
        ? json['customer']['name']?.toString()
        : null;

    // ⭐ تحليل العميل
    Customer? customer;
    if (json['customer'] is Map<String, dynamic>) {
      customer = Customer.fromJson(json['customer']);
    }

    // ⭐ تحليل المورد
    Supplier? supplier;
    if (json['supplier'] is Map<String, dynamic>) {
      supplier = Supplier.fromJson(json['supplier']);
    }

    // ⭐ تحليل السائق
    Driver? driver;
    if (json['driver'] is Map<String, dynamic>) {
      driver = Driver.fromJson(json['driver']);
    }

    // ⭐ معلومات السائق (من الحقول المنفصلة)
    String? driverId =
        json['driverId']?.toString() ??
        (json['driver'] is Map
            ? json['driver']['_id']?.toString()
            : json['driver'] is String
            ? json['driver']
            : null);

    String? driverName =
        json['driverName']?.toString() ??
        (json['driver'] is Map ? json['driver']['name']?.toString() : null);

    String? driverPhone =
        json['driverPhone']?.toString() ??
        (json['driver'] is Map ? json['driver']['phone']?.toString() : null);

    String? vehicleNumber =
        json['vehicleNumber']?.toString() ??
        (json['driver'] is Map
            ? json['driver']['vehicleNumber']?.toString()
            : null);

    // ⭐ معلومات المورد (من الحقول المنفصلة)
    String? supplierId =
        json['supplierId']?.toString() ??
        (json['supplier'] is Map
            ? json['supplier']['_id']?.toString()
            : json['supplier'] is String
            ? json['supplier']
            : null);

    String? supplierContactPerson =
        json['supplierContactPerson']?.toString() ??
        (json['supplier'] is Map
            ? json['supplier']['contactPerson']?.toString()
            : null);

    String? supplierPhone =
        json['supplierPhone']?.toString() ??
        (json['supplier'] is Map
            ? json['supplier']['phone']?.toString()
            : null);

    String? supplierAddress =
        json['supplierAddress']?.toString() ??
        (json['supplier'] is Map
            ? json['supplier']['address']?.toString()
            : null);

    String? supplierCompany =
        json['supplierCompany']?.toString() ??
        (json['supplier'] is Map
            ? json['supplier']['company']?.toString()
            : null);

    // ⭐ معلومات العميل (من الحقول المنفصلة)
    String? customerName =
        json['customerName']?.toString() ??
        (json['customer'] is Map ? json['customer']['name']?.toString() : null);

    String? customerAddress =
        json['customerAddress']?.toString() ??
        (json['customer'] is Map
            ? json['customer']['address']?.toString()
            : null);

    String? customerCode =
        json['customerCode']?.toString() ??
        (json['customer'] is Map ? json['customer']['code']?.toString() : null);

    String? customerPhone =
        json['customerPhone']?.toString() ??
        (json['customer'] is Map
            ? json['customer']['phone']?.toString()
            : null);

    String? customerEmail =
        json['customerEmail']?.toString() ??
        (json['customer'] is Map
            ? json['customer']['email']?.toString()
            : null);

    // ⭐ إذا لم يكن العميل موجوداً في JSON ولكن هناك معلومات منفصلة، ننشئ كائن Customer
    if (customer == null && customerName != null) {
      customer = Customer(
        id: '',
        name: customerName,
        code: customerCode ?? '',
        phone: customerPhone ?? '',
        email: customerEmail ?? '',
        city: json['city']?.toString(),
        area: json['area']?.toString(),
        address: customerAddress ?? json['address']?.toString(),
        company: '',
        contactPerson: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        status: 'active',
        createdById: '',
      );
    }

    final parsedAttachments = <Attachment>[];
    final rawAttachments = json['attachments'] ?? json['attachmentUrls'];
    final attachmentItems = <dynamic>[];

    if (rawAttachments is List) {
      attachmentItems.addAll(rawAttachments);
    } else if (rawAttachments is Map) {
      attachmentItems.add(rawAttachments);
    } else if (rawAttachments is String) {
      final trimmed = rawAttachments.trim();
      if (trimmed.isNotEmpty) {
        if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              attachmentItems.addAll(decoded);
            } else {
              attachmentItems.add(decoded);
            }
          } catch (_) {
            attachmentItems.add(trimmed);
          }
        } else {
          attachmentItems.add(trimmed);
        }
      }
    }

    for (final item in attachmentItems) {
      if (item is Map<String, dynamic>) {
        parsedAttachments.add(Attachment.fromJson(item));
      } else if (item is Map) {
        parsedAttachments.add(
          Attachment.fromJson(Map<String, dynamic>.from(item)),
        );
      } else if (item is String) {
        final normalized = item.trim().replaceAll('\\', '/');
        final fileName = normalized.split('/').last.trim();
        parsedAttachments.add(
          Attachment(
            id: '',
            filename: fileName.isEmpty ? 'attachment' : fileName,
            path: item.trim(),
            uploadedAt: DateTime.now(),
          ),
        );
      }
    }

    final cancellationApproval = _asOrderMap(json['cancellationApproval']);
    final driverAssignmentReminder = _asOrderMap(
      json['driverAssignmentReminder'],
    );
    final driverReminderDaysRaw = driverAssignmentReminder?['days'];
    final driverReminderHoursRaw = driverAssignmentReminder?['hours'];
    final driverReminderCreatedByRaw = driverAssignmentReminder?['createdBy'];

    return Order(
      id: json['_id']?.toString() ?? '',
      orderDate:
          DateTime.tryParse(json['orderDate']?.toString() ?? '') ??
          DateTime.now(),

      // ⭐ الحقول الجديدة
      orderSource: parsedOrderSource,
      mergeStatus: json['mergeStatus']?.toString() ?? 'منفصل',

      entryChannel: parsedEntryChannel,
      movementState: json['movementState']?.toString(),
      movementCustomerId:
          json['movementCustomerId']?.toString() ??
          (json['movementCustomer'] is Map
              ? (json['movementCustomer']['_id'] ??
                        json['movementCustomer']['id'])
                    ?.toString()
              : json['movementCustomer']?.toString()) ??
          (treatCustomerFieldAsMovementCustomer ? fallbackCustomerId : null),
      movementCustomerName:
          json['movementCustomerName']?.toString() ??
          (json['movementCustomer'] is Map
              ? json['movementCustomer']['name']?.toString()
              : null) ??
          (treatCustomerFieldAsMovementCustomer ? fallbackCustomerName : null),
      movementCustomerRequestDate: DateTime.tryParse(
        json['movementCustomerRequestDate']?.toString() ?? '',
      ),
      movementExpectedArrivalDate: DateTime.tryParse(
        json['movementExpectedArrivalDate']?.toString() ?? '',
      ),
      movementCustomerOrderId:
          json['movementCustomerOrderId'] is Map
          ? json['movementCustomerOrderId']['_id']?.toString()
          : json['movementCustomerOrderId']?.toString(),
      movementMergedOrderId:
          json['movementMergedOrderId'] is Map
          ? json['movementMergedOrderId']['_id']?.toString()
          : json['movementMergedOrderId']?.toString(),
      movementMergedOrderNumber: json['movementMergedOrderNumber']?.toString(),
      movementDirectedAt: DateTime.tryParse(
        json['movementDirectedAt']?.toString() ?? '',
      ),
      movementDirectedByName: json['movementDirectedByName']?.toString(),
      portalStatus: json['portalStatus']?.toString(),
      portalReviewNotes: json['portalReviewNotes']?.toString(),
      portalReviewedAt: DateTime.tryParse(
        json['portalReviewedAt']?.toString() ?? '',
      ),
      portalReviewedByName: json['portalReviewedByName']?.toString(),
      portalCustomerId: json['portalCustomer'] is Map
          ? json['portalCustomer']['_id']?.toString()
          : json['portalCustomer']?.toString(),
      portalCustomerName: json['portalCustomer'] is Map
          ? json['portalCustomer']['name']?.toString()
          : json['portalCustomerName']?.toString(),
      destinationStationId: json['destinationStationId'] is Map
          ? json['destinationStationId']['_id']?.toString()
          : json['destinationStationId']?.toString(),
      destinationStationName: json['destinationStationId'] is Map
          ? json['destinationStationId']['stationName']?.toString()
          : json['destinationStationName']?.toString(),
      carrierName: json['carrierName']?.toString(),
      supplierName:
          json['supplierName']?.toString() ??
          (supplier != null ? supplier.name : ''),

      requestType: json['requestType']?.toString(),
      requestAmount: json['requestAmount'] != null
          ? double.tryParse(json['requestAmount'].toString())
          : null,

      orderNumber: json['orderNumber']?.toString() ?? '',
      supplierOrderNumber: json['supplierOrderNumber']?.toString(),

      loadingDate:
          DateTime.tryParse(json['loadingDate']?.toString() ?? '') ??
          DateTime.now(),
      loadingTime: json['loadingTime']?.toString() ?? '08:00',
      arrivalDate:
          DateTime.tryParse(json['arrivalDate']?.toString() ?? '') ??
          DateTime.now(),
      arrivalTime: json['arrivalTime']?.toString() ?? '10:00',

      status: json['status']?.toString() ?? 'في المستودع',

      // معلومات المورد
      supplierId: supplierId,
      supplierContactPerson: supplierContactPerson,
      supplierPhone: supplierPhone,
      supplierAddress: supplierAddress,
      supplierCompany: supplierCompany,
      customerAddress: customerAddress,

      // الموقع
      city: json['city']?.toString(),
      area: json['area']?.toString(),
      address: json['address']?.toString(),

      // السائق
      driverId: driverId,
      driverName: driverName,
      driverPhone: driverPhone,
      vehicleNumber: vehicleNumber,

      // معلومات الطلب
      fuelType: json['fuelType']?.toString(),
      quantity: json['quantity'] != null
          ? double.tryParse(json['quantity'].toString())
          : null,
      unit: json['unit']?.toString(),
      notes: json['notes']?.toString(),
      companyLogo: json['companyLogo']?.toString(),

      attachments: parsedAttachments,

      createdById: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id']?.toString() ?? '',
      createdByName: json['createdByName']?.toString(),

      // ⭐ الكائنات المرتبطة
      customer: customer,
      supplier: supplier,
      driver: driver,

      // ⭐ معلومات الدمج
      mergedWithOrderId: json['mergedWithOrderId']?.toString(),
      mergedWithInfo: json['mergedWithInfo'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['mergedWithInfo'])
          : null,

      notificationSentAt: DateTime.tryParse(
        json['notificationSentAt']?.toString() ?? '',
      ),
      arrivalNotificationSentAt: DateTime.tryParse(
        json['arrivalNotificationSentAt']?.toString() ?? '',
      ),
      driverAssignmentReminderAt: DateTime.tryParse(
        driverAssignmentReminder?['remindAt']?.toString() ?? '',
      ),
      driverAssignmentReminderDays:
          driverReminderDaysRaw is int
              ? driverReminderDaysRaw
              : int.tryParse(driverReminderDaysRaw?.toString() ?? ''),
      driverAssignmentReminderHours:
          driverReminderHoursRaw is int
              ? driverReminderHoursRaw
              : int.tryParse(driverReminderHoursRaw?.toString() ?? ''),
      driverAssignmentReminderActive:
          driverAssignmentReminder?['active'] == true,
      driverAssignmentReminderCreatedById:
          driverReminderCreatedByRaw is Map
              ? driverReminderCreatedByRaw['_id']?.toString()
              : driverReminderCreatedByRaw?.toString(),
      driverAssignmentReminderCreatedByName:
          driverAssignmentReminder?['createdByName']?.toString(),
      driverAssignmentReminderNotifiedAt: DateTime.tryParse(
        driverAssignmentReminder?['notifiedAt']?.toString() ?? '',
      ),
      loadingCompletedAt: DateTime.tryParse(
        json['loadingCompletedAt']?.toString() ?? '',
      ),
      actualFuelType: json['actualFuelType']?.toString(),
      actualLoadedLiters: json['actualLoadedLiters'] != null
          ? double.tryParse(json['actualLoadedLiters'].toString())
          : null,
      loadingStationName: json['loadingStationName']?.toString(),
      driverLoadingNotes: json['driverLoadingNotes']?.toString(),
      driverLoadingSubmittedAt: DateTime.tryParse(
        json['driverLoadingSubmittedAt']?.toString() ?? '',
      ),
      actualArrivalTime: json['actualArrivalTime']?.toString(),
      loadingDuration: json['loadingDuration'] is int
          ? json['loadingDuration']
          : int.tryParse(json['loadingDuration']?.toString() ?? ''),
      delayReason: json['delayReason']?.toString(),

      // ⭐ معلومات إضافية
      unitPrice: json['unitPrice'] != null
          ? double.tryParse(json['unitPrice'].toString())
          : null,
      totalPrice: json['totalPrice'] != null
          ? double.tryParse(json['totalPrice'].toString())
          : null,
      vatRate: json['vatRate'] != null
          ? double.tryParse(json['vatRate'].toString())
          : null,
      vatAmount: json['vatAmount'] != null
          ? double.tryParse(json['vatAmount'].toString())
          : null,
      totalPriceWithVat: json['totalPriceWithVat'] != null
          ? double.tryParse(json['totalPriceWithVat'].toString())
          : null,
      paymentMethod: json['paymentMethod']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      productType: json['productType']?.toString(),
      driverEarnings: json['driverEarnings'] != null
          ? double.tryParse(json['driverEarnings'].toString())
          : null,
      distance: json['distance'] != null
          ? double.tryParse(json['distance'].toString())
          : null,
      deliveryDuration: json['deliveryDuration'] is int
          ? json['deliveryDuration']
          : int.tryParse(json['deliveryDuration']?.toString() ?? ''),
      transportSourceCity: json['transportSourceCity']?.toString(),
      transportCapacityLiters: json['transportCapacityLiters'] is int
          ? json['transportCapacityLiters']
          : int.tryParse(json['transportCapacityLiters']?.toString() ?? ''),
      pricingSnapshot: _asOrderMap(json['pricingSnapshot']),
      transportPricingOverride: _asOrderMap(json['transportPricingOverride']),

      mergedAt: DateTime.tryParse(json['mergedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(json['cancelledAt']?.toString() ?? ''),
      cancellationReason: json['cancellationReason']?.toString(),
      cancellationApprovalStatus: cancellationApproval?['status']?.toString(),
      cancellationApprovalRequestedAt: DateTime.tryParse(
        cancellationApproval?['requestedAt']?.toString() ?? '',
      ),
      cancellationApprovalRequestedByName:
          cancellationApproval?['requestedByName']?.toString(),
      cancellationApprovalApprovedAt: DateTime.tryParse(
        cancellationApproval?['approvedAt']?.toString() ?? '',
      ),
      cancellationApprovalApprovedByName:
          cancellationApproval?['approvedByName']?.toString(),
      cancellationApprovalNotes:
          cancellationApproval?['approvalNotes']?.toString(),

      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  // =========================
  // toJson
  // =========================
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'orderDate': orderDate.toIso8601String(),
      'orderSource': orderSource,
      'mergeStatus': mergeStatus,
      'entryChannel': entryChannel,
      'movementState': movementState,
      'movementCustomer': movementCustomerId,
      'movementCustomerId': movementCustomerId,
      'movementCustomerName': movementCustomerName,
      'movementCustomerRequestDate':
          movementCustomerRequestDate?.toIso8601String(),
      'movementExpectedArrivalDate':
          movementExpectedArrivalDate?.toIso8601String(),
      'movementCustomerOrderId': movementCustomerOrderId,
      'movementMergedOrderId': movementMergedOrderId,
      'movementMergedOrderNumber': movementMergedOrderNumber,
      'movementDirectedAt': movementDirectedAt?.toIso8601String(),
      'movementDirectedByName': movementDirectedByName,
      'portalStatus': portalStatus,
      'portalReviewNotes': portalReviewNotes,
      'portalReviewedAt': portalReviewedAt?.toIso8601String(),
      'portalReviewedByName': portalReviewedByName,
      'portalCustomer': portalCustomerId,
      'portalCustomerName': portalCustomerName,
      'destinationStationId': destinationStationId,
      'destinationStationName': destinationStationName,
      'carrierName': carrierName,
      'supplierName': supplierName,
      'requestType': requestType,
      'requestAmount': requestAmount,
      'orderNumber': orderNumber,
      'supplierOrderNumber': supplierOrderNumber,
      'loadingDate': loadingDate.toIso8601String(),
      'loadingTime': loadingTime,
      'arrivalDate': arrivalDate.toIso8601String(),
      'arrivalTime': arrivalTime,
      'status': status,

      // معلومات المورد
      'supplier': supplierId,
      'supplierId': supplierId,
      'supplierContactPerson': supplierContactPerson,
      'supplierPhone': supplierPhone,
      'supplierAddress': supplierAddress,
      'supplierCompany': supplierCompany,
      'customerAddress': customerAddress,

      // الموقع
      'city': city,
      'area': area,
      'address': address,

      // السائق
      'driver': driverId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'vehicleNumber': vehicleNumber,

      // معلومات الطلب
      'fuelType': fuelType,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
      'companyLogo': companyLogo,

      'attachments': attachments.map((e) => e.toJson()).toList(),
      'createdBy': createdById,
      'createdByName': createdByName,

      // معلومات العميل
      'customer': customer?.id,
      'customerName': customer?.name,
      'customerCode': customer?.code,
      'customerPhone': customer?.phone,
      'customerEmail': customer?.email,

      // معلومات الدمج
      'mergedWithOrderId': mergedWithOrderId,
      'mergedWithInfo': mergedWithInfo,

      'notificationSentAt': notificationSentAt?.toIso8601String(),
      'arrivalNotificationSentAt': arrivalNotificationSentAt?.toIso8601String(),
      if (driverAssignmentReminderAt != null ||
          driverAssignmentReminderActive ||
          driverAssignmentReminderCreatedById != null)
        'driverAssignmentReminder': {
          'remindAt': driverAssignmentReminderAt?.toIso8601String(),
          'days': driverAssignmentReminderDays,
          'hours': driverAssignmentReminderHours,
          'active': driverAssignmentReminderActive,
          'createdBy': driverAssignmentReminderCreatedById,
          'createdByName': driverAssignmentReminderCreatedByName,
          'notifiedAt':
              driverAssignmentReminderNotifiedAt?.toIso8601String(),
        },
      'loadingCompletedAt': loadingCompletedAt?.toIso8601String(),
      'actualFuelType': actualFuelType,
      'actualLoadedLiters': actualLoadedLiters,
      'loadingStationName': loadingStationName,
      'driverLoadingNotes': driverLoadingNotes,
      'driverLoadingSubmittedAt': driverLoadingSubmittedAt?.toIso8601String(),
      'actualArrivalTime': actualArrivalTime,
      'loadingDuration': loadingDuration,
      'delayReason': delayReason,

      // معلومات إضافية
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'totalPriceWithVat': totalPriceWithVat,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'productType': productType,
      'driverEarnings': driverEarnings,
      'distance': distance,
      'deliveryDuration': deliveryDuration,
      'transportSourceCity': transportSourceCity,
      'transportCapacityLiters': transportCapacityLiters,
      'pricingSnapshot': pricingSnapshot,
      'transportPricingOverride': transportPricingOverride,

      'mergedAt': mergedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      if (cancellationApprovalStatus != null ||
          cancellationApprovalRequestedAt != null ||
          cancellationApprovalRequestedByName != null ||
          cancellationApprovalApprovedAt != null ||
          cancellationApprovalApprovedByName != null ||
          cancellationApprovalNotes != null)
        'cancellationApproval': {
          'status': cancellationApprovalStatus,
          'requestedAt': cancellationApprovalRequestedAt?.toIso8601String(),
          'requestedByName': cancellationApprovalRequestedByName,
          'approvedAt': cancellationApprovalApprovedAt?.toIso8601String(),
          'approvedByName': cancellationApprovalApprovedByName,
          'approvalNotes': cancellationApprovalNotes,
        },

      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // =========================
  // ⭐ دالات مساعدة جديدة
  // =========================

  /// تحقق إذا كان الطلب من نوع مورد
  bool get isSupplierOrder => orderSource == 'مورد';

  /// تحقق إذا كان الطلب من نوع عميل
  bool get isCustomerOrder => orderSource == 'عميل';

  /// تحقق إذا كان الطلب مدمجاً
  bool get isMergedOrder => orderSource == 'مدمج';

  /// تحقق إذا كان الطلب مدمجاً
  bool get isMerged => mergeStatus == 'مدمج' || mergeStatus == 'مكتمل';

  bool get isMovementOrder => entryChannel == 'movement';

  bool get isSupplierPortalOrder => entryChannel == 'supplier_portal';

  bool get isPortalPendingReview => portalStatus == 'pending_review';

  bool get isPortalApproved => portalStatus == 'approved';

  bool get isPortalRejected => portalStatus == 'rejected';

  bool get isMovementPendingDriver => movementState == 'pending_driver';

  bool get isMovementPendingDispatch => movementState == 'pending_dispatch';

  bool get isMovementDirected => movementState == 'directed';

  bool get hasActiveDriverAssignmentReminder =>
      driverAssignmentReminderActive && driverAssignmentReminderAt != null;

  double? pricingNumber(String key) {
    final value = pricingSnapshot?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String? pricingText(String key) => pricingSnapshot?[key]?.toString();

  double get effectiveVatRate => pricingNumber('vatRate') ?? vatRate ?? 0.15;

  double get effectiveVatAmount =>
      pricingNumber('vatAmount') ??
      vatAmount ??
      ((totalPrice ?? 0) * effectiveVatRate);

  double get effectiveTotalWithVat =>
      pricingNumber('totalWithVat') ??
      pricingNumber('totalPriceWithVat') ??
      totalPriceWithVat ??
      ((totalPrice ?? 0) + effectiveVatAmount);

  double get effectiveFuelPricePerLiter =>
      pricingNumber('fuelPricePerLiter') ??
      customer?.fuelPriceFor(fuelType) ??
      0;

  double get effectiveFuelSubtotal =>
      pricingNumber('fuelSubtotal') ??
      ((quantity ?? 0) * effectiveFuelPricePerLiter);

  double get effectiveTransportCharge => pricingNumber('transportCharge') ?? 0;

  double get effectiveReturnCharge => pricingNumber('returnCharge') ?? 0;

  double get effectiveSubtotal =>
      pricingNumber('subtotal') ??
      totalPrice ??
      (effectiveFuelSubtotal + effectiveTransportCharge + effectiveReturnCharge);

  double get effectiveUnitPricePerLiter =>
      pricingNumber('unitPricePerLiter') ??
      unitPrice ??
      ((quantity ?? 0) > 0 ? effectiveSubtotal / (quantity ?? 1) : 0);

  String? get effectiveTransportMode => pricingText('transportMode');

  double? get effectiveTransportValue => pricingNumber('transportValue');

  String? get effectiveReturnMode => pricingText('returnMode');

  double? get effectiveReturnValue => pricingNumber('returnValue');

  String? get effectiveTransportSourceCity =>
      pricingText('sourceCity') ?? transportSourceCity;

  int? get effectiveTransportCapacityLiters =>
      pricingNumber('capacityLiters')?.round() ?? transportCapacityLiters;

  bool get hasPricingSnapshot => pricingSnapshot?.isNotEmpty == true;

  /// تحقق إذا كان الطلب قابلاً للدمج
  bool get canMerge =>
      mergeStatus == 'منفصل' || mergeStatus == 'في انتظار الدمج';

  /// تحقق إذا كانت الحالة نهائية
  bool get isFinalStatus {
    final finalStatuses = ['تم التسليم', 'تم التنفيذ', 'مكتمل', 'ملغى'];
    return finalStatuses.contains(status);
  }

  bool get isCancellationPendingOwnerApproval =>
      cancellationApprovalStatus == 'pending_owner_approval';

  bool get isCancellationApproved => cancellationApprovalStatus == 'approved';

  /// الحصول على لون الحالة
  Color get statusColor {
    // طلبات المورد
    if (orderSource == 'مورد') {
      switch (status) {
        case 'في المستودع':
          return const Color(0xFFFF9800);
        case 'تم الإنشاء':
          return const Color(0xFF2196F3);
        case 'في انتظار الدمج':
          return const Color(0xFFFF5722);
        case 'تم دمجه مع العميل':
          return const Color(0xFF9C27B0);
        case 'جاهز للتحميل':
          return const Color(0xFF00BCD4);
        case 'تم التحميل':
          return const Color(0xFF4CAF50);
        case 'في الطريق':
          return const Color(0xFF3F51B5);
        case 'تم التسليم':
          return const Color(0xFF8BC34A);
        default:
          return const Color(0xFF757575);
      }
    }
    // طلبات العميل
    else if (orderSource == 'عميل') {
      switch (status) {
        case 'في انتظار التخصيص':
          return const Color(0xFFFF9800);
        case 'تم تخصيص طلب المورد':
          return const Color(0xFF2196F3);
        case 'في انتظار الدمج':
          return const Color(0xFFFF5722);
        case 'تم دمجه مع المورد':
          return const Color(0xFF9C27B0);
        case 'في انتظار التحميل':
          return const Color(0xFF00BCD4);
        case 'في الطريق':
          return const Color(0xFF3F51B5);
        case 'تم التسليم':
          return const Color(0xFF8BC34A);
        default:
          return const Color(0xFF757575);
      }
    }
    // طلبات مدمجة
    else if (orderSource == 'مدمج') {
      switch (status) {
        case 'تم الدمج':
          return const Color(0xFF9C27B0);
        case 'مخصص للعميل':
          return const Color(0xFF2196F3);
        case 'جاهز للتحميل':
          return const Color(0xFF00BCD4);
        case 'تم التحميل':
          return const Color(0xFF4CAF50);
        case 'في الطريق':
          return const Color(0xFF3F51B5);
        case 'تم التسليم':
          return const Color(0xFF8BC34A);
        case 'تم التنفيذ':
          return const Color(0xFF4CAF50);
        default:
          return const Color(0xFF757575);
      }
    }
    // حالات عامة
    switch (status) {
      case 'ملغى':
        return const Color(0xFFF44336);
      case 'مكتمل':
        return const Color(0xFF8BC34A);
      default:
        return const Color(0xFF757575);
    }
  }

  /// الحصول على نص مصدر الطلب
  String get orderSourceText {
    switch (orderSource) {
      case 'مورد':
        return 'طلب مورد';
      case 'عميل':
        return 'طلب عميل';
      case 'مدمج':
        return 'طلب مدمج';
      default:
        return 'طلب';
    }
  }

  /// الحصول على معلومات الموقع
  String get location {
    if (city != null && area != null) {
      return '$city - $area';
    }
    return city ?? area ?? 'غير محدد';
  }

  /// الحصول على معلومات العرض
  Map<String, dynamic> get displayInfo {
    return {
      'orderNumber': orderNumber,
      'orderSource': orderSource,
      'orderSourceText': orderSourceText,
      'supplierName': supplierName,
      'customerName': customer?.name ?? 'غير محدد',
      'status': status,
      'statusColor': statusColor,
      'location': location,
      'fuelType': fuelType,
      'quantity': quantity,
      'unit': unit,
      'mergeStatus': mergeStatus,
      'totalPrice': totalPrice,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt,
    };
  }

  /// الحصول على وقت التحميل الكامل كـ DateTime
  DateTime get fullLoadingDateTime {
    try {
      if (loadingTime.isEmpty) {
        return loadingDate;
      }
      final timeParts = loadingTime.split(':');
      final hours = timeParts.length > 0 ? int.tryParse(timeParts[0]) ?? 8 : 8;
      final minutes = timeParts.length > 1
          ? int.tryParse(timeParts[1]) ?? 0
          : 0;

      return DateTime(
        loadingDate.year,
        loadingDate.month,
        loadingDate.day,
        hours,
        minutes,
      );
    } catch (e) {
      return loadingDate;
    }
  }

  /// الحصول على وقت الوصول الكامل كـ DateTime
  DateTime get fullArrivalDateTime {
    try {
      if (arrivalTime.isEmpty) {
        return arrivalDate;
      }
      final timeParts = arrivalTime.split(':');
      final hours = timeParts.length > 0
          ? int.tryParse(timeParts[0]) ?? 10
          : 10;
      final minutes = timeParts.length > 1
          ? int.tryParse(timeParts[1]) ?? 0
          : 0;

      return DateTime(
        arrivalDate.year,
        arrivalDate.month,
        arrivalDate.day,
        hours,
        minutes,
      );
    } catch (e) {
      return arrivalDate;
    }
  }

  String get formattedLoadingDateTime =>
      '${DateFormat('yyyy/MM/dd').format(loadingDate)} $loadingTime';

  String get formattedArrivalDateTime =>
      '${DateFormat('yyyy/MM/dd').format(arrivalDate)} $arrivalTime';

  /// ⭐ تحديث: دالة للحصول على المدة المتبقية للوصول
  Duration get arrivalRemaining =>
      fullArrivalDateTime.difference(DateTime.now());

  /// ⭐ تحديث: دالة للحصول على المدة المتبقية للتحميل
  Duration get loadingRemaining =>
      fullLoadingDateTime.difference(DateTime.now());

  /// ⭐ تحديث: دالة للحصول على المؤقت المنسق للوصول
  String get formattedArrivalCountdown {
    if (arrivalRemaining <= Duration.zero) {
      return 'متأخر';
    }

    final totalSeconds = arrivalRemaining.inSeconds;
    final days = totalSeconds ~/ (24 * 3600);
    final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours ساعة');
    if (minutes > 0) parts.add('$minutes دقيقة');

    return parts.isEmpty ? 'أقل من دقيقة' : parts.join(' ، ');
  }

  String get effectiveRequestType {
    // 1️⃣ لو موجود على الطلب نفسه
    if (requestType != null && requestType!.trim().isNotEmpty) {
      return requestType!;
    }

    // 2️⃣ لو طلب مدمج وخزّن نوع العملية داخل mergedWithInfo
    if (mergedWithInfo != null) {
      const directKeys = [
        'requestType',
        'customerRequestType',
        'clientRequestType',
        'orderRequestType',
        'purchaseType',
        'operationType',
      ];

      for (final key in directKeys) {
        final value = mergedWithInfo![key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }

      const nestedKeys = [
        'customerOrder',
        'customer',
        'clientOrder',
        'client',
        'order',
      ];

      for (final key in nestedKeys) {
        final nested = mergedWithInfo![key];
        if (nested is Map) {
          final nestedValue =
              nested['requestType'] ??
              nested['customerRequestType'] ??
              nested['purchaseType'] ??
              nested['operationType'];
          if (nestedValue != null && nestedValue.toString().trim().isNotEmpty) {
            return nestedValue.toString();
          }
        }
      }
    }

    return 'غير محدد';
  }

  /// ⭐ تحديث: دالة للحصول على المؤقت المنسق للتحميل
  String get formattedLoadingCountdown {
    if (loadingRemaining <= Duration.zero) {
      return 'تأخر';
    }

    final totalSeconds = loadingRemaining.inSeconds;
    final days = totalSeconds ~/ (24 * 3600);
    final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours ساعة');
    if (minutes > 0) parts.add('$minutes دقيقة');

    return parts.isEmpty ? 'أقل من دقيقة' : parts.join(' و ');
  }

  // ⭐ إنشاء نسخة محدثة من الطلب
  Order copyWith({
    String? id,
    DateTime? orderDate,
    String? orderSource,
    String? mergeStatus,
    String? entryChannel,
    String? movementState,
    String? movementCustomerId,
    String? movementCustomerName,
    DateTime? movementCustomerRequestDate,
    DateTime? movementExpectedArrivalDate,
    String? movementCustomerOrderId,
    String? movementMergedOrderId,
    String? movementMergedOrderNumber,
    DateTime? movementDirectedAt,
    String? movementDirectedByName,
    String? portalStatus,
    String? portalReviewNotes,
    DateTime? portalReviewedAt,
    String? portalReviewedByName,
    String? portalCustomerId,
    String? portalCustomerName,
    String? destinationStationId,
    String? destinationStationName,
    String? carrierName,
    String? supplierName,
    String? requestType,
    double? requestAmount,
    String? orderNumber,
    String? supplierOrderNumber,
    DateTime? loadingDate,
    String? loadingTime,
    DateTime? arrivalDate,
    String? arrivalTime,
    String? status,
    String? supplierId,
    String? supplierContactPerson,
    String? supplierPhone,
    String? supplierAddress,
    String? supplierCompany,
    String? customerAddress,
    String? city,
    String? area,
    String? address,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? vehicleNumber,
    String? fuelType,
    double? quantity,
    String? unit,
    String? notes,
    String? companyLogo,
    List<Attachment>? attachments,
    String? createdById,
    String? createdByName,
    Customer? customer,
    Supplier? supplier,
    Driver? driver,
    String? mergedWithOrderId,
    Map<String, dynamic>? mergedWithInfo,
    DateTime? notificationSentAt,
    DateTime? arrivalNotificationSentAt,
    DateTime? driverAssignmentReminderAt,
    int? driverAssignmentReminderDays,
    int? driverAssignmentReminderHours,
    bool? driverAssignmentReminderActive,
    String? driverAssignmentReminderCreatedById,
    String? driverAssignmentReminderCreatedByName,
    DateTime? driverAssignmentReminderNotifiedAt,
    DateTime? loadingCompletedAt,
    String? actualFuelType,
    double? actualLoadedLiters,
    String? loadingStationName,
    String? driverLoadingNotes,
    DateTime? driverLoadingSubmittedAt,
    String? actualArrivalTime,
    int? loadingDuration,
    String? delayReason,
    double? unitPrice,
    double? totalPrice,
    double? vatRate,
    double? vatAmount,
    double? totalPriceWithVat,
    String? paymentMethod,
    String? paymentStatus,
    String? productType,
    double? driverEarnings,
    double? distance,
    int? deliveryDuration,
    String? transportSourceCity,
    int? transportCapacityLiters,
    Map<String, dynamic>? pricingSnapshot,
    Map<String, dynamic>? transportPricingOverride,
    DateTime? mergedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? cancellationApprovalStatus,
    DateTime? cancellationApprovalRequestedAt,
    String? cancellationApprovalRequestedByName,
    DateTime? cancellationApprovalApprovedAt,
    String? cancellationApprovalApprovedByName,
    String? cancellationApprovalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderDate: orderDate ?? this.orderDate,
      orderSource: orderSource ?? this.orderSource,
      mergeStatus: mergeStatus ?? this.mergeStatus,
      entryChannel: entryChannel ?? this.entryChannel,
      movementState: movementState ?? this.movementState,
      movementCustomerId: movementCustomerId ?? this.movementCustomerId,
      movementCustomerName: movementCustomerName ?? this.movementCustomerName,
      movementCustomerRequestDate:
          movementCustomerRequestDate ?? this.movementCustomerRequestDate,
      movementExpectedArrivalDate:
          movementExpectedArrivalDate ?? this.movementExpectedArrivalDate,
      movementCustomerOrderId:
          movementCustomerOrderId ?? this.movementCustomerOrderId,
      movementMergedOrderId:
          movementMergedOrderId ?? this.movementMergedOrderId,
      movementMergedOrderNumber:
          movementMergedOrderNumber ?? this.movementMergedOrderNumber,
      movementDirectedAt: movementDirectedAt ?? this.movementDirectedAt,
      movementDirectedByName:
          movementDirectedByName ?? this.movementDirectedByName,
      portalStatus: portalStatus ?? this.portalStatus,
      portalReviewNotes: portalReviewNotes ?? this.portalReviewNotes,
      portalReviewedAt: portalReviewedAt ?? this.portalReviewedAt,
      portalReviewedByName:
          portalReviewedByName ?? this.portalReviewedByName,
      portalCustomerId: portalCustomerId ?? this.portalCustomerId,
      portalCustomerName: portalCustomerName ?? this.portalCustomerName,
      destinationStationId: destinationStationId ?? this.destinationStationId,
      destinationStationName:
          destinationStationName ?? this.destinationStationName,
      carrierName: carrierName ?? this.carrierName,
      supplierName: supplierName ?? this.supplierName,
      requestType: requestType ?? this.requestType,
      requestAmount: requestAmount ?? this.requestAmount,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierOrderNumber: supplierOrderNumber ?? this.supplierOrderNumber,
      loadingDate: loadingDate ?? this.loadingDate,
      loadingTime: loadingTime ?? this.loadingTime,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      status: status ?? this.status,
      supplierId: supplierId ?? this.supplierId,
      supplierContactPerson:
          supplierContactPerson ?? this.supplierContactPerson,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      supplierAddress: supplierAddress ?? this.supplierAddress,
      supplierCompany: supplierCompany ?? this.supplierCompany,
      customerAddress: customerAddress ?? this.customerAddress,
      city: city ?? this.city,
      area: area ?? this.area,
      address: address ?? this.address,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      fuelType: fuelType ?? this.fuelType,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      companyLogo: companyLogo ?? this.companyLogo,
      attachments: attachments ?? this.attachments,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      customer: customer ?? this.customer,
      supplier: supplier ?? this.supplier,
      driver: driver ?? this.driver,
      mergedWithOrderId: mergedWithOrderId ?? this.mergedWithOrderId,
      mergedWithInfo: mergedWithInfo ?? this.mergedWithInfo,
      notificationSentAt: notificationSentAt ?? this.notificationSentAt,
      arrivalNotificationSentAt:
          arrivalNotificationSentAt ?? this.arrivalNotificationSentAt,
      driverAssignmentReminderAt:
          driverAssignmentReminderAt ?? this.driverAssignmentReminderAt,
      driverAssignmentReminderDays:
          driverAssignmentReminderDays ?? this.driverAssignmentReminderDays,
      driverAssignmentReminderHours:
          driverAssignmentReminderHours ?? this.driverAssignmentReminderHours,
      driverAssignmentReminderActive:
          driverAssignmentReminderActive ??
          this.driverAssignmentReminderActive,
      driverAssignmentReminderCreatedById:
          driverAssignmentReminderCreatedById ??
          this.driverAssignmentReminderCreatedById,
      driverAssignmentReminderCreatedByName:
          driverAssignmentReminderCreatedByName ??
          this.driverAssignmentReminderCreatedByName,
      driverAssignmentReminderNotifiedAt:
          driverAssignmentReminderNotifiedAt ??
          this.driverAssignmentReminderNotifiedAt,
      loadingCompletedAt: loadingCompletedAt ?? this.loadingCompletedAt,
      actualFuelType: actualFuelType ?? this.actualFuelType,
      actualLoadedLiters: actualLoadedLiters ?? this.actualLoadedLiters,
      loadingStationName: loadingStationName ?? this.loadingStationName,
      driverLoadingNotes: driverLoadingNotes ?? this.driverLoadingNotes,
      driverLoadingSubmittedAt:
          driverLoadingSubmittedAt ?? this.driverLoadingSubmittedAt,
      actualArrivalTime: actualArrivalTime ?? this.actualArrivalTime,
      loadingDuration: loadingDuration ?? this.loadingDuration,
      delayReason: delayReason ?? this.delayReason,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      vatRate: vatRate ?? this.vatRate,
      vatAmount: vatAmount ?? this.vatAmount,
      totalPriceWithVat: totalPriceWithVat ?? this.totalPriceWithVat,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      productType: productType ?? this.productType,
      driverEarnings: driverEarnings ?? this.driverEarnings,
      distance: distance ?? this.distance,
      deliveryDuration: deliveryDuration ?? this.deliveryDuration,
      transportSourceCity: transportSourceCity ?? this.transportSourceCity,
      transportCapacityLiters:
          transportCapacityLiters ?? this.transportCapacityLiters,
      pricingSnapshot: pricingSnapshot ?? this.pricingSnapshot,
      transportPricingOverride:
          transportPricingOverride ?? this.transportPricingOverride,
      mergedAt: mergedAt ?? this.mergedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationApprovalStatus:
          cancellationApprovalStatus ?? this.cancellationApprovalStatus,
      cancellationApprovalRequestedAt:
          cancellationApprovalRequestedAt ??
          this.cancellationApprovalRequestedAt,
      cancellationApprovalRequestedByName:
          cancellationApprovalRequestedByName ??
          this.cancellationApprovalRequestedByName,
      cancellationApprovalApprovedAt:
          cancellationApprovalApprovedAt ??
          this.cancellationApprovalApprovedAt,
      cancellationApprovalApprovedByName:
          cancellationApprovalApprovedByName ??
          this.cancellationApprovalApprovedByName,
      cancellationApprovalNotes:
          cancellationApprovalNotes ?? this.cancellationApprovalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
