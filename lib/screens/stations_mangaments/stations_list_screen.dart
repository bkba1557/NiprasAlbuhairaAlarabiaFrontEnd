import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
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
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? stations
        : stations.where((station) {
            final fuel = station.fuelTypes.join(' ').toLowerCase();
            return station.stationName.toLowerCase().contains(query) ||
                station.stationCode.toLowerCase().contains(query) ||
                station.city.toLowerCase().contains(query) ||
                station.location.toLowerCase().contains(query) ||
                station.managerName.toLowerCase().contains(query) ||
                fuel.contains(query);
          }).toList();

    final bool web = isWeb(context);
    final bool tablet = isTablet(context);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 241, 241),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: const Text('المحطات', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'إضافة محطة',
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadStations,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(web ? 12 : 16),
                      child: AppSurfaceCard(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(26),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث عن محطة...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() => _searchController.clear());
                                    },
                                  ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.82),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    Expanded(
                      child: stationProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                          ? const _EmptyState()
                          : web || tablet
                          ? GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(web ? 12 : 16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: web ? 3 : 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: web ? 1.7 : 1.4,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildStationCard(filtered[index], web);
                              },
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return _buildStationCard(
                                  filtered[index],
                                  false,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= Station Card =================

  Widget _buildStationCard(Station station, bool web) {
    return AppSurfaceCard(
      padding: EdgeInsets.all(web ? 12 : 16),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.stationDetails,
          arguments: station.id,
        );
      },
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

          final infoRows = <Widget>[
            _infoRow(
              title: 'الموقع',
              value: '${station.city} - ${station.location}',
              web: web,
            ),
            _infoRow(title: 'المدير', value: station.managerName, web: web),
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
          ];

          Widget buildInfoBlock() {
            if (hasBoundedHeight) {
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: infoRows,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < infoRows.length; i++) ...[
                  infoRows[i],
                  if (i != infoRows.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Column(
            mainAxisSize: hasBoundedHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: web ? 40 : 44,
                    height: web ? 40 : 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_gas_station_rounded,
                      color: Colors.white,
                      size: 22,
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
                            fontSize: web ? 16 : 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          station.stationCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: web ? 12 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(station.isActive, web),
                ],
              ),
              const SizedBox(height: 10),
              buildInfoBlock(),
            ],
          );
        },
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
