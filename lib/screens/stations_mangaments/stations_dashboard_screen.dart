import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/stat_card.dart';
import 'package:order_tracker/widgets/stations/session_status_card.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class StationsDashboardScreen extends StatefulWidget {
  const StationsDashboardScreen({super.key});

  @override
  State<StationsDashboardScreen> createState() =>
      _StationsDashboardScreenState();
}

class _StationsDashboardScreenState extends State<StationsDashboardScreen> {
  String _selectedStationId = '';
  DateTime _selectedDate = DateTime.now();

  bool isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 1100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    await stationProvider.fetchStations();

    if (stationProvider.stations.isNotEmpty && _selectedStationId.isEmpty) {
      setState(() {
        _selectedStationId = stationProvider.stations.first.id;
      });
      await stationProvider.fetchStationStats(
        _selectedStationId,
        startDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        endDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);

      final stationProvider = Provider.of<StationProvider>(
        context,
        listen: false,
      );

      await stationProvider.fetchStationStats(
        _selectedStationId,
        startDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        endDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final stats = stationProvider.stationStats;
    final bool web = isWeb(context);
    final riyalFormatter = NumberFormat.decimalPattern('ar');

    final complianceValue = stats != null && stats.totalSales > 0
        ? (stats.netRevenue / stats.totalSales) * 100
        : 0.0;
    final complianceText = stats != null
        ? '${math.min(math.max(complianceValue, 0.0), 100.0).toStringAsFixed(1)}%'
        : '-';
    final revenueText =
        stats != null ? riyalFormatter.format(stats.totalSales) : '-';
    final sessionsText = stats?.totalSessions.toString() ?? '-';
    final stationsText = stationProvider.stations.isNotEmpty
        ? stationProvider.stations.length.toString()
        : '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة مبيعات المحطات',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_today),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(web ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= Filters =================
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(web ? 12 : 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('yyyy/MM/dd').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: web ? 14 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.business,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _selectedStationId,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: stationProvider.stations.map((s) {
                                    return DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        s.stationName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    setState(() => _selectedStationId = v);
                                    await stationProvider.fetchStationStats(
                                      v,
                                      startDate: DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(_selectedDate),
                                      endDate: DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(_selectedDate),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'إحصائيات اليوم',
                            style: TextStyle(
                              fontSize: web ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: web ? 20 : 16,
                        vertical: web ? 18 : 14,
                      ),
                      child: Row(
                        children: [
                          _buildSummaryStatCard(
                            context: context,
                            icon: Icons.verified,
                            value: complianceText,
                            label: 'مطابقة',
                            color: AppColors.successGreen,
                          ),
                          SizedBox(width: web ? 16 : 12),
                          _buildSummaryStatCard(
                            context: context,
                            icon: Icons.attach_money,
                            value: revenueText,
                            label: 'ريال اليوم',
                            color: AppColors.warningOrange,
                          ),
                          SizedBox(width: web ? 16 : 12),
                          _buildSummaryStatCard(
                            context: context,
                            icon: Icons.play_circle_outline,
                            value: sessionsText,
                            label: 'جلسة نشطة',
                            color: AppColors.infoBlue,
                          ),
                          SizedBox(width: web ? 16 : 12),
                          _buildSummaryStatCard(
                            context: context,
                            icon: Icons.local_gas_station,
                            value: stationsText,
                            label: 'محطة',
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================= Stats =================
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: web ? 4 : 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: web ? 1.6 : 1.2,
                    children: [
                      StatCard(
                        title: 'الجلسات النشطة',
                        value: stats?.totalSessions.toString() ?? '0',
                        icon: Icons.play_circle_outline,
                        color: AppColors.infoBlue,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.infoBlue,
                            AppColors.infoBlue.withOpacity(0.7),
                          ],
                        ),
                      ),
                      StatCard(
                        title: 'إجمالي اللترات',
                        value: stats?.totalLiters.toStringAsFixed(2) ?? '0.00',
                        subtitle: 'لتر',
                        icon: Icons.water_drop,
                        color: AppColors.secondaryTeal,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondaryTeal,
                            AppColors.secondaryTeal.withOpacity(0.7),
                          ],
                        ),
                      ),
                      StatCard(
                        title: 'إجمالي المبيعات',
                        value: stats?.totalSales.toStringAsFixed(2) ?? '0.00',
                        subtitle: 'ريال',
                        icon: Icons.attach_money,
                        color: AppColors.successGreen,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.successGreen,
                            AppColors.successGreen.withOpacity(0.7),
                          ],
                        ),
                      ),
                      StatCard(
                        title: 'صافي الإيراد',
                        value: stats?.netRevenue.toStringAsFixed(2) ?? '0.00',
                        subtitle: 'ريال',
                        icon: Icons.trending_up,
                        color: AppColors.warningOrange,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.warningOrange,
                            AppColors.warningOrange.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ================= Chart =================
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(web ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'توزيع المبيعات',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: web ? 180 : 220,
                            child: stats == null
                                ? const Center(child: Text('لا توجد بيانات'))
                                : SfCircularChart(
                                    legend: Legend(
                                      isVisible: true,
                                      position: LegendPosition.bottom,
                                    ),
                                    series: <CircularSeries>[
                                      DoughnutSeries<
                                        Map<String, dynamic>,
                                        String
                                      >(
                                        dataSource: [
                                          {
                                            'type': 'نقدي',
                                            'value':
                                                stats.paymentBreakdown.cash,
                                            'color': AppColors.successGreen,
                                          },
                                          {
                                            'type': 'بطاقة',
                                            'value':
                                                stats.paymentBreakdown.card,
                                            'color': AppColors.infoBlue,
                                          },
                                          {
                                            'type': 'مدى',
                                            'value':
                                                stats.paymentBreakdown.mada,
                                            'color': AppColors.primaryBlue,
                                          },
                                          {
                                            'type': 'أخرى',
                                            'value':
                                                stats.paymentBreakdown.other,
                                            'color': AppColors.mediumGray,
                                          },
                                        ],
                                        xValueMapper: (d, _) => d['type'],
                                        yValueMapper: (d, _) => d['value'],
                                        pointColorMapper: (d, _) => d['color'],
                                        dataLabelSettings:
                                            const DataLabelSettings(
                                              isVisible: true,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ================= Actions =================
                  Text(
                    'إجراءات سريعة',
                    style: TextStyle(
                      fontSize: web ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: web ? 4 : 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: web ? 1.8 : 1.5,
                    children: [
                      SessionStatusCard(
                        title: 'فتح جلسة جديدة',
                        icon: Icons.play_circle_fill,
                        color: AppColors.successGreen,
                        onTap: () {
                          Navigator.pushNamed(context, '/sessions/open');
                        },
                      ),
                      SessionStatusCard(
                        title: 'إغلاق جلسة',
                        icon: Icons.stop_circle,
                        color: AppColors.errorRed,
                        onTap: () {},
                      ),
                      SessionStatusCard(
                        title: 'جرد يومي',
                        icon: Icons.inventory,
                        color: AppColors.infoBlue,
                        onTap: () {
                          Navigator.pushNamed(context, '/inventory/create');
                        },
                      ),
                      SessionStatusCard(
                        title: 'تقرير مفصل',
                        icon: Icons.assessment,
                        color: AppColors.warningOrange,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: web
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/sessions/open');
              },
              icon: const Icon(Icons.add),
              label: const Text('فتح جلسة جديدة'),
              backgroundColor: AppColors.primaryBlue,
            ),
    );
  }

  Widget _buildSummaryStatCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final bool web = isWeb(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(web ? 8 : 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: web ? 20 : 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: web ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: web ? 13 : 12,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
}
