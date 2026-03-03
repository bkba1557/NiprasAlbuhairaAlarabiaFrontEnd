import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/location/location_card.dart';
import 'package:order_tracker/widgets/hr/location/location_filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  late HRProvider _hrProvider;
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'جميع الأنواع';
  String _selectedStatus = 'جميع الحالات';
  String _selectedSort = 'الأحدث';
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocations();
    });
  }

  Future<void> _loadLocations() async {
    await _hrProvider.fetchLocations();
  }

  @override
  Widget build(BuildContext context) {
    _hrProvider = Provider.of<HRProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة مواقع العمل',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'فلترة',
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _showOnMap,
            tooltip: 'عرض على الخريطة',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/hr/locations/form');
            },
            tooltip: 'إضافة موقع',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          _buildSearchBar(),

          // إحصائيات المواقع
          _buildLocationsStats(),

          // قائمة المواقع
          Expanded(child: _buildLocationsList(isLargeScreen)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/hr/locations/form');
        },
        backgroundColor: AppColors.hrTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_location),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الموقع أو العنوان...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        // بحث
                      },
                    ),
                  ),
                  onChanged: (value) {
                    // بحث
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: _detectCurrentLocation,
                tooltip: 'تحديد الموقع الحالي',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilterChip(
                label: const Text('النشطة فقط'),
                selected: _showActiveOnly,
                onSelected: (selected) {
                  setState(() {
                    _showActiveOnly = selected;
                    _filterLocations();
                  });
                },
                backgroundColor: _showActiveOnly
                    ? AppColors.hrTeal.withOpacity(0.1)
                    : null,
              ),
              const SizedBox(width: 8),
              const Spacer(),
              Text(
                'عدد المواقع: ${_hrProvider.locations.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.hrTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsStats() {
    final totalLocations = _hrProvider.locations.length;
    final activeLocations = _hrProvider.locations
        .where((l) => l.isActive)
        .length;
    final offices = _hrProvider.locations.where((l) => l.type == 'مكتب').length;
    const employeesCount = 0; // سيتم حسابها من API

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        border: const Border(bottom: BorderSide(color: AppColors.lightGray)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'إجمالي المواقع',
            totalLocations.toString(),
            AppColors.hrTeal,
            Icons.location_on,
          ),
          _buildStatItem(
            'نشطة',
            activeLocations.toString(),
            AppColors.successGreen,
            Icons.check_circle,
          ),
          _buildStatItem(
            'مكاتب',
            offices.toString(),
            AppColors.hrPurple,
            Icons.business,
          ),
          _buildStatItem(
            'الموظفين',
            employeesCount.toString(),
            AppColors.hrCyan,
            Icons.people,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 20,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
        ),
      ],
    );
  }

  Widget _buildLocationsList(bool isLargeScreen) {
    if (_hrProvider.isLoadingLocations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hrProvider.locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: AppColors.lightGray),
            const SizedBox(height: 16),
            const Text(
              'لا توجد مواقع',
              style: TextStyle(fontSize: 18, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/hr/locations/form');
              },
              child: const Text('إضافة موقع جديد'),
            ),
          ],
        ),
      );
    }

    List<WorkLocation> filteredLocations = _hrProvider.locations;

    if (_showActiveOnly) {
      filteredLocations = filteredLocations.where((l) => l.isActive).toList();
    }

    if (_searchController.text.isNotEmpty) {
      filteredLocations = filteredLocations.where((location) {
        return location.name.contains(_searchController.text) ||
            location.address.contains(_searchController.text) ||
            location.code.contains(_searchController.text);
      }).toList();
    }

    final crossAxisCount = isLargeScreen ? 3 : 2;
    final childAspectRatio = isLargeScreen ? 1.1 : 1.3;

    return RefreshIndicator(
      onRefresh: _loadLocations,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filteredLocations.length,
        itemBuilder: (context, index) {
          final location = filteredLocations[index];
          return LocationCard(
            location: location,
            onTap: () {
              _viewLocationDetails(location);
            },
            onEdit: () {
              Navigator.pushNamed(
                context,
                '/hr/locations/form',
                arguments: location,
              );
            },
            onToggleStatus: () {
              _toggleLocationStatus(location);
            },
            onViewEmployees: () {
              _viewLocationEmployees(location);
            },
            onNavigate: () {
              _navigateToLocation(location);
            },
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return LocationFilterDialog(
          selectedType: _selectedType,
          selectedStatus: _selectedStatus,
          selectedSort: _selectedSort,
          onTypeChanged: (value) {
            setState(() {
              _selectedType = value;
            });
          },
          onStatusChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
          },
          onSortChanged: (value) {
            setState(() {
              _selectedSort = value;
            });
          },
          onApply: () {
            Navigator.pop(context);
            _filterLocations();
          },
          onClear: () {
            setState(() {
              _selectedType = 'جميع الأنواع';
              _selectedStatus = 'جميع الحالات';
              _selectedSort = 'الأحدث';
              _showActiveOnly = true;
              _searchController.clear();
            });
            Navigator.pop(context);
            _loadLocations();
          },
        );
      },
    );
  }

  void _filterLocations() {
    List<WorkLocation> filtered = _hrProvider.locations;

    if (_showActiveOnly) {
      filtered = filtered.where((l) => l.isActive).toList();
    }

    if (_selectedType != 'جميع الأنواع') {
      filtered = filtered.where((l) => l.type == _selectedType).toList();
    }

    if (_selectedStatus != 'جميع الحالات') {
      filtered = filtered
          .where(
            (l) =>
                (_selectedStatus == 'نشط' && l.isActive) ||
                (_selectedStatus == 'غير نشط' && !l.isActive),
          )
          .toList();
    }

    // تطبيق الفرز
    switch (_selectedSort) {
      case 'الأحدث':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'الأقدم':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'الاسم':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'النوع':
        filtered.sort((a, b) => a.type.compareTo(b.type));
        break;
    }

    // تحديث القائمة المعروضة
    // Note: في التطبيق الحقيقي، يجب إرسال معاملات الفلترة إلى API
  }

  void _showOnMap() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('عرض المواقع على الخريطة'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: const Center(child: Text('سيتم عرض الخريطة هنا')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  void _detectCurrentLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تحديد الموقع الحالي...'),
        backgroundColor: AppColors.infoBlue,
      ),
    );

    // استخدام geolocator أو أي مكتبة لتحديد الموقع
    // final position = await Geolocator.getCurrentPosition();

    await Future.delayed(const Duration(seconds: 2));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديد الموقع الحالي'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  void _viewLocationDetails(WorkLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تفاصيل الموقع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.business, color: AppColors.hrTeal),
                title: Text(location.name),
                subtitle: Text('كود: ${location.code}'),
              ),
              ListTile(
                leading: const Icon(Icons.category, color: AppColors.hrPurple),
                title: Text('النوع: ${location.type}'),
                subtitle: Text(location.isActive ? 'نشط' : 'غير نشط'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.hrCyan),
                title: const Text('العنوان:'),
                subtitle: Text(location.address),
              ),
              ListTile(
                leading: const Icon(
                  Icons.schedule,
                  color: AppColors.warningOrange,
                ),
                title: const Text('ساعات العمل:'),
                subtitle: Text(location.formattedWorkingHours),
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: AppColors.mediumGray,
                ),
                title: const Text('أيام العطلة:'),
                subtitle: Text(location.formattedOffDays),
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.infoBlue),
                title: const Text('الإعدادات:'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نصف القطر: ${location.radius} متر'),
                    Text(
                      'يتطلب تحديد الموقع: ${location.settings.requireLocation ? 'نعم' : 'لا'}',
                    ),
                    Text(
                      'يسمح بالعمل عن بعد: ${location.settings.allowRemote ? 'نعم' : 'لا'}',
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people, color: AppColors.hrCyan),
                title: const Text('الموظفون المسموحون:'),
                subtitle: const Text('0 موظف'), // سيتم جلب العدد من API
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _viewLocationEmployees(location),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToLocation(location);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hrTeal,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.directions, size: 20),
                        SizedBox(width: 4),
                        Text('التوجه إلى'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareLocation(location);
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 4),
                        Text('مشاركة'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightGray,
                  foregroundColor: AppColors.darkGray,
                ),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleLocationStatus(WorkLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${location.isActive ? 'تعطيل' : 'تفعيل'} الموقع'),
        content: Text(
          'هل تريد ${location.isActive ? 'تعطيل' : 'تفعيل'} موقع ${location.name}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: location.isActive
                  ? AppColors.errorRed
                  : AppColors.successGreen,
            ),
            child: Text(location.isActive ? 'تعطيل' : 'تفعيل'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _hrProvider.toggleLocationStatus(location.id, !location.isActive);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ${location.isActive ? 'تعطيل' : 'تفعيل'} الموقع'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadLocations();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحديث: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _viewLocationEmployees(WorkLocation location) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('موظفون موقع ${location.name}'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: FutureBuilder<List<Employee>>(
              future: _hrProvider.getLocationEmployees(location.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError ||
                    snapshot.data == null ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد موظفون لهذا الموقع'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final employee = snapshot.data![index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.hrPurple,
                        child: Text(
                          employee.name[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(employee.name),
                      subtitle: Text(employee.position),
                      trailing: Text(employee.department),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToLocation(WorkLocation location) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري فتح الخريطة للذهاب إلى ${location.name}'),
        backgroundColor: AppColors.infoBlue,
      ),
    );

    // فتح خرائط Google أو Apple
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.coordinates.latitude},${location.coordinates.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareLocation(WorkLocation location) {
    // مشاركة الموقع عبر التطبيقات المختلفة
    final shareText =
        'موقع ${location.name}\nالعنوان: ${location.address}\nإحداثيات: ${location.coordinates.latitude}, ${location.coordinates.longitude}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري إعداد المشاركة...'),
        backgroundColor: AppColors.infoBlue,
      ),
    );
  }
}
