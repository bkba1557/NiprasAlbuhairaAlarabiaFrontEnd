import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/providers/user_management_provider.dart';
import 'package:order_tracker/utils/access_control.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/permission_definitions.dart';
import 'package:provider/provider.dart';


//momen111985@gmail.com

const List<String> _roleOptions = [
  'owner',
  'owner_station',
  'admin',
  'manager',
  'supervisor',
  'maintenance',
  'Maintenance_Technician',
  'maintenance_station',
  'employee',
  'viewer',
  'station_boy',
  'sales_manager_statiun',
  'maintenance_car_management',
  'finance_manager',
  'driver',
  'movement',
  'supplier',
];

const Map<String, String> _roleLabels = {
  'owner': 'المالك',
  'owner_station': 'مالك محطة',
  'admin': 'المديرالعام',
  'manager': 'المدير',
  'supervisor': 'المشرف',
  'maintenance': 'فني صيانة مركبات',
  'Maintenance_Technician': 'عامل صيانة محطة',
  'maintenance_station': 'فني صيانة محطة',
  'employee': 'مسوق محطات',
  'viewer': 'للقراءة فقط',
  'station_boy': 'عامل محطة',
  'sales_manager_statiun': 'مدير مبيعات المحطات',
  'maintenance_car_management': 'مدير صيانة المركبات',
  'finance_manager': 'المدير المالي',
  'driver': 'السائق',
  'movement': 'الحركة',
  'supplier': 'المورد',
};

String _roleDisplay(String role) => _roleLabels[role] ?? role;

Color _roleColor(String role) {
  switch (role) {
    case 'owner':
      return AppColors.primaryBlue;
    case 'owner_station':
      return const Color(0xFF1565C0);
    case 'admin':
      return AppColors.errorRed;
    case 'manager':
      return AppColors.warningOrange;
    case 'supervisor':
      return AppColors.secondaryTeal;
    case 'maintenance':
      return AppColors.infoBlue;
    case 'Maintenance_Technician':
      return const Color.fromARGB(255, 9, 74, 128);
    case 'maintenance_station':
      return const Color(0xFF1B5E20);
    case 'viewer':
      return AppColors.successGreen;
    case 'station_boy':
      return AppColors.successGreen;
    case 'sales_manager_statiun':
      return AppColors.accentBlue;
    case 'finance_manager':
      return const Color(0xFF2E7D32);
    case 'driver':
      return AppColors.statusGold;
    case 'movement':
      return AppColors.appBarBlue;
    case 'supplier':
      return const Color(0xFF00695C);
    default:
      return AppColors.mediumGray;
  }
}

class UserManagementScreen extends StatelessWidget {
  static const routeName = '/users/manage';

  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final canViewUsers =
        user?.hasAnyPermission(const [
          'users_view',
          'users_create',
          'users_edit',
          'users_delete',
          'users_block',
          'users_manage',
        ]) ??
        false;

    if (!canViewUsers) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة المستخدمين',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text('You do not have permission to access this area.'),
        ),
      );
    }

    // ✅ Providers المطلوبة للشاشة
    return ChangeNotifierProvider(
      create: (_) => UserManagementProvider()..fetchUsers(),
      child: const _UserManagementView(),
    );
  }
}

class _UserManagementView extends StatefulWidget {
  const _UserManagementView();

