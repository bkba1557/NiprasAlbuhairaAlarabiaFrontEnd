import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/stations/fuel_price_card.dart';
import 'package:order_tracker/widgets/stations/pump_card.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StationDetailsScreen extends StatefulWidget {
  final String stationId;

  const StationDetailsScreen({super.key, required this.stationId});

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  int _selectedTab = 0;
  DateTime _selectedDate = DateTime.now();
  TabController? _tabController;
  final ScrollController _pumpsScrollController = ScrollController();
  final ScrollController _fuelPricesScrollController = ScrollController();

  bool isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 1100;

  bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1100;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStationDetails();
    });
  }

  Future<void> _loadStationDetails() async {
    await Provider.of<StationProvider>(
      context,
      listen: false,
    ).fetchStationById(widget.stationId);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _pumpsScrollController.dispose();
    _fuelPricesScrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null) return;
    if (!controller.indexIsChanging) {
      setState(() {
        _selectedTab = controller.index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role == 'owner';
    final station = stationProvider.selectedStation;
    final sessions = stationProvider.sessions;

    final web = isWeb(context);

    if (stationProvider.isLoading && station == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (station == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المحطة')),
        body: const Center(child: Text('المحطة غير موجودة')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          if (_tabController != controller) {
            _tabController?.removeListener(_handleTabChange);
            _tabController = controller;
            _tabController?.addListener(_handleTabChange);
            _selectedTab = controller?.index ?? 0;
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                station.stationName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              actions: [
                // تسعيرة الوقود (عرض التسعيرة)
                IconButton(
                  tooltip: 'تسعيرة الوقود',
                  icon: const Icon(Icons.local_gas_station),
                  onPressed: () {
                    _showFuelPricingDialog(context, station);
                  },
                ),

                // تعديل بيانات المحطة
                IconButton(
                  tooltip: 'تعديل المحطة',
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/station/form',
                      arguments: station,
                    );
                  },
                ),

                // حذف المحطة (للمالك فقط)
                if (isOwner)
                  IconButton(
                    tooltip: 'حذف المحطة',
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('تأكيد الحذف'),
                          content: const Text(
                            'هل أنت متأكد من حذف المحطة؟ لا يمكن التراجع عن هذا الإجراء.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.errorRed,
                              ),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      final success = await stationProvider.deleteStation(
                        station.id,
                      );

                      if (!mounted) return;

                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حذف المحطة بنجاح'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              stationProvider.error ?? 'فشل حذف المحطة',
                            ),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                      }
                    },
                  ),

                // اختيار التاريخ
                IconButton(
                  tooltip: 'اختيار التاريخ',
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                onTap: (index) {
                  _tabController?.animateTo(index);
                },

                // ✅ لون الخط تحت التاب (المؤشر)
                indicatorColor: Colors.red,
                indicatorWeight: 3,

                // ✅ لون التاب المختار
                labelColor: Colors.red,

                // ✅ لون التابات غير المختارة
                unselectedLabelColor: Colors.red.withOpacity(0.6),

                // (اختياري) شكل الخط
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),

                tabs: const [
                  Tab(text: 'نظرة عامة'),
                  Tab(text: 'المضخات'),
                  Tab(text: 'جلسات اليوم'),
                ],
              ),

            ),

            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: TabBarView(
                  children: [
                    _buildOverviewTab(station),
                    _buildPumpsTab(station),
                    _buildSessionsTab(sessions),
                  ],
                ),
              ),
            ),
            floatingActionButton: _selectedTab == 1 && !web
                ? FloatingActionButton(
                    onPressed: () {
                      _showAddPumpDialog(context, station);
                    },
                    child: const Icon(Icons.add),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(Station station) {
    final double w = MediaQuery.of(context).size.width;
    final bool web = w >= 1100;
    final bool tablet = w >= 700 && w < 1100;

    // عرض مناسب للكروت على الويب (مايبقاش عريض زيادة)
    final double maxWidth = web ? 1100 : double.infinity;

    // مقاسات موحّدة
    final double outerPadding = web ? 12 : 16;
    final double cardPadding = web ? 16 : 20;
    final double titleSize = web ? 15 : 16;
    final double headerSize = web ? 18 : 20;
    final double gap = web ? 12 : 16;

    Widget sectionCard({
      required String title,
      required Widget child,
      double? titleFont,
    }) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFont ?? titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: web ? 10 : 15),
              child,
            ],
          ),
        ),
      );
    }

    // ================= Station Info Content =================

    final stationInfo = sectionCard(
      title: 'معلومات المحطة',
      titleFont: headerSize,
      child: web
          // ================= WEB: Grid =================
          ? GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // عمودين
                crossAxisSpacing: 20,
                mainAxisSpacing: 11,
                childAspectRatio: 7.2, // 👈 يطوّل الكارت ويقلل العرض
              ),
              children: [
                _buildInfoRow('كود المحطة', station.stationCode),
                _buildInfoRow('اسم المحطة', station.stationName),
                _buildInfoRow(
                  'الموقع',
                  '${station.city} - ${station.location}',
                ),
                _buildInfoRow('اسم المدير', station.managerName),
                _buildInfoRow('هاتف المدير', station.managerPhone),
                _buildInfoRow(
                  'تاريخ الإنشاء',
                  DateFormat('yyyy/MM/dd').format(station.createdAt),
                ),
                _buildInfoRow(
                  'الحالة',
                  station.isActive ? 'نشطة' : 'غير نشطة',
                  valueColor: station.isActive
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                ),
              ],
            )
        
        
          // ================= MOBILE / TABLET: Column =================
          : Column(
              children: [
                _buildInfoRow('كود المحطة', station.stationCode),
                _buildInfoRow('اسم المحطة', station.stationName),
                _buildInfoRow(
                  'الموقع',
                  '${station.city} - ${station.location}',
                ),
                _buildInfoRow('اسم المدير', station.managerName),
                _buildInfoRow('هاتف المدير', station.managerPhone),
                _buildInfoRow(
                  'تاريخ الإنشاء',
                  DateFormat('yyyy/MM/dd').format(station.createdAt),
                ),
                _buildInfoRow(
                  'الحالة',
                  station.isActive ? 'نشطة' : 'غير نشطة',
                  valueColor: station.isActive
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                ),
              ],
            ),
    );

    // ================= Fuel Types Content =================
    final fuelTypes = sectionCard(
      title: 'أنواع الوقود المتاحة',
      child: Wrap(
        spacing: web ? 8 : 10,
        runSpacing: web ? 8 : 10,
        children: station.fuelTypes.map((fuelType) {
          return Chip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.symmetric(
              horizontal: web ? 8 : 10,
              vertical: web ? 0 : 2,
            ),
            label: Text(
              fuelType,
              style: TextStyle(
                fontSize: web ? 12 : 14,
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.primaryBlue.withOpacity(0.10),
          );
        }).toList(),
      ),
    );

    // ================= Pumps Summary Content =================
final pumpsSummary = SizedBox(
      height: web ? 280 : 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// العنوان + العدد (ثابت)
              Row(
                children: [
                  const Text(
                    'المضخات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Chip(label: Text('${station.pumps.length}')),
                ],
              ),

              const SizedBox(height: 10),

              /// 🔴 ده كان سبب المشكلة
              /// ✅ لازم Expanded
              Expanded(
                child: station.pumps.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد المضخات',
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      )
              : Scrollbar(
                  thumbVisibility: true,
                  controller: _pumpsScrollController,
                  child: ListView.separated(
                    controller: _pumpsScrollController,
                    primary: false,
                    physics: const BouncingScrollPhysics(),
                          itemCount: station.pumps.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            return PumpCard(pump: station.pumps[index]);
                          },
                        ),
                      ),
              ),

              /// زر (ثابت)
              if (station.pumps.length > 3)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () {
                      _tabController?.animateTo(1);
                    },
                    child: const Text('عرض جميع المضخات'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );


    // ================= Fuel Prices Content =================
    final fuelPrices = sectionCard(
      title: 'أسعار الوقود',
      child: station.fuelPrices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لا توجد أسعار',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
            )
          : SizedBox(
              height: 220, // 👈 ارتفاع ثابت للكارت
            child: Scrollbar(
              thumbVisibility: true,
              controller: _fuelPricesScrollController,
              child: ListView.separated(
                controller: _fuelPricesScrollController,
                primary: false,
                itemCount: station.fuelPrices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return FuelPriceCard(price: station.fuelPrices[index]);
                  },
                ),
              ),
            ),
    );

    final statistics = sectionCard(
      title: 'إحصائيات اليوم',
      child: SizedBox(
        height: web ? 190 : 230,
        child: SfCircularChart(
          legend: Legend(
            isVisible: true,
            position: LegendPosition.bottom,
            textStyle: TextStyle(fontFamily: 'Cairo', fontSize: web ? 11 : 12),
          ),
          series: <CircularSeries>[
            DoughnutSeries<Map<String, dynamic>, String>(
              dataSource: const [
                {
                  'type': 'بنزين 91',
                  'value': 45,
                  'color': AppColors.primaryBlue,
                },
                {'type': 'بنزين 95', 'value': 30, 'color': AppColors.infoBlue},
                {'type': 'ديزل', 'value': 20, 'color': AppColors.warningOrange},
                {'type': 'كيروسين', 'value': 5, 'color': AppColors.mediumGray},
              ],
              xValueMapper: (data, _) => data['type'],
              yValueMapper: (data, _) => data['value'],
              pointColorMapper: (data, _) => data['color'],
              dataLabelSettings: DataLabelSettings(
                isVisible: true,
                labelPosition: ChartDataLabelPosition.outside,
                textStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: web ? 10 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(outerPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (web || tablet) ...[
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: web ? 2 : 1,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    childAspectRatio: web ? 2.2 : 1.6,
                  ),
                  children: [stationInfo, fuelTypes],
                ),
                SizedBox(height: gap),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: web ? 2 : 1,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    childAspectRatio: web ? 1.7 : 1.35,
                  ),
                  children: [pumpsSummary, fuelPrices],
                ),
                SizedBox(height: gap),
                statistics,
              ] else ...[
                stationInfo,
                SizedBox(height: gap),
                fuelTypes,
                SizedBox(height: gap),
                pumpsSummary,
                SizedBox(height: gap),
                if (station.fuelPrices.isNotEmpty) fuelPrices,
                SizedBox(height: gap),
                statistics,
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }




  void _showAddPumpDialog(BuildContext rootContext, Station station) {
    final TextEditingController pumpNumberController = TextEditingController();
    final stationProvider = Provider.of<StationProvider>(
      rootContext,
      listen: false,
    );
    final bool web = isWeb(rootContext);
    final List<NozzleData> nozzlesData = [NozzleData(position: 'يمين')];
    bool isActive = true;
    bool isSubmitting = false;

    showDialog(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void addNozzle() {
              nozzlesData.add(NozzleData(position: 'يمين'));
              setState(() {});
            }

            void removeNozzle(int index) {
              nozzlesData.removeAt(index);
              setState(() {});
            }

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: web ? 400 : 24,
                vertical: 24,
              ),
              title: const Text(
                'Add pump',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: web ? 420 : double.infinity,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pumpNumberController,
                        decoration: InputDecoration(
                          labelText: 'Pump number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.primaryBlue.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nozzles',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: addNozzle,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (nozzlesData.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.mediumGray.withOpacity(0.3),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'No nozzles yet',
                              style: TextStyle(color: AppColors.mediumGray),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: List.generate(nozzlesData.length, (index) {
                            final nozzle = nozzlesData[index];
                            final bool isLast = index == nozzlesData.length - 1;
                            return Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGray.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.mediumGray.withOpacity(
                                      0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Nozzle ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: AppColors.errorRed,
                                            size: 20,
                                          ),
                                          onPressed: () => removeNozzle(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.infoBlue.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.lightGray,
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: nozzle.position.isNotEmpty
                                            ? nozzle.position
                                            : null,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        hint: const Text('Position'),
                                        items: const [
                                          DropdownMenuItem<String>(
                                            value: 'يمين',
                                            child: Text('يمين'),
                                          ),
                                          DropdownMenuItem<String>(
                                            value: 'يسار',
                                            child: Text('يسار'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            nozzle.position = value ?? '';
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.infoBlue.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.lightGray,
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: nozzle.fuelType.isNotEmpty
                                            ? nozzle.fuelType
                                            : null,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        hint: const Text('Fuel type'),
                                        items: station.fuelTypes.map((
                                          fuelType,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: fuelType,
                                            child: Text(fuelType),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            nozzle.fuelType = value ?? '';
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Checkbox(
                            value: isActive,
                            onChanged: (value) {
                              setState(() {
                                isActive = value ?? true;
                              });
                            },
                          ),
                          const Text(
                            'Active',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (pumpNumberController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter pump number'),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                            return;
                          }
                          if (nozzlesData.isEmpty) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text('Add at least one nozzle'),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                            return;
                          }
                          for (int i = 0; i < nozzlesData.length; i++) {
                            final nozzle = nozzlesData[i];
                            if (nozzle.position.isEmpty ||
                                nozzle.fuelType.isEmpty) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Complete nozzle ${i + 1} details',
                                  ),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                              return;
                            }
                          }

                          setState(() {
                            isSubmitting = true;
                          });

                          final nozzlePayload = nozzlesData.asMap().entries.map(
                            (entry) {
                              final position = entry.value.position;
                              final side = position == 'يسار'
                                  ? 'left'
                                  : 'right';
                              return {
                                'nozzleNumber': entry.key + 1,
                                'side': side,
                                'fuelType': entry.value.fuelType,
                                'isActive': true,
                              };
                            },
                          ).toList();

                          final fuelTypeCount = <String, int>{};
                          for (final nozzle in nozzlePayload) {
                            final fuelType =
                                nozzle['fuelType'] as String? ?? '';
                            if (fuelType.isEmpty) continue;
                            fuelTypeCount[fuelType] =
                                (fuelTypeCount[fuelType] ?? 0) + 1;
                          }

                          final mainFuelType = fuelTypeCount.isNotEmpty
                              ? fuelTypeCount.entries
                                    .reduce(
                                      (a, b) => a.value >= b.value ? a : b,
                                    )
                                    .key
                              : station.fuelTypes.isNotEmpty
                              ? station.fuelTypes.first
                              : '';

                          final pumpPayload = {
                            'pumpNumber': pumpNumberController.text.trim(),
                            'fuelType': mainFuelType,
                            'nozzleCount': nozzlePayload.length,
                            'isActive': isActive,
                            'createdAt': DateTime.now().toIso8601String(),
                            'nozzles': nozzlePayload,
                          };

                          final success = await stationProvider.addPump(
                            station.id,
                            pumpPayload,
                          );

                          if (!dialogContext.mounted || !mounted) {
                            return;
                          }

                          setState(() {
                            isSubmitting = false;
                          });

                          if (success) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text('Pump added successfully'),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  stationProvider.error ?? 'Failed to add pump',
                                ),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add pump'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPumpsTab(Station station) {
    final bool web = isWeb(context);

    return RefreshIndicator(
      onRefresh: _loadStationDetails,
      child: ListView(
        padding: EdgeInsets.all(web ? 20 : 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Text(
                'Pumps',
                style: TextStyle(
                  fontSize: web ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  '${station.pumps.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (web)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add pump'),
                onPressed: () => _showAddPumpDialog(context, station),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
              ),
            ),
          if (web) const SizedBox(height: 12),
          if (station.pumps.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: web ? 40 : 80),
              child: const Center(
                child: Text(
                  'No pumps yet',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
            )
          else
            ...station.pumps.map((pump) {
              return PumpCard(
                pump: pump,
                onTap: () => _showPumpActionsDialog(context, station.id, pump),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(List<PumpSession> sessions) {
    final bool web = MediaQuery.of(context).size.width >= 1100;
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final todaySessions = sessions.where((session) {
      final sessionDay = DateTime(
        session.sessionDate.year,
        session.sessionDate.month,
        session.sessionDate.day,
      );
      return sessionDay == selectedDay;
    }).toList();

    final openSessions = todaySessions
        .where((session) => session.status == 'مفتوحة')
        .toList();
    final closedSessions = todaySessions
        .where((session) => session.status == 'مغلقة')
        .toList();
    final approvedSessions = todaySessions
        .where((session) => session.status == 'معتمدة')
        .toList();

    Widget sectionHeader(String title, Color color, int count) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: web ? 15 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Chip(
            label: Text('$count', style: TextStyle(fontSize: web ? 11 : 12)),
          ),
        ],
      );
    }

    Widget buildSessionList(List<PumpSession> list) {
      if (list.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'لا توجد جلسات لعرضها',
            style: TextStyle(color: AppColors.mediumGray),
          ),
        );
      }

      return Column(
        children: list.map((session) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text('${session.pumpNumber} · ${session.shiftType}'),
              subtitle: Text(
                '${session.openingEmployeeName ?? ''} · ${DateFormat('HH:mm').format(session.openingTime)}',
              ),
              trailing: Text(
                session.status,
                style: TextStyle(
                  color: session.status == 'مفتوحة'
                      ? AppColors.warningOrange
                      : session.status == 'مغلقة'
                      ? AppColors.primaryBlue
                      : AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }



    return RefreshIndicator(
      onRefresh: _loadStationDetails,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(web ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'الجلسات المفتوحة',
              AppColors.warningOrange,
              openSessions.length,
            ),
            const SizedBox(height: 8),
            buildSessionList(openSessions),
            const SizedBox(height: 20),
            sectionHeader(
              'الجلسات المغلقة',
              AppColors.primaryBlue,
              closedSessions.length,
            ),
            const SizedBox(height: 8),
            buildSessionList(closedSessions),
            const SizedBox(height: 20),
            sectionHeader(
              'الجلسات المعتمدة',
              AppColors.successGreen,
              approvedSessions.length,
            ),
            const SizedBox(height: 8),
            buildSessionList(approvedSessions),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: web ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: web ? 110 : 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mediumGray,
                fontSize: web ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: web ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? AppColors.darkGray,
                fontSize: web ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPumpActionsDialog(
    BuildContext context,
    String stationId,
    Pump pump,
  ) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    // ================= WEB → Dialog =================
    if (web) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 400,
            vertical: 24,
          ),
          title: const Text(
            'إجراءات المضخات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionTile(
                icon: Icons.edit,
                iconColor: AppColors.primaryBlue,
                title: 'تعديل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showEditPumpDialog(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: pump.isActive ? Icons.pause_circle : Icons.play_circle,
                iconColor: pump.isActive
                    ? AppColors.warningOrange
                    : AppColors.successGreen,
                title: pump.isActive ? 'تعطيل المضخات' : 'تفعيل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _togglePumpStatus(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: Icons.delete,
                iconColor: AppColors.errorRed,
                title: 'حذف المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showDeletePumpDialog(context, stationId, pump.id);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    // ================= MOBILE → BottomSheet =================
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionTile(
                icon: Icons.edit,
                iconColor: AppColors.primaryBlue,
                title: 'تعديل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showEditPumpDialog(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: pump.isActive ? Icons.pause_circle : Icons.play_circle,
                iconColor: pump.isActive
                    ? AppColors.warningOrange
                    : AppColors.successGreen,
                title: pump.isActive ? 'تعطيل المضخات' : 'تفعيل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _togglePumpStatus(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: Icons.delete,
                iconColor: AppColors.errorRed,
                title: 'حذف المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showDeletePumpDialog(context, stationId, pump.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

void _showEditPumpDialog(BuildContext context, String stationId, Pump pump) {
    final TextEditingController pumpNumberController = TextEditingController(
      text: pump.pumpNumber,
    );

    List<NozzleData> nozzlesData = pump.nozzles
        .map((n) => NozzleData(position: n.position, fuelType: n.fuelType))
        .toList();

    bool isActive = pump.isActive;
    final bool web = MediaQuery.of(context).size.width >= 1100;

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final station = stationProvider.selectedStation;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void addNozzle() {
              setState(() {
                nozzlesData.add(NozzleData());
              });
            }

            void removeNozzle(int index) {
              setState(() {
                nozzlesData.removeAt(index);
              });
            }

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: web ? 400 : 24,
                vertical: 24,
              ),
              title: const Text(
                'تعديل المضخات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75, // ✅ مهم
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// رقم المضخات
                      TextField(
                        controller: pumpNumberController,
                        decoration: InputDecoration(
                          labelText: 'رقم المضخات',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.primaryBlue.withOpacity(0.05),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// عنوان الليات
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الليات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: addNozzle,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة لي'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// ✅ قائمة الليات (قابلة للتمرير)
                      SizedBox(
                        height: 300,
                        child: nozzlesData.isEmpty
                            ? const Center(
                                child: Text(
                                  'لم يتم إضافة أي لي بعد',
                                  style: TextStyle(color: AppColors.mediumGray),
                                ),
                              )
                            : ListView.separated(
                                itemCount: nozzlesData.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final nozzle = nozzlesData[index];
                                  return _buildNozzleEditor(
                                    context,
                                    index,
                                    nozzle,
                                    station?.fuelTypes ?? [],
                                    () => removeNozzle(index),
                                    setState,
                                  );
                                },
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                              ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Checkbox(
                            value: isActive,
                            onChanged: (v) =>
                                setState(() => isActive = v ?? true),
                          ),
                          const Text('نشطة'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  child: const Text('حفظ'),
                  onPressed: () async {
                    if (pumpNumberController.text.trim().isEmpty ||
                        nozzlesData.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى استكمال البيانات'),
                          backgroundColor: AppColors.errorRed,
                        ),
                      );
                      return;
                    }

                    final updatedPump = Pump(
                      id: pump.id,
                      pumpNumber: pumpNumberController.text.trim(),
                      fuelType: pump.fuelType,
                      nozzleCount: nozzlesData.length,
                      isActive: isActive,
                      createdAt: pump.createdAt,
                      nozzles: nozzlesData.map((d) {
                        return Nozzle(
                          id: '',
                          nozzleNumber: '${nozzlesData.indexOf(d) + 1}',
                          position: d.position,
                          fuelType: d.fuelType,
                          isActive: true,
                          currentReading: 0,
                          createdAt: DateTime.now(),
                        );
                      }).toList(),
                    );

                    final success = await stationProvider.updatePump(
                      stationId,
                      updatedPump,
                    );

                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'تم تحديث المضخات بنجاح'
                              : 'فشل تحديث المضخات',
                        ),
                        backgroundColor: success
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNozzleEditor(
    BuildContext context,
    int index,
    NozzleData nozzle,
    List<String> fuelTypes,
    VoidCallback onRemove,
    void Function(void Function()) setState,
  ) {
    final fuelOptions = fuelTypes.toSet().toList();
    final selectedFuelType =
        fuelOptions.contains(nozzle.fuelType) ? nozzle.fuelType : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mediumGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// عنوان اللي + حذف
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'اللي ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: AppColors.errorRed,
                  size: 20,
                ),
                onPressed: onRemove,
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// موقع اللي (يمين / يسار)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: DropdownButton<String>(
              value: nozzle.position.isNotEmpty ? nozzle.position : null,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('موقع اللي'),
              items: const [
                DropdownMenuItem(value: 'يمين', child: Text('يمين')),
                DropdownMenuItem(value: 'يسار', child: Text('يسار')),
              ],
              onChanged: (value) {
                setState(() {
                  nozzle.position = value ?? '';
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          /// نوع الوقود
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: DropdownButton<String>(
              value: selectedFuelType,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('نوع الوقود'),
              items: fuelOptions.map((fuel) {
                return DropdownMenuItem(value: fuel, child: Text(fuel));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  nozzle.fuelType = value ?? '';
                });
              },
            ),
          ),
        ],
      ),
    );
  }




  void _togglePumpStatus(BuildContext context, String stationId, Pump pump) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: web ? 420 : 24,
          vertical: 24,
        ),
        title: Row(
          children: [
            Icon(
              pump.isActive ? Icons.pause_circle : Icons.play_circle,
              color: pump.isActive
                  ? AppColors.warningOrange
                  : AppColors.successGreen,
            ),
            const SizedBox(width: 8),
            Text(
              pump.isActive ? 'تعطيل المضخات' : 'تفعيل المضخات',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: web ? 420 : double.infinity),
          child: Text(
            pump.isActive
                ? 'هل تريد تعطيل المضخات رقم ${pump.pumpNumber}؟'
                : 'هل تريد تفعيل المضخات رقم ${pump.pumpNumber}؟',
            style: const TextStyle(fontSize: 15),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pump.isActive
                  ? AppColors.warningOrange
                  : AppColors.successGreen,
            ),
            onPressed: () async {
              final stationProvider = Provider.of<StationProvider>(
                context,
                listen: false,
              );

              // 🔧 مكان تنفيذ منطق التفعيل / التعطيل الحقيقي
              final success = await stationProvider.togglePumpStatus(
                stationId,
                pump.id,
                !pump.isActive,
              );

              if (!mounted) return;

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      pump.isActive
                          ? 'تم تعطيل المضخات بنجاح'
                          : 'تم تفعيل المضخات بنجاح',
                    ),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      stationProvider.error ?? 'فشل تغيير حالة المضخات',
                    ),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showDeletePumpDialog(
    BuildContext context,
    String stationId,
    String pumpId,
  ) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: web ? 420 : 24,
          vertical: 24,
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_forever, color: AppColors.errorRed),
            SizedBox(width: 8),
            Text('حذف المضخات', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: web ? 420 : double.infinity),
          child: const Text(
            'هل أنت متأكد من حذف هذه المضخات؟\n'
            'لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(fontSize: 15),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () async {
              final stationProvider = Provider.of<StationProvider>(
                context,
                listen: false,
              );

              // 🔧 هنا مكان تنفيذ منطق الحذف الحقيقي
              final success = await stationProvider.deletePump(
                stationId,
                pumpId,
              );

              if (!mounted) return;

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف المضخات بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(stationProvider.error ?? 'فشل حذف المضخات'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showFuelPricingDialog(BuildContext context, Station station) {
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    /// Controllers لكل نوع وقود
    final Map<String, TextEditingController> controllers = {
      for (final fuel in station.fuelTypes)
        fuel: TextEditingController(
          text: station.fuelPrices
              .firstWhere(
                (p) => p.fuelType == fuel,
                orElse: () => FuelPrice(
                  id: '',
                  fuelType: fuel,
                  price: 0,
                  effectiveDate: DateTime.now(),
                ),
              )
              .price
              .toString(),
        ),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تسعيرة الوقود للمحطة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: station.fuelTypes.map((fuelType) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        fuelType,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: controllers[fuelType],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'السعر',
                          suffixText: 'ريال',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            child: const Text('حفظ التسعيرة'),
            onPressed: () async {
              /// تجهيز البيانات للإرسال
              final List<Map<String, dynamic>> prices = [];

              for (final fuelType in station.fuelTypes) {
                final price = double.tryParse(
                  controllers[fuelType]!.text.trim(),
                );

                if (price != null && price > 0) {
                  prices.add({'fuelType': fuelType, 'price': price});
                }
              }

              if (prices.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال سعر واحد على الأقل'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
                return;
              }

              final success = await stationProvider.updateFuelPrices(
                station.id,
                prices,
              );

              if (!mounted) return;

              if (success) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث تسعيرة الوقود بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// نموذج بيانات اللي المؤقت
class NozzleData {
  String position;
  String fuelType;

  NozzleData({this.position = 'يمين', this.fuelType = ''});
}
