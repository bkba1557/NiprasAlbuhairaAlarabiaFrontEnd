import 'package:flutter/material.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';

class CustomerAccountsScreen extends StatelessWidget {
  const CustomerAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابات العملاء')),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 46),
                        const SizedBox(height: 10),
                        const Text(
                          'كشف حساب العملاء متاح عبر شاشة الخزينة.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.orderManagementTreasury,
                          ),
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text('فتح الخزينة'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

