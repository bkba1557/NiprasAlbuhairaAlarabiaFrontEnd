import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkshopFuelSupplyDetailsScreen extends StatelessWidget {
  const WorkshopFuelSupplyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supply = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;

    if (supply == null) {
      return const Scaffold(
        body: Center(child: Text('لا توجد بيانات للتوريد')),
      );
    }

    final date = DateTime.tryParse(supply['createdAt']?.toString() ?? '') ??
        DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل التوريد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow('التاريخ', DateFormat('yyyy/MM/dd').format(date)),
            _buildRow('الكمية', '${supply['quantity'] ?? 0} لتر'),
            _buildRow('سعر اللتر', '${supply['unitPrice'] ?? 0} ريال'),
            _buildRow('الإجمالي', '${supply['totalAmount'] ?? 0} ريال'),
            _buildRow('المورد', supply['supplierName'] ?? '--'),
            _buildRow('رقم التنكر', supply['tankerNumber'] ?? '--'),
            _buildRow('ملاحظات', supply['notes'] ?? '--'),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
