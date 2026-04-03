import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/models/transport_pricing_rule_model.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/services/order_management_pricing_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

enum CustomerPricingMode { fuel, transport }

class CustomerPricingScreen extends StatefulWidget {
  final CustomerPricingMode mode;

  const CustomerPricingScreen({super.key, required this.mode});

  @override
  State<CustomerPricingScreen> createState() => _CustomerPricingScreenState();
}

class _CustomerPricingScreenState extends State<CustomerPricingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س',
    decimalDigits: 3,
  );

  bool _loaded = false;
  bool _loadingRules = false;
  bool _activeOnly = true;
  String? _error;
  List<TransportPricingRule> _transportRules = const [];

  bool get _isFuelMode => widget.mode == CustomerPricingMode.fuel;

  String get _title =>
      _isFuelMode ? 'تسعيرة الوقود للعملاء' : 'تسعيرة النقل';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;

    await context.read<CustomerProvider>().fetchCustomers(fetchAll: true);
    if (!_isFuelMode) {
      await _loadTransportRules();
    }
  }

  Future<void> _loadTransportRules() async {
    if (_loadingRules) return;
    setState(() {
      _loadingRules = true;
      _error = null;
    });

    try {
      final rules = await OrderManagementPricingService.fetchTransportPricingRules(
        isActive: _activeOnly ? true : null,
      );
      if (!mounted) return;
      setState(() => _transportRules = rules);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRules = false);
    }
  }

  List<Customer> _filteredCustomers(List<Customer> customers) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return customers;

    return customers.where((customer) {
      return customer.name.toLowerCase().contains(query) ||
          customer.code.toLowerCase().contains(query) ||
          (customer.phone?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<TransportPricingRule> _filteredRules() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _transportRules;

    return _transportRules.where((rule) {
      return rule.sourceCity.toLowerCase().contains(query) ||
          rule.fuelType.toLowerCase().contains(query) ||
          '${rule.capacityLiters}'.contains(query) ||
          (rule.notes?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _editCustomerFuelPricing(Customer customer) async {
    final controllers = <String, TextEditingController>{
      for (final fuelType in kSupportedFuelTypes)
        fuelType: TextEditingController(
          text: customer.fuelPriceFor(fuelType)?.toStringAsFixed(3) ?? '',
        ),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('تسعيرة الوقود - ${customer.displayName}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final fuelType in kSupportedFuelTypes) ...[
                    TextField(
                      controller: controllers[fuelType],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: fuelType,
                        suffixText: 'ر.س / لتر',
                        prefixIcon: const Icon(
                          Icons.local_gas_station_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (fuelType != kSupportedFuelTypes.last)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    final payload = <Map<String, dynamic>>[];
    for (final fuelType in kSupportedFuelTypes) {
      final value = double.tryParse(
        controllers[fuelType]!.text.trim().replaceAll(',', '.'),
      );
      if (value != null) {
        payload.add({'fuelType': fuelType, 'pricePerLiter': value});
      }
      controllers[fuelType]!.dispose();
    }

    if (result != true) return;

    final ok = await context.read<CustomerProvider>().updateCustomer(
      customer.id,
      {
        'fuelPricing': payload,
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم تحديث تسعيرة الوقود' : 'تعذر تحديث التسعيرة'),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  Future<void> _openTransportRuleDialog({TransportPricingRule? rule}) async {
    final sourceCityController = TextEditingController(
      text: rule?.sourceCity ?? '',
    );
    final transportValueController = TextEditingController(
      text: rule?.transportValue.toStringAsFixed(3) ?? '',
    );
    final returnValueController = TextEditingController(
      text: rule?.returnValue.toStringAsFixed(3) ?? '',
    );
    final notesController = TextEditingController(text: rule?.notes ?? '');

    var fuelType = rule?.fuelType ?? kSupportedFuelTypes.first;
    var capacityLiters = rule?.capacityLiters ??
        OrderManagementPricingService.supportedCapacities.first;
    var transportMode = rule?.transportMode ?? 'per_liter';
    var returnMode = rule?.returnMode ?? 'fixed';
    var isActive = rule?.isActive ?? true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(rule == null ? 'إضافة تسعيرة نقل' : 'تعديل تسعيرة نقل'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: sourceCityController,
                        decoration: InputDecoration(
                          labelText: 'مدينة مصدر الوقود',
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: fuelType,
                        items: kSupportedFuelTypes
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => fuelType = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'نوع الوقود',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: capacityLiters,
                        items: OrderManagementPricingService.supportedCapacities
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value لتر'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => capacityLiters = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'السعة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: transportMode,
                              items: const [
                                DropdownMenuItem(
                                  value: 'per_liter',
                                  child: Text('النقل باللتر'),
                                ),
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('النقل مبلغ ثابت'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => transportMode = value);
                              },
                              decoration: InputDecoration(
                                labelText: 'وضع النقل',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: transportValueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'قيمة النقل',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: returnMode,
                              items: const [
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('الرد مبلغ ثابت'),
                                ),
                                DropdownMenuItem(
                                  value: 'per_liter',
                                  child: Text('الرد باللتر'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => returnMode = value);
                              },
                              decoration: InputDecoration(
                                labelText: 'وضع الرد',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: returnValueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'قيمة الرد',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('فعالة'),
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) {
      sourceCityController.dispose();
      transportValueController.dispose();
      returnValueController.dispose();
      notesController.dispose();
      return;
    }

    try {
      final sourceCity = sourceCityController.text.trim();
      final transportValue = double.tryParse(
        transportValueController.text.trim().replaceAll(',', '.'),
      );
      final returnValue = double.tryParse(
        returnValueController.text.trim().replaceAll(',', '.'),
      );

      if (sourceCity.isEmpty || transportValue == null || returnValue == null) {
        throw Exception('أكمل بيانات التسعيرة بشكل صحيح');
      }

      await OrderManagementPricingService.saveTransportPricingRule(
        id: rule?.id,
        payload: {
          'sourceCity': sourceCity,
          'fuelType': fuelType,
          'capacityLiters': capacityLiters,
          'transportMode': transportMode,
          'transportValue': transportValue,
          'returnMode': returnMode,
          'returnValue': returnValue,
          'notes': notesController.text.trim(),
          'isActive': isActive,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rule == null ? 'تم إضافة التسعيرة' : 'تم تحديث التسعيرة'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _loadTransportRules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      sourceCityController.dispose();
      transportValueController.dispose();
      returnValueController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _deleteTransportRule(TransportPricingRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التسعيرة'),
        content: Text(
          'سيتم حذف تسعيرة ${rule.fuelType} من ${rule.sourceCity} لسعة ${rule.capacityLiters} لتر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await OrderManagementPricingService.deleteTransportPricingRule(rule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف التسعيرة'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _loadTransportRules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildFuelMode(CustomerProvider provider) {
    final customers = _filteredCustomers(provider.customers);

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (customers.isEmpty) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final fuelEntries = customer.fuelPricing.isNotEmpty
            ? customer.fuelPricing
            : kSupportedFuelTypes
                .map(
                  (fuelType) => customer.fuelPriceFor(fuelType) == null
                      ? null
                      : CustomerFuelPrice(
                          fuelType: fuelType,
                          pricePerLiter: customer.fuelPriceFor(fuelType)!,
                        ),
                )
                .whereType<CustomerFuelPrice>()
                .toList();

        return AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          onTap: () => _editCustomerFuelPricing(customer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customer.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: () => _editCustomerFuelPricing(customer),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (fuelEntries.isEmpty)
                Text(
                  'لم يتم ضبط أي تسعيرة لهذا العميل.',
                  style: TextStyle(
                    color: Colors.black87.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: fuelEntries
                      .map(
                        (entry) => _priceChip(
                          icon: Icons.local_gas_station_outlined,
                          label: entry.fuelType,
                          value: _money.format(entry.pricePerLiter),
                          emphasize: entry.fuelType == 'ديزل',
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransportMode() {
    final rules = _filteredRules();

    if (_loadingRules) {
      return const Center(child: CircularProgressIndicator());
    }

    if (rules.isEmpty) {
      return Center(
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 52,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: 10),
              const Text(
                'لا توجد تسعيرات نقل حتى الآن.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _openTransportRuleDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة تسعيرة'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rule = rules[index];
        final transportText = rule.transportMode == 'per_liter'
            ? '${_money.format(rule.transportValue)} / لتر'
            : _money.format(rule.transportValue);
        final returnText = rule.returnMode == 'per_liter'
            ? '${_money.format(rule.returnValue)} / لتر'
            : _money.format(rule.returnValue);

        return AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          onTap: () => _openTransportRuleDialog(rule: rule),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${rule.sourceCity} • ${rule.fuelType} • ${rule.capacityLiters} لتر',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: () => _openTransportRuleDialog(rule: rule),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: () => _deleteTransportRule(rule),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _priceChip(
                    icon: Icons.local_shipping_outlined,
                    label: rule.transportMode == 'per_liter'
                        ? 'النقل/لتر'
                        : 'النقل',
                    value: transportText,
                    emphasize: true,
                  ),
                  _priceChip(
                    icon: Icons.keyboard_return_outlined,
                    label:
                        rule.returnMode == 'per_liter' ? 'الرد/لتر' : 'الرد',
                    value: returnText,
                  ),
                  _priceChip(
                    icon: rule.isActive
                        ? Icons.verified_outlined
                        : Icons.pause_circle_outline,
                    label: 'الحالة',
                    value: rule.isActive ? 'فعالة' : 'موقفة',
                  ),
                ],
              ),
              if (rule.notes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  rule.notes!,
                  style: TextStyle(
                    color: Colors.black87.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _priceChip({
    required IconData icon,
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primaryBlue.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasize
              ? AppColors.primaryBlue.withValues(alpha: 0.20)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: emphasize ? AppColors.primaryBlue : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: emphasize ? AppColors.primaryBlue : Colors.black87,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: emphasize ? AppColors.primaryBlue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (!_isFuelMode)
            IconButton(
              tooltip: 'إضافة تسعيرة نقل',
              onPressed: () => _openTransportRuleDialog(),
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _isFuelMode
                                ? 'ابحث بالاسم أو الكود أو الجوال...'
                                : 'ابحث بالمدينة أو نوع الوقود أو السعة...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.85),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (!_isFuelMode) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('عرض التسعيرات الفعالة فقط'),
                                  value: _activeOnly,
                                  onChanged: (value) async {
                                    setState(() => _activeOnly = value);
                                    await _loadTransportRules();
                                  },
                                ),
                              ),
                              IconButton(
                                tooltip: 'تحديث',
                                onPressed: _loadTransportRules,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                        ],
                        if (_error != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isFuelMode
                        ? _buildFuelMode(provider)
                        : _buildTransportMode(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
