import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class FingerprintEnrollmentScreen extends StatelessWidget {
  const FingerprintEnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل بصمة'),
      ),
      body: const Center(
        child: Text('واجهة تسجيل البصمة قيد البناء'),
      ),
    );
  }
}
