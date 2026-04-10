import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/screens/order_details_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class MovementArchiveOrdersScreen extends StatefulWidget {
  const MovementArchiveOrdersScreen({super.key});

  @override
  State<MovementArchiveOrdersScreen> createState() =>
      _MovementArchiveOrdersScreenState();
}

class _MovementArchiveOrdersScreenState
    extends State<MovementArchiveOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  List<Order> _orders = <Order>[];
  bool _loading = true;
  String? _busyOrderId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final orders = await context.read<OrderProvider>().fetchMovementArchiveOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return _dateFormat.format(value);
  }

  String _formatSchedule(DateTime? date, String? time) {
    final timeText = (time ?? '').trim();
    if (date == null && timeText.isEmpty) return '-';
    final dateText = date == null ? '-' : _dateFormat.format(date);
    return timeText.isEmpty ? dateText : '$dateText - $timeText';
  }

  List<Order> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _orders;
    return _orders.where((order) {
      final haystack = <String>[
        order.orderNumber,
        order.supplierOrderNumber ?? '',
        order.supplierName,
        order.movementCustomerName ?? '',
        order.driverName ?? '',
        order.vehicleNumber ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _pickFiles({
    required ValueSetter<List<PlatformFile>> onPicked,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    onPicked(result.files);
  }

  Future<void> _showCompletionDialog(Order order) async {
    final notesController = TextEditingController();
    var taxInvoiceFiles = <PlatformFile>[];
    var fuelReceiptFiles = <PlatformFile>[];
    var saving = false;

    Future<void> submit(StateSetter setDialogState) async {
      if (taxInvoiceFiles.isEmpty || fuelReceiptFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'أرفق الفاتورة الضريبية وسند استلام المحروقات قبل الحفظ.',
            ),
          ),
        );
        return;
      }

      setDialogState(() => saving = true);
      setState(() => _busyOrderId = order.id);

      final success = await context.read<OrderProvider>().completeMovementArchiveOrder(
            orderId: order.id,
            taxInvoiceFiles: taxInvoiceFiles,
            fuelReceiptFiles: fuelReceiptFiles,
            notes: notesController.text,
          );

      if (!mounted) return;

      setDialogState(() => saving = false);
      setState(() {
        _busyOrderId = null;
        if (success) {
          _orders.removeWhere((item) => item.id == order.id);
        }
      });

      if (!success) {
        final error = context.read<OrderProvider>().error ?? 'تعذر إنهاء الأرشفة.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }

      Navigator.of(context).pop();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(
            orderId: order.id,
            screenTitle: 'تفاصيل الطلب بعد الأرشفة',
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ مستندات الطلب ${order.orderNumber} وإنهاء الأرشفة.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('إنهاء أرشفة ${order.orderNumber}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _uploadField(
                        title: 'الفاتورة الضريبية',
                        files: taxInvoiceFiles,
                        onPick: () async {
                          await _pickFiles(
                            onPicked: (files) {
                              setDialogState(() => taxInvoiceFiles = files);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _uploadField(
                        title: 'سند استلام المحروقات',
                        files: fuelReceiptFiles,
                        onPick: () async {
                          await _pickFiles(
                            onPicked: (files) {
                              setDialogState(() => fuelReceiptFiles = files);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : () => submit(setDialogState),
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.task_alt_rounded),
                  label: const Text('حفظ وإنهاء'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
  }

  Widget _uploadField({
    required String title,
    required List<PlatformFile> files,
    required VoidCallback onPick,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.16)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('إرفاق'),
              ),
            ],
          ),
          if (files.isEmpty)
            Text(
              'لم يتم إرفاق ملفات بعد',
              style: TextStyle(color: AppColors.mediumGray),
            )
          else
            ...files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.insert_drive_file_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filteredOrders;
    final viewport = MediaQuery.sizeOf(context);
    final isWideWeb = viewport.width >= 1200;
    final contentMaxWidth = isWideWeb ? 1580.0 : 980.0;
    final horizontalPadding = isWideWeb ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشفة طلبات الحركة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              end: isWideWeb ? 16 : 8,
              start: 8,
            ),
            child: isWideWeb
                ? OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('تسجيل خروج'),
                  )
                : IconButton(
                    tooltip: 'تسجيل خروج',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.primaryBlue.withValues(alpha: 0.06),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(isWideWeb ? 24 : 18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'طلبات بانتظار الإنهاء',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'تظهر هنا الطلبات الموجهة التي تحتاج رفع الفاتورة الضريبية وسند استلام المحروقات.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _statChip('بانتظار الأرشفة', '${_orders.length}'),
                      _statChip('الظاهر الآن', '${filteredOrders.length}'),
                    ],
                  ),
                ],
              ),
            ),
            TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الطلب أو رقم طلب المورد أو العميل أو السائق',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredOrders.isEmpty
                      ? const Center(
                          child: Text('لا توجد طلبات موجهة بانتظار الأرشفة حاليًا.'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              final busy = _busyOrderId == order.id;
                              final arrivalDate =
                                  order.movementExpectedArrivalDate ?? order.arrivalDate;
                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            order.orderNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.warningOrange
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'بانتظار الإنهاء',
                                            style: TextStyle(
                                              color: AppColors.warningOrange,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: <Widget>[
                                        _detailChip('المورد', order.supplierName),
                                        _detailChip(
                                          'رقم طلب المورد الخارجي',
                                          order.supplierOrderNumber ?? '-',
                                        ),
                                        _detailChip(
                                          'العميل',
                                          order.movementCustomerName ?? '-',
                                        ),
                                        _detailChip(
                                          'السائق',
                                          order.driverName ?? '-',
                                        ),
                                        _detailChip(
                                          'المركبة',
                                          order.vehicleNumber ?? '-',
                                        ),
                                        _detailChip(
                                          'الوقود',
                                          order.fuelType ?? '-',
                                        ),
                                        _detailChip(
                                          'الكمية',
                                          '${order.quantity ?? 0} ${order.unit ?? ''}'.trim(),
                                        ),
                                        _detailChip(
                                          'موعد التحميل',
                                          _formatSchedule(order.loadingDate, order.loadingTime),
                                        ),
                                        _detailChip(
                                          'موعد الوصول',
                                          _formatSchedule(arrivalDate, order.arrivalTime),
                                        ),
                                        _detailChip(
                                          'تاريخ التوجيه',
                                          _formatDate(order.movementDirectedAt),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: <Widget>[
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => OrderDetailsScreen(
                                                  orderId: order.id,
                                                  screenTitle: 'تفاصيل أرشفة الطلب',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility_outlined),
                                          label: const Text('التفاصيل'),
                                        ),
                                        FilledButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _showCompletionDialog(order),
                                          icon: busy
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.task_alt_rounded),
                                          label: const Text('إنهاء'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ));
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDarkBlue,
            ),
          ),
        ],
      ),
    );
  }
}
