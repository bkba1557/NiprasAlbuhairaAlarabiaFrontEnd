
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

class ReportFilters extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApply;

  const ReportFilters({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<ReportFilters> createState() => _ReportFiltersState();
}

class _ReportFiltersState extends State<ReportFilters> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _filters;
  final Map<String, TextEditingController> _controllers = {};

  final List<String> _dateRangeOptions = [
    'اليوم',
    'أمس',
    'آخر 7 أيام',
    'آخر 30 يوم',
    'هذا الشهر',
    'الشهر الماضي',
    'هذه السنة',
    'مخصص',
  ];

  String _selectedDateRange = 'مخصص';

  @override
  void initState() {
    super.initState();
    _filters = Map.from(widget.initialFilters);
    _initializeControllers();
  }

  void _initializeControllers() {
    _controllers['startDate'] = TextEditingController(
      text: _filters['startDate']?.toString() ?? '',
    );
    _controllers['endDate'] = TextEditingController(
      text: _filters['endDate']?.toString() ?? '',
    );
    _controllers['customerId'] = TextEditingController(
      text: _filters['customerId']?.toString() ?? '',
    );
    _controllers['driverId'] = TextEditingController(
      text: _filters['driverId']?.toString() ?? '',
    );
    _controllers['supplierId'] = TextEditingController(
      text: _filters['supplierId']?.toString() ?? '',
    );
    _controllers['city'] = TextEditingController(
      text: _filters['city']?.toString() ?? '',
    );
    _controllers['area'] = TextEditingController(
      text: _filters['area']?.toString() ?? '',
    );
    _controllers['search'] = TextEditingController(
      text: _filters['search']?.toString() ?? '',
    );
  }

  Future<void> _selectDate(BuildContext context, String field) async {
    final initialDate = _filters[field] != null
        ? DateTime.tryParse(_filters[field].toString())
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filters[field] = DateFormat('yyyy-MM-dd').format(picked);
        _controllers[field]?.text = _filters[field];
      });
    }
  }

  void _applyDateRange(String range) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (range) {
      case 'اليوم':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'أمس':
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = DateTime(now.year, now.month, now.day);
        break;
      case 'آخر 7 أيام':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'آخر 30 يوم':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'هذا الشهر':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'الشهر الماضي':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonth;
        endDate = DateTime(now.year, now.month, 0);
        break;
      case 'هذه السنة':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        return;
    }

    setState(() {
      _selectedDateRange = range;
      _filters['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
      _filters['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
      _controllers['startDate']?.text = _filters['startDate'];
      _controllers['endDate']?.text = _filters['endDate'];
    });
  }

  void _applyFilters() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      // تنظيف الفلاتر الفارغة
      final cleanFilters = Map<String, dynamic>.from(_filters)
        ..removeWhere(
          (key, value) =>
              value == null ||
              value.toString().isEmpty ||
              (value is List && value.isEmpty),
        );

      widget.onApply(cleanFilters);
      Navigator.pop(context);
    }
  }

  void _clearFilters() {
    setState(() {
      _filters.clear();
      _selectedDateRange = 'مخصص';
      _controllers.forEach((key, controller) {
        controller.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'فلاتر البحث',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: _applyFilters,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range
                    _buildDateRangeSection(),
                    const SizedBox(height: 20),

                    // Quick Filters
                    _buildQuickFilters(),
                    const SizedBox(height: 20),

                    // Advanced Filters
                    _buildAdvancedFilters(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.errorRed),
                      ),
                      child: const Text(
                        'مسح الكل',
                        style: TextStyle(color: AppColors.errorRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('تطبيق الفلاتر'),
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

  Widget _buildDateRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الفترة الزمنية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),

        // Quick Date Ranges
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _dateRangeOptions.length,
            itemBuilder: (context, index) {
              final option = _dateRangeOptions[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(option),
                  selected: _selectedDateRange == option,
                  onSelected: (_) => _applyDateRange(option),
                  selectedColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    color: _selectedDateRange == option
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Custom Date Range
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controllers['startDate'],
                decoration: InputDecoration(
                  labelText: 'من تاريخ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, 'startDate'),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, 'startDate'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _controllers['endDate'],
                decoration: InputDecoration(
                  labelText: 'إلى تاريخ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, 'endDate'),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, 'endDate'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'فلاتر سريعة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickFilterChip('طلبات اليوم', Icons.today),
            _buildQuickFilterChip('متأخرة', Icons.warning),
            _buildQuickFilterChip('مكتملة', Icons.check_circle),
            _buildQuickFilterChip('ملغية', Icons.cancel),
            _buildQuickFilterChip('قيد التنفيذ', Icons.schedule),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, IconData icon) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      selected: _filters['quickFilter'] == label,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _filters['quickFilter'] = label;
          } else {
            _filters.remove('quickFilter');
          }
        });
      },
    );
  }

  Widget _buildAdvancedFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'فلاتر متقدمة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

        // Search
        TextFormField(
          controller: _controllers['search'],
          decoration: const InputDecoration(
            labelText: 'بحث بالاسم أو الرقم',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => _filters['search'] = value,
        ),
        const SizedBox(height: 16),

        // Location
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controllers['city'],
                decoration: const InputDecoration(labelText: 'المدينة'),
                onChanged: (value) => _filters['city'] = value,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _controllers['area'],
                decoration: const InputDecoration(labelText: 'المنطقة'),
                onChanged: (value) => _filters['area'] = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Status
        _buildStatusFilter(),
        const SizedBox(height: 16),

        // Amount Range
        _buildAmountFilter(),
      ],
    );
  }

  Widget _buildStatusFilter() {
    const statuses = [
      'في انتظار التحميل',
      'جاهز للتحميل',
      'مخصص للعميل',
      'في الطريق',
      'تم التحميل',
      'تم التسليم',
      'ملغى',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('حالة الطلب'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses.map((status) {
            return FilterChip(
              label: Text(status),
              selected:
                  (_filters['status'] as List?)?.contains(status) ?? false,
              onSelected: (selected) {
                setState(() {
                  final List<String> statusList = List<String>.from(
                    _filters['status'] ?? [],
                  );

                  if (selected) {
                    statusList.add(status);
                  } else {
                    statusList.remove(status);
                  }

                  _filters['status'] = statusList.isNotEmpty
                      ? statusList
                      : null;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmountFilter() {
    const amountRanges = [
      {'label': 'أقل من 1,000', 'min': 0, 'max': 1000},
      {'label': '1,000 - 5,000', 'min': 1000, 'max': 5000},
      {'label': '5,000 - 10,000', 'min': 5000, 'max': 10000},
      {'label': '10,000 - 50,000', 'min': 10000, 'max': 50000},
      {'label': 'أكثر من 50,000', 'min': 50000, 'max': 1000000},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('نطاق المبلغ'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amountRanges.map((range) {
            return FilterChip(
              label: Text(range['label'] as String),
              selected: _filters['amountRange'] == range['label'],
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filters['amountRange'] = {
                      'min': range['min'],
                      'max': range['max'],
                    };
                  } else {
                    _filters.remove('amountRange');
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}
