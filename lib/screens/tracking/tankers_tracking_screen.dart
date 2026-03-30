import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/tanker_model.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/tanker_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TankerProvider>().fetchTankers();
    });
  }

  @override
  void dispose() {
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
    if (vehicleNumber.isNotEmpty) {
      return vehicleNumber;
    }
    if (driverName.isNotEmpty) {
      return driverName;
    }
    return 'غير مرتبط بسيارة';
  }

  String _capacityLabel(Tanker tanker) {
    final capacity = tanker.capacityLiters;
    if (capacity == null || capacity <= 0) {
      return 'غير محدد';
    }

    return '$capacity لتر';
  }

  String? _normalizedDigits(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String? _aramcoStickerLabel(Tanker tanker) {
    final unifiedSticker = tanker.aramcoUnifiedSticker?.trim() ?? '';
    if (unifiedSticker.isNotEmpty) {
      return 'استيكر أرامكو الموحد: $unifiedSticker';
    }

    final headSticker = tanker.aramcoHeadSticker?.trim() ?? '';
    final tankerSticker = tanker.aramcoTankerSticker?.trim() ?? '';
    if (headSticker.isEmpty && tankerSticker.isEmpty) {
      return null;
    }

    if (headSticker.isNotEmpty && tankerSticker.isNotEmpty) {
      return 'استيكرات أرامكو • الرأس: $headSticker • الصهريج: $tankerSticker';
    }

    if (headSticker.isNotEmpty) {
      return 'استيكر أرامكو الرأس: $headSticker';
    }

    return 'استيكر أرامكو الصهريج: $tankerSticker';
  }

  List<Driver> _vehicleOptions(List<Driver> drivers, {Tanker? tanker}) {
    final items =
        drivers
            .where(
              (driver) => (driver.vehicleNumber?.trim().isNotEmpty ?? false),
            )
            .toList()
          ..sort((a, b) {
            final left = a.vehicleNumber?.trim().isNotEmpty == true
                ? a.vehicleNumber!.trim()
                : a.name.trim();
            final right = b.vehicleNumber?.trim().isNotEmpty == true
                ? b.vehicleNumber!.trim()
                : b.name.trim();
            return left.compareTo(right);
          });

    final linkedDriverId = tanker?.linkedDriverId?.trim() ?? '';
    if (linkedDriverId.isEmpty ||
        items.any((driver) => driver.id == linkedDriverId)) {
      return items;
    }

    items.insert(
      0,
      Driver(
        id: linkedDriverId,
        name: tanker?.linkedDriverName?.trim().isNotEmpty == true
            ? tanker!.linkedDriverName!.trim()
            : 'المركبة الحالية',
        licenseNumber: '',
        phone: '',
        vehicleType: tanker?.linkedVehicleType?.trim().isNotEmpty == true
            ? tanker!.linkedVehicleType!.trim()
            : 'غير محدد',
        vehicleNumber: tanker?.linkedVehicleNumber,
        vehicleStatus: 'فاضي',
        status: 'نشط',
        isActive: true,
        createdById: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return items;
  }

  String _vehicleOptionLabel(Driver driver) {
    final vehicleNumber = driver.vehicleNumber?.trim() ?? '';
    if (vehicleNumber.isEmpty) {
      return driver.name;
    }

    return '$vehicleNumber • ${driver.name}';
  }

  Driver? _findDriverById(List<Driver> drivers, String? driverId) {
    if (driverId == null || driverId.trim().isEmpty) {
      return null;
    }

    for (final driver in drivers) {
      if (driver.id == driverId) {
        return driver;
      }
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
          (tanker.linkedVehicleType ?? '').toLowerCase().contains(query) ||
          (tanker.fuelType ?? '').toLowerCase().contains(query) ||
          (tanker.capacityLiters?.toString() ?? '').contains(query) ||
          (tanker.aramcoUnifiedSticker ?? '').contains(query) ||
          (tanker.aramcoHeadSticker ?? '').contains(query) ||
          (tanker.aramcoTankerSticker ?? '').contains(query);
    }).toList();
  }

  Future<void> _showTankerForm({Tanker? tanker}) async {
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
    final driverProvider = context.read<DriverProvider>();
    final provider = context.read<TankerProvider>();
    final vehicleDrivers = _vehicleOptions(
      await driverProvider.fetchActiveDrivers(),
      tanker: tanker,
    );

    if (!mounted) return;

    String status = _statuses.contains(tanker?.status)
        ? tanker!.status
        : 'فاضي';
    String? linkedDriverId = tanker?.linkedDriverId?.trim().isNotEmpty == true
        ? tanker!.linkedDriverId!.trim()
        : null;

    if (linkedDriverId != null &&
        vehicleDrivers.every((driver) => driver.id != linkedDriverId)) {
      linkedDriverId = null;
    }

    String? fuelType = _fuelTypes.contains(tanker?.fuelType)
        ? tanker!.fuelType
        : null;
    String aramcoStickerMode =
        tanker?.aramcoStickerMode == 'منفصل' ||
            (tanker?.aramcoHeadSticker?.trim().isNotEmpty == true) ||
            (tanker?.aramcoTankerSticker?.trim().isNotEmpty == true)
        ? 'منفصل'
        : 'موحد';
    bool aramcoStickersExpanded = tanker?.hasAramcoStickerData == true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
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
                            prefixIcon: Icon(
                              Icons.confirmation_number_outlined,
                            ),
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
                          initialValue: linkedDriverId,
                          decoration: InputDecoration(
                            labelText: 'السيارة المرتبطة',
                            prefixIcon: const Icon(
                              Icons.directions_car_filled_outlined,
                            ),
                            helperText: vehicleDrivers.isEmpty
                                ? 'لا توجد سيارات مسجلة للسائقين حالياً'
                                : 'اختر السيارة التي يعمل معها هذا الصهريج',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('بدون ربط حالياً'),
                            ),
                            ...vehicleDrivers.map(
                              (driver) => DropdownMenuItem<String?>(
                                value: driver.id,
                                child: Text(
                                  _vehicleOptionLabel(driver),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            linkedDriverId = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
                        DropdownButtonFormField<String>(
                          initialValue: fuelType,
                          decoration: const InputDecoration(
                            labelText: 'نوع الوقود',
                            prefixIcon: Icon(Icons.opacity_outlined),
                          ),
                          items: _fuelTypes
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            fuelType = value;
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
                          initialValue: _statuses.contains(status)
                              ? status
                              : 'فاضي',
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
                            status = value ?? 'فاضي';
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  setDialogState(() {
                                    aramcoStickersExpanded =
                                        !aramcoStickersExpanded;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_offer_outlined,
                                        color: AppColors.primaryBlue,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'استيكرات أرامكو',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'رقم موحد أو رقمين منفصلين للراس والصهريج',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        aramcoStickersExpanded
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        color: const Color(0xFF475569),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (aramcoStickersExpanded) ...[
                                Divider(
                                  height: 1,
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ChoiceChip(
                                            label: const Text('رقم موحد'),
                                            selected:
                                                aramcoStickerMode == 'موحد',
                                            onSelected: (_) {
                                              setDialogState(() {
                                                aramcoStickerMode = 'موحد';
                                              });
                                            },
                                          ),
                                          ChoiceChip(
                                            label: const Text('منفصل'),
                                            selected:
                                                aramcoStickerMode == 'منفصل',
                                            onSelected: (_) {
                                              setDialogState(() {
                                                aramcoStickerMode = 'منفصل';
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (aramcoStickerMode == 'موحد')
                                        TextFormField(
                                          controller:
                                              aramcoUnifiedStickerController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'استيكر الراس والصهريج',
                                            prefixIcon: Icon(
                                              Icons.pin_outlined,
                                            ),
                                          ),
                                        )
                                      else
                                        Directionality(
                                          textDirection: TextDirection.rtl,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller:
                                                      aramcoTankerStickerController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  decoration: const InputDecoration(
                                                    labelText: 'استيكر الصهريج',
                                                    prefixIcon: Icon(
                                                      Icons
                                                          .local_shipping_outlined,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: TextFormField(
                                                  controller:
                                                      aramcoHeadStickerController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  decoration: const InputDecoration(
                                                    labelText: 'استيكر الراس',
                                                    prefixIcon: Icon(
                                                      Icons
                                                          .directions_car_filled_outlined,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
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
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          final aramcoUnifiedSticker = _normalizedDigits(
                            aramcoUnifiedStickerController.text,
                          );
                          final aramcoHeadSticker = _normalizedDigits(
                            aramcoHeadStickerController.text,
                          );
                          final aramcoTankerSticker = _normalizedDigits(
                            aramcoTankerStickerController.text,
                          );

                          if (aramcoStickerMode == 'منفصل' &&
                              ((aramcoHeadSticker == null) !=
                                  (aramcoTankerSticker == null))) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'أدخل استيكر الرأس واستيكر الصهريج معًا أو اتركهما فارغين',
                                ),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                            return;
                          }

                          String? selectedAramcoStickerMode;
                          String? selectedAramcoUnifiedSticker;
                          String? selectedAramcoHeadSticker;
                          String? selectedAramcoTankerSticker;

                          if (aramcoStickerMode == 'موحد' &&
                              aramcoUnifiedSticker != null) {
                            selectedAramcoStickerMode = 'موحد';
                            selectedAramcoUnifiedSticker = aramcoUnifiedSticker;
                          } else if (aramcoStickerMode == 'منفصل' &&
                              aramcoHeadSticker != null &&
                              aramcoTankerSticker != null) {
                            selectedAramcoStickerMode = 'منفصل';
                            selectedAramcoHeadSticker = aramcoHeadSticker;
                            selectedAramcoTankerSticker = aramcoTankerSticker;
                          }

                          final capacityLiters = int.parse(
                            capacityController.text.trim(),
                          );
                          final linkedDriver = _findDriverById(
                            vehicleDrivers,
                            linkedDriverId,
                          );

                          final payload = Tanker(
                            id: tanker?.id ?? '',
                            number: numberController.text.trim(),
                            status: status,
                            capacityLiters: capacityLiters,
                            fuelType: fuelType,
                            linkedDriverId: linkedDriverId,
                            linkedDriverName: linkedDriver?.name,
                            linkedVehicleNumber: linkedDriver?.vehicleNumber,
                            linkedVehicleType: linkedDriver?.vehicleType,
                            aramcoStickerMode: selectedAramcoStickerMode,
                            aramcoUnifiedSticker: selectedAramcoUnifiedSticker,
                            aramcoHeadSticker: selectedAramcoHeadSticker,
                            aramcoTankerSticker: selectedAramcoTankerSticker,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                            createdAt: tanker?.createdAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          final ok = tanker == null
                              ? await provider.createTanker(payload)
                              : await provider.updateTanker(tanker.id, payload);

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
    } else if (result == false && mounted && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ'),
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
        final availableCount = allTankers
            .where((t) => t.status == 'فاضي')
            .length;
        final busyCount = allTankers.where((t) => t.status == 'في طلب').length;
        final maintenanceCount = allTankers
            .where((t) => t.status == 'تحت الصيانة')
            .length;

        return RefreshIndicator(
          onRefresh: provider.fetchTankers,
          child: TrackingPageShell(
            icon: Icons.local_shipping_rounded,
            title: 'متابعة الصهاريج',
            subtitle:
                'مراجعة الصهاريج، حالتها التشغيلية، ربطها بالسيارات، وإدارة السعات والملاحظات من شاشة واحدة.',
            metrics: [
              TrackingMetric(
                label: 'إجمالي الصهاريج',
                value: '${allTankers.length}',
                icon: Icons.local_shipping_outlined,
                color: AppColors.primaryBlue,
                helper: 'كل الصهاريج المسجلة في النظام',
              ),
              TrackingMetric(
                label: 'متاحة حالياً',
                value: '$availableCount',
                icon: Icons.check_circle_rounded,
                color: AppColors.successGreen,
                helper: 'جاهزة للاستلام أو الإسناد',
              ),
              TrackingMetric(
                label: 'في طلب',
                value: '$busyCount',
                icon: Icons.assignment_rounded,
                color: AppColors.statusGold,
                helper: 'مرتبطة بطلبات نشطة',
              ),
              TrackingMetric(
                label: 'تحت الصيانة',
                value: '$maintenanceCount',
                icon: Icons.build_circle_outlined,
                color: AppColors.pendingYellow,
                helper: 'بحاجة متابعة أو إصلاح',
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: provider.isLoading ? null : () => _showTankerForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة صهريج'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            side: BorderSide(
              color: AppColors.primaryBlue.withValues(alpha: 0.18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
              hintText: 'ابحث برقم الصهريج أو السيارة أو السعة أو الملاحظات...',
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
        title: 'لا توجد نتائج حالياً',
        message: _searchController.text.trim().isEmpty
            ? 'لا توجد صهاريج مسجلة في النظام حالياً.'
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
    final vehicleText = _vehicleLabel(tanker);
    final aramcoStickerText = _aramcoStickerLabel(tanker);
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
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
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
          _buildInfoRow(
            Icons.local_gas_station_outlined,
            _capacityLabel(tanker),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.opacity_outlined, fuelTypeText),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.directions_car_filled_outlined, vehicleText),
          if (tanker.linkedVehicleType?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.category_outlined,
              tanker.linkedVehicleType!.trim(),
            ),
          ],
          if (aramcoStickerText != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.local_offer_outlined, aramcoStickerText),
          ],
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.infoBlue.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'حذف',
                onPressed: provider.isLoading
                    ? null
                    : () => _confirmDelete(tanker),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.errorRed.withValues(alpha: 0.10),
                  foregroundColor: AppColors.errorRed,
                ),
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
