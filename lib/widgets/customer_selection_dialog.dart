import 'package:flutter/material.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class CustomerSelectionDialog extends StatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer?> onCustomerSelected;

  const CustomerSelectionDialog({
    super.key,
    this.selectedCustomer,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.selectedCustomer;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customerProvider = Provider.of<CustomerProvider>(
      context,
      listen: false,
    );
    await customerProvider.fetchCustomers(fetchAll: true);
    _filterCustomers('');
  }

  void _filterCustomers(String query) {
    final customerProvider = Provider.of<CustomerProvider>(
      context,
      listen: false,
    );

    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = customerProvider.customers;
      });
    } else {
      setState(() {
        _filteredCustomers = customerProvider.customers.where((customer) {
          return customer.name.toLowerCase().contains(query.toLowerCase()) ||
              customer.code.toLowerCase().contains(query.toLowerCase()) ||
              (customer.phone?.toLowerCase().contains(query.toLowerCase()) ??
                  false);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختر عميل'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: _filterCustomers,
              decoration: InputDecoration(
                hintText: 'ابحث عن عميل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected customer (if any)
            if (_selectedCustomer != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _selectedCustomer!.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCustomer!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'كود: ${_selectedCustomer!.code}',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedCustomer = null;
                        });
                      },
                      icon: const Icon(Icons.clear, color: Colors.red),
                    ),
                  ],
                ),
              ),

            // Customers list
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد عملاء',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        final isSelected = _selectedCustomer?.id == customer.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : AppColors.lightGray.withOpacity(0.3),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  customer.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              customer.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              'كود: ${customer.code}',
                              style: TextStyle(color: AppColors.mediumGray),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: AppColors.primaryBlue,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCustomer = customer;
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Add new customer button
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/customer/form').then((value) {
                    if (value != null && value is Customer) {
                      widget.onCustomerSelected(value);
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('إضافة عميل جديد'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _selectedCustomer != null
              ? () {
                  widget.onCustomerSelected(_selectedCustomer);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('اختيار'),
        ),
      ],
    );
  }
}
