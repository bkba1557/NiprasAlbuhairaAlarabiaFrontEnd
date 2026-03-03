import 'package:flutter/material.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FingerprintAttendanceScreen extends StatefulWidget {
  const FingerprintAttendanceScreen({super.key});

  @override
  State<FingerprintAttendanceScreen> createState() =>
      _FingerprintAttendanceScreenState();
}

class _FingerprintAttendanceScreenState
    extends State<FingerprintAttendanceScreen> {
  late HRProvider _hrProvider;
  bool _isScanning = false;
  String _scanStatus = 'جاهز للمسح';
  Color _scanStatusColor = AppColors.infoBlue;
  String? _employeeName;
  String? _employeeNumber;
  DateTime? _scanTime;
  bool _isCheckIn = true;
  bool _showLocationWarning = false;
  double? _currentLatitude;
  double? _currentLongitude;
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadRecentScans();
  }

  Future<void> _getCurrentLocation() async {
    // استخدام geolocator للحصول على الموقع الحالي
    // final position = await Geolocator.getCurrentPosition();
    // setState(() {
    //   _currentLatitude = position.latitude;
    //   _currentLongitude = position.longitude;
    // });

    // لمحاكاة الموقع
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _currentLatitude = 24.7136;
      _currentLongitude = 46.6753;
    });
  }

  Future<void> _loadRecentScans() async {
    // تحميل عمليات المسح الأخيرة
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _recentScans = [
        {
          'employeeName': 'أحمد محمد',
          'employeeNumber': 'EMP001',
          'time': DateTime.now().subtract(const Duration(minutes: 5)),
          'type': 'checkin',
          'status': 'نجاح',
        },
        {
          'employeeName': 'سعيد علي',
          'employeeNumber': 'EMP002',
          'time': DateTime.now().subtract(const Duration(minutes: 10)),
          'type': 'checkin',
          'status': 'نجاح',
        },
        {
          'employeeName': 'فاطمة حسن',
          'employeeNumber': 'EMP003',
          'time': DateTime.now().subtract(const Duration(minutes: 15)),
          'type': 'checkin',
          'status': 'نجاح',
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    _hrProvider = Provider.of<HRProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تسجيل الحضور بالبصمة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _resetScanner();
              _loadRecentScans();
            },
            tooltip: 'إعادة تعيين',
          ),
          IconButton(
            icon: Icon(_isCheckIn ? Icons.login : Icons.logout),
            onPressed: _toggleCheckType,
            tooltip: _isCheckIn ? 'تسجيل الانصراف' : 'تسجيل الحضور',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // معلومات الموقع الحالي
          _buildLocationInfo(),

          // مساحة المسح
          _buildScanArea(),

          // نتائج المسح
          _buildScanResult(),

          // عمليات المسح الأخيرة
          Expanded(child: _buildRecentScans()),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
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
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: _showLocationWarning
                ? AppColors.errorRed
                : AppColors.successGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showLocationWarning
                      ? '⚠️ خارج موقع العمل'
                      : '✓ داخل موقع العمل',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _showLocationWarning
                        ? AppColors.errorRed
                        : AppColors.successGreen,
                  ),
                ),
                if (_currentLatitude != null && _currentLongitude != null)
                  Text(
                    'الإحداثيات: ${_currentLatitude!.toStringAsFixed(6)}, ${_currentLongitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _getCurrentLocation,
            tooltip: 'تحديث الموقع',
          ),
        ],
      ),
    );
  }

  Widget _buildScanArea() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.hrPurple.withOpacity(0.1),
            AppColors.hrLightPurple.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            _isCheckIn ? 'تسجيل الحضور' : 'تسجيل الانصراف',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.hrPurple,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _startScan,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning
                    ? AppColors.hrPurple.withOpacity(0.3)
                    : AppColors.hrPurple.withOpacity(0.1),
                border: Border.all(
                  color: _isScanning
                      ? AppColors.hrPurple
                      : AppColors.hrLightPurple,
                  width: 4,
                ),
                boxShadow: _isScanning
                    ? [
                        BoxShadow(
                          color: AppColors.hrPurple.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isScanning ? Icons.fingerprint : Icons.touch_app,
                      size: 60,
                      color: _isScanning
                          ? AppColors.hrPurple
                          : AppColors.hrDarkPurple,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning ? 'جاري المسح...' : 'المس للمسح',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isScanning
                            ? AppColors.hrPurple
                            : AppColors.hrDarkPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _scanStatus,
            style: TextStyle(
              fontSize: 16,
              color: _scanStatusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanResult() {
    if (_employeeName == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.lightGray),
          bottom: BorderSide(color: AppColors.lightGray),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.hrPurple,
                radius: 30,
                child: Text(
                  _employeeName![0],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _employeeName!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'رقم الموظف: $_employeeNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.mediumGray,
                      ),
                    ),
                    if (_scanTime != null)
                      Text(
                        'الوقت: ${DateFormat('hh:mm a').format(_scanTime!)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.lightGray,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                _isCheckIn ? Icons.login : Icons.logout,
                color: _isCheckIn ? AppColors.successGreen : AppColors.infoBlue,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_showLocationWarning)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.errorRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text(
                      'أنت خارج موقع العمل المسموح به. يرجى التوجه إلى موقع العمل.',
                      style: TextStyle(color: AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _confirmAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check),
                    SizedBox(width: 8),
                    Text('تأكيد'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _resetScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightGray,
                  foregroundColor: AppColors.darkGray,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('إعادة'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScans() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'عمليات المسح الأخيرة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _recentScans.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد عمليات مسح سابقة',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentScans.length,
                    itemBuilder: (context, index) {
                      final scan = _recentScans[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scan['status'] == 'نجاح'
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                            child: Icon(
                              scan['type'] == 'checkin'
                                  ? Icons.login
                                  : Icons.logout,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(scan['employeeName']),
                          subtitle: Text(
                            '${DateFormat('hh:mm a').format(scan['time'])} - ${scan['employeeNumber']}',
                          ),
                          trailing: Chip(
                            label: Text(scan['status']),
                            backgroundColor: scan['status'] == 'نجاح'
                                ? AppColors.successGreen.withOpacity(0.1)
                                : AppColors.errorRed.withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: scan['status'] == 'نجاح'
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanStatus = 'جاري التعرف على البصمة...';
      _scanStatusColor = AppColors.warningOrange;
    });

    // محاكاة مسح البصمة
    await Future.delayed(const Duration(seconds: 2));

    // في التطبيق الحقيقي، سيتم الاتصال بجهاز البصمة عبر Bluetooth
    // واستقبال بيانات البصمة

    final success = await _simulateFingerprintScan();

    setState(() {
      _isScanning = false;

      if (success) {
        _employeeName = 'أحمد محمد';
        _employeeNumber = 'EMP001';
        _scanTime = DateTime.now();
        _scanStatus = 'تم التعرف على البصمة بنجاح';
        _scanStatusColor = AppColors.successGreen;

        // التحقق من الموقع
        _checkLocation();

        // إضافة للمسح الأخير
        _recentScans.insert(0, {
          'employeeName': _employeeName,
          'employeeNumber': _employeeNumber,
          'time': _scanTime!,
          'type': _isCheckIn ? 'checkin' : 'checkout',
          'status': 'نجاح',
        });
      } else {
        _scanStatus = 'فشل التعرف على البصمة';
        _scanStatusColor = AppColors.errorRed;
      }
    });
  }

  Future<bool> _simulateFingerprintScan() async {
    // محاكاة المسح - في التطبيق الحقيقي سيتم استبدالها باتصال حقيقي
    return true; // نجاح المسح
  }

  void _checkLocation() {
    // في التطبيق الحقيقي، سيتم التحقق من الموقع المسموح به
    // ومقارنته بالموقع الحالي

    final isWithinAllowedLocation = true; // افتراض أن الموقع مسموح

    setState(() {
      _showLocationWarning = !isWithinAllowedLocation;
    });

    if (_showLocationWarning && _isCheckIn) {
      _scanStatus = 'خارج موقع العمل - غير مسموح بالحضور';
      _scanStatusColor = AppColors.errorRed;
    }
  }

  void _toggleCheckType() {
    setState(() {
      _isCheckIn = !_isCheckIn;
      _resetScanner();
    });
  }

  void _resetScanner() {
    setState(() {
      _isScanning = false;
      _employeeName = null;
      _employeeNumber = null;
      _scanTime = null;
      _scanStatus = 'جاهز للمسح';
      _scanStatusColor = AppColors.infoBlue;
      _showLocationWarning = false;
    });
  }

  Future<void> _confirmAttendance() async {
    if (_employeeName == null) return;

    try {
      // إرسال بيانات الحضور إلى السيرفر
      final attendanceData = {
        'fingerprintData':
            'SIMULATED_FINGERPRINT_DATA', // في الحقيقة بيانات البصمة
        'type': _isCheckIn ? 'checkin' : 'checkout',
        'latitude': _currentLatitude,
        'longitude': _currentLongitude,
        'deviceId': 'MOBILE_DEVICE',
      };

      await _hrProvider.recordFingerprintAttendance(attendanceData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCheckIn ? 'تم تسجيل الحضور بنجاح' : 'تم تسجيل الانصراف بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );

      _resetScanner();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التسجيل: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