  @override
  State<_UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<_UserManagementView> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final provider = context.read<UserManagementProvider>();
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120 &&
        provider.hasMore &&
        !provider.isLoading) {
      provider.fetchUsers(
        page: provider.currentPage + 1,
        append: true,
        search: _searchController.text,
      );
    }
  }

  Future<void> _runSearch() async {
    final query = _searchController.text;
    await context.read<UserManagementProvider>().fetchUsers(
      page: 1,
      search: query,
      append: false,
    );
  }

  Future<void> _showUserForm({User? user}) async {
    final authUser = context.read<AuthProvider>().user;
    final canCreateUsers =
        authUser?.hasAnyPermission(const ['users_create', 'users_manage']) ??
        false;
    final canEditUsers =
        authUser?.hasAnyPermission(const ['users_edit', 'users_manage']) ??
        false;
    if (user == null && !canCreateUsers) return;
    if (user != null && !canEditUsers) return;

    final provider = context.read<UserManagementProvider>();
    final stationProvider = context.read<StationProvider>();
    final driverProvider = context.read<DriverProvider>();
    final supplierProvider = context.read<SupplierProvider>();

    if ((user?.role == 'station_boy' || user?.role == 'owner_station') &&
        stationProvider.stations.isEmpty) {
      await stationProvider.fetchStations();
    }

    if ((user?.role == 'supplier' || user?.supplierId != null) &&
        supplierProvider.suppliers.isEmpty) {
      await supplierProvider.fetchSuppliers(
        filters: <String, dynamic>{'isActive': 'true'},
      );
    }

    List<Driver> availableDrivers = const [];
    if (user?.role == 'driver' || user?.driverId != null) {
      availableDrivers = await driverProvider.fetchActiveDrivers();
      if (user?.driverId != null) {
        final currentDriver = await driverProvider.loadDriver(user!.driverId!);
        if (currentDriver != null &&
            availableDrivers.every((driver) => driver.id != currentDriver.id)) {
          availableDrivers = [...availableDrivers, currentDriver];
        }
      }
    }

    String? selectedStationId = user?.stationId;
    final selectedStationIds = <String>{
      ...user?.stationIds ?? const <String>[],
    };
    String? selectedDriverId = user?.driverId;
    String? selectedSupplierId = user?.supplierId;

    final isEditing = user != null;
    final nameController = TextEditingController(text: user?.name ?? '');
    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    final emailController = TextEditingController(text: user?.email ?? '');
    final companyController = TextEditingController(text: user?.company ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final passwordController = TextEditingController();

    String roleValue = user?.role ?? 'employee';
    final formKey = GlobalKey<FormState>();
    final selectedPermissions = Set<String>.from(
      user?.permissions.isNotEmpty == true
          ? user!.permissions
          : defaultPermissionsForRole(roleValue),
    );

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: const Color.fromARGB(0, 241, 240, 240),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final stations = context.watch<StationProvider>().stations;
            final isStationsLoading = context
                .watch<StationProvider>()
                .isStationsLoading;
            final suppliers = context.watch<SupplierProvider>().suppliers;

            // تحديد الحجم بناءً على نوع الجهاز
            final isMobile = MediaQuery.of(context).size.width < 600;
            final maxFormWidth = isMobile
                ? MediaQuery.of(context).size.width
                : MediaQuery.of(context).size.width * 0.6;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxFormWidth),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'تعديل المستخدم' : 'إنشاء مستخدم',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                          ),
                          const SizedBox(height: 16),

                          // ================= الاسم =================
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'الاسم بالكامل',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'الاسم مطلوب'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // ================= البريد =================
                          TextFormField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                            ),
                            validator: (v) {
                              final input = v?.trim() ?? '';
                              if (input.isEmpty) return null;
                              if (input.length < 3) {
                                return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                              }
                              if (input.contains(' ')) {
                                return 'اسم المستخدم لا يجب أن يحتوي على مسافات';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'البريد مطلوب';
                              }
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+',
                              ).hasMatch(v)) {
                                return 'البريد غير صحيح';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // ================= الشركة =================
                          TextFormField(
                            controller: companyController,
                            decoration: const InputDecoration(
                              labelText: 'الشركة',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'الشركة مطلوبة'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // ================= الجوال =================
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),

                          // ================= الدور =================
                          DropdownButtonFormField<String>(
                            value: roleValue,
                            decoration: const InputDecoration(
                              labelText: 'الصلاحية',
                            ),
                            items: _roleOptions
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(_roleDisplay(r)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              if (value == null) return;

                              final nextDefaults = defaultPermissionsForRole(
                                value,
                              );
                              setModalState(() {
                                roleValue = value;
                                selectedStationId = null;
                                selectedStationIds.clear();
                                if (value != 'driver') {
                                  selectedDriverId = null;
                                }
                                if (value != 'supplier') {
                                  selectedSupplierId = null;
                                }
                                selectedPermissions
                                  ..clear()
                                  ..addAll(nextDefaults);
                              });

                              if ((value == 'station_boy' ||
                                      value == 'owner_station') &&
                                  stationProvider.stations.isEmpty) {
                                await stationProvider.fetchStations();
                              }

                              if (value == 'driver') {
                                final drivers = await driverProvider
                                    .fetchActiveDrivers();
                                Driver? currentDriver;
                                if (selectedDriverId != null) {
                                  currentDriver = await driverProvider
                                      .loadDriver(selectedDriverId!);
                                }
                                setModalState(() {
                                  availableDrivers =
                                      currentDriver != null &&
                                          drivers.every(
                                            (driver) =>
                                                driver.id != currentDriver!.id,
                                          )
                                      ? [...drivers, currentDriver]
                                      : drivers;
                                });
                              }

                              if (value == 'supplier' &&
                                  supplierProvider.suppliers.isEmpty) {
                                await supplierProvider.fetchSuppliers(
                                  filters: <String, dynamic>{'isActive': 'true'},
                                );
                              }
                            },
                          ),

                          // ================= المحطة (لعامل المحطة فقط) =================
                          if (roleValue == 'driver') ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value:
                                  availableDrivers.any(
                                    (driver) => driver.id == selectedDriverId,
                                  )
                                  ? selectedDriverId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'السائق المرتبط',
                              ),
                              items: availableDrivers
                                  .map(
                                    (driver) => DropdownMenuItem<String>(
                                      value: driver.id,
                                      child: Text(driver.displayInfo),
                                    ),
                                  )
                                  .toList(),
                              validator: (value) {
                                if (roleValue != 'driver') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى اختيار السائق المرتبط';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setModalState(() {
                                  selectedDriverId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (roleValue == 'supplier') ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: suppliers.any(
                                (supplier) => supplier.id == selectedSupplierId,
                              )
                                  ? selectedSupplierId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'المورد المرتبط',
                              ),
                              items: suppliers
                                  .map(
                                    (supplier) => DropdownMenuItem<String>(
                                      value: supplier.id,
                                      child: Text(
                                        supplier.company.trim().isEmpty
                                            ? supplier.name
                                            : '${supplier.name} - ${supplier.company}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              validator: (value) {
                                if (roleValue != 'supplier') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى اختيار المورد المرتبط';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setModalState(() {
                                  selectedSupplierId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (roleValue == 'station_boy') ...[
                            const SizedBox(height: 16),

                            if (isStationsLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(),
                                ),
                              ),

                            if (!isStationsLoading && stations.isEmpty)
                              const Text(
                                'لا توجد محطات متاحة',
                                style: TextStyle(color: Colors.red),
                              ),

                            if (!isStationsLoading && stations.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: selectedStationId,
                                decoration: const InputDecoration(
                                  labelText: 'المحطة المرتبطة',
                                ),
                                items: stations
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.stationName),
                                      ),
                                    )
                                    .toList(),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'يرجى اختيار المحطة'
                                    : null,
                                onChanged: (v) {
                                  setModalState(() {
                                    selectedStationId = v;
                                  });
                                },
                              ),
                            const SizedBox(height: 16),
                          ],
                          if (roleValue == 'owner_station') ...[
                            const SizedBox(height: 16),
                            if (isStationsLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            if (!isStationsLoading && stations.isEmpty)
                              const Text(
                                'لا توجد محطات متاحة',
                                style: TextStyle(color: Colors.red),
                              ),
                            if (!isStationsLoading && stations.isNotEmpty) ...[
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await _pickStationsForOwner(
                                    stations: stations,
                                    initialSelection: selectedStationIds,
                                  );
                                  if (picked == null) return;
                                  setModalState(() {
                                    selectedStationIds
                                      ..clear()
                                      ..addAll(picked);
                                  });
                                },
                                icon: const Icon(Icons.alt_route_rounded),
                                label: Text(
                                  selectedStationIds.isEmpty
                                      ? 'اختيار المحطات'
                                      : 'المحطات المختارة (${selectedStationIds.length})',
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (selectedStationIds.isEmpty)
                                const Text(
                                  'يرجى اختيار محطة واحدة على الأقل',
                                  style: TextStyle(color: Colors.red),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: stations
                                      .where(
                                        (station) => selectedStationIds
                                            .contains(station.id),
                                      )
                                      .map(
                                        (station) => Chip(
                                          label: Text(station.stationName),
                                          backgroundColor: AppColors.primaryBlue
                                              .withOpacity(0.08),
                                          side: BorderSide(
                                            color: AppColors.primaryBlue
                                                .withOpacity(0.18),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                            const SizedBox(height: 16),
                          ],

                          // ================= الصلاحيات =================
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'صلاحيات العرض والتحكم',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    selectedPermissions
                                      ..clear()
                                      ..addAll(
                                        defaultPermissionsForRole(roleValue),
                                      );
                                  });
                                },
                                icon: const Icon(Icons.restart_alt),
                                label: const Text('تطبيق صلاحيات الدور'),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    selectedPermissions
                                      ..clear()
                                      ..addAll(permissionKeys);
                                  });
                                },
                                icon: const Icon(Icons.select_all),
                                label: const Text('تحديد الكل'),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(selectedPermissions.clear);
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('مسح الكل'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'يمكنك تعديل صلاحيات الدور يدويًا واختيار الصفحات التي يراها المستخدم وما يستطيع تنفيذه داخل النظام.',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...permissionSections.expand(
                            (section) => [
                              _buildPermissionSection(
                                title: section.title,
                                permissions: section.permissions,
                                selectedPermissions: selectedPermissions,
                                setModalState: setModalState,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ================= كلمة المرور =================
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: isEditing
                                  ? 'كلمة المرور (اتركها فارغة للاحتفاظ بها)'
                                  : 'كلمة المرور',
                            ),
                            validator: (v) {
                              if (isEditing && (v == null || v.isEmpty))
                                return null;
                              if (v == null || v.length < 6) {
                                return 'كلمة المرور 6 أحرف على الأقل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ================= زر الحفظ =================
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: provider.isSaving
                                  ? null
                                  : () async {
                                      if (roleValue == 'owner_station' &&
                                          selectedStationIds.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'يرجى اختيار محطة واحدة على الأقل',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (!formKey.currentState!.validate())
                                        return;

                                      if (roleValue == 'station_boy' ||
                                          roleValue == 'owner_station') {
                                        await stationProvider.fetchStations(
                                          limit: 0,
                                        );

                                        final availableStationIds =
                                            stationProvider.stations
                                                .map((s) => s.id)
                                                .toSet();

                                        if (roleValue == 'station_boy') {
                                          final normalizedStationId =
                                              selectedStationId?.trim();
                                          if (normalizedStationId == null ||
                                              normalizedStationId.isEmpty) {
                                            return;
                                          }

                                          if (!availableStationIds.contains(
                                            normalizedStationId,
                                          )) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'المحطة المختارة غير موجودة، يرجى اختيار محطة من القائمة.',
                                                ),
                                              ),
                                            );
                                            setModalState(() {
                                              selectedStationId = null;
                                            });
                                            return;
                                          }

                                          selectedStationId =
                                              normalizedStationId;
                                        }

                                        if (roleValue == 'owner_station') {
                                          final cleanedStationIds =
                                              selectedStationIds
                                                  .map((id) => id.trim())
                                                  .where((id) => id.isNotEmpty)
                                                  .where(
                                                    availableStationIds
                                                        .contains,
                                                  )
                                                  .toSet();

                                          if (cleanedStationIds.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'يرجى اختيار محطة واحدة على الأقل',
                                                ),
                                              ),
                                            );
                                            setModalState(() {
                                              selectedStationIds
                                                ..clear()
                                                ..addAll(cleanedStationIds);
                                            });
                                            return;
                                          }

                                          if (cleanedStationIds.length !=
                                              selectedStationIds.length) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تم حذف بعض المحطات المختارة لأنها لم تعد متاحة. يرجى إعادة الاختيار.',
                                                ),
                                              ),
                                            );
                                            setModalState(() {
                                              selectedStationIds
                                                ..clear()
                                                ..addAll(cleanedStationIds);
                                            });
                                            return;
                                          }

                                          setModalState(() {
                                            selectedStationIds
                                              ..clear()
                                              ..addAll(cleanedStationIds);
                                          });
                                        }
                                      }

                                      final Map<String, dynamic> payload = {
                                        'name': nameController.text.trim(),
                                        'username': usernameController.text
                                            .trim(),
                                        'email': emailController.text.trim(),
                                        'company': companyController.text
                                            .trim(),
                                        'phone': phoneController.text.trim(),
                                        'role': roleValue,
                                        'driverId': roleValue == 'driver'
                                            ? selectedDriverId
                                            : null,
                                        'supplierId': roleValue == 'supplier'
                                            ? selectedSupplierId
                                            : null,
                                        'permissions': selectedPermissions
                                            .toList(),
                                      };

                                      // ✅ ربط عامل المحطة بمحطة
                                      if (roleValue == 'station_boy' &&
                                          selectedStationId != null) {
                                        payload['stationId'] =
                                            selectedStationId;
                                      }
                                      if (roleValue == 'owner_station') {
                                        payload['stationIds'] =
                                            selectedStationIds.toList();
                                      }

                                      // ✅ كلمة المرور
                                      if (!isEditing ||
                                          passwordController.text.isNotEmpty) {
                                        payload['password'] = passwordController
                                            .text
                                            .trim();
                                      }

                                      try {
                                        if (isEditing) {
                                          await provider.updateUser(
                                            user!.id,
                                            payload,
                                          );
                                        } else {
                                          await provider.createUser(payload);
                                        }

                                        // ✅ تحديث القائمة مرة واحدة فقط
                                        await provider.refresh();

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: provider.isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(isEditing ? 'تحديث' : 'إنشاء'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Set<String>?> _pickStationsForOwner({
    required List<dynamic> stations,
    required Set<String> initialSelection,
  }) async {
    final tempSelection = Set<String>.from(initialSelection);

    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اختيار محطات المالك'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: stations.map<Widget>((station) {
                      final isChecked = tempSelection.contains(station.id);
                      return CheckboxListTile(
                        value: isChecked,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(station.stationName),
                        subtitle: Text(station.stationCode),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              tempSelection.add(station.id);
                            } else {
                              tempSelection.remove(station.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, tempSelection),
                  child: const Text('تطبيق'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(User user) async {
    final authUser = context.read<AuthProvider>().user;
    final canDeleteUsers =
        authUser?.hasAnyPermission(const ['users_delete', 'users_manage']) ??
        false;
    if (!canDeleteUsers) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد الحذف؟ ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('الغاء'),
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

    if (confirmed != true) return;

    final provider = context.read<UserManagementProvider>();
    try {
      await provider.deleteUser(user.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المستخدم')));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'غير قادر على الحذف')),
      );
    }
  }

  Future<void> _toggleBlock(User user) async {
    final authUser = context.read<AuthProvider>().user;
    final canBlockUsers =
        authUser?.hasAnyPermission(const ['users_block', 'users_manage']) ??
        false;
    if (!canBlockUsers) return;

    final provider = context.read<UserManagementProvider>();

    try {
      await provider.toggleBlock(user.id, !user.isBlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isBlocked ? 'تم إلغاء حظر المستخدم' : 'تم حظر المستخدم',
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'تعذر تحديث المستخدم')),
      );
    }
  }

  Widget _buildPermissionSection({
    required String title,
    required List<PermissionDefinition> permissions,
    required Set<String> selectedPermissions,
    required StateSetter setModalState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: permissions.map((permission) {
            final isSelected = selectedPermissions.contains(permission.key);
            return FilterChip(
              label: Text(
                permission.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.darkGray,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primaryBlue.withOpacity(0.15),
              checkmarkColor: AppColors.primaryBlue,
              backgroundColor: AppColors.backgroundGray,
              onSelected: (selected) {
                setModalState(() {
                  if (selected) {
                    selectedPermissions.add(permission.key);
                  } else {
                    selectedPermissions.remove(permission.key);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserManagementProvider>();
    final authUser = context.watch<AuthProvider>().user;
    final canCreateUsers =
        authUser?.hasAnyPermission(const ['users_create', 'users_manage']) ??
        false;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المستخدمين',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : provider.refresh,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: 16,
          ),
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1400 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= شريط البحث =================
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'البحث عن المستخدمين...',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _searchController.text.isEmpty
                                ? Icons.search
                                : Icons.clear,
                          ),
                          onPressed: () {
                            if (_searchController.text.isEmpty) {
                              _runSearch();
                              return;
                            }

                            _searchController.clear();
                            _runSearch();
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (isDesktop && canCreateUsers) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showUserForm(),
                      icon: const Icon(Icons.person_add),
                      label: const Text('مستخدم جديد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ================= رسالة الخطأ =================
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.errorRed),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: AppColors.errorRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ================= إحصائيات سريعة =================
              if (isDesktop)
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      'إجمالي المستخدمين',
                      provider.users.length.toString(),
                      Icons.people,
                      AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      'المستخدمين النشطين',
                      provider.users
                          .where((user) => !user.isBlocked)
                          .length
                          .toString(),
                      Icons.person,
                      AppColors.successGreen,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      'المستخدمين المحظورين',
                      provider.users
                          .where((user) => user.isBlocked)
                          .length
                          .toString(),
                      Icons.lock,
                      AppColors.errorRed,
                    ),
                  ],
                ),
              if (isDesktop) const SizedBox(height: 20),

              // ================= قائمة المستخدمين =================
              Expanded(
                child: Container(
                  decoration: isDesktop
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: provider.isLoading && provider.users.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: provider.refresh,
                          child: provider.users.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 80,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'لم يتم العثور على مستخدمين',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_searchController.text.isNotEmpty)
                                        OutlinedButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            _runSearch();
                                          },
                                          child: const Text('مسح البحث'),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  itemCount:
                                      provider.users.length +
                                      (provider.hasMore ? 1 : 0),
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.grey[200],
                                  ),
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, index) {
                                    if (index >= provider.users.length) {
                                      return Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Center(
                                          child: provider.isLoading
                                              ? const CircularProgressIndicator()
                                              : const Text(
                                                  'جارِ تحميل المزيد...',
                                                ),
                                        ),
                                      );
                                    }

                                    final user = provider.users[index];
                                    return isDesktop
                                        ? _buildDesktopUserItem(user)
                                        : _buildMobileUserItem(user);
                                  },
                                ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      // زر إضافة مستخدم جديد (يظهر فقط على الجوال والتابلت)
      floatingActionButton: !isDesktop && canCreateUsers
          ? FloatingActionButton.extended(
              onPressed: () => _showUserForm(),
              backgroundColor: AppColors.primaryBlue,
              icon: const Icon(Icons.person_add),
              label: const Text('مستخدم جديد'),
            )
          : null,
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopUserItem(User user) {
    final authUser = context.read<AuthProvider>().user;
    final canEditUsers =
        authUser?.hasAnyPermission(const ['users_edit', 'users_manage']) ??
        false;
    final canBlockUsers =
        authUser?.hasAnyPermission(const ['users_block', 'users_manage']) ??
        false;
    final canDeleteUsers =
        authUser?.hasAnyPermission(const ['users_delete', 'users_manage']) ??
        false;
    final displayPermissions = user.effectivePermissions;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: user.isBlocked ? Colors.red.withOpacity(0.02) : Colors.white,
        border: user.isBlocked
            ? Border(left: BorderSide(color: AppColors.errorRed, width: 4))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصورة والمعلومات الأساسية
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
                  child: Text(
                    user.name.isNotEmpty
                        ? user.name
                              .split(' ')
                              .map((p) => p.isNotEmpty ? p[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(user.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _roleDisplay(user.role),
                              style: TextStyle(
                                color: _roleColor(user.role),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (user.isBlocked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'محظور',
                                style: TextStyle(
                                  color: AppColors.errorRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (user.username.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.alternate_email,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.username,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        user.company,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if ((user.supplierName ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.business_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              user.supplierName!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (user.phone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              user.phone!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (user.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('yyyy-MM-dd').format(user.createdAt!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // الصلاحيات
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displayPermissions
                  .take(5) // عرض أول 5 صلاحيات فقط
                  .map(
                    (permission) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        permissionLabel(permission),
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          // الأزرار
          SizedBox(
            width: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canEditUsers) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showUserForm(user: user),
                    tooltip: 'تحرير المستخدم',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (canBlockUsers) ...[
                  IconButton(
                    icon: Icon(
                      user.isBlocked ? Icons.lock_open : Icons.lock,
                      size: 20,
                    ),
                    onPressed: () => _toggleBlock(user),
                    tooltip: user.isBlocked
                        ? 'إلغاء حظر المستخدم'
                        : 'حظر المستخدم',
                    style: IconButton.styleFrom(
                      backgroundColor: user.isBlocked
                          ? AppColors.successGreen.withOpacity(0.1)
                          : AppColors.warningOrange.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (canDeleteUsers)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDelete(user),
                    tooltip: 'حذف المستخدم',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.errorRed.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileUserItem(User user) {
    final authUser = context.read<AuthProvider>().user;
    final canEditUsers =
        authUser?.hasAnyPermission(const ['users_edit', 'users_manage']) ??
        false;
    final canBlockUsers =
        authUser?.hasAnyPermission(const ['users_block', 'users_manage']) ??
        false;
    final canDeleteUsers =
        authUser?.hasAnyPermission(const ['users_delete', 'users_manage']) ??
        false;
    final displayPermissions = user.effectivePermissions;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف العلوي: الصورة والمعلومات والأزرار
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
                  child: Text(
                    user.name.isNotEmpty
                        ? user.name
                              .split(' ')
                              .map((p) => p.isNotEmpty ? p[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (user.username.isNotEmpty)
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        user.company,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if ((user.supplierName ?? '').trim().isNotEmpty)
                        Text(
                          'المورد: ${user.supplierName}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canEditUsers || canBlockUsers || canDeleteUsers)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      if (canEditUsers)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 20),
                              const SizedBox(width: 8),
                              const Text('تعديل'),
                            ],
                          ),
                        ),
                      if (canBlockUsers)
                        PopupMenuItem(
                          value: 'toggle_block',
                          child: Row(
                            children: [
                              Icon(
                                user.isBlocked ? Icons.lock_open : Icons.lock,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(user.isBlocked ? 'إلغاء الحظر' : 'حظر'),
                            ],
                          ),
                        ),
                      if (canDeleteUsers) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'حذف',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showUserForm(user: user);
                          break;
                        case 'toggle_block':
                          _toggleBlock(user);
                          break;
                        case 'delete':
                          _confirmDelete(user);
                          break;
                      }
                    },
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // المعلومات الإضافية
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(_roleDisplay(user.role)),
                  backgroundColor: _roleColor(user.role).withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: _roleColor(user.role),
                    fontSize: 12,
                  ),
                ),
                if (user.isBlocked)
                  const Chip(
                    label: Text('محظور'),
                    backgroundColor: AppColors.errorRed,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                if (user.createdAt != null)
                  Chip(
                    label: Text(
                      DateFormat('yyyy-MM-dd').format(user.createdAt!),
                    ),
                    backgroundColor: AppColors.backgroundGray,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),

            if (user.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    user.phone!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ],

            if (displayPermissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'الصلاحيات:',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayPermissions
                    .map(
                      (permission) => Chip(
                        label: Text(
                          permissionLabel(permission),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                        labelStyle: TextStyle(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
