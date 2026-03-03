import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class SalaryDetailsScreen extends StatelessWidget {
  final String salaryId;

  const SalaryDetailsScreen({super.key, required this.salaryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الراتب'),
      ),
      body: Center(
        child: Text('تفاصيل الراتب ID: $salaryId'),
      ),
    );
  }
}
