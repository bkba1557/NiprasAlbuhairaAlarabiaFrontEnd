import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class StationsListScreen extends StatefulWidget {
  const StationsListScreen({super.key});

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 1100;

  bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1100;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStations();
    });
  }

  Future<void> _loadStations() async {
    await Provider.of<StationProvider>(context, listen: false).fetchStations();
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final stations = stationProvider.stations;

    final bool web = isWeb(context);
    final bool tablet = isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحطات', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/station/form');
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: web
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/station/form');
              },
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // ================= Search =================
                Padding(
                  padding: EdgeInsets.all(web ? 12 : 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث عن محطة...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      // TODO: implement search
                    },
                  ),
                ),

                // ================= List / Grid =================
                Expanded(
                  child: stationProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : stations.isEmpty
                      ? const _EmptyState()
                      : web || tablet
                      ? GridView.builder(
                          padding: EdgeInsets.all(web ? 12 : 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: web ? 3 : 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: web ? 1.7 : 1.4,
                              ),
                          itemCount: stations.length,
                          itemBuilder: (context, index) {
                            return _buildStationCard(stations[index], web);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: stations.length,
                          itemBuilder: (context, index) {
                            return _buildStationCard(stations[index], false);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= Station Card =================

  Widget _buildStationCard(Station station, bool web) {
    return Card(
      elevation: web ? 2 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.stationDetails,
            arguments: station.id, // ⚠️ لازم Mongo _id
          );
        },
        child: Padding(
          padding: EdgeInsets.all(web ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= Header (ثابت) =================
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(web ? 8 : 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.business,
                      color: AppColors.primaryBlue,
                      size: web ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.stationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: web ? 15 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          station.stationCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: web ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(station.isActive, web),
                ],
              ),

              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // ================= Body (Expandable) =================
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      title: 'الموقع',
                      value: '${station.city} - ${station.location}',
                      web: web,
                    ),
                    _infoRow(
                      title: 'المدير',
                      value: station.managerName,
                      web: web,
                    ),
                    _infoRow(
                      title: 'أنواع الوقود',
                      value: station.fuelTypes.join('، '),
                      web: web,
                    ),
                    _infoRow(
                      title: 'المضخات',
                      value: '${station.pumps.length} مضخة',
                      web: web,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String value,
    required bool web,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.mediumGray,
            fontSize: web ? 11 : 12,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: web ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool isActive, bool web) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: web ? 10 : 12,
        vertical: web ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.successGreen.withOpacity(0.1)
            : AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppColors.successGreen : AppColors.errorRed,
        ),
      ),
      child: Text(
        isActive ? 'نشطة' : 'غير نشطة',
        style: TextStyle(
          color: isActive ? AppColors.successGreen : AppColors.errorRed,
          fontSize: web ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ================= Empty State =================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد محطات',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
