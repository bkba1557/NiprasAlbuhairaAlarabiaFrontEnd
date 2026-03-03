import 'package:flutter/material.dart';
import 'package:order_tracker/screens/order/costomer_order/customer_form_screen.dart';
import 'package:order_tracker/widgets/empty_state_widget.dart';
import 'package:provider/provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/customer_item.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
    });
  }

  void _confirmDeleteCustomer(BuildContext context, String customerId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف العميل'),
          content: const Text(
            'هل أنت متأكد من حذف هذا العميل؟\nلا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('حذف', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(context);

                final provider = Provider.of<CustomerProvider>(
                  context,
                  listen: false,
                );

                final success = await provider.deleteCustomer(customerId);

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف العميل بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'فشل حذف العميل'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCustomers() async {
    await Provider.of<CustomerProvider>(
      context,
      listen: false,
    ).fetchCustomers(fetchAll: true);
  }

  void _searchCustomers(String query) {
    Provider.of<CustomerProvider>(
      context,
      listen: false,
    ).searchCustomers(query);
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final bool isMobile = width < 600;
        final bool isTablet = width >= 600 && width < 1024;
        final bool isDesktop = width >= 1024;

        final double maxWidth = isDesktop ? 1100 : double.infinity;
        final double horizontalPadding = isDesktop ? 24 : 16;

        return Scaffold(
          appBar: AppBar(title: const Text('العملاء', style: TextStyle(color: Colors.white),)),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/customer/form');
            },
            child: const Icon(Icons.add),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchCustomers,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن عميل...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Customers list
                  Expanded(
                    child: customerProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : customerProvider.customers.isEmpty
                        ? EmptyCustomersWidget(
                            onCreateCustomer: () {
                              Navigator.pushNamed(context, '/customer/form');
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCustomers,
                            child: ListView.separated(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: 16,
                              ),
                              itemCount: customerProvider.customers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final customer =
                                    customerProvider.customers[index];
                                return CustomerItem(
                                  customer: customer,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CustomerFormScreen(
                                          customerToEdit: customer,
                                        ),
                                      ),
                                    );
                                  },
                                  onDelete: () {
                                    _confirmDeleteCustomer(
                                      context,
                                      customer.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
