import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:order_tracker/localization/app_localizations.dart' as loc;
import 'package:order_tracker/models/driver_tracking_models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/driver_tracking_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/services/firebase_storage_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/driver_background_location_permission.dart';
import 'package:order_tracker/utils/tracking_directions_service.dart';
import 'package:order_tracker/widgets/maps/advanced_web_map.dart';
import 'package:provider/provider.dart';

class DriverDeliveryTrackingScreen extends StatefulWidget {
  final String? orderId;
  final Order? initialOrder;
  final bool showMap;

  const DriverDeliveryTrackingScreen({
    super.key,
    this.orderId,
    this.initialOrder,
    this.showMap = true,
  });

  @override
  State<DriverDeliveryTrackingScreen> createState() =>
      _DriverDeliveryTrackingScreenState();
}

class _DriverDeliveryTrackingScreenState
    extends State<DriverDeliveryTrackingScreen> {
  static const String _defaultLoadingStationLabelAr = 'أرامكو بريدة';
  static const String _defaultLoadingStationLabelEn = 'Aramco Buraidah';
  static const String _defaultLoadingStationQueryAr =
      'أرامكو بريدة، القصيم، السعودية';
  static const String _defaultLoadingStationQueryEn =
      'Aramco Buraidah, Al Qassim, Saudi Arabia';
  static const List<String> _fuelTypes = <String>[
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
    'غاز طبيعي',
    'أخرى',
  ];

  Order? _order;
  String? _driverId;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _orderRefreshTimer;
  List<LatLng> _routePoints = const <LatLng>[];
  double? _distanceKm;
  int? _durationMinutes;
  DateTime? _lastPublishedAt;
  LatLng? _lastPublishedLocation;
  DateTime? _lastRouteRefreshAt;
  String? _error;
  String? _routeError;
  bool _isPreparing = true;
  bool _isSharing = false;
  bool _isRouteLoading = false;
  bool _isUpdatingStatus = false;

  final ImagePicker _imagePicker = ImagePicker();
  String? _cachedCustomerId;
  LatLng? _cachedCustomerLocation;
  bool _isCustomerLocationLoading = false;
  String? _customerLocationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  String get _normalizedStatus => _order?.status.trim() ?? '';

  String get _languageCode {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code == 'ar' ? 'ar' : 'en';
  }

  bool get _isArabic => _languageCode == 'ar';

  String get _defaultLoadingStationLabel =>
      _isArabic
          ? _defaultLoadingStationLabelAr
          : _defaultLoadingStationLabelEn;

  String get _defaultLoadingStationQuery =>
      _isArabic
          ? _defaultLoadingStationQueryAr
          : _defaultLoadingStationQueryEn;

  String _text(String key, [Map<String, String> params = const {}]) {
    const copy = <String, Map<String, String>>{
      'screenTitle': {
        'ar': 'تنفيذ الطلب والتتبع الحي',
        'en': 'Order Execution & Live Tracking',
      },
      'refresh': {'ar': 'تحديث', 'en': 'Refresh'},
      'noDriverLinked': {
        'ar': 'لا يوجد سائق مرتبط بهذا المستخدم',
        'en': 'No driver is linked to this user.',
      },
      'noOrderData': {
        'ar': 'لا توجد بيانات للطلب',
        'en': 'No order data is available.',
      },
      'dispatchStatus': {'ar': 'حالة التوجيه', 'en': 'Dispatch status'},
      'loadingDestination': {'ar': 'وجهة التعبئة', 'en': 'Loading destination'},
      'deliveryDestination': {'ar': 'وجهة التسليم', 'en': 'Delivery destination'},
      'waitingDispatchTitle': {
        'ar': 'بانتظار توجيه الحركة إلى العميل',
        'en': 'Waiting for movement dispatch to the customer',
      },
      'waitingDispatchDestination': {
        'ar': 'بانتظار توجيه الحركة للعميل',
        'en': 'Waiting for movement dispatch to the customer',
      },
      'customerLocation': {'ar': 'موقع العميل', 'en': 'Customer location'},
      'currentLocation': {'ar': 'موقعك الحالي', 'en': 'Your current location'},
      'remainingDistance': {'ar': 'المسافة المتبقية', 'en': 'Remaining distance'},
      'eta': {'ar': 'الوقت المتوقع', 'en': 'Estimated time'},
      'lastSync': {'ar': 'آخر إرسال', 'en': 'Last update'},
      'trackingStatus': {'ar': 'حالة التتبع', 'en': 'Tracking status'},
      'trackingActive': {'ar': 'يعمل الآن', 'en': 'Active now'},
      'trackingStopped': {'ar': 'متوقف', 'en': 'Stopped'},
      'stopTracking': {'ar': 'إيقاف التتبع', 'en': 'Stop tracking'},
      'startTracking': {'ar': 'تشغيل التتبع', 'en': 'Start tracking'},
      'updateRoute': {'ar': 'تحديث المسار', 'en': 'Refresh route'},
      'orderDetails': {
        'ar': 'تفاصيل الطلب {number}',
        'en': 'Order details {number}',
      },
      'customer': {'ar': 'العميل', 'en': 'Customer'},
      'loadingStation': {'ar': 'محطة التعبئة', 'en': 'Loading station'},
      'requestedFuel': {'ar': 'الوقود المطلوب', 'en': 'Requested fuel'},
      'requestedQuantity': {'ar': 'الكمية المطلوبة', 'en': 'Requested quantity'},
      'orderNotes': {'ar': 'ملاحظات الطلب', 'en': 'Order notes'},
      'loadingData': {'ar': 'بيانات التعبئة', 'en': 'Loading data'},
      'actualFuel': {'ar': 'الوقود الفعلي', 'en': 'Actual fuel'},
      'actualLiters': {'ar': 'اللترات الفعلية', 'en': 'Actual liters'},
      'submittedAt': {'ar': 'وقت الإرسال', 'en': 'Submitted at'},
      'driverNotes': {'ar': 'ملاحظات السائق', 'en': 'Driver notes'},
      'loadingSentWait': {
        'ar': 'تم إرسال بيانات التعبئة. بانتظار توجيه الحركة للعميل.',
        'en': 'Loading data was submitted. Waiting for movement dispatch to the customer.',
      },
      'loadingSentContinue': {
        'ar': 'تم إرسال بيانات التعبئة. استكمل الرحلة إلى العميل.',
        'en': 'Loading data was submitted. Continue the trip to the customer.',
      },
      'loadingPromptWait': {
        'ar': 'بعد التعبئة صوّر كرت أرامكو ثم أدخل بيانات التعبئة. سيتم وضع الطلب بانتظار توجيه الحركة للعميل.',
        'en': 'After loading, capture the Aramco card and enter loading data. The order will wait for movement dispatch to the customer.',
      },
      'loadingPromptContinue': {
        'ar': 'بعد التعبئة صوّر كرت أرامكو ثم أدخل بيانات التعبئة لمتابعة التوصيل إلى العميل.',
        'en': 'After loading, capture the Aramco card and enter loading data to continue delivery to the customer.',
      },
      'loadingPendingData': {
        'ar': 'ستظهر هنا بيانات التعبئة بمجرد إرسالها من السائق.',
        'en': 'Loading data will appear here once it is submitted by the driver.',
      },
      'loadingDone': {'ar': 'تم التعبئة', 'en': 'Loading completed'},
      'driverActions': {'ar': 'إجراءات السائق', 'en': 'Driver actions'},
      'waitingDispatchMessage': {
        'ar': 'الطلب بانتظار توجيه الحركة إلى العميل. سيتم تحديث الوجهة تلقائياً عند التوجيه.',
        'en': 'This order is waiting for movement dispatch to the customer. The destination will update automatically once dispatched.',
      },
      'noExtraActions': {
        'ar': 'لا توجد إجراءات إضافية حالياً لهذا الطلب.',
        'en': 'There are no additional actions for this order right now.',
      },
      'enterLoadingFirst': {
        'ar': 'أدخل بيانات التعبئة أولاً قبل بدء التوصيل إلى العميل.',
        'en': 'Enter loading data first before starting delivery to the customer.',
      },
      'unload': {'ar': 'تفريغ', 'en': 'Unload'},
      'deliveryProofTitle': {
        'ar': 'إثبات التفريغ (مطلوب)',
        'en': 'Unloading proof (required)',
      },
      'deliveryProofMessage': {
        'ar': 'قبل إنهاء الطلب يجب تصوير جميع الصور المطلوبة بالكاميرا فقط.',
        'en': 'Before completing the order, capture all required photos using the camera only.',
      },
      'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
      'uploading': {'ar': 'جاري الرفع...', 'en': 'Uploading...'},
      'sendAndComplete': {'ar': 'إرسال وإكمال', 'en': 'Submit & complete'},
      'capture': {'ar': 'تصوير', 'en': 'Capture'},
      'retake': {'ar': 'إعادة', 'en': 'Retake'},
      'allPhotosRequired': {
        'ar': 'الرجاء تصوير جميع الصور المطلوبة قبل الإكمال.',
        'en': 'Please capture all required photos before completing.',
      },
      'deliveryUploadFailed': {
        'ar': 'فشل رفع صور التفريغ. حاول مرة أخرى.',
        'en': 'Failed to upload unloading photos. Please try again.',
      },
      'fuelPhoto': {'ar': 'صورة البنزين', 'en': 'Fuel photo'},
      'stationPhoto': {'ar': 'صورة المحطة', 'en': 'Station photo'},
      'carPhoto': {'ar': 'صورة السيارة', 'en': 'Vehicle photo'},
      'tankPhoto': {'ar': 'صورة التانكي من الأعلى', 'en': 'Tank top photo'},
      'workerPhoto': {'ar': 'صورة وجه العامل', 'en': 'Worker face photo'},
      'receiptPhoto': {'ar': 'صورة سند الاستلام', 'en': 'Receipt photo'},
      'actualFuelType': {'ar': 'نوع الوقود الفعلي', 'en': 'Actual fuel type'},
      'actualLitersCount': {
        'ar': 'عدد اللترات الفعلية',
        'en': 'Actual loaded liters',
      },
      'driverNotesInput': {'ar': 'ملاحظات السائق', 'en': 'Driver notes'},
      'aramcoCardRequired': {
        'ar': 'صورة كرت أرامكو مطلوبة (كاميرا فقط)',
        'en': 'An Aramco card photo is required (camera only).',
      },
      'enterValidLiters': {
        'ar': 'أدخل كمية فعلية صحيحة باللتر',
        'en': 'Enter a valid actual quantity in liters.',
      },
      'aramcoCardUploadFailed': {
        'ar': 'فشل رفع صورة كرت أرامكو. حاول مرة أخرى.',
        'en': 'Failed to upload the Aramco card photo. Please try again.',
      },
      'loadingSubmitFailed': {
        'ar': 'فشل إرسال بيانات التعبئة',
        'en': 'Failed to submit loading data.',
      },
      'aramcoCardCamera': {
        'ar': 'صورة كرت أرامكو (كاميرا فقط)',
        'en': 'Aramco card photo (camera only)',
      },
      'aramcoCardCaptured': {
        'ar': 'تم التقاط صورة كرت أرامكو',
        'en': 'Aramco card photo captured',
      },
      'saveInProgress': {'ar': 'جارٍ الحفظ...', 'en': 'Saving...'},
      'enterValidQtyShort': {'ar': 'أدخل كمية صحيحة', 'en': 'Enter a valid quantity'},
      'statusUpdated': {
        'ar': 'تم تحديث حالة الطلب إلى {status}',
        'en': 'Order status updated to {status}',
      },
      'statusUpdateFailed': {
        'ar': 'فشل تحديث حالة الطلب',
        'en': 'Failed to update order status.',
      },
      'routeNotFound': {
        'ar': 'لم يتم العثور على مسار للوجهة الحالية',
        'en': 'No route was found for the current destination.',
      },
      'destinationIncomplete': {
        'ar': 'عنوان الوجهة غير مكتمل',
        'en': 'The destination address is incomplete.',
      },
      'deliveryLoadingSuccessWait': {
        'ar': 'تم إرسال بيانات التعبئة. بانتظار توجيه الحركة للعميل.',
        'en': 'Loading data was submitted. Waiting for movement dispatch to the customer.',
      },
      'deliveryLoadingSuccessContinue': {
        'ar': 'تم إرسال بيانات التعبئة. استكمل الرحلة إلى العميل.',
        'en': 'Loading data was submitted. Continue the trip to the customer.',
      },
      'customerLocationLoadFailed': {
        'ar': 'تعذر تحميل موقع العميل',
        'en': 'Unable to load the customer location.',
      },
      'customerLocationReadFailed': {
        'ar': 'تعذر قراءة بيانات العميل',
        'en': 'Unable to read customer data.',
      },
      'customerCoordinatesMissing': {
        'ar': 'لا توجد إحداثيات للعميل',
        'en': 'No customer coordinates are available.',
      },
      'locationServiceDisabled': {
        'ar': 'خدمة الموقع غير مفعلة على الجهاز',
        'en': 'Location service is disabled on this device.',
      },
      'locationPermissionDenied': {
        'ar': 'تم رفض صلاحية الموقع، ولا يمكن تشغيل التتبع الحي',
        'en': 'Location permission was denied, so live tracking cannot start.',
      },
      'customerChangedRoute': {
        'ar': 'تم تبديل العميل وتم تحديث المسار تلقائياً.',
        'en': 'The customer was changed and the route was updated automatically.',
      },
    };

    var value = copy[key]?[_languageCode] ?? copy[key]?['ar'] ?? key;
    params.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
  }

  String _localizedFuelType(String? fuelType) {
    final value = fuelType?.trim();
    if (value == null || value.isEmpty) {
      return context.tr(loc.AppStrings.driverUnknownFuel);
    }

    switch (value) {
      case 'بنزين 91':
        return context.tr(loc.AppStrings.filterFuelType91);
      case 'بنزين 95':
        return context.tr(loc.AppStrings.filterFuelType95);
      case 'ديزل':
        return context.tr(loc.AppStrings.filterFuelTypeDiesel);
      case 'غاز':
      case 'غاز طبيعي':
        return context.tr(loc.AppStrings.filterFuelTypeGas);
      default:
        return value;
    }
  }

  String _localizedStatus(String status) {
    switch (status.trim()) {
      case 'تم التحميل':
        return context.tr(loc.AppStrings.driverStatusLoaded);
      case 'في الطريق':
        return context.tr(loc.AppStrings.driverStatusOnWay);
      case 'تم التسليم':
        return context.tr(loc.AppStrings.driverStatusDelivered);
      case 'تم التنفيذ':
        return context.tr(loc.AppStrings.driverStatusExecuted);
      case 'مكتمل':
        return context.tr(loc.AppStrings.driverStatusCompleted);
      case 'ملغى':
        return context.tr(loc.AppStrings.driverStatusCanceled);
      default:
        return status;
    }
  }

  bool get _hasLoadingData {
    final order = _order;
    if (order == null) return false;
    final hasFuel = order.actualFuelType?.trim().isNotEmpty == true;
    final hasLiters = (order.actualLoadedLiters ?? 0) > 0;
    return hasFuel && hasLiters;
  }

  bool get _isWaitingMovementDispatch {
    final order = _order;
    if (order == null) return false;
    return order.isMovementOrder &&
        order.isMovementPendingDispatch &&
        _normalizedStatus == 'تم التحميل';
  }

  bool get _isHeadingToLoadingStation {
    if (_isWaitingMovementDispatch) return false;
    const postLoadingStatuses = <String>{
      'تم التحميل',
      'في الطريق',
      'تم التسليم',
      'تم التنفيذ',
      'مكتمل',
      'ملغى',
    };
    return !postLoadingStatuses.contains(_normalizedStatus);
  }

  bool get _isFinalStatus {
    const finalStatuses = <String>{
      'تم التسليم',
      'تم التنفيذ',
      'مكتمل',
      'ملغى',
    };
    return finalStatuses.contains(_normalizedStatus);
  }

  bool get _canSubmitLoadingData {
    if (_hasLoadingData || _isFinalStatus || _isWaitingMovementDispatch) {
      return false;
    }
    return _isHeadingToLoadingStation || _normalizedStatus == 'تم التحميل';
  }

  String get _loadingStationName {
    final order = _order;
    if (order == null) return _defaultLoadingStationLabel;

    final explicitStation = order.loadingStationName?.trim();
    if (explicitStation != null && explicitStation.isNotEmpty) {
      if (explicitStation == 'محطة أرامكو') {
        return _defaultLoadingStationLabel;
      }
      return explicitStation;
    }

    return _defaultLoadingStationLabel;
  }

  String get _loadingStationDestinationText {
    final order = _order;
    if (order == null) return _defaultLoadingStationLabel;

    if (order.supplierAddress?.trim().isNotEmpty == true) {
      return order.supplierAddress!.trim();
    }

    return _loadingStationName;
  }

  String get _customerDestinationText {
    final order = _order;
    if (order == null) return '';

    if (order.address?.trim().isNotEmpty == true) {
      return order.address!.trim();
    }

    if (order.customerAddress?.trim().isNotEmpty == true) {
      return order.customerAddress!.trim();
    }

    final parts = <String>[
      if (order.city?.trim().isNotEmpty == true) order.city!.trim(),
      if (order.area?.trim().isNotEmpty == true) order.area!.trim(),
    ];

    final locationText = parts.join(' - ');
    if (locationText.trim().isNotEmpty) return locationText.trim();

    final movementCustomer = order.movementCustomerName?.trim();
    if (movementCustomer != null && movementCustomer.isNotEmpty) {
      return movementCustomer;
    }

    return '';
  }

  String get _destinationText {
    if (_isWaitingMovementDispatch) {
      return _text('waitingDispatchDestination');
    }
    return _isHeadingToLoadingStation
        ? _loadingStationDestinationText
        : _customerDestinationText;
  }

  String? get _destinationQuery {
    if (_isWaitingMovementDispatch) return null;
    if (_isHeadingToLoadingStation) {
      final text = _loadingStationDestinationText.trim();
      if (text.isEmpty) {
        return _defaultLoadingStationQuery;
      }
      if (text == _defaultLoadingStationLabel) {
        return _defaultLoadingStationQuery;
      }
      return text.isEmpty ? null : text;
    }

    final cached = _cachedCustomerLocation;
    if (cached != null) {
      return '${cached.latitude},${cached.longitude}';
    }

    final text = _customerDestinationText.trim();
    return text.isEmpty ? null : text;
  }

  String get _destinationLabel {
    if (_isWaitingMovementDispatch) {
      return _text('dispatchStatus');
    }
    return _isHeadingToLoadingStation
        ? _text('loadingDestination')
        : _text('deliveryDestination');
  }

  String get _stageTitle {
    if (_isWaitingMovementDispatch) {
      return _text('waitingDispatchTitle');
    }
    return _isHeadingToLoadingStation
        ? context.tr(loc.AppStrings.driverHeadingToLoadingStation)
        : context.tr(loc.AppStrings.driverHeadingToCustomer);
  }

  String get _destinationMarkerTitle {
    if (_isHeadingToLoadingStation) return _loadingStationName;
    return _text('customerLocation');
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthProvider>();
    final driverId = auth.user?.driverId;
    if (driverId == null || driverId.trim().isEmpty) {
      setState(() {
        _error = _text('noDriverLinked');
        _isPreparing = false;
      });
      return;
    }

    _driverId = driverId;

    try {
      await _loadOrder(forceRefresh: true);
      final locationReady = await _ensureLocationPermission();
      if (!locationReady) {
        setState(() => _isPreparing = false);
        return;
      }

      await _loadCurrentLocation();
      await _refreshRoute(force: true);
      await _startSharing();
      _startOrderRefresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _loadOrder({bool forceRefresh = false}) async {
    final orderProvider = context.read<OrderProvider>();
    final preferredOrderId = widget.orderId ?? widget.initialOrder?.id;
    if (preferredOrderId == null || preferredOrderId.isEmpty) {
      throw Exception(_text('noOrderData'));
    }

    final fallbackOrder =
        widget.initialOrder ??
        orderProvider.getOrderById(preferredOrderId) ??
        _order;
    if (fallbackOrder != null && fallbackOrder.id.isNotEmpty) {
      _setOrder(fallbackOrder, notify: !forceRefresh);
    }

    if (forceRefresh) {
      await orderProvider.fetchOrderById(preferredOrderId, silent: true);
      final freshOrder =
          orderProvider.selectedOrder ??
          orderProvider.getOrderById(preferredOrderId);

      if (freshOrder != null) {
        _setOrder(freshOrder);
      } else if (orderProvider.error != null && mounted) {
        setState(() {
          _error = orderProvider.error;
        });
      }
    }

    if (_order == null) {
      throw Exception(_text('noOrderData'));
    }
  }

  void _setOrder(Order order, {bool notify = true}) {
    final previousMovementCustomerId = _order?.movementCustomerId?.trim();
    final nextMovementCustomerId = order.movementCustomerId?.trim();

    if (!mounted || !notify) {
      _order = order;
    } else {
      setState(() {
        _order = order;
      });
    }

    _syncCustomerCoordinates(order);

    if (previousMovementCustomerId != null &&
        previousMovementCustomerId.isNotEmpty &&
        nextMovementCustomerId != null &&
        nextMovementCustomerId.isNotEmpty &&
        previousMovementCustomerId != nextMovementCustomerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_text('customerChangedRoute')),
            backgroundColor: AppColors.infoBlue,
          ),
        );
      });

      if (widget.showMap) {
        unawaited(_refreshRoute(force: true));
      }
    }

    if (_isFinalStatus) {
      unawaited(_stopSharing());
    }
  }

  void _syncCustomerCoordinates(Order order) {
    final customer = order.customer;
    final directId = customer?.id.trim();
    final movementId = order.movementCustomerId?.trim();

    final customerId = (directId != null && directId.isNotEmpty)
        ? directId
        : (movementId != null && movementId.isNotEmpty ? movementId : null);

    if (customerId == null) {
      if (_cachedCustomerId != null ||
          _cachedCustomerLocation != null ||
          _customerLocationError != null) {
        setState(() {
          _cachedCustomerId = null;
          _cachedCustomerLocation = null;
          _customerLocationError = null;
        });
      }
      return;
    }

    final lat = customer?.latitude;
    final lng = customer?.longitude;
    if (lat != null && lng != null) {
      if (_cachedCustomerId != customerId ||
          _cachedCustomerLocation?.latitude != lat ||
          _cachedCustomerLocation?.longitude != lng) {
        setState(() {
          _cachedCustomerId = customerId;
          _cachedCustomerLocation = LatLng(lat, lng);
          _customerLocationError = null;
        });
      }
      return;
    }

    if (_cachedCustomerId == customerId && _cachedCustomerLocation != null) {
      return;
    }

    unawaited(_fetchCustomerLocation(customerId));
  }

  Future<void> _fetchCustomerLocation(String customerId) async {
    if (!mounted) return;
    if (_isCustomerLocationLoading && _cachedCustomerId == customerId) {
      return;
    }

    setState(() {
      _cachedCustomerId = customerId;
      _cachedCustomerLocation = null;
      _isCustomerLocationLoading = true;
      _customerLocationError = null;
    });

    try {
      await ApiService.loadToken();
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/customers/$customerId'),
        headers: ApiService.headers,
      );

      if (response.statusCode != 200) {
        throw Exception(_text('customerLocationLoadFailed'));
      }

      final data = ApiService.decodeJsonMap(response);
      final raw = data['customer'] ?? data['data'] ?? data;
      if (raw is! Map) {
        throw Exception(_text('customerLocationReadFailed'));
      }

      final map = Map<String, dynamic>.from(raw);
      final latitude = (map['latitude'] as num?)?.toDouble();
      final longitude = (map['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        if (!mounted) return;
        setState(() {
          _customerLocationError = _text('customerCoordinatesMissing');
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _cachedCustomerLocation = LatLng(latitude, longitude);
        _customerLocationError = null;
      });

      if (widget.showMap) {
        unawaited(_refreshRoute(force: true));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _customerLocationError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCustomerLocationLoading = false;
        });
      }
    }
  }

  void _startOrderRefresh() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted || _order == null) return;
      await _loadOrder(forceRefresh: true);
      await _refreshRoute(force: true);
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = _text('locationServiceDisabled');
      });
      return false;
    }

    var permission = await DriverBackgroundLocationPermission
        .requestBackgroundLocationPermission();

    if (permission == LocationPermission.deniedForever && mounted) {
      await DriverBackgroundLocationPermission.showSettingsDialog(context);
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _error = _text('locationPermissionDenied');
      });
      return false;
    }

    return true;
  }

  Future<void> _loadCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    await _publishLocation(position, force: true);
  }

  Future<void> _startSharing() async {
    if (_isSharing || _isFinalStatus) return;
    await _positionSubscription?.cancel();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _trackingLocationSettings,
        ).listen(
          (position) async {
            if (!mounted) return;
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
            await _publishLocation(position);
            unawaited(_refreshRoute());
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _error = error.toString();
            });
          },
        );

    if (mounted) {
      setState(() {
        _isSharing = true;
      });
    }
  }

  Future<void> _stopSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _publishLocation(Position position, {bool force = false}) async {
    if (_driverId == null || _order == null || _isFinalStatus) return;

    final nextLocation = LatLng(position.latitude, position.longitude);
    final now = DateTime.now();
    final movedEnough =
        _lastPublishedLocation == null ||
        Geolocator.distanceBetween(
              _lastPublishedLocation!.latitude,
              _lastPublishedLocation!.longitude,
              nextLocation.latitude,
              nextLocation.longitude,
            ) >=
            15;
    final waitedEnough =
        _lastPublishedAt == null ||
        now.difference(_lastPublishedAt!).inSeconds >= 8;

    if (!force && !movedEnough && !waitedEnough) {
      return;
    }

    final snapshot = DriverLocationSnapshot(
      id: '',
      driverId: _driverId!,
      orderId: _order!.id,
      latitude: nextLocation.latitude,
      longitude: nextLocation.longitude,
      accuracy: position.accuracy,
      speed: position.speed >= 0 ? position.speed : 0,
      heading: position.heading >= 0 ? position.heading : 0,
      timestamp: now,
    );

    final trackingProvider = context.read<DriverTrackingProvider>();
    final ok = await trackingProvider.publishDriverLocation(snapshot: snapshot);
    if (!ok || !mounted) {
      if (mounted && trackingProvider.error != null) {
        setState(() {
          _error = trackingProvider.error;
        });
      }
      return;
    }

    setState(() {
      _lastPublishedAt = now;
      _lastPublishedLocation = nextLocation;
      _error = null;
    });
  }

  Future<void> _refreshRoute({bool force = false}) async {
    if (!widget.showMap) return;
    if (_currentLocation == null || _order == null) return;

    final destinationQuery = _destinationQuery;
    if (destinationQuery == null || destinationQuery.trim().isEmpty) {
      setState(() {
        _routePoints = const <LatLng>[];
        _distanceKm = null;
        _durationMinutes = null;
        _routeError = _isWaitingMovementDispatch
            ? null
            : _text('destinationIncomplete');
      });
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRouteRefreshAt != null &&
        now.difference(_lastRouteRefreshAt!).inSeconds < 12) {
      return;
    }
    _lastRouteRefreshAt = now;

    setState(() {
      _isRouteLoading = true;
      _routeError = null;
    });

    try {
      final routes = await fetchTrackingRoutes(
        origin: '${_currentLocation!.latitude},${_currentLocation!.longitude}',
        destination: destinationQuery,
        language: _languageCode,
      );
      if (!mounted) return;

      if (routes.isEmpty) {
        setState(() {
          _routePoints = const <LatLng>[];
          _distanceKm = null;
          _durationMinutes = null;
          _routeError = _text('routeNotFound');
          _isRouteLoading = false;
        });
        return;
      }

      final route = routes.first;
      setState(() {
        _routePoints = route.points;
        _distanceKm = route.distanceKm;
        _durationMinutes = route.durationMinutes;
        _routeError = null;
        _isRouteLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _routeError = error.toString();
        _isRouteLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
    await _loadOrder(forceRefresh: true);
    await _refreshRoute(force: true);
  }

  Future<void> _updateStatus(String nextStatus) async {
    final order = _order;
    if (order == null || _isUpdatingStatus) return;

    List<Map<String, dynamic>>? deliveryAttachments;
    if (nextStatus == 'تم التسليم') {
      deliveryAttachments = await _promptDeliveryProofAttachments(order.id);
      if (!mounted) return;
      if (deliveryAttachments == null) {
        return;
      }
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    final provider = context.read<OrderProvider>();
    final ok = await provider.updateOrderStatus(
      order.id,
      nextStatus,
      attachments: deliveryAttachments,
    );

    if (!mounted) return;

    if (ok) {
      await _loadOrder(forceRefresh: true);

      if (nextStatus == 'تم التسليم') {
        await _stopSharing();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'statusUpdated',
              {'status': _localizedStatus(nextStatus)},
            ),
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _refreshRoute(force: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? _text('statusUpdateFailed')),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>?> _promptDeliveryProofAttachments(
    String orderId,
  ) async {
    final required = <({String key, String label, String fileName})>[
      (
        key: 'fuel',
        label: _text('fuelPhoto'),
        fileName: 'delivery_fuel.jpg',
      ),
      (
        key: 'station',
        label: _text('stationPhoto'),
        fileName: 'delivery_station.jpg',
      ),
      (
        key: 'car',
        label: _text('carPhoto'),
        fileName: 'delivery_car.jpg',
      ),
      (
        key: 'tank',
        label: _text('tankPhoto'),
        fileName: 'delivery_tank_top.jpg',
      ),
      (
        key: 'worker',
        label: _text('workerPhoto'),
        fileName: 'delivery_worker_face.jpg',
      ),
      (
        key: 'receipt',
        label: _text('receiptPhoto'),
        fileName: 'delivery_receipt.jpg',
      ),
    ];

    final picked = <String, XFile>{};
    String? error;
    var isUploading = false;

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickPhoto(String key) async {
              final photo = await _imagePicker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );
              if (photo == null) return;
              setDialogState(() {
                picked[key] = photo;
                error = null;
              });
            }

            Future<void> handleSubmit() async {
              final missing = required
                  .where((item) => !picked.containsKey(item.key))
                  .toList();
              if (missing.isNotEmpty) {
                setDialogState(() {
                  error = _text('allPhotosRequired');
                });
                return;
              }

              setDialogState(() {
                isUploading = true;
                error = null;
              });

              try {
                final attachments = <Map<String, dynamic>>[];
                for (final item in required) {
                  final file = picked[item.key]!;
                  attachments.add(
                    await FirebaseStorageService.uploadOrderDriverMedia(
                      orderKey: orderId,
                      section: 'delivery_proof',
                      file: file,
                      filenameOverride: item.fileName,
                    ),
                  );
                }

                if (!context.mounted) return;
                Navigator.of(dialogContext).pop(attachments);
              } catch (e) {
                setDialogState(() {
                  isUploading = false;
                  error = _text('deliveryUploadFailed');
                });
              }
            }

            return AlertDialog(
              title: Text(_text('deliveryProofTitle')),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('deliveryProofMessage'),
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...required.map((item) {
                        final done = picked.containsKey(item.key);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lightGray),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (done
                                          ? AppColors.successGreen
                                          : AppColors.statusGold)
                                      .withValues(alpha: 0.14),
                                ),
                                child: Icon(
                                  done
                                      ? Icons.check_circle_rounded
                                      : Icons.camera_alt_outlined,
                                  color: done
                                      ? AppColors.successGreen
                                      : AppColors.statusGold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    isUploading ? null : () => pickPhoto(item.key),
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: Text(
                                  done ? _text('retake') : _text('capture'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: AppColors.errorRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(_text('cancel')),
                ),
                ElevatedButton.icon(
                  onPressed:
                      isUploading ? null : handleSubmit,
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    isUploading
                        ? _text('uploading')
                        : _text('sendAndComplete'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  List<String> _allowedNextStatuses(Order order) {
    final currentStatus = order.status.trim();
    final waitingDispatch =
        order.isMovementOrder &&
        order.isMovementPendingDispatch &&
        currentStatus == 'تم التحميل';

    if (waitingDispatch) {
      return const <String>[];
    }

    if (!_hasLoadingData &&
        const <String>{
          'جاهز للتحميل',
          'في انتظار التحميل',
          'تم التحميل',
        }.contains(currentStatus)) {
      return const <String>[];
    }

    switch (currentStatus) {
      case 'تم التحميل':
        return const <String>['في الطريق'];
      case 'في الطريق':
        return const <String>['تم التسليم'];
      default:
        return const <String>[];
    }
  }

  Future<void> _submitLoadingData() async {
    final order = _order;
    if (order == null) return;

    final formKey = GlobalKey<FormState>();
    final litersController = TextEditingController(
      text: order.actualLoadedLiters == null
          ? ''
          : _formatLiters(order.actualLoadedLiters),
    );
    final notesController = TextEditingController(
      text: order.driverLoadingNotes ?? '',
    );
    var selectedFuel = order.actualFuelType?.trim().isNotEmpty == true
        ? order.actualFuelType!.trim()
        : order.fuelType?.trim().isNotEmpty == true
        ? order.fuelType!.trim()
        : _fuelTypes.first;
    String? submitError;
    bool isSubmitting = false;
    XFile? aramcoCardPhoto;

    final submitted =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                Future<void> handleSubmit() async {
                  if (aramcoCardPhoto == null) {
                    setDialogState(() {
                      submitError = _text('aramcoCardRequired');
                    });
                    return;
                  }

                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final liters = double.tryParse(
                    litersController.text.trim().replaceAll(',', '.'),
                  );
                  if (liters == null || liters <= 0) {
                    setDialogState(() {
                      submitError = _text('enterValidLiters');
                    });
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = true;
                    submitError = null;
                  });

                  Map<String, dynamic>? aramcoAttachment;
                  try {
                    aramcoAttachment =
                        await FirebaseStorageService.uploadOrderDriverMedia(
                          orderKey: order.id,
                          section: 'loading',
                          file: aramcoCardPhoto!,
                          filenameOverride: 'aramco_card.jpg',
                        );
                  } catch (e) {
                    if (!mounted) return;
                    setDialogState(() {
                      isSubmitting = false;
                      submitError = _text('aramcoCardUploadFailed');
                    });
                    return;
                  }

                  final ok =
                      await context.read<OrderProvider>().submitDriverLoadingData(
                            order.id,
                            actualFuelType: selectedFuel,
                            actualLoadedLiters: liters,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                            attachments: aramcoAttachment == null
                                ? null
                                : <Map<String, dynamic>>[aramcoAttachment],
                          );

                  if (!mounted) return;

                  if (ok) {
                    Navigator.of(dialogContext).pop(true);
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = false;
                    submitError =
                        context.read<OrderProvider>().error ??
                        _text('loadingSubmitFailed');
                  });
                }

                return AlertDialog(
                  title: Text(_text('loadingDone')),
                  content: SizedBox(
                    width: 420,
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundGray,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightGray),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    aramcoCardPhoto == null
                                        ? _text('aramcoCardCamera')
                                        : _text('aramcoCardCaptured'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          final picked = await _imagePicker
                                              .pickImage(
                                                source: ImageSource.camera,
                                                imageQuality: 85,
                                              );
                                          if (picked == null) return;
                                          setDialogState(() {
                                            aramcoCardPhoto = picked;
                                            submitError = null;
                                          });
                                        },
                                  icon: const Icon(Icons.camera_alt_rounded),
                                  label: Text(
                                    aramcoCardPhoto == null
                                        ? _text('capture')
                                        : _text('retake'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedFuel,
                            decoration: InputDecoration(
                              labelText: _text('actualFuelType'),
                              border: const OutlineInputBorder(),
                            ),
                            items: _fuelTypes
                                .map(
                                  (fuel) => DropdownMenuItem<String>(
                                    value: fuel,
                                    child: Text(_localizedFuelType(fuel)),
                                  ),
                                )
                                .toList(),
                            onChanged: isSubmitting
                                ? null
                                : (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return;
                                    }
                                    setDialogState(() {
                                      selectedFuel = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: litersController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: _text('actualLitersCount'),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                value?.trim().replaceAll(',', '.') ?? '',
                              );
                              if (parsed == null || parsed <= 0) {
                                return _text('enterValidQtyShort');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: notesController,
                            enabled: !isSubmitting,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: _text('driverNotesInput'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          if (submitError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              submitError!,
                              style: const TextStyle(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                      child: Text(_text('cancel')),
                    ),
                    ElevatedButton.icon(
                      onPressed: isSubmitting ? null : handleSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isSubmitting
                            ? _text('saveInProgress')
                            : _text('loadingDone'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    litersController.dispose();
    notesController.dispose();

    if (!mounted || !submitted) return;

    await _loadOrder(forceRefresh: true);
    await _refreshRoute(force: true);

    if (!mounted) return;
    final message = _isWaitingMovementDispatch
        ? _text('loadingSentWait')
        : _text('loadingSentContinue');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return _isArabic ? 'لم يتم الإرسال بعد' : 'Not sent yet';
    final local = value.toLocal();
    final twoDigits = (int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return context.tr(loc.AppStrings.driverNotAvailable);
    final local = value.toLocal();
    final twoDigits = (int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _formatDurationLocalized(int? durationMinutes) {
    if (durationMinutes == null || durationMinutes <= 0) {
      return context.tr(loc.AppStrings.driverNotAvailable);
    }

    if (_isArabic) {
      return formatTrackingDuration(durationMinutes);
    }

    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (minutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $minutes min';
  }

  String _formatLiters(double? value) {
    if (value == null) return context.tr(loc.AppStrings.driverNotSpecified);
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  LocationSettings get _trackingLocationSettings {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          intervalDuration: Duration(seconds: 10),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: _isArabic
                ? 'التتبع المباشر للطلبات مفعل'
                : 'Live order tracking is active',
            notificationText: _isArabic
                ? 'يتم تحديث موقعك في الخلفية حتى يمكن متابعة الطلب مباشرة.'
                : 'Your location is updated in the background so the order can be tracked live.',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        );
    }
  }

  LatLng get _mapCenter {
    if (_currentLocation != null) return _currentLocation!;
    if (_routePoints.isNotEmpty) return _routePoints.first;
    return const LatLng(24.7136, 46.6753);
  }

  Widget _buildMap() {
    final currentLocation = _currentLocation;
    final destinationLocation = _routePoints.isEmpty ? null : _routePoints.last;

    final markers = <Marker>{
      if (currentLocation != null)
        Marker(
          markerId: const MarkerId('driver-current'),
          position: currentLocation,
          infoWindow: InfoWindow(title: _text('currentLocation')),
        ),
      if (destinationLocation != null)
        Marker(
          markerId: const MarkerId('driver-destination'),
          position: destinationLocation,
          infoWindow: InfoWindow(title: _destinationMarkerTitle),
        ),
    };

    final polylines = <Polyline>{
      if (_routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('delivery-route'),
          points: _routePoints,
          color: AppColors.primaryBlue,
          width: 5,
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            Positioned.fill(
              child: kIsWeb
                  ? AdvancedWebMap(
                      center: _mapCenter,
                      zoom: 13,
                      primaryMarker: destinationLocation ?? currentLocation,
                      secondaryMarker: destinationLocation != null
                          ? currentLocation
                          : null,
                      polyline: _routePoints.length >= 2 ? _routePoints : null,
                    )
                  : GoogleMap(
                      key: ValueKey(
                        '${_mapCenter.latitude}-${_mapCenter.longitude}-${_routePoints.length}-${(_destinationQuery ?? _destinationText).hashCode}',
                      ),
                      initialCameraPosition: CameraPosition(
                        target: _mapCenter,
                        zoom: 13,
                      ),
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                    ),
            ),
            if (_isRouteLoading)
              const Positioned(
                top: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSummaryCard(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _stageTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    color: AppColors.statusGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _localizedStatus(order.status),
                    style: const TextStyle(
                      color: AppColors.statusGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DeliveryInfoRow(
              label: _destinationLabel,
              value: _destinationText.isEmpty
                  ? context.tr(loc.AppStrings.driverNotSpecified)
                  : _destinationText,
            ),
            _DeliveryInfoRow(
              label: _text('remainingDistance'),
              value: _distanceKm == null
                  ? context.tr(loc.AppStrings.driverNotAvailable)
                  : '${_distanceKm!.toStringAsFixed(1)} كم',
            ),
            _DeliveryInfoRow(
              label: _text('eta'),
              value: _formatDurationLocalized(_durationMinutes),
            ),
            _DeliveryInfoRow(
              label: _text('lastSync'),
              value: _formatTimestamp(_lastPublishedAt),
            ),
            _DeliveryInfoRow(
              label: _text('trackingStatus'),
              value: _isSharing
                  ? _text('trackingActive')
                  : _text('trackingStopped'),
            ),
            if (_routeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _routeError!,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFinalStatus
                        ? null
                        : (_isSharing ? _stopSharing : _startSharing),
                    icon: Icon(
                      _isSharing
                          ? Icons.pause_circle_outline
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      _isSharing
                          ? _text('stopTracking')
                          : _text('startTracking'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRouteLoading
                        ? null
                        : () => _refreshRoute(force: true),
                    icon: const Icon(Icons.alt_route),
                    label: Text(_text('updateRoute')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('orderDetails', {'number': order.orderNumber}),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _DeliveryInfoRow(
              label: _text('customer'),
              value:
                  order.movementCustomerName?.trim().isNotEmpty == true
                      ? order.movementCustomerName!.trim()
                      : order.customer?.name.trim().isNotEmpty == true
                      ? order.customer!.name.trim()
                      : context.tr(loc.AppStrings.driverNotSpecified),
            ),
            _DeliveryInfoRow(
              label: _text('loadingStation'),
              value: _loadingStationName,
            ),
            _DeliveryInfoRow(
              label: _text('requestedFuel'),
              value: order.fuelType?.trim().isNotEmpty == true
                  ? _localizedFuelType(order.fuelType)
                  : context.tr(loc.AppStrings.driverNotSpecified),
            ),
            _DeliveryInfoRow(
              label: _text('requestedQuantity'),
              value: order.quantity == null
                  ? context.tr(loc.AppStrings.driverNotSpecified)
                  : '${_formatLiters(order.quantity)} ${order.unit ?? context.tr(loc.AppStrings.driverLitersUnit)}',
            ),
            if (order.notes?.trim().isNotEmpty == true)
              _DeliveryInfoRow(
                label: _text('orderNotes'),
                value: order.notes!.trim(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(Order order) {
    final hasAnyLoadingData =
        _hasLoadingData ||
        order.driverLoadingSubmittedAt != null ||
        order.driverLoadingNotes?.trim().isNotEmpty == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('loadingData'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (hasAnyLoadingData) ...[
              _DeliveryInfoRow(
                label: _text('actualFuel'),
                value: order.actualFuelType?.trim().isNotEmpty == true
                    ? _localizedFuelType(order.actualFuelType)
                    : context.tr(loc.AppStrings.driverNotSpecified),
              ),
              _DeliveryInfoRow(
                label: _text('actualLiters'),
                value: order.actualLoadedLiters == null
                    ? context.tr(loc.AppStrings.driverNotSpecified)
                    : '${_formatLiters(order.actualLoadedLiters)} ${context.tr(loc.AppStrings.driverLitersUnit)}',
              ),
              _DeliveryInfoRow(
                label: _text('submittedAt'),
                value: _formatDateTime(order.driverLoadingSubmittedAt),
              ),
              if (order.driverLoadingNotes?.trim().isNotEmpty == true)
                _DeliveryInfoRow(
                  label: _text('driverNotes'),
                  value: order.driverLoadingNotes!.trim(),
                ),
              if (_hasLoadingData) ...[
                const SizedBox(height: 8),
                Text(
                  _isWaitingMovementDispatch
                      ? _text('loadingSentWait')
                      : _text('loadingSentContinue'),
                  style: TextStyle(
                    color: AppColors.successGreen.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ] else ...[
              Text(
                _canSubmitLoadingData
                    ? (order.isMovementOrder && order.isMovementPendingDispatch
                        ? _text('loadingPromptWait')
                        : _text('loadingPromptContinue'))
                    : _text('loadingPendingData'),
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_canSubmitLoadingData) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitLoadingData,
                  icon: const Icon(Icons.local_gas_station_rounded),
                  label: Text(_text('loadingDone')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverActionsCard(List<String> nextStatuses) {
    if (nextStatuses.isEmpty) {
      if (_canSubmitLoadingData || _order == null) {
        return const SizedBox.shrink();
      }

      final message = _isWaitingMovementDispatch
          ? _text('waitingDispatchMessage')
          : _hasLoadingData
          ? _text('noExtraActions')
          : _text('enterLoadingFirst');

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('driverActions'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: nextStatuses.map((status) {
                final actionLabel = status == 'تم التسليم'
                    ? _text('unload')
                    : status == 'في الطريق'
                        ? 'Start'
                        : _localizedStatus(status);
                final actionIcon = status == 'تم التسليم'
                    ? Icons.outbox_rounded
                    : status == 'في الطريق'
                        ? Icons.play_arrow_rounded
                        : Icons.check_circle_outline;

                return ElevatedButton.icon(
                  onPressed:
                      _isUpdatingStatus ? null : () => _updateStatus(status),
                  icon: _isUpdatingStatus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(actionIcon),
                  label: Text(actionLabel),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final nextStatuses = order == null
        ? const <String>[]
        : _allowedNextStatuses(order);

    return Scaffold(
      appBar: AppBar(
        title: Text(_text('screenTitle')),
        actions: [
          IconButton(
            tooltip: _text('refresh'),
            onPressed: _isPreparing ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : order == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? _text('noOrderData'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.showMap) ...[
                    _buildMap(),
                    const SizedBox(height: 16),
                  ],
                  _buildTrackingSummaryCard(order),
                  const SizedBox(height: 12),
                  _buildOrderDetailsCard(order),
                  const SizedBox(height: 12),
                  _buildLoadingCard(order),
                  const SizedBox(height: 12),
                  _buildDriverActionsCard(nextStatuses),
                ],
              ),
            ),
    );
  }
}

class _DeliveryInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeliveryInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
