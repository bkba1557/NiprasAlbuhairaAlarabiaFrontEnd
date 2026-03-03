import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/driver_provider.dart';
import '../widgets/driver_item.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrivers();
    });
  }

  void _confirmDeleteDriver(BuildContext context, String driverId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف السائق'),
          content: const Text(
            'هل أنت متأكد من حذف هذا السائق؟\nلا يمكن التراجع عن هذا الإجراء.',
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

                final provider = Provider.of<DriverProvider>(
                  context,
                  listen: false,
                );

                final success = await provider.deleteDriver(driverId);

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف السائق بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadDrivers();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'فشل حذف السائق'),
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

  Future<void> _loadDrivers() async {
    await Provider.of<DriverProvider>(context, listen: false).fetchDrivers();
  }

  void _searchDrivers(String query) {
    Provider.of<DriverProvider>(context, listen: false).searchDrivers(query);
  }

  void _filterByStatus(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    Provider.of<DriverProvider>(
      context,
      listen: false,
    ).fetchDrivers(status: status);
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final bool isMobile = width < 600;
        final bool isTablet = width >= 600 && width < 1024;
        final bool isDesktop = width >= 1024;

        final double maxWidth = isDesktop ? 1200 : double.infinity;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'السائقين',
              style: TextStyle(color: Colors.white),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/driver/form');
            },
            child: const Icon(Icons.add),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  /// 🔍 Search & Filters
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: isMobile
                        ? Column(
                            children: [
                              _buildSearchField(),
                              const SizedBox(height: 12),
                              _buildStatusFilters(),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildSearchField()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatusFilters()),
                            ],
                          ),
                  ),

                  /// 🚗 Drivers List
                  Expanded(
                    child: driverProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : driverProvider.drivers.isEmpty
                        ? const _EmptyDriversView()
                        : RefreshIndicator(
                            onRefresh: _loadDrivers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: driverProvider.drivers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final driver = driverProvider.drivers[index];
                                return DriverItem(
                                  driver: driver,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/driver/form',
                                      arguments: driver,
                                    );
                                  },
                                  onDelete: () {
                                    _confirmDeleteDriver(context, driver.id);
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

  /// 🔍 Search Field
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _searchDrivers,
      decoration: InputDecoration(
        hintText: 'ابحث عن سائق...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// 🏷 Status Filters
  Widget _buildStatusFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip('الكل', null),
        _buildChip('نشط', 'نشط'),
        _buildChip('غير نشط', 'غير نشط'),
        _buildChip('في إجازة', 'في إجازة'),
      ],
    );
  }

  Widget _buildChip(String label, String? status) {
    return FilterChip(
      label: Text(label),
      selected: _selectedStatus == status,
      onSelected: (_) => _filterByStatus(status),
    );
  }
}

/// 🚫 Empty State
class _EmptyDriversView extends StatelessWidget {
  const _EmptyDriversView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد سائقين',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
