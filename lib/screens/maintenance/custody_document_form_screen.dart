import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/custody_document_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/custody_document_provider.dart';
import 'package:order_tracker/screens/maintenance/custody_document_design.dart';
import 'package:provider/provider.dart';

const List<String> _destinationTypes = ['سيارة', 'ورشة', 'مكتب', 'محطة'];

class _DetailRow {
  final TextEditingController labelController;
  final TextEditingController valueController;

  _DetailRow({String label = '', String value = ''})
    : labelController = TextEditingController(text: label),
      valueController = TextEditingController(text: value);

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }
}

class CustodyDocumentFormScreen extends StatefulWidget {
  const CustodyDocumentFormScreen({super.key});

  @override
  State<CustodyDocumentFormScreen> createState() =>
      _CustodyDocumentFormScreenState();
}

class _CustodyDocumentFormScreenState extends State<CustodyDocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _documentNumberController =
      TextEditingController();
  final TextEditingController _documentTitleController = TextEditingController(
    text: 'سند عهدة',
  );
  final TextEditingController _custodianController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final List<_DetailRow> _detailRows = [];
  DateTime _selectedDate = DateTime.now();
  String _destinationType = _destinationTypes.first;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _documentNumberController.text =
        'CH-${DateTime.now().millisecondsSinceEpoch}';
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final authName = context.read<AuthProvider>().user?.name ?? 'مسؤول الصيانة';
    _custodianController.text = authName;
    _amountController.text = '0';

    _detailRows
      ..clear()
      ..add(_DetailRow());
    _vehicleNumberController.clear();
    _syncAmountFromDetails();
  }

  void _addDetailRow({String label = '', String value = ''}) {
    setState(() {
      _detailRows.add(_DetailRow(label: label, value: value));
    });
  }

  String _normalizeNumberInput(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = input.trim().replaceAll(',', '.');
    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], i.toString());
    }
    return result;
  }

  double _calculateDetailsTotal() {
    double total = 0;
    for (final row in _detailRows) {
      final raw = _normalizeNumberInput(row.valueController.text);
      final parsed = double.tryParse(raw);
      if (parsed != null) {
        total += parsed;
      }
    }
    return total;
  }

  void _syncAmountFromDetails() {
    final total = _calculateDetailsTotal();
    _amountController.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _documentNumberController.dispose();
    _documentTitleController.dispose();
    _custodianController.dispose();
    _destinationController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _vehicleNumberController.dispose();
    _amountController.dispose();
    for (final row in _detailRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<CustodyDocumentProvider>();
      final auth = context.read<AuthProvider>();
      final rows = _detailRows
          .where((row) => row.labelController.text.trim().isNotEmpty)
          .map((row) {
            return CustodyDocumentRow(
              label: row.labelController.text.trim(),
              value: row.valueController.text.trim(),
            );
          })
          .toList();
      final detailsTotal = _calculateDetailsTotal();

      final document = CustodyDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        documentNumber: _documentNumberController.text.trim(),
        documentTitle: _documentTitleController.text.trim(),
        documentDate: _selectedDate,
        custodianName: _custodianController.text.trim(),
        destinationType: _destinationType,
        destinationName: _destinationController.text.trim(),
        reason: _reasonController.text.trim(),
        notes: _notesController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
        rows: rows,
        amount: detailsTotal,
        status: CustodyDocumentStatus.pending,
        createdBy: auth.user?.name ?? 'غير معروف',
      );

      await provider.addDocument(document);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ سند العهدة تحت المراجعة'),
          backgroundColor: Colors.green,
        ),
      );

      _showPostSubmitOptions(document);
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ السند: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _documentNumberController.text =
          'CH-${DateTime.now().millisecondsSinceEpoch}';
      _documentTitleController.text = 'سند عهدة';
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _destinationType = _destinationTypes.first;
      _destinationController.clear();
      _reasonController.clear();
      _notesController.clear();
      _amountController.text = '0';
      final authName =
          context.read<AuthProvider>().user?.name ?? 'مسؤول الصيانة';
      _custodianController.text = authName;
      _vehicleNumberController.clear();
      for (final row in _detailRows) {
        row.dispose();
      }
      _detailRows
        ..clear()
        ..add(_DetailRow());
      _syncAmountFromDetails();
    });
  }

  void _showPostSubmitOptions(CustodyDocument document) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تم إنشاء السند'),
          content: SingleChildScrollView(
            child: CustodyDocumentPreview(document: document),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await printCustodyDocument(document);
              },
              child: const Text('طباعة'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await saveCustodyDocumentPdf(document);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGeneralSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'معلومات السند',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                if (isWide) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDocumentNumberField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDocumentTitleField()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDateField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDestinationTypeField()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildAmountField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDestinationField()),
                        ],
                      ),
                      if (_destinationType == 'سيارة') ...[
                        const SizedBox(height: 16),
                        _buildVehicleNumberField(),
                      ],
                      const SizedBox(height: 16),
                      _buildCustodianField(),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildDocumentNumberField(),
                      const SizedBox(height: 16),
                      _buildDocumentTitleField(),
                      const SizedBox(height: 16),
                      _buildDateField(),
                      const SizedBox(height: 16),
                      _buildDestinationTypeField(),
                      const SizedBox(height: 16),
                      _buildAmountField(),
                      if (_destinationType == 'سيارة') ...[
                        const SizedBox(height: 16),
                        _buildVehicleNumberField(),
                      ],
                      const SizedBox(height: 16),
                      _buildDestinationField(),
                      const SizedBox(height: 16),
                      _buildCustodianField(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'قيمة العهدة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      readOnly: true,
      validator: (value) {
        final parsed = double.tryParse(value?.trim() ?? '');
        if (parsed == null || parsed < 0) {
          return 'يرجى إدخال مبلغ صحيح';
        }
        return null;
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDocumentNumberField() {
    return TextFormField(
      controller: _documentNumberController,
      decoration: InputDecoration(
        labelText: 'رقم السند',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      readOnly: true,
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDocumentTitleField() {
    return TextFormField(
      controller: _documentTitleController,
      decoration: InputDecoration(
        labelText: 'عنوان السند',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال عنوان السند';
        }
        return null;
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: _pickDate,
      decoration: InputDecoration(
        labelText: 'التاريخ',
        suffixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDestinationTypeField() {
    return DropdownButtonFormField<String>(
      value: _destinationType,
      decoration: InputDecoration(
        labelText: 'الجهة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: _destinationTypes
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type, style: const TextStyle(fontSize: 16)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _destinationType = value;
            if (value != 'سيارة') {
              _vehicleNumberController.clear();
            }
          });
        }
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildVehicleNumberField() {
    return TextFormField(
      controller: _vehicleNumberController,
      decoration: InputDecoration(
        labelText: 'رقم السيارة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (_destinationType == 'سيارة' &&
            (value == null || value.trim().isEmpty)) {
          return 'يرجى إدخال رقم السيارة';
        }
        return null;
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDestinationField() {
    return TextFormField(
      controller: _destinationController,
      decoration: InputDecoration(
        labelText: 'اسم الجهة أو جهة التوجيه',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال اسم الجهة';
        }
        return null;
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildCustodianField() {
    return TextFormField(
      controller: _custodianController,
      decoration: InputDecoration(
        labelText: 'مستلم السند',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال اسم المستلم';
        }
        return null;
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildRowsSection() {
    final total = _calculateDetailsTotal();
    final totalText = NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    ).format(total);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تفاصيل السند',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Column(
              children: _detailRows
                  .asMap()
                  .entries
                  .map((entry) => _buildDetailRow(entry.key, entry.value))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Text(
                      'قيمة العهدة (الإجمالي): $totalText',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _addDetailRow,
                icon: const Icon(Icons.add, size: 22),
                label: const Text(
                  'إضافة تفاصيل',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(int index, _DetailRow detail) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: detail.labelController,
                    decoration: InputDecoration(
                      labelText: 'عنوان التفاصيل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: detail.valueController,
                    decoration: InputDecoration(
                      labelText: 'القيمة أو الوصف',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(_syncAmountFromDetails),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => _removeDetailRow(index),
                  icon: const Icon(Icons.delete_outline, size: 28),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                TextFormField(
                  controller: detail.labelController,
                  decoration: InputDecoration(
                    labelText: 'عنوان التفاصيل',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: detail.valueController,
                        decoration: InputDecoration(
                          labelText: 'القيمة أو الوصف',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (_) => setState(_syncAmountFromDetails),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _removeDetailRow(index),
                      icon: const Icon(Icons.delete_outline, size: 28),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _removeDetailRow(int index) {
    if (_detailRows.length <= 1) return;
    setState(() {
      final row = _detailRows.removeAt(index);
      row.dispose();
      _syncAmountFromDetails();
    });
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تفاصيل إضافية',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _reasonController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'سبب التعميد',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'ملاحظات عامة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'سبب التعميد',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات عامة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إنشاء سند عهدة',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 2,
      ),
      body: Center(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<CustodyDocumentProvider>().refreshDocuments(),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 48 : 16,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
                maxWidth: isLargeScreen ? 1200 : double.infinity,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isLargeScreen) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                _buildGeneralSection(),
                                const SizedBox(height: 20),
                                _buildRowsSection(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildNotesSection(),
                                const SizedBox(height: 20),
                                _buildSubmitButton(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      _buildGeneralSection(),
                      const SizedBox(height: 20),
                      _buildRowsSection(),
                      const SizedBox(height: 20),
                      _buildNotesSection(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'حفظ وارسال للمراجعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const Text(
                'جاري حفظ السند...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
