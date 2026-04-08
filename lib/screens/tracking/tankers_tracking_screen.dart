import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:order_tracker/models/tanker_model.dart';
import 'package:order_tracker/models/vehicle_model.dart';
import 'package:order_tracker/providers/tanker_provider.dart';
import 'package:order_tracker/providers/vehicle_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/tracking/tracking_page_shell.dart';
import 'package:provider/provider.dart';

class TankersTrackingScreen extends StatefulWidget {
  const TankersTrackingScreen({super.key});

  @override
  State<TankersTrackingScreen> createState() => _TankersTrackingScreenState();
}

class _TankersTrackingScreenState extends State<TankersTrackingScreen> {
  static const List<String> _statuses = [
    'تحت الصيانة',
    'في طلب',
    'فاضي',
    'شغال',
    'متوقف',
  ];
  static const List<String> _fuelTypes = ['بنزين', 'ديزل', 'كيروسين'];

  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TankerProvider>().fetchTankers();
      context.read<VehicleProvider>().fetchVehicles();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;
      await context.read<TankerProvider>().fetchTankers(silent: true);
      if (!mounted) return;
      await context.read<VehicleProvider>().fetchVehicles(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.trim()) {
      case 'تحت الصيانة':
        return AppColors.pendingYellow;
      case 'في طلب':
        return AppColors.statusGold;
      case 'فاضي':
        return AppColors.successGreen;
      case 'شغال':
        return AppColors.infoBlue;
      case 'متوقف':
        return AppColors.errorRed;
      default:
        return Colors.grey;
    }
  }

  String _vehicleLabel(Tanker tanker) {
    final vehicleNumber = tanker.linkedVehicleNumber?.trim() ?? '';
    final driverName = tanker.linkedDriverName?.trim() ?? '';
    if (vehicleNumber.isNotEmpty && driverName.isNotEmpty) {
      return '$vehicleNumber • $driverName';
    }
    if (vehicleNumber.isNotEmpty) return vehicleNumber;
    if (driverName.isNotEmpty) return driverName;
    return 'غير مرتبط بسيارة';
  }

  String _capacityLabel(Tanker tanker) {
    final capacity = tanker.capacityLiters;
    if (capacity == null || capacity <= 0) return 'غير محدد';
    return '$capacity لتر';
  }

  String? _normalizedDigits(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  List<Vehicle> _vehicleOptions(List<Vehicle> vehicles, {Tanker? tanker}) {
    final items = vehicles.toList()
      ..sort((a, b) => a.plateNumber.compareTo(b.plateNumber));
    final linkedVehicleId = tanker?.linkedVehicleId?.trim() ?? '';
    if (linkedVehicleId.isEmpty ||
        items.any((vehicle) => vehicle.id == linkedVehicleId)) {
      return items;
    }
    if ((tanker?.linkedVehicleNumber ?? '').trim().isNotEmpty) {
      items.insert(
        0,
        Vehicle(
          id: linkedVehicleId,
          plateNumber: tanker!.linkedVehicleNumber!.trim(),
          vehicleType: tanker.linkedVehicleType?.trim().isNotEmpty == true
              ? tanker.linkedVehicleType!.trim()
              : 'غير محدد',
          status: 'فاضي',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    return items;
  }

  String _vehicleOptionLabel(Vehicle vehicle) {
    final parts = <String>[vehicle.plateNumber];
    if (vehicle.linkedDriver?.name.trim().isNotEmpty == true) {
      parts.add(vehicle.linkedDriver!.name.trim());
    }
    return parts.join(' • ');
  }

  Vehicle? _findVehicleById(List<Vehicle> vehicles, String? vehicleId) {
    if (vehicleId == null || vehicleId.trim().isEmpty) return null;
    for (final vehicle in vehicles) {
      if (vehicle.id == vehicleId) return vehicle;
    }
    return null;
  }

  List<Tanker> _applySearch(List<Tanker> tankers) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return tankers;
    return tankers.where((tanker) {
      return tanker.number.toLowerCase().contains(query) ||
          tanker.status.toLowerCase().contains(query) ||
          (tanker.notes ?? '').toLowerCase().contains(query) ||
          (tanker.linkedVehicleNumber ?? '').toLowerCase().contains(query) ||
          (tanker.linkedDriverName ?? '').toLowerCase().contains(query) ||
          (tanker.fuelType ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showTankerForm({Tanker? tanker}) async {
    final tankerProvider = context.read<TankerProvider>();
    final vehicleProvider = context.read<VehicleProvider>();
    if (vehicleProvider.vehicles.isEmpty && !vehicleProvider.isLoading) {
      await vehicleProvider.fetchVehicles();
    }
    if (!mounted) return;

    final vehicles = _vehicleOptions(vehicleProvider.vehicles, tanker: tanker);
    final numberController = TextEditingController(text: tanker?.number ?? '');
    final capacityController = TextEditingController(
      text: tanker?.capacityLiters?.toString() ?? '',
    );
    final notesController = TextEditingController(text: tanker?.notes ?? '');
    final aramcoUnifiedStickerController = TextEditingController(
      text: tanker?.aramcoUnifiedSticker ?? '',
    );
    final aramcoHeadStickerController = TextEditingController(
      text: tanker?.aramcoHeadSticker ?? '',
    );
    final aramcoTankerStickerController = TextEditingController(
      text: tanker?.aramcoTankerSticker ?? '',
    );

    DateTime? aramcoUnifiedStickerExpiryDate =
        tanker?.aramcoUnifiedStickerExpiryDate;
    DateTime? aramcoHeadStickerExpiryDate = tanker?.aramcoHeadStickerExpiryDate;
    DateTime? aramcoTankerStickerExpiryDate =
        tanker?.aramcoTankerStickerExpiryDate;

    String status =
        _statuses.contains(tanker?.status) ? tanker!.status : 'فاضي';
    String? linkedVehicleId = tanker?.linkedVehicleId?.trim().isNotEmpty == true
        ? tanker!.linkedVehicleId!.trim()
        : null;
    String? fuelType =
        _fuelTypes.contains(tanker?.fuelType) ? tanker!.fuelType : null;

    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String formatDate(DateTime? value) {
              if (value == null) return 'غير محدد';
              final local = value.toLocal();
              final iso = local.toIso8601String();
              return iso.contains('T') ? iso.split('T').first : iso;
            }

            Future<void> pickDate(
              DateTime? currentValue,
              ValueChanged<DateTime?> onChanged,
            ) async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: currentValue ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
              );
              if (picked == null) return;
              setDialogState(() {
                onChanged(picked);
              });
            }

            Widget buildDateField({
              required String label,
              required DateTime? value,
              required IconData icon,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: Icon(icon),
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(formatDate(value)),
                ),
              );
            }

            final hasUnifiedSticker =
                _normalizedDigits(aramcoUnifiedStickerController.text) != null;
            final hasSeparateStickers =
                _normalizedDigits(aramcoHeadStickerController.text) != null &&
                _normalizedDigits(aramcoTankerStickerController.text) != null;

            return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(tanker == null ? 'إضافة صهريج' : 'تعديل الصهريج'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: numberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الصهريج / اللوحة',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرقم مطلوب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: linkedVehicleId != null &&
                              vehicles.any((item) => item.id == linkedVehicleId)
                          ? linkedVehicleId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'السيارة المرتبطة',
                        prefixIcon: const Icon(
                          Icons.directions_car_filled_outlined,
                        ),
                        helperText: vehicles.isEmpty
                            ? 'لا توجد سيارات مسجلة حاليًا'
                            : 'اختر السيارة التي يعمل معها هذا الصهريج',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('بدون ربط حاليًا'),
                        ),
                        ...vehicles.map(
                          (vehicle) => DropdownMenuItem<String?>(
                            value: vehicle.id,
                            child: Text(
                              _vehicleOptionLabel(vehicle),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          linkedVehicleId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'سعة الصهريج باللتر',
                        prefixIcon: Icon(Icons.local_gas_station_outlined),
                      ),
                      validator: (value) {
                        final capacity = int.tryParse(value?.trim() ?? '');
                        if (capacity == null || capacity <= 0) {
                          return 'أدخل سعة صحيحة باللتر';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: fuelType,
                      decoration: const InputDecoration(
                        labelText: 'نوع الوقود',
                        prefixIcon: Icon(Icons.opacity_outlined),
                      ),
                      items: _fuelTypes
                          .map(
                            (item) => DropdownMenuItem<String?>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          fuelType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'اختر نوع الوقود';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _statuses.contains(status) ? status : 'فاضي',
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: _statuses
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          status = value ?? 'فاضي';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: aramcoUnifiedStickerController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'استيكر أرامكو موحد',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (hasUnifiedSticker) ...[
                      buildDateField(
                        label: 'انتهاء استيكر أرامكو (موحد)',
                        value: aramcoUnifiedStickerExpiryDate,
                        icon: Icons.event_outlined,
                        onTap: () => pickDate(
                          aramcoUnifiedStickerExpiryDate,
                          (value) => aramcoUnifiedStickerExpiryDate = value,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: aramcoHeadStickerController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'استيكر الرأس',
                              prefixIcon: Icon(
                                Icons.directions_car_filled_outlined,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: aramcoTankerStickerController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'استيكر الصهريج',
                              prefixIcon: Icon(Icons.local_shipping_outlined),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasSeparateStickers) ...[
                      Row(
                        children: [
                          Expanded(
                            child: buildDateField(
                              label: 'انتهاء استيكر الرأس',
                              value: aramcoHeadStickerExpiryDate,
                              icon: Icons.event_outlined,
                              onTap: () => pickDate(
                                aramcoHeadStickerExpiryDate,
                                (value) =>
                                    aramcoHeadStickerExpiryDate = value,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildDateField(
                              label: 'انتهاء استيكر الصهريج',
                              value: aramcoTankerStickerExpiryDate,
                              icon: Icons.event_outlined,
                              onTap: () => pickDate(
                                aramcoTankerStickerExpiryDate,
                                (value) =>
                                    aramcoTankerStickerExpiryDate = value,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: tankerProvider.isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final linkedVehicle = _findVehicleById(
                        vehicles,
                        linkedVehicleId,
                      );
                      final payload = Tanker(
                        id: tanker?.id ?? '',
                        number: numberController.text.trim(),
                        status: status,
                        capacityLiters: int.parse(capacityController.text.trim()),
                        fuelType: fuelType,
                        linkedVehicleId: linkedVehicleId,
                        linkedVehicleNumber: linkedVehicle?.plateNumber,
                        linkedVehicleType: linkedVehicle?.vehicleType,
                        linkedDriverId: linkedVehicle?.linkedDriverId,
                        linkedDriverName: linkedVehicle?.linkedDriver?.name,
                        aramcoStickerMode: _normalizedDigits(
                                  aramcoUnifiedStickerController.text,
                                ) !=
                                null
                            ? 'موحد'
                            : (_normalizedDigits(aramcoHeadStickerController.text) !=
                                        null &&
                                    _normalizedDigits(
                                          aramcoTankerStickerController.text,
                                        ) !=
                                        null)
                                ? 'منفصل'
                                : null,
                        aramcoUnifiedSticker:
                            _normalizedDigits(aramcoUnifiedStickerController.text),
                        aramcoUnifiedStickerExpiryDate:
                            aramcoUnifiedStickerExpiryDate,
                        aramcoHeadSticker:
                            _normalizedDigits(aramcoHeadStickerController.text),
                        aramcoHeadStickerExpiryDate: aramcoHeadStickerExpiryDate,
                        aramcoTankerSticker:
                            _normalizedDigits(aramcoTankerStickerController.text),
                        aramcoTankerStickerExpiryDate:
                            aramcoTankerStickerExpiryDate,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                        createdAt: tanker?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      final ok = tanker == null
                          ? await tankerProvider.createTanker(payload)
                          : await tankerProvider.updateTanker(tanker.id, payload);
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext, ok);
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ'),
            ),
          ],
            );
          },
        );
      },
    );

    numberController.dispose();
    capacityController.dispose();
    notesController.dispose();
    aramcoUnifiedStickerController.dispose();
    aramcoHeadStickerController.dispose();
    aramcoTankerStickerController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tanker == null ? 'تمت الإضافة' : 'تم التحديث'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await context.read<TankerProvider>().fetchTankers();
      await context.read<VehicleProvider>().fetchVehicles(silent: true);
    } else if (result == false && mounted && tankerProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tankerProvider.error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Tanker tanker) async {
    final provider = context.read<TankerProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('حذف الصهريج'),
          content: Text('هل أنت متأكد من حذف الصهريج ${tanker.number}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final success = await provider.deleteTanker(tanker.id);
    if (!mounted) return;
    if (success) {
      await context.read<VehicleProvider>().fetchVehicles(silent: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'تم الحذف' : (provider.error ?? 'فشل الحذف')),
        backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TankerProvider>(
      builder: (context, provider, _) {
        final allTankers = provider.tankers;
        final items = _applySearch(allTankers);
        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchTankers();
            if (!mounted) return;
            await context.read<VehicleProvider>().fetchVehicles(silent: true);
          },
          child: TrackingPageShell(
            icon: Icons.local_shipping_rounded,
            title: 'متابعة الصهاريج',
            subtitle:
                'مراجعة الصهاريج، حالتها التشغيلية، وربطها بالسيارات من شاشة واحدة.',
            metrics: [
              TrackingMetric(
                label: 'إجمالي الصهاريج',
                value: '${allTankers.length}',
                icon: Icons.local_shipping_outlined,
                color: AppColors.primaryBlue,
              ),
            ],
            headerActions: _buildHeaderActions(provider),
            toolbar: _buildToolbar(items.length),
            child: _buildContent(provider, items),
          ),
        );
      },
    );
  }

  Widget _buildHeaderActions(TankerProvider provider) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: provider.isLoading ? null : provider.fetchTankers,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تحديث'),
        ),
        OutlinedButton.icon(
          onPressed: provider.isLoading ? null : () => _showTankerForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة صهريج'),
        ),
      ],
    );
  }

  Widget _buildToolbar(int resultCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final chips = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            TrackingStatusBadge(
              label: '$resultCount نتيجة',
              color: AppColors.infoBlue,
              icon: Icons.filter_alt_rounded,
            ),
            const TrackingStatusBadge(
              label: 'تحديث تلقائي كل 12 ثانية',
              color: AppColors.secondaryTeal,
              icon: Icons.schedule_rounded,
            ),
            const TrackingStatusBadge(
              label: 'فلترة حسب الرقم أو السيارة',
              color: AppColors.secondaryTeal,
              icon: Icons.tune_rounded,
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: TrackingSearchField(
                  controller: _searchController,
                  hintText:
                      'ابحث برقم الصهريج أو السيارة أو السعة أو الملاحظات...',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              chips,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackingSearchField(
              controller: _searchController,
              hintText:
                  'ابحث برقم الصهريج أو السيارة أو السعة أو الملاحظات...',
              onChanged: (_) => setState(() {}),
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            chips,
          ],
        );
      },
    );
  }

  Widget _buildContent(TankerProvider provider, List<Tanker> items) {
    if (provider.isLoading && provider.tankers.isEmpty) {
      return const TrackingStateCard(
        icon: Icons.local_shipping_outlined,
        title: 'جاري تحميل الصهاريج',
        message: 'يتم الآن جلب الصهاريج والحالات التشغيلية الحالية.',
        color: AppColors.infoBlue,
        action: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }

    if (provider.error != null && provider.tankers.isEmpty) {
      return TrackingStateCard(
        icon: Icons.error_outline_rounded,
        title: 'تعذر تحميل الصهاريج',
        message: provider.error ?? 'حدث خطأ أثناء جلب الصهاريج.',
        color: AppColors.errorRed,
        action: FilledButton.icon(
          onPressed: provider.fetchTankers,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }

    if (items.isEmpty) {
      return TrackingStateCard(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج حاليًا',
        message: _searchController.text.trim().isEmpty
            ? 'لا توجد صهاريج مسجلة في النظام حاليًا.'
            : 'لا توجد صهاريج مطابقة لنص البحث الحالي.',
        color: AppColors.primaryBlue,
        action: _searchController.text.trim().isEmpty
            ? FilledButton.icon(
                onPressed: () => _showTankerForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة صهريج'),
              )
            : OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('مسح البحث'),
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1320 ? 3 : (width >= 860 ? 2 : 1);
        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (tanker) => SizedBox(
                  width: cardWidth,
                  child: _buildTankerCard(provider, tanker),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTankerCard(TankerProvider provider, Tanker tanker) {
    final color = _statusColor(tanker.status);
    final fuelTypeText = tanker.fuelType?.trim().isNotEmpty == true
        ? tanker.fuelType!.trim()
        : 'غير محدد';
    final notesText = tanker.notes?.trim().isNotEmpty == true
        ? tanker.notes!.trim()
        : 'بدون ملاحظات';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      color: Colors.white.withValues(alpha: 0.82),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tanker.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vehicleLabel(tanker),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TrackingStatusBadge(
                label: tanker.status,
                color: color,
                icon: Icons.flag_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.confirmation_number_outlined, tanker.number),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.local_gas_station_outlined, _capacityLabel(tanker)),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.opacity_outlined, fuelTypeText),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.directions_car_filled_outlined, _vehicleLabel(tanker)),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.notes_outlined, notesText),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showTankerForm(tanker: tanker),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'حذف',
                onPressed: provider.isLoading ? null : () => _confirmDelete(tanker),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
