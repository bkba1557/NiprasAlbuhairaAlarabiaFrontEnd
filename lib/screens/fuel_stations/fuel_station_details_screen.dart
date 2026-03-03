import 'package:flutter/material.dart';
import 'package:order_tracker/models/fuel_station_model.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class FuelStationDetailsScreen extends StatefulWidget {
  final String stationId;

  const FuelStationDetailsScreen({super.key, required this.stationId});

  @override
  State<FuelStationDetailsScreen> createState() =>
      _FuelStationDetailsScreenState();
}

class _FuelStationDetailsScreenState extends State<FuelStationDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStationDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStationDetails() async {
    await Provider.of<FuelStationProvider>(
      context,
      listen: false,
    ).fetchStationById(widget.stationId);
  }

  void _openMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _callPhone(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _sendEmail(String email) async {
    final url = 'mailto:$email';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FuelStationProvider>(context);
    final station = provider.selectedStation;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    if (provider.isLoading && station == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (station == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'تفاصيل المحطة',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(child: Text('المحطة غير موجودة')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            station.stationName,
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.fuelStationForm,
                  arguments: station,
                );
              },
              icon: const Icon(Icons.edit),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: isLargeScreen ? false : true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'نظرة عامة'),
              Tab(icon: Icon(Icons.build), text: 'المعدات'),
              Tab(icon: Icon(Icons.local_gas_station), text: 'الوقود'),
              Tab(icon: Icon(Icons.attach_file), text: 'المرفقات'),
            ],
            labelColor: Colors.white,
            dividerColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(station, isLargeScreen),
            _buildEquipmentTab(station, isLargeScreen),
            _buildFuelTab(station, isLargeScreen),
            _buildAttachmentsTab(station, isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(FuelStation station, bool isLargeScreen) {
    Color statusColor = _getStatusColor(station.status);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 32 : 16,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLargeScreen ? 1200 : double.infinity,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLargeScreen)
              _buildLargeScreenOverview(station, statusColor)
            else
              _buildSmallScreenOverview(station, statusColor),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeScreenOverview(FuelStation station, Color statusColor) {
    return Column(
      children: [
        // Top Row: Status + Manager
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildStatusCard(station, statusColor)),
            const SizedBox(width: 16),
            Expanded(flex: 1, child: _buildManagerCard(station)),
          ],
        ),
        const SizedBox(height: 16),

        // Middle Row: Location
        _buildLocationCard(station),
        const SizedBox(height: 16),

        // Bottom Row: Details
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDetailsCard(station)),
            const SizedBox(width: 16),
            Expanded(child: _buildQuickStatsCard(station)),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallScreenOverview(FuelStation station, Color statusColor) {
    return Column(
      children: [
        _buildStatusCard(station, statusColor),
        const SizedBox(height: 16),
        _buildLocationCard(station),
        const SizedBox(height: 16),
        _buildManagerCard(station),
        const SizedBox(height: 16),
        _buildDetailsCard(station),
      ],
    );
  }

  Widget _buildStatusCard(FuelStation station, Color statusColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_gas_station,
                color: statusColor,
                size: 36,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.stationName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    station.stationCode,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          station.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Text(
                          station.stationType,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(FuelStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'الموقع الجغرافي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('العنوان', station.address),
                      _buildDetailRow(
                        'الموقع',
                        '${station.city} - ${station.region}',
                      ),
                      _buildDetailRow(
                        'الإحداثيات',
                        '${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _openMaps(station.latitude, station.longitude),
                      icon: const Icon(Icons.map),
                      label: const Text('فتح الخريطة'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (station.googleMapsLink != null)
                          IconButton(
                            onPressed: () async {
                              if (await canLaunchUrl(
                                Uri.parse(station.googleMapsLink!),
                              )) {
                                await launchUrl(
                                  Uri.parse(station.googleMapsLink!),
                                );
                              }
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.map, color: Colors.blue),
                            ),
                          ),
                        if (station.wazeLink != null)
                          IconButton(
                            onPressed: () async {
                              if (await canLaunchUrl(
                                Uri.parse(station.wazeLink!),
                              )) {
                                await launchUrl(Uri.parse(station.wazeLink!));
                              }
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerCard(FuelStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'مدير المحطة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Text(
                station.managerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.managerPhone),
                  if (station.managerEmail != null) Text(station.managerEmail!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callPhone(station.managerPhone),
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (station.managerEmail != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendEmail(station.managerEmail!),
                      icon: const Icon(Icons.email),
                      label: const Text('بريد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(FuelStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'تفاصيل المحطة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildDetailChip('السعة الإجمالية', '${station.capacity} لتر'),
                _buildDetailChip(
                  'عدد الفنيين',
                  station.totalTechnicians.toString(),
                ),
                _buildDetailChip(
                  'تاريخ التأسيس',
                  _formatDate(station.establishedDate),
                ),
                _buildDetailChip(
                  'آخر صيانة',
                  _formatDate(station.lastMaintenanceDate),
                ),
                _buildDetailChip(
                  'الصيانة القادمة',
                  _formatDate(station.nextMaintenanceDate),
                ),
                _buildDetailChip(
                  'تاريخ الإنشاء',
                  _formatDateTime(station.createdAt),
                ),
                _buildDetailChip(
                  'آخر تحديث',
                  _formatDateTime(station.updatedAt),
                ),
                _buildDetailChip('تم الإنشاء بواسطة', station.createdByName),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard(FuelStation station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'إحصائيات سريعة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('عدد المعدات', station.equipment.length.toString()),
            _buildStatRow('أنواع الوقود', station.fuelTypes.length.toString()),
            _buildStatRow('المرفقات', station.attachments.length.toString()),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملخص',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'المحطة ${station.status} وتحتوي على ${station.equipment.length} معدات و${station.fuelTypes.length} نوع وقود.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentTab(FuelStation station, bool isLargeScreen) {
    if (station.equipment.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد معدات مسجلة',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: 16,
      ),
      child: isLargeScreen
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: station.equipment.length,
              itemBuilder: (context, index) {
                return _buildEquipmentCard(station.equipment[index], true);
              },
            )
          : ListView.builder(
              itemCount: station.equipment.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildEquipmentCard(station.equipment[index], false),
                );
              },
            ),
    );
  }

  Widget _buildEquipmentCard(StationEquipment equipment, bool isGrid) {
    Color statusColor = _getEquipmentStatusColor(equipment.status);

    if (isGrid) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.build, color: statusColor, size: 20),
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
                      equipment.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                equipment.equipmentName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                equipment.equipmentType,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildCompactDetailRow('SN', equipment.serialNumber),
              _buildCompactDetailRow('الشركة', equipment.manufacturer),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy/MM/dd').format(equipment.nextServiceDate),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    equipment.equipmentName,
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
                      equipment.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDetailRow('النوع', equipment.equipmentType),
              _buildDetailRow('الرقم التسلسلي', equipment.serialNumber),
              _buildDetailRow('الشركة المصنعة', equipment.manufacturer),
              _buildDetailRow(
                'تاريخ التركيب',
                _formatDate(equipment.installationDate),
              ),
              _buildDetailRow(
                'آخر صيانة',
                _formatDate(equipment.lastServiceDate),
              ),
              _buildDetailRow(
                'الصيانة القادمة',
                _formatDate(equipment.nextServiceDate),
              ),
              if (equipment.notes != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'ملاحظات:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(equipment.notes!),
              ],
            ],
          ),
        ),
      );
    }
  }

  Widget _buildFuelTab(FuelStation station, bool isLargeScreen) {
    if (station.fuelTypes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_gas_station, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد أنواع وقود مسجلة',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: 16,
      ),
      child: isLargeScreen
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: station.fuelTypes.length,
              itemBuilder: (context, index) {
                return _buildFuelCard(station.fuelTypes[index], true);
              },
            )
          : ListView.builder(
              itemCount: station.fuelTypes.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFuelCard(station.fuelTypes[index], false),
                );
              },
            ),
    );
  }

  Widget _buildFuelCard(StationFuelType fuelType, bool isGrid) {
    double percentage = (fuelType.availableQuantity / fuelType.capacity) * 100;
    Color levelColor = percentage > 70
        ? Colors.green
        : percentage > 30
        ? Colors.orange
        : Colors.red;

    if (isGrid) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      fuelType.fuelName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      fuelType.status,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${fuelType.pricePerLiter} ريال/لتر',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildCompactDetailRow('الخزان', fuelType.tankNumber),
              _buildCompactDetailRow('السعة', '${fuelType.capacity} لتر'),
              _buildCompactDetailRow(
                'المتاح',
                '${fuelType.availableQuantity} لتر',
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مستوى التخزين',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          color: levelColor,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fuelType.fuelName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${fuelType.pricePerLiter} ريال/لتر',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow('الخزان', fuelType.tankNumber),
              _buildDetailRow('السعة', '${fuelType.capacity} لتر'),
              _buildDetailRow('المتاح', '${fuelType.availableQuantity} لتر'),
              _buildDetailRow(
                'آخر تزويد',
                _formatDate(fuelType.lastDeliveryDate),
              ),
              _buildDetailRow(
                'التزويد القادم',
                _formatDate(fuelType.nextDeliveryDate),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مستوى التخزين',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          color: levelColor,
                          minHeight: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAttachmentsTab(FuelStation station, bool isLargeScreen) {
    if (station.attachments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_file, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد مرفقات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: 16,
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLargeScreen ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: station.attachments.length,
        itemBuilder: (context, index) {
          return _buildAttachmentCard(station.attachments[index]);
        },
      ),
    );
  }

  Widget _buildAttachmentCard(StationAttachment attachment) {
    IconData icon;
    Color color;

    switch (attachment.fileType) {
      case 'صورة':
        icon = Icons.image;
        color = Colors.green;
        break;
      case 'مخطط':
        icon = Icons.architecture;
        color = Colors.blue;
        break;
      case 'عقد':
        icon = Icons.description;
        color = Colors.orange;
        break;
      case 'رخصة':
        icon = Icons.badge;
        color = Colors.purple;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              attachment.filename,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              attachment.fileType,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(attachment.uploadedAt),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // TODO: View/download attachment
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text('عرض'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('yyyy/MM/dd HH:mm').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'نشطة':
        return Colors.green;
      case 'صيانة':
        return Colors.orange;
      case 'متوقفة':
        return Colors.red;
      case 'مغلقة':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getEquipmentStatusColor(String status) {
    switch (status) {
      case 'نشط':
        return Colors.green;
      case 'معطل':
        return Colors.red;
      case 'تحت الصيانة':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
