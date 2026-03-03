import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SessionEditScreen extends StatefulWidget {
  final PumpSession session;

  const SessionEditScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _openingControllers = {};
  final Map<String, TextEditingController> _closingControllers = {};
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _differenceReasonController =
      TextEditingController();
  final TextEditingController _carriedForwardController =
      TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _madaController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _fuelTypeController = TextEditingController();
  final TextEditingController _fuelQuantityController = TextEditingController();
  final TextEditingController _tankerNumberController =
      TextEditingController();
  final TextEditingController _supplierNameController =
      TextEditingController();
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, XFile?> _selectedReadingImages = {};
  final Map<String, Uint8List?> _readingImageBytes = {};
  final List<_EditableExpense> _expenseItems = [];
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    final payment = widget.session.paymentTypes;
    _notesController.text = widget.session.notes ?? '';
    _differenceReasonController.text = widget.session.differenceReason ?? '';
    _carriedForwardController.text =
        widget.session.carriedForwardBalance.toStringAsFixed(2);
    _cashController.text = payment.cash.toStringAsFixed(2);
    _cardController.text = payment.card.toStringAsFixed(2);
    _madaController.text = payment.mada.toStringAsFixed(2);
    _otherController.text = payment.other.toStringAsFixed(2);

    final fuelSupply = widget.session.fuelSupply;
    if (fuelSupply != null) {
      _fuelTypeController.text = fuelSupply.fuelType;
      _fuelQuantityController.text = fuelSupply.quantity.toStringAsFixed(2);
      _tankerNumberController.text = fuelSupply.tankerNumber ?? '';
      _supplierNameController.text = fuelSupply.supplierName ?? '';
    }

    for (final reading in widget.session.nozzleReadings ?? []) {
      final openKey = _fieldKey(reading, 'opening');
      final closeKey = _fieldKey(reading, 'closing');
      _openingControllers[openKey] = TextEditingController(
        text: reading.openingReading.toStringAsFixed(2),
      );
      _closingControllers[closeKey] = TextEditingController(
        text: reading.closingReading?.toStringAsFixed(2) ?? '',
      );
    }

    _expenseItems.addAll(
      (widget.session.expenses ?? []).map(
            (expense) => _EditableExpense.fromExpense(expense),
          ),
    );

    if (_expenseItems.isEmpty) {
      _expenseItems.add(_EditableExpense());
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _differenceReasonController.dispose();
    _carriedForwardController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    _madaController.dispose();
    _otherController.dispose();
    _fuelTypeController.dispose();
    _fuelQuantityController.dispose();
    _tankerNumberController.dispose();
    _supplierNameController.dispose();
    for (final controller in _openingControllers.values) {
      controller.dispose();
    }
    for (final controller in _closingControllers.values) {
      controller.dispose();
    }
    for (final expense in _expenseItems) {
      expense.dispose();
    }
    super.dispose();
  }

  String _fieldKey(NozzleReading reading, String suffix) {
    final id = reading.nozzleId.isNotEmpty
        ? reading.nozzleId
        : '${reading.pumpNumber}_${reading.nozzleNumber}';
    return '${id}_$suffix';
  }

  double? _parseNullable(String? value) {
    final normalized = value?.trim().replaceAll(',', '.');
    if (normalized == null || normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  double _parseOrFallback(String? value, double fallback) {
    final parsed = _parseNullable(value);
    return parsed ?? fallback;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final nozzles = widget.session.nozzleReadings ?? [];
    final Map<String, String?> uploadedImageUrls = {};

    try {
      for (final reading in nozzles) {
        for (final isOpening in [true, false]) {
          final key = _readingImageKey(reading, isOpening);
          final selected = _selectedReadingImages[key];
          if (selected != null) {
            final url = await _uploadReadingImage(selected, reading, isOpening);
            uploadedImageUrls[key] = url;
          }
        }
      }
    } catch (e, st) {
      debugPrint('Image upload failed: $e');
      debugPrint('$st');
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر رفع الصور: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final nozzlePayload = nozzles.map((reading) {
      final openingKey = _readingImageKey(reading, true);
      final closingKey = _readingImageKey(reading, false);

      return {
        'nozzleId': reading.nozzleId,
        'pumpId': reading.pumpId,
        'pumpNumber': reading.pumpNumber,
        'nozzleNumber': reading.nozzleNumber,
        'fuelType': reading.fuelType,
        'position': reading.position,
        'openingReading': _parseOrFallback(
          _openingControllers[_fieldKey(reading, 'opening')]!.text,
          reading.openingReading,
        ),
        'closingReading': _parseNullable(
          _closingControllers[_fieldKey(reading, 'closing')]!.text,
        ),
        'openingImageUrl': uploadedImageUrls[openingKey] ??
            reading.openingImageUrl,
        'closingImageUrl': uploadedImageUrls[closingKey] ??
            reading.closingImageUrl,
      };
    }).toList();

    final expensesPayload = _expenseItems.map((item) {
      final amount = _parseNullable(item.amountController.text);
      if (amount == null) return null;

      final data = <String, dynamic>{
        'amount': amount,
        'description': item.descriptionController.text.trim(),
        'category': item.categoryController.text.trim(),
      };

      if (item.source?.id.isNotEmpty ?? false) {
        data['id'] = item.source!.id;
      }

      return data;
    }).whereType<Map<String, dynamic>>().toList();

    final fuelQuantity = _parseNullable(_fuelQuantityController.text);

    final payload = {
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'differenceReason': _differenceReasonController.text.trim().isEmpty
          ? null
          : _differenceReasonController.text.trim(),
      'carriedForwardBalance': _parseOrFallback(
        _carriedForwardController.text,
        widget.session.carriedForwardBalance,
      ),
      'paymentTypes': {
        'cash': _parseOrFallback(
          _cashController.text,
          widget.session.paymentTypes.cash,
        ),
        'card': _parseOrFallback(
          _cardController.text,
          widget.session.paymentTypes.card,
        ),
        'mada': _parseOrFallback(
          _madaController.text,
          widget.session.paymentTypes.mada,
        ),
        'other': _parseOrFallback(
          _otherController.text,
          widget.session.paymentTypes.other,
        ),
      },
      'fuelSupply': (_fuelTypeController.text.trim().isNotEmpty &&
              fuelQuantity != null &&
              fuelQuantity > 0)
          ? {
              'fuelType': _fuelTypeController.text.trim(),
              'quantity': fuelQuantity,
              'tankerNumber': _tankerNumberController.text.trim(),
              'supplierName': _supplierNameController.text.trim(),
            }
          : null,
      'nozzleReadings': nozzlePayload,
      'expenses': expensesPayload,
      'expensesTotal': _expensesTotal,
    };

    final stationProvider =
        Provider.of<StationProvider>(context, listen: false);
    final success = await stationProvider.editSession(
      widget.session.id,
      payload,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stationProvider.error ?? 'فشل حفظ التعديلات',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildNozzleEditor(NozzleReading reading) {
    final openingController = _openingControllers[_fieldKey(reading, 'opening')]!;
    final closingController = _closingControllers[_fieldKey(reading, 'closing')]!;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المضخات ${reading.pumpNumber} · لي ${reading.nozzleNumber}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'نوع الوقود: ${reading.fuelType}',
              style: const TextStyle(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: openingController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'قراءة الفتح',
                      hintText: '0.00',
                    ),
                    validator: (value) {
                      final parsed = _parseNullable(value);
                      if (parsed == null) {
                        return 'الرجاء إدخال قراءة صحيحة';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: closingController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'قراءة الغلق',
                      hintText: '0.00',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      if (_parseNullable(value) == null) {
                        return 'رقم غير صالح';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildReadingImagePicker(reading, true),
                const SizedBox(width: 12),
                _buildReadingImagePicker(reading, false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _readingImageKey(NozzleReading reading, bool isOpening) {
    final base = reading.nozzleId.isNotEmpty
        ? reading.nozzleId
        : '${reading.pumpNumber}_${reading.nozzleNumber}';
    final suffix = isOpening ? 'opening' : 'closing';
    return '$base-$suffix';
  }

  Future<void> _pickReadingImage(NozzleReading reading, bool isOpening) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1400,
        imageQuality: 70,
      );

      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        final key = _readingImageKey(reading, isOpening);
        _selectedReadingImages[key] = picked;
        _readingImageBytes[key] = bytes;
      });
    } catch (e, st) {
      debugPrint('Could not pick image: $e');
      debugPrint('$st');
    }
  }

  Future<String> _uploadReadingImage(
    XFile image,
    NozzleReading reading,
    bool isOpening,
  ) async {
    final suffix = isOpening ? 'opening' : 'closing';
    final fileName =
        'pump_${reading.pumpNumber}_nozzle_${reading.nozzleNumber}_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance
        .ref()
        .child('sessions/${widget.session.id}/edit/$suffix/$fileName');

    final bytes = await image.readAsBytes();
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final uploadTask = await ref.putData(bytes, metadata);
    return await uploadTask.ref.getDownloadURL();
  }

  Widget _buildReadingImagePicker(NozzleReading reading, bool isOpening) {
    final key = _readingImageKey(reading, isOpening);
    final label = isOpening ? 'صورة الفتح' : 'صورة الغلق';
    final existingUrl =
        isOpening ? reading.openingImageUrl : reading.closingImageUrl;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickReadingImage(reading, isOpening),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightGray),
                color: AppColors.lightGray.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _readingImagePreview(key, existingUrl),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _pickReadingImage(reading, isOpening),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('تغيير الصورة'),
          ),
        ],
      ),
    );
  }

  Widget _readingImagePreview(String key, String? existingUrl) {
    final bytes = _readingImageBytes[key];
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (existingUrl != null && existingUrl.isNotEmpty) {
      return Image.network(
        existingUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _emptyImagePlaceholder(),
      );
    }

    return _emptyImagePlaceholder();
  }

  Widget _emptyImagePlaceholder() {
    return Container(
      color: AppColors.lightGray.withOpacity(0.05),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.photo, size: 36, color: AppColors.mediumGray),
          SizedBox(height: 4),
          Text(
            'اضغط لإرفاق صورة',
            style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    final session = widget.session;
    final openingTime = session.openingTime != null
        ? _dateTimeFormat.format(session.openingTime)
        : '-';
    final closingTime = session.closingTime != null
        ? _dateTimeFormat.format(session.closingTime!)
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات الجلسة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSessionInfoRow(
                    'رقم الجلسة',
                    session.sessionNumber,
                  ),
                ),
                Expanded(
                  child: _buildSessionInfoRow(
                    'الوضع',
                    session.status,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSessionInfoRow(
                    'تاريخ الجلسة',
                    _dateFormat.format(session.sessionDate),
                  ),
                ),
                Expanded(
                  child: _buildSessionInfoRow(
                    'الوردية',
                    session.shiftType,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSessionInfoRow(
                    'فتح الجلسة',
                    openingTime,
                  ),
                ),
                Expanded(
                  child: _buildSessionInfoRow(
                    'غلق الجلسة',
                    closingTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSessionInfoRow(
                    'موظف الفتح',
                    session.openingEmployeeName ?? '-',
                  ),
                ),
                Expanded(
                  child: _buildSessionInfoRow(
                    'موظف الغلق',
                    session.closingEmployeeName ?? '-',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentField(String label, TextEditingController controller) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'أدخل قيمة';
          if (_parseNullable(value) == null) return 'رقم غير صالح';
          return null;
        },
      ),
    );
  }

  double get _expensesTotal {
    return _expenseItems.fold(
      0,
      (total, item) => total + (item.parsedAmount ?? 0),
    );
  }

  void _addExpense() {
    setState(() {
      _expenseItems.add(_EditableExpense());
    });
  }

  void _removeExpense(int index) {
    setState(() {
      _expenseItems[index].dispose();
      _expenseItems.removeAt(index);
    });
  }

  Widget _buildExpensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'المصروفات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text('إضافة مصروف'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._expenseItems.asMap().entries.map(
          (entry) => _buildExpenseCard(entry.key, entry.value),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.successGreen.withOpacity(0.1),
            border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.summarize, color: AppColors.successGreen),
              const SizedBox(width: 8),
              const Text('إجمالي المصروفات'),
              const Spacer(),
              Text(
                '${_expensesTotal.toStringAsFixed(2)} ريال',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(int index, _EditableExpense item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'مصروف ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeExpense(index),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.errorRed,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'أدخل قيمة';
                      if (_parseNullable(value) == null) return 'رقم غير صالح';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item.categoryController,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: item.descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final nozzles = widget.session.nozzleReadings ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تعديل الجلسة ${widget.session.sessionNumber}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'المحطة: ${widget.session.stationName} · الوردية: ${widget.session.shiftType}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSessionInfoCard(),
                      if (stationProvider.isLoading || _isSaving)
                        const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'قراءات المضخات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (nozzles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('لا توجد قراءات لليّات في هذه الجلسة.'),
                        )
                      else
                        ...nozzles.map(_buildNozzleEditor),
                      const SizedBox(height: 20),
                      const Text(
                        'طرق الدفع',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildPaymentField('نقدي', _cashController),
                          const SizedBox(width: 8),
                          _buildPaymentField('بطاقة', _cardController),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildPaymentField('مدى', _madaController),
                          const SizedBox(width: 8),
                          _buildPaymentField('أخرى', _otherController),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'توريد الوقود',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fuelTypeController,
                        decoration: const InputDecoration(
                          labelText: 'نوع الوقود',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fuelQuantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'الكمية (لتر)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _tankerNumberController,
                              decoration: const InputDecoration(
                                labelText: 'رقم التانكر',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supplierNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المورد',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'الرصيد والملاحظات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _carriedForwardController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'الرصيد المرحل',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل قيمة';
                          }
                          if (_parseNullable(value) == null) return 'رقم غير صالح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _differenceReasonController,
                        decoration: const InputDecoration(
                          labelText: 'سبب الفرق',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات إضافية',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      _buildExpensesSection(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isSaving || stationProvider.isLoading)
                              ? null
                              : _submitForm,
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التعديلات'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditableExpense {
  Expense? source;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final TextEditingController categoryController;

  _EditableExpense({this.source})
      : amountController = TextEditingController(
          text: source != null ? source.amount.toStringAsFixed(2) : '',
        ),
        descriptionController =
            TextEditingController(text: source?.description ?? ''),
        categoryController =
            TextEditingController(text: source?.category ?? '');

  double? get parsedAmount {
    final value = amountController.text.trim().replaceAll(',', '.');
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
  }

  factory _EditableExpense.fromExpense(Expense expense) {
    return _EditableExpense(source: expense);
  }
}
