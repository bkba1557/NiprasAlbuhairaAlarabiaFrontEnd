import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

class FilterDialog extends StatefulWidget {
  const FilterDialog({super.key});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _status;
  String? _supplierName;
  String? _orderNumber;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.white,
        title: Row(
          children: const [
            Icon(Icons.filter_alt_outlined, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text(
            '\u062a\u0635\u0641\u064a\u0629 \u0627\u0644\u0637\u0644\u0628\u0627\u062a',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                    '\u0627\u062e\u062a\u0631 \u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u0645\u0646\u0627\u0633\u0628\u0629 \u0644\u0639\u0631\u0636 \u0627\u0644\u0637\u0644\u0628\u0627\u062a',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'Cairo',
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: InputDecoration(
                    labelText: '\u062d\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628',
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: AppColors.primaryBlue,
                          width: 1.4,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundGray.withOpacity(0.35),
                    ),
                  items: [
                    '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631',
                    '\u0642\u064a\u062f \u0627\u0644\u062a\u062c\u0647\u064a\u0632',
                    '\u062c\u0627\u0647\u0632 \u0644\u0644\u062a\u062d\u0645\u064a\u0644',
                    '\u062a\u0645 \u0627\u0644\u062a\u062d\u0645\u064a\u0644',
                    '\u0645\u0644\u063a\u0649',
                  ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                    labelText: '\u0627\u0633\u0645 \u0627\u0644\u0645\u0648\u0631\u062f',
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: AppColors.primaryBlue,
                          width: 1.4,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundGray.withOpacity(0.35),
                    ),
                    onChanged: (value) {
                      _supplierName = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                    labelText: '\u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628',
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: AppColors.primaryBlue,
                          width: 1.4,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundGray.withOpacity(0.35),
                    ),
                    onChanged: (value) {
                      _orderNumber = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundGray.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _startDate != null
                                      ? DateFormat('yyyy/MM/dd').format(_startDate!)
                                      : '\u0645\u0646 \u062a\u0627\u0631\u064a\u062e',
                                  style: TextStyle(
                                    color: _startDate != null
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                                const Icon(Icons.calendar_today, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundGray.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _endDate != null
                                      ? DateFormat('yyyy/MM/dd').format(_endDate!)
                                      : '\u0625\u0644\u0649 \u062a\u0627\u0631\u064a\u062e',
                                  style: TextStyle(
                                    color: _endDate != null
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                                const Icon(Icons.calendar_today, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.mediumGray,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          child: const Text(
            '\u0625\u0644\u063a\u0627\u0621',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          ),
          ElevatedButton(
            onPressed: () {
              final filters = {
                if (_status != null && _status!.isNotEmpty) 'status': _status!,
                if (_supplierName != null && _supplierName!.isNotEmpty)
                  'supplierName': _supplierName!,
                if (_orderNumber != null && _orderNumber!.isNotEmpty)
                  'orderNumber': _orderNumber!,
                if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
                if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
              };
              Navigator.pop(context, filters);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        child: const Text(
          '\u062a\u0637\u0628\u064a\u0642',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
          ),
        ],
      ),
    );
  }
}
