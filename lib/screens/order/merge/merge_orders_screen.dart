import 'dart:async';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class MergeOrdersScreen extends StatefulWidget {
  final Order? orderToEdit;

  const MergeOrdersScreen({super.key, this.orderToEdit});

  @override
  State<MergeOrdersScreen> createState() => _MergeOrdersScreenState();
}

class _MergeOrdersScreenState extends State<MergeOrdersScreen> {
  // ============================================
  // 📌 متغيرات الطلبات
  // ============================================
  Order? _selectedSupplierOrder;
  Order? _selectedCustomerOrder;

  String? _selectedCustomerId;
  String? _selectedSupplierId;

  bool _isEditingMergedOrder = false;
  Order? _mergedOrder;
  bool _hasMergedOrders = false;

  // ============================================
  // 📌 بيانات التصفية
  // ============================================
  String _fuelTypeFilter = 'جميع الأنواع';
  String _quantityFilter = 'جميع الكميات';

  bool _isEditMode = false;

  // ============================================
  // 📌 قوائم البيانات
  // ============================================
  List<Order> _supplierOrders = [];
  List<Order> _customerOrders = [];
  List<Order> _filteredCustomerOrders = [];

  // ============================================
  // 📌 أنواع الوقود والكميات
  // ============================================
  final List<String> _fuelTypes = [
    'جميع الأنواع',
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
  ];

  final List<String> _quantityRanges = [
    'جميع الكميات',
    '1000 - 5000 لتر',
    '5000 - 10000 لتر',
    '10000 - 20000 لتر',
    '20000 - 30000 لتر',
    '30000+ لتر',
  ];

  // ============================================
  // 📌 دوال جلب البيانات
  // ============================================
  @override
  void initState() {
    super.initState();

    if (widget.orderToEdit != null) {
      _isEditMode = true;
      _initializeEditMode(widget.orderToEdit!);
    }
    _loadOrders();
  }

  void _initializeEditMode(Order mergedOrder) {
    _isEditingMergedOrder = true;
    _mergedOrder = mergedOrder;
    _fuelTypeFilter = 'جميع الأنواع';
    _quantityFilter = 'جميع الكميات';
  }

  void _closeForm({bool changed = false}) {
    if (!mounted) return;
    Navigator.pop(context, changed ? true : null);
  }

