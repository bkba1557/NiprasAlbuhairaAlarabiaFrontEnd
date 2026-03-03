import 'package:flutter/material.dart';
import 'package:order_tracker/models/fuel_station_model.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/widgets/fuel_station/fuel_station_data_grid.dart';
import 'package:order_tracker/widgets/fuel_station/station_filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:url_launcher/url_launcher.dart';

class FuelStationsScreen extends StatefulWidget {
  const FuelStationsScreen({super.key});

  @override
  State<FuelStationsScreen> createState() => _FuelStationsScreenState();
}

class _FuelStationsScreenState extends State<FuelStationsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _showMapView = false;
  Future<void>? _trackingFuture;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _trackingFuture = context
          .read<FuelStationProvider>()
          .fetchTechnicianLocations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<FuelStationProvider>(context, listen: false);
    await provider.fetchStations();
  }

  Future<void> _showFilters() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const StationFilterDialog(),
    );

    if (result != null) {
      final provider = Provider.of<FuelStationProvider>(context, listen: false);
      await provider.fetchStations(filters: result);
    }
  }

  void _toggleView() {
    setState(() {
      _showMapView = !_showMapView;
    });
  }

  void _openInMaps(double lat, double lng, String? googleMapsLink) async {
    final url =
        googleMapsLink ??
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _openInWaze(double lat, double lng, String? wazeLink) async {
    final url = wazeLink ?? 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FuelStationProvider>();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة محطات الوقود',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              onPressed: _toggleView,
              icon: Icon(_showMapView ? Icons.list : Icons.map),
              tooltip: _showMapView ? 'عرض القائمة' : 'عرض الخريطة',
            ),
            IconButton(
              onPressed: _showFilters,
              icon: const Icon(Icons.filter_alt_outlined),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.fuelStationForm);
              },
              icon: const Icon(Icons.add),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'جميع المحطات'),
              Tab(text: 'سجل الصيانة'),
              Tab(text: 'طلبات الموافقة'),
              Tab(text: 'التحذيرات'),
              Tab(text: 'تتبع الفنيين'),
            ],
            labelColor: Colors.white,
            indicatorColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // All Stations Tab
            _buildStationsTab(provider),
            // Maintenance Tab
            _buildMaintenanceTab(provider),
            // Approval Tab
            _buildApprovalTab(provider),
            // Alerts Tab
            _buildAlertsTab(provider),
            // Technician Tracking Tab
            _buildTrackingTab(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsTab(FuelStationProvider provider) {
    if (_showMapView) {
      return _buildMapView(provider);
    }

    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المحطة أو المنطقة أو المدينة',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (provider.filters.isNotEmpty)
                Chip(
                  label: Text('مفعلة ${provider.filters.length}'),
                  onDeleted: () {
                    provider.clearFilters();
                  },
                  deleteIcon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        // Data grid
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.stations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_gas_station,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد محطات وقود',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : FuelStationDataGrid(
                  stations: provider.stations,
                  onStationTap: (station) {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.fuelStationDetails,
                      arguments: station.id,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMapView(FuelStationProvider provider) {
    if (provider.stations.isEmpty) {
      return const Center(child: Text('لا توجد محطات لعرضها على الخريطة'));
    }

    return SfMaps(
      layers: [
        MapTileLayer(
          initialFocalLatLng: MapLatLng(
            provider.stations.first.latitude,
            provider.stations.first.longitude,
          ),
          initialZoomLevel: 10,
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          initialMarkersCount: provider.stations.length,
          markerBuilder: (context, index) {
            final station = provider.stations[index];
            Color markerColor;
            switch (station.status) {
              case 'نشطة':
                markerColor = Colors.green;
                break;
              case 'صيانة':
                markerColor = Colors.orange;
                break;
              case 'متوقفة':
                markerColor = Colors.red;
                break;
              default:
                markerColor = Colors.blue;
            }

            return MapMarker(
              latitude: station.latitude,
              longitude: station.longitude,
              child: GestureDetector(
                onTap: () {
                  _showStationPopup(station);
                },
                child: Column(
                  children: [
                    Icon(Icons.local_gas_station, color: markerColor, size: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        station.stationName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showStationPopup(FuelStation station) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(station.stationName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكود: ${station.stationCode}'),
            Text('المدينة: ${station.city}'),
            Text('المنطقة: ${station.region}'),
            Text('الحالة: ${station.status}'),
            Text('المدير: ${station.managerName}'),
            Text('الهاتف: ${station.managerPhone}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/fuel-station/details',
                arguments: station.id,
              );
            },
            child: const Text('تفاصيل'),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _openInMaps(
                  station.latitude,
                  station.longitude,
                  station.googleMapsLink,
                ),
                icon: const Icon(Icons.map, color: Colors.green),
                tooltip: 'فتح في Google Maps',
              ),
              IconButton(
                onPressed: () => _openInWaze(
                  station.latitude,
                  station.longitude,
                  station.wazeLink,
                ),
                icon: const Icon(Icons.directions_car, color: Colors.blue),
                tooltip: 'فتح في Waze',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab(FuelStationProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'سجل الصيانة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.maintenanceFuelForms);
                },
                icon: const Icon(Icons.add),
                label: const Text('طلب صيانة جديد'),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.maintenanceRecords.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.build, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد سجلات صيانة',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.maintenanceRecords.length,
                  itemBuilder: (context, index) {
                    final record = provider.maintenanceRecords[index];
                    return _buildMaintenanceCard(record);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceCard(MaintenanceRecord record) {
    Color statusColor;
    switch (record.status) {
      case 'مطلوب':
        statusColor = Colors.red;
        break;
      case 'تحت التنفيذ':
        statusColor = Colors.orange;
        break;
      case 'مكتمل':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  record.stationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    record.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'مقرر: ${_formatDate(record.scheduledDate)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  record.technicianName ?? 'لم يتم التعيين',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            if (record.completedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'مكتمل: ${_formatDate(record.completedDate!)}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalTab(FuelStationProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'طلبات الموافقة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.approvalRequest);
                },
                icon: const Icon(Icons.add),
                label: const Text('طلب موافقة جديد'),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.approvalRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.approval, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد طلبات موافقة',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.approvalRequests.length,
                  itemBuilder: (context, index) {
                    final request = provider.approvalRequests[index];
                    return _buildApprovalCard(request);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildApprovalCard(ApprovalRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case 'منتظر':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'قيد المراجعة':
        statusColor = Colors.blue;
        statusIcon = Icons.reviews;
        break;
      case 'معتمد':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'مرفوض':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        request.stationName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المبلغ',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      '${request.amount} ${request.currency}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'مقدم الطلب',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      request.requestedByName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(request.requestedAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (request.approvedAt != null) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(request.approvedAt!),
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsTab(FuelStationProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'التحذيرات والإشعارات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.sendAlert);
                },
                icon: const Icon(Icons.add_alert),
                label: const Text('إرسال تحذير'),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.alerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد تحذيرات',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.alerts.length,
                  itemBuilder: (context, index) {
                    final alert = provider.alerts[index];
                    return _buildAlertCard(alert);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(AlertNotification alert) {
    Color priorityColor;
    IconData priorityIcon;

    switch (alert.priority) {
      case 'عالي':
        priorityColor = Colors.red;
        priorityIcon = Icons.warning;
        break;
      case 'متوسط':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning_amber;
        break;
      case 'منخفض':
        priorityColor = Colors.blue;
        priorityIcon = Icons.info;
        break;
      default:
        priorityColor = Colors.grey;
        priorityIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(priorityIcon, size: 20, color: priorityColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        alert.stationName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    alert.priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(alert.message),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  alert.sentByName,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(alert.sentAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (alert.sendEmail)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text(
                          'بريد',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                if (alert.sendSMS)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sms, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text(
                          'رسالة',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                if (alert.sendPush)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'تنبيه',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (alert.readAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'تم القراءة: ${_formatDateTime(alert.readAt!)}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTab(FuelStationProvider provider) {
    // ✅ لو لسه ما اتعملش init
    if (_trackingFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: _trackingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تتبع الفنيين الميدانيين',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _trackingFuture = provider.fetchTechnicianLocations();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.technicianLocations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد مواقع نشطة للفنيين',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : SfMaps(
                      layers: [
                        MapTileLayer(
                          initialFocalLatLng: MapLatLng(
                            provider.technicianLocations.first.latitude,
                            provider.technicianLocations.first.longitude,
                          ),
                          initialZoomLevel: 12,
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          initialMarkersCount:
                              provider.technicianLocations.length,
                          markerBuilder: (context, index) {
                            final location =
                                provider.technicianLocations[index];
                            return MapMarker(
                              latitude: location.latitude,
                              longitude: location.longitude,
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: Colors.blue,
                                size: 36,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showTechnicianPopup(TechnicianLocation location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location.technicianName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المحطة: ${location.stationName}'),
            Text('السرعة: ${location.speed.toStringAsFixed(1)} كم/ساعة'),
            Text('الدقة: ${location.accuracy.toStringAsFixed(1)} متر'),
            Text('النشاط: ${location.activity}'),
            Text('التوقيت: ${_formatDateTime(location.timestamp)}'),
            if (location.notes != null) Text('ملاحظات: ${location.notes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openInMaps(location.latitude, location.longitude, null);
            },
            child: const Text('فتح في الخريطة'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
