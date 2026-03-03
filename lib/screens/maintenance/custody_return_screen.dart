import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/custody_document_model.dart';
import 'package:order_tracker/providers/custody_document_provider.dart';
import 'package:provider/provider.dart';

class CustodyReturnScreen extends StatefulWidget {
  const CustodyReturnScreen({super.key});

  @override
  State<CustodyReturnScreen> createState() => _CustodyReturnScreenState();
}

class _CustodyReturnScreenState extends State<CustodyReturnScreen> {
  String _query = '';
  String? _selectedId;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustodyDocumentProvider>().refreshDocuments();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustodyDocumentProvider>();
    final currency = NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    );

    final documents = provider.documents.where((doc) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim();
      return doc.documentNumber.contains(q) ||
          doc.documentTitle.contains(q) ||
          doc.destinationName.contains(q) ||
          doc.custodianName.contains(q);
    }).toList();

    final CustodyDocument? selected = documents.isEmpty
        ? null
        : documents.firstWhere(
            (doc) => doc.id == _selectedId,
            orElse: () => documents.first,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'عمل مردود عهدة',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F5F2), Color(0xFFE9EEF5)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'اختيار السند',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) => setState(() {
                            _query = value;
                          }),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            labelText: 'بحث برقم السند أو العنوان أو الجهة',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: documents
                              .map(
                                (doc) => DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(
                                    '${doc.documentNumber} • ${doc.documentTitle}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedId = value;
                            });
                          },
                        ),
                        if (documents.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('لا توجد سندات متاحة للمردود حالياً'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (selected != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تفاصيل السند',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'رقم السند',
                            value: selected.documentNumber,
                          ),
                          _InfoRow(
                            label: 'عنوان السند',
                            value: selected.documentTitle,
                          ),
                          _InfoRow(
                            label: 'الجهة',
                            value:
                                '${selected.destinationType} - ${selected.destinationName}',
                          ),
                          _InfoRow(
                            label: 'التاريخ',
                            value: DateFormat('yyyy-MM-dd').format(
                              selected.documentDate,
                            ),
                          ),
                          _InfoRow(
                            label: 'المبلغ',
                            value: currency.format(selected.amount),
                          ),
                          _InfoRow(
                            label: 'حالة السند',
                            value: selected.status.displayTitle,
                          ),
                          _InfoRow(
                            label: 'حالة المردود',
                            value: selected.returnStatus.displayTitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (selected != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'مبلغ المردود',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'أدخل مبلغ المردود',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final eligible =
                                    selected.status ==
                                        CustodyDocumentStatus.approved &&
                                    selected.returnStatus ==
                                        CustodyReturnStatus.none &&
                                    selected.amount > 0;
                                if (!eligible) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'لا يمكن طلب مردود لهذا السند حالياً',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final amount = double.tryParse(
                                  _amountController.text.trim(),
                                );
                                if (amount == null ||
                                    amount <= 0 ||
                                    amount > selected.amount) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'يرجى إدخال مبلغ صالح لا يتجاوز قيمة السند',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                await context
                                    .read<CustodyDocumentProvider>()
                                    .requestReturn(selected.id, amount);

                                if (!mounted) return;
                                _amountController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم إرسال طلب المردود'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.undo),
                              label: const Text('إرسال طلب المردود'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