  PreferredSizeWidget _buildDesktopAppBar() {
    final title = _isEditingMergedOrder ? 'تعديل الطلب المدمج' : 'دمج الطلبات';

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
        onPressed: () => _closeForm(changed: _hasMergedOrders),
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

  void _selectMergedOrders(List<Order> allOrders) {
    if (_mergedOrder == null) return;
    if (_mergedOrder!.status == 'تم التنفيذ') return;

    final supplier = allOrders.firstWhere(
      (o) => o.orderSource == 'مورد' && o.mergedWithOrderId == _mergedOrder!.id,
      orElse: () => _selectedSupplierOrder ?? Order.empty(),
    );
    final customer = allOrders.firstWhere(
      (o) => o.orderSource == 'عميل' && o.mergedWithOrderId == _mergedOrder!.id,
      orElse: () => _selectedCustomerOrder ?? Order.empty(),
    );

    if (supplier.id.isNotEmpty) {
      _selectedSupplierOrder = supplier;
      _selectedSupplierId = supplier.id;
      _fuelTypeFilter = supplier.fuelType ?? 'جميع الأنواع';
      _quantityFilter = 'جميع الكميات';
    }

    if (customer.id.isNotEmpty) {
      _selectedCustomerOrder = customer;
      _selectedCustomerId = customer.id;
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchOrders(silent: true);

      final allOrders = orderProvider.orders;

      if (_isEditMode) {
        _selectMergedOrders(allOrders);
      }

      // =========================
      // طلبات المورد (مورد فقط + غير مدموجة)
      // =========================
      _supplierOrders = allOrders.where((order) {
        return order.orderSource == 'مورد' &&
            order.mergeStatus != 'مدمج' &&
            order.mergeStatus != 'مكتمل' &&
            [
              'في المستودع',
              'تم الإنشاء',
              'جاهز للتحميل',
              'تم التحميل',
            ].contains(order.status);
      }).toList();

      // =========================
      // طلبات العملاء (عميل فقط + غير مدموجة)
      // =========================
      // =========================
      // طلبات العملاء (عميل فقط + غير مدموجة)
      // =========================
      _customerOrders = allOrders.where((order) {
        return order.orderSource == 'عميل' &&
            order.mergeStatus != 'مدمج' &&
            order.status == 'في انتظار التخصيص';
      }).toList();

      _filteredCustomerOrders = List.from(_customerOrders);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error loading orders for merge: $e');
    }
  }

  // ============================================
  // 🔍 دوال التصفية
  // ============================================
  void _filterCustomerOrders() {
    setState(() {
      _filteredCustomerOrders = _customerOrders.where((order) {
        // =========================
        // لو فيه مورد مختار → فلترة تلقائية
        // =========================
        if (_selectedSupplierOrder != null) {
          final supplier = _selectedSupplierOrder!;

          // 1️⃣ نفس نوع الوقود
          if (order.fuelType != supplier.fuelType) {
            return false;
          }

          // 2️⃣ كمية العميل ≤ كمية المورد
          if (order.quantity == null || supplier.quantity == null) {
            return false;
          }

          if (order.quantity! > supplier.quantity!) {
            return false;
          }
        }

        // =========================
        // فلترة يدوية (Dropdowns)
        // =========================

        // نوع الوقود
        if (_fuelTypeFilter != 'جميع الأنواع' &&
            order.fuelType != _fuelTypeFilter) {
          return false;
        }

        // نطاق الكمية
        if (_quantityFilter != 'جميع الكميات' && order.quantity != null) {
          final q = order.quantity!;
          switch (_quantityFilter) {
            case '1000 - 5000 لتر':
              if (q < 1000 || q > 5000) return false;
              break;
            case '5000 - 10000 لتر':
              if (q < 5000 || q > 10000) return false;
              break;
            case '10000 - 20000 لتر':
              if (q < 10000 || q > 20000) return false;
              break;
            case '20000 - 30000 لتر':
              if (q < 20000 || q > 30000) return false;
              break;
            case '30000+ لتر':
              if (q < 30000) return false;
              break;
          }
        }

        return true;
      }).toList();
    });
  }

  Future<void> _updateMergedOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final success = await orderProvider.updateOrderLimited(_mergedOrder!.id, {
      'status': _mergedOrder!.status,
      'driver': _mergedOrder!.driverId,
      'arrivalDate': _mergedOrder!.arrivalDate.toIso8601String(),
      'arrivalTime': _mergedOrder!.arrivalTime,
      'notes': _mergedOrder!.notes,
    }, null);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تحديث الطلب المدمج بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      _closeForm(changed: true);
    }
  }

  // ============================================
  // 🔗 دمج الطلبات
  // ============================================
  Future<void> _mergeOrders() async {
    if (_selectedSupplierOrder == null || _selectedCustomerOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار طلب مورد وطلب عميل للدمج'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // التحقق من التوافق
    if (!_areOrdersCompatible()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'الطلبات غير متوافقة (تختلف في نوع الوقود أو الكمية)',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    try {
      final success = await orderProvider.mergeOrders(
        supplierOrderId: _selectedSupplierOrder!.id,
        customerOrderId: _selectedCustomerOrder!.id,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم دمج الطلب ${_selectedSupplierOrder!.orderNumber} '
              'مع الطلب ${_selectedCustomerOrder!.orderNumber} بنجاح',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );

        // إعادة تعيين القيم
        setState(() {
          _selectedSupplierOrder = null;
          _selectedCustomerOrder = null;
          _selectedCustomerId = null;
          _selectedSupplierId = null;
        });

        // تحديث البيانات
        await _loadOrders();
        _hasMergedOrders = true;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الدمج: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _replaceMergeOrders() async {
    if (_selectedSupplierOrder == null || _selectedCustomerOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار طلب مورد وطلب عميل للدمج'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (!_areOrdersCompatible()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'الطلبات غير متوافقة (تختلف في نوع الوقود أو الكمية)',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (_mergedOrder == null) return;
    if (_mergedOrder!.status == 'تم التنفيذ') return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final unmerged = await orderProvider.unmergeOrder(_mergedOrder!.id);
    if (!unmerged) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderProvider.error ?? 'فشل فك الدمج الحالي'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    try {
      final success = await orderProvider.mergeOrders(
        supplierOrderId: _selectedSupplierOrder!.id,
        customerOrderId: _selectedCustomerOrder!.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تحديث الدمج بنجاح'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        _closeForm(changed: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الدمج: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ============================================
  // ✅ التحقق من التوافق
  // ============================================
  bool _areOrdersCompatible() {
    if (_selectedSupplierOrder == null || _selectedCustomerOrder == null) {
      return false;
    }

    final supplier = _selectedSupplierOrder!;
    final customer = _selectedCustomerOrder!;

    // 1️⃣ تحقق من نوع الوقود
    if (supplier.fuelType == null ||
        customer.fuelType == null ||
        supplier.fuelType != customer.fuelType) {
      return false;
    }

    // 2️⃣ تحقق من الكمية
    if (supplier.quantity == null || customer.quantity == null) {
      return false;
    }

    if (customer.quantity != supplier.quantity) {
      return false;
    }

    // 3️⃣ تحقق من الوقت (اختياري لكن منطقي)
    return true;
  }

  // ============================================
  // 📱 واجهة الجوال
  // ============================================
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _buildSupplierOrderCard(),
          const SizedBox(height: 20),
          _buildCustomerOrderCard(),
          const SizedBox(height: 20),
          _buildMergeButton(),
          const SizedBox(height: 20),
          if (_selectedSupplierOrder != null && _selectedCustomerOrder != null)
            _buildCompatibilityInfo(),
        ],
      ),
    );
  }

  // ============================================
  // 💻 واجهة سطح المكتب
  // ============================================
  Widget _buildDesktopLayout() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPaneSurface(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 20),
                        _buildSupplierOrderCard(),
                        const SizedBox(height: 20),
                        if (_selectedSupplierOrder != null &&
                            _selectedCustomerOrder != null)
                          _buildCompatibilityInfo(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPaneSurface(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _buildCustomerOrderCard(),
                        const SizedBox(height: 20),
                        _buildMergeButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaneSurface({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  // ============================================
  // 🎴 مكونات الواجهة
  // ============================================
  Widget _buildHeaderCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(Icons.link, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                _isEditMode ? 'تعديل الطلب المدمج' : 'دمج الطلبات المتوافقة',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'اختر طلب مورد وطلب عميل متوافقين للدمج',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierOrderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppColors.primaryBlue, size: 24),
                const SizedBox(width: 12),
                Text(
                  'طلب المورد',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Column(
              children: [
                // 🔹 كارت الطلب المختار (لو موجود)
                if (_selectedSupplierOrder != null)
                  _buildSelectedOrderCard(
                    order: _selectedSupplierOrder!,
                    isSupplier: true,
                    onRemove: () {
                      setState(() {
                        _selectedSupplierOrder = null;
                        _selectedSupplierId = null;
                      });
                    },
                  ),

                // 🔹 قائمة الطلبات (تظهر دائمًا)
                _buildOrderSelectionList(
                  orders: _supplierOrders,
                  isSupplier: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerOrderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.secondaryTeal, size: 24),
                const SizedBox(width: 12),
                Text(
                  'طلب العميل',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // فلاتر البحث
            _buildFilterSection(),
            const SizedBox(height: 16),

            if (_selectedCustomerOrder == null)
              _buildOrderSelectionList(
                orders: _filteredCustomerOrders,
                isSupplier: false,
              )
            else
              _buildSelectedOrderCard(
                order: _selectedCustomerOrder!,
                isSupplier: false,
                onRemove: () {
                  setState(() {
                    _selectedCustomerOrder = null;
                    _selectedCustomerId = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تصفية الطلبات:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.mediumGray,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نوع الوقود',
                    style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: DropdownButton<String>(
                      value: _fuelTypeFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _fuelTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _fuelTypeFilter = value;
                          _filterCustomerOrders();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نطاق الكمية',
                    style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: DropdownButton<String>(
                      value: _quantityFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _quantityRanges.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _quantityFilter = value;
                          _filterCustomerOrders();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_selectedSupplierOrder != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.infoBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يتم عرض الطلبات المتوافقة مع طلب المورد المحدد',
                    style: TextStyle(fontSize: 12, color: AppColors.infoBlue),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrderSelectionList({
    required List<Order> orders,
    required bool isSupplier,
  }) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              isSupplier ? Icons.business : Icons.person,
              size: 48,
              color: AppColors.mediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              isSupplier
                  ? 'لا توجد طلبات مورد متاحة للدمج'
                  : 'لا توجد طلبات عملاء مطابقة للتصفية',
              style: TextStyle(color: AppColors.mediumGray, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderListItem(order, isSupplier);
        },
      ),
    );
  }

  Widget _simpleInfo({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryTeal),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildOrderListItem(Order order, bool isSupplier) {
    final bool isSelected =
        (isSupplier && _selectedSupplierId == order.id) ||
        (!isSupplier && _selectedCustomerId == order.id);

    final String orderBadge =
        (order.orderNumber.isNotEmpty && order.orderNumber.length >= 3)
        ? order.orderNumber.substring(0, 3)
        : order.orderNumber;

    final String locationText =
        '${order.city ?? 'مدينة غير محددة'} - ${order.area ?? 'منطقة غير محددة'}';

    return InkWell(
      onTap: () {
        setState(() {
          if (isSupplier) {
            // =========================
            // اختيار طلب المورد
            // =========================
            _selectedSupplierOrder = order;
            _selectedSupplierId = order.id;

            // تثبيت نوع الوقود تلقائيًا
            _fuelTypeFilter = order.fuelType ?? 'جميع الأنواع';
            _quantityFilter = 'جميع الكميات';

            // إعادة تعيين اختيار العميل (لو كان غير متوافق)
            _selectedCustomerOrder = null;
            _selectedCustomerId = null;

            // إعادة فلترة طلبات العملاء
            _filterCustomerOrders();
          } else {
            // =========================
            // اختيار طلب العميل
            // =========================
            _selectedCustomerOrder = order;
            _selectedCustomerId = order.id;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // Header
            // =========================
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSupplier
                        ? AppColors.primaryBlue.withOpacity(0.2)
                        : AppColors.secondaryTeal.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      orderBadge,
                      style: TextStyle(
                        color: isSupplier
                            ? AppColors.primaryBlue
                            : AppColors.secondaryTeal,
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
                        order.orderNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        isSupplier
                            ? (order.supplierName ?? 'مورد')
                            : (order.customer?.name ?? 'عميل'),
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                      if (isSupplier &&
                          order.supplierOrderNumber != null &&
                          order.supplierOrderNumber!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'رقم طلب المورد: ${order.supplierOrderNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.infoBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.successGreen),
              ],
            ),

            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 8),

            // =========================
            // Fuel + Quantity
            // =========================
            Row(
              children: [
                const Icon(
                  Icons.local_gas_station,
                  size: 16,
                  color: AppColors.warningOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  order.fuelType ?? 'غير محدد',
                  style: const TextStyle(
                    color: AppColors.warningOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.scale, size: 16, color: AppColors.infoBlue),
                const SizedBox(width: 8),
                Text(
                  '${order.quantity?.toStringAsFixed(0) ?? '0'} لتر',
                  style: const TextStyle(
                    color: AppColors.infoBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // =========================
            // City + Area
            // =========================
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationText,
                    style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // =========================
            // Date + Time
            // =========================
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.secondaryTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat(
                    'yyyy/MM/dd',
                  ).format(isSupplier ? order.loadingDate : order.arrivalDate),
                  style: const TextStyle(
                    color: AppColors.secondaryTeal,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.secondaryTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  isSupplier ? order.loadingTime : order.arrivalTime,
                  style: const TextStyle(
                    color: AppColors.secondaryTeal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedOrderCard({
    required Order order,
    required bool isSupplier,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ======================
                // رقم الطلب + اسم المورد
                // ======================
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                      child: Text(
                        order.orderNumber.substring(0, 3),
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            order.supplierName ?? 'مورد',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ======================
                // اسم السائق
                // ======================
                if (order.driverName != null)
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'السائق: ${order.driverName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // ======================
                // الوقود + الكمية
                // ======================
                Row(
                  children: [
                    _simpleInfo(
                      icon: Icons.local_gas_station,
                      text: order.fuelType ?? 'غير محدد',
                    ),
                    const SizedBox(width: 16),
                    _simpleInfo(
                      icon: Icons.scale,
                      text: '${order.quantity?.toStringAsFixed(0) ?? '0'} لتر',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ======================
                // التاريخ + الوقت
                // ======================
                Row(
                  children: [
                    _simpleInfo(
                      icon: Icons.calendar_today,
                      text: DateFormat('yyyy/MM/dd').format(order.loadingDate),
                    ),
                    const SizedBox(width: 16),
                    _simpleInfo(
                      icon: Icons.access_time,
                      text: order.loadingTime,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // زر الإزالة
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              icon: Icon(Icons.close, color: AppColors.errorRed),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityInfo() {
    if (_selectedSupplierOrder == null || _selectedCustomerOrder == null) {
      return Container();
    }

    final isCompatible = _areOrdersCompatible();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompatible ? Icons.check_circle : Icons.warning,
                  color: isCompatible
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  isCompatible ? 'الطلبات متوافقة' : 'الطلبات غير متوافقة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCompatible
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // تفاصيل التوافق
            _buildCompatibilityDetail(
              label: 'نوع الوقود',
              supplierValue: _selectedSupplierOrder!.fuelType ?? 'غير محدد',
              customerValue: _selectedCustomerOrder!.fuelType ?? 'غير محدد',
              isCompatible:
                  _selectedSupplierOrder!.fuelType ==
                  _selectedCustomerOrder!.fuelType,
            ),

            _buildCompatibilityDetail(
              label: 'الكمية',
              supplierValue:
                  '${_selectedSupplierOrder!.quantity?.toStringAsFixed(0) ?? '0'} لتر',
              customerValue:
                  '${_selectedCustomerOrder!.quantity?.toStringAsFixed(0) ?? '0'} لتر',
              isCompatible:
                  (_selectedSupplierOrder!.quantity ?? 0) >=
                  (_selectedCustomerOrder!.quantity ?? 0),
            ),

            _buildCompatibilityDetail(
              label: 'وقت التحميل/الوصول',
              supplierValue:
                  '${DateFormat('yyyy/MM/dd').format(_selectedSupplierOrder!.loadingDate)} ${_selectedSupplierOrder!.loadingTime}',
              customerValue:
                  '${DateFormat('yyyy/MM/dd').format(_selectedCustomerOrder!.arrivalDate)} ${_selectedCustomerOrder!.arrivalTime}',
              isCompatible: true,
            ),

            if (!isCompatible)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'ملاحظة: يجب أن تكون الكمية المتوفرة لدى المورد تساوي كمية طلب العميل، وأن يكون وقت التحميل بعد وقت الوصول',
                  style: TextStyle(color: AppColors.errorRed, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityDetail({
    required String label,
    required String supplierValue,
    required String customerValue,
    required bool isCompatible,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCompatible ? Icons.check : Icons.close,
            color: isCompatible ? AppColors.successGreen : AppColors.errorRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'المورد: $supplierValue',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'العميل: $customerValue',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMergedOrderForm() {
    final order = _mergedOrder!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),

          const SizedBox(height: 20),

          _buildSelectedOrderCard(
            order: order,
            isSupplier: true,
            onRemove: () {}, 
          ),

          const SizedBox(height: 20),

          // ✅ تعديل السائق
          if (order.driverName != null)
            Text('السائق الحالي: ${order.driverName}'),

          const SizedBox(height: 20),

          GradientButton(
            text: 'تحديث الطلب المدمج',
            gradient: AppColors.accentGradient,
            onPressed: _updateMergedOrder,
          ),
        ],
      ),
    );
  }

  Widget _buildMergeButton() {
    final orderProvider = Provider.of<OrderProvider>(context);

    if (_isEditMode) {
      return GradientButton(
        onPressed:
            (_selectedSupplierOrder != null &&
                _selectedCustomerOrder != null &&
                _areOrdersCompatible() &&
                !orderProvider.isLoading)
            ? _replaceMergeOrders
            : null,
        text: orderProvider.isLoading ? 'جاري التحديث...' : 'تحديث الدمج',
        gradient: AppColors.accentGradient,
        isLoading: orderProvider.isLoading,
      );
    }

    return GradientButton(
      onPressed:
          (_selectedSupplierOrder != null &&
              _selectedCustomerOrder != null &&
              _areOrdersCompatible() &&
              !orderProvider.isLoading)
          ? _mergeOrders
          : null,
      text: orderProvider.isLoading ? 'جاري الدمج...' : 'دمج الطلبات',
      gradient: AppColors.accentGradient,
      isLoading: orderProvider.isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    final content = isDesktop ? _buildDesktopLayout() : _buildMobileLayout();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeForm(changed: _hasMergedOrders);
      },
      child: Scaffold(
        appBar: _buildDesktopAppBar(),
        body: Stack(
          children: [
            const AppSoftBackground(),
            Positioned.fill(child: content),
          ],
        ),
      ),
    );
  }
}
