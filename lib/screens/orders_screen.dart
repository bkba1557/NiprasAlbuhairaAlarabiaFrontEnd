import 'package:flutter/material.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../widgets/order_data_grid.dart';
import '../widgets/filter_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchOrders();
    });
  }

  List<Order> _applySearch(List<Order> orders) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return orders;

    return orders.where((order) {
      final orderNumber = order.orderNumber;
      final supplierName = order.supplierName;
      final driverName = order.driverName;

      return orderNumber.contains(query) ||
          (supplierName != null && supplierName.contains(query)) ||
          (driverName != null && driverName.contains(query));
    }).toList();
  }

  Future<void> _showFilters() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const FilterDialog(),
    );

    if (result != null && mounted) {
      await Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchOrders(filters: result);
    }
  }

  /// ✅ هنا التعديل المهم
  Widget _buildOrdersTab(List<Order> orders) {
    final filtered = _applySearch(orders);

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth, // 👈 عرض التاب بالكامل
            child: OrderDataGrid(
              dataSource: OrderDataSource(filtered),
              onRowTap: (order) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.orderDetails,
                  arguments: order.id,
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          title: const Text(
            AppStrings.orders,
            style: TextStyle(fontFamily: "Cairo"),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'الكل'),
              Tab(text: 'طلبات العملاء'),
              Tab(text: 'طلبات الموردين'),
              Tab(text: 'المدمجة'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _showFilters,
              icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.orderForm);
          },
          child: const Icon(Icons.add),
        ),

        body: Column(
          children: [
            // 🔍 البحث
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: AppStrings.search,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // 📋 المحتوى
            Expanded(
              child: orderProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildOrdersTab(orderProvider.orders),

                        _buildOrdersTab(
                          orderProvider.orders
                              .where((o) => o.orderNumber.startsWith('CUS-'))
                              .toList(),
                        ),

                        _buildOrdersTab(
                          orderProvider.orders
                              .where((o) => o.orderNumber.startsWith('SUP-'))
                              .toList(),
                        ),

                        _buildOrdersTab(
                          orderProvider.orders
                              .where((o) => o.orderNumber.startsWith('MIX-'))
                              .toList(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
