import 'package:flutter/foundation.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/api_service.dart';

class HRProvider extends ChangeNotifier {
  // الموظفين
  List<Employee> _employees = [];
  Map<String, dynamic>? _employeesStats;
  bool _isLoading = false;

  // الحضور
  List<Attendance> _attendanceRecords = [];
  Map<String, dynamic>? _attendanceStats;
  bool _isLoadingAttendance = false;

  // الرواتب
  List<Salary> _salaries = [];
  Map<String, dynamic>? _salarySummary;
  bool _isLoadingSalaries = false;

  // السلف
  List<Advance> _advances = [];
  bool _isLoadingAdvances = false;

  // الجزاءات
  List<Penalty> _penalties = [];
  bool _isLoadingPenalties = false;

  // المواقع
  List<WorkLocation> _locations = [];
  bool _isLoadingLocations = false;

  // ربط الأجهزة
  List<DeviceEnrollmentRequest> _deviceEnrollmentRequests = [];
  bool _isLoadingDeviceRequests = false;
  String _deviceRequestsStatusFilter = 'pending';

  // لوحة التحكم
  HRDashboardStats? _dashboardStats;
  List<Attendance> _todayAttendance = [];
  List<Employee> _upcomingEvents = [];
  List<Employee> _expiringContracts = [];
  List<Employee> _expiringResidencies = [];
  bool _isLoadingDashboard = false;

  // Getters
  List<Employee> get employees => _employees;
  Map<String, dynamic>? get employeesStats => _employeesStats;
  bool get isLoading => _isLoading;

  List<Attendance> get attendanceRecords => _attendanceRecords;
  Map<String, dynamic>? get attendanceStats => _attendanceStats;
  bool get isLoadingAttendance => _isLoadingAttendance;

  List<Salary> get salaries => _salaries;
  Map<String, dynamic>? get salarySummary => _salarySummary;
  bool get isLoadingSalaries => _isLoadingSalaries;

  List<Advance> get advances => _advances;
  bool get isLoadingAdvances => _isLoadingAdvances;

  List<Penalty> get penalties => _penalties;
  bool get isLoadingPenalties => _isLoadingPenalties;

  List<WorkLocation> get locations => _locations;
  bool get isLoadingLocations => _isLoadingLocations;

  List<DeviceEnrollmentRequest> get deviceEnrollmentRequests =>
      _deviceEnrollmentRequests;
  bool get isLoadingDeviceRequests => _isLoadingDeviceRequests;

  HRDashboardStats? get dashboardStats => _dashboardStats;
  List<Attendance> get todayAttendance => _todayAttendance;
  List<Employee> get upcomingEvents => _upcomingEvents;
  List<Employee> get expiringContracts => _expiringContracts;
  List<Employee> get expiringResidencies => _expiringResidencies;
  bool get isLoadingDashboard => _isLoadingDashboard;

  // الموظفين
  Future<void> fetchEmployees({
    String? search,
    String? department,
    String? status,
    bool fingerprintOnly = false,
    bool activeOnly = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (search != null) queryParams['search'] = search;
      if (department != null) queryParams['department'] = department;
      if (status != null) queryParams['status'] = status;
      if (fingerprintOnly) queryParams['fingerprintOnly'] = 'true';
      if (activeOnly) queryParams['activeOnly'] = 'true';

      final response = await ApiService.hrGet(
        '/employees?${_buildQueryString(queryParams)}',
      );

      if (response['success']) {
        _employees = (response['data'] as List)
            .map((json) => Employee.fromJson(json))
            .toList();

        _employeesStats = {
          'total': _employees.length,
          'active': _employees.where((e) => e.isActive).length,
          'fingerprintEnrolled': _employees
              .where((e) => e.hasFingerprint)
              .length,
          'contractExpiring': _expiringContracts.length,
        };
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching employees: $error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createEmployee(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost('/employees', data);
      if (response['success']) {
        final newEmployee = Employee.fromJson(response['data']);
        _employees.insert(0, newEmployee);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error creating employee: $error');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPut('/employees/$id', data);
      if (response['success']) {
        final updatedEmployee = Employee.fromJson(response['data']);
        final index = _employees.indexWhere((e) => e.id == id);
        if (index != -1) {
          _employees[index] = updatedEmployee;
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error updating employee: $error');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeEmployeeStatus(
    String id,
    String status, {
    DateTime? terminationDate,
    String? terminationReason,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = {
        'status': status,
        if (terminationDate != null)
          'terminationDate': terminationDate.toIso8601String(),
        if (terminationReason != null) 'terminationReason': terminationReason,
      };

      final response = await ApiService.hrPut('/employees/$id/status', data);
      if (response['success']) {
        final index = _employees.indexWhere((e) => e.id == id);
        if (index != -1) {
          _employees[index] = Employee.fromJson(response['data']);
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error changing employee status: $error');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSortedEmployees(List<Employee> sortedList) {
    _employees = sortedList;
    notifyListeners();
  }

  // الحضور
  Future<void> fetchAttendanceRecords({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? department,
    String? search,
  }) async {
    _isLoadingAttendance = true;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (date != null) queryParams['date'] = date.toIso8601String();
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (status != null) queryParams['status'] = status;
      if (department != null) queryParams['department'] = department;
      if (search != null) queryParams['search'] = search;

      final response = await ApiService.hrGet(
        '/attendance?${_buildQueryString(queryParams)}',
      );

      if (response['success']) {
        _attendanceRecords = (response['data'] as List)
            .map((json) => Attendance.fromJson(json))
            .toList();

        _attendanceStats = response['stats'] ?? {};
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching attendance: $error');
      }
    } finally {
      _isLoadingAttendance = false;
      notifyListeners();
    }
  }

  Future<void> addManualAttendance(Map<String, dynamic> data) async {
    _isLoadingAttendance = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost('/attendance/manual', data);
      if (response['success']) {
        final newAttendance = Attendance.fromJson(response['data']);
        _attendanceRecords.insert(0, newAttendance);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error adding manual attendance: $error');
      }
      rethrow;
    } finally {
      _isLoadingAttendance = false;
      notifyListeners();
    }
  }

  Future<void> updateAttendance(String id, Map<String, dynamic> data) async {
    _isLoadingAttendance = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPut('/attendance/$id', data);
      if (response['success']) {
        final updatedAttendance = Attendance.fromJson(response['data']);
        final index = _attendanceRecords.indexWhere((a) => a.id == id);
        if (index != -1) {
          _attendanceRecords[index] = updatedAttendance;
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error updating attendance: $error');
      }
      rethrow;
    } finally {
      _isLoadingAttendance = false;
      notifyListeners();
    }
  }

  // الرواتب
  Future<void> fetchSalaries({
    int? month,
    int? year,
    String? department,
    String? status,
  }) async {
    _isLoadingSalaries = true;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;
      if (department != null) queryParams['department'] = department;
      if (status != null) queryParams['status'] = status;

      final response = await ApiService.hrGet(
        '/salaries?${_buildQueryString(queryParams)}',
      );

      if (response['success']) {
        _salaries = (response['data'] as List)
            .map((json) => Salary.fromJson(json))
            .toList();

        _salarySummary = response['stats'] ?? {};
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching salaries: $error');
      }
    } finally {
      _isLoadingSalaries = false;
      notifyListeners();
    }
  }

  Future<void> generateSalarySheets(int month, int year) async {
    _isLoadingSalaries = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost('/salaries/create', {
        'month': month,
        'year': year,
      });

      if (response['success']) {
        await fetchSalaries(month: month, year: year);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error generating salary sheets: $error');
      }
      rethrow;
    } finally {
      _isLoadingSalaries = false;
      notifyListeners();
    }
  }

  // السلف
  Future<void> fetchAdvances({String? status, String? department}) async {
    _isLoadingAdvances = true;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (department != null) queryParams['department'] = department;

      final response = await ApiService.hrGet(
        '/advances?${_buildQueryString(queryParams)}',
      );

      if (response['success']) {
        _advances = (response['data'] as List)
            .map((json) => Advance.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching advances: $error');
      }
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  // الجزاءات
  Future<void> requestAdvance(Map<String, dynamic> data) async {
    _isLoadingAdvances = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost('/advances', data);
      if (response['success']) {
        final advance = Advance.fromJson(response['data']);
        _advances.insert(0, advance);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error requesting advance: $error');
      }
      rethrow;
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  Future<void> fetchPenalties({
    String? status,
    String? type,
    String? department,
  }) async {
    _isLoadingPenalties = true;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type;
      if (department != null) queryParams['department'] = department;

      final response = await ApiService.hrGet(
        '/penalties?${_buildQueryString(queryParams)}',
      );

      if (response['success']) {
        _penalties = (response['data'] as List)
            .map((json) => Penalty.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching penalties: $error');
      }
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  // المواقع
  Future<void> issuePenalty(Map<String, dynamic> data) async {
    _isLoadingPenalties = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost('/penalties', data);
      if (response['success']) {
        final penalty = Penalty.fromJson(response['data']);
        _penalties.insert(0, penalty);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error issuing penalty: $error');
      }
      rethrow;
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  Future<void> fetchLocations() async {
    _isLoadingLocations = true;
    notifyListeners();

    try {
      final response = await ApiService.hrGet('/locations');

      if (response['success']) {
        _locations = (response['data'] as List)
            .map((json) => WorkLocation.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching locations: $error');
      }
    } finally {
      _isLoadingLocations = false;
      notifyListeners();
    }
  }

  Future<WorkLocation?> createLocation(Map<String, dynamic> data) async {
    _isLoadingLocations = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost('/locations', data);
      if (response['success']) {
        final location = WorkLocation.fromJson(response['data']);
        _locations.insert(0, location);
        return location;
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error creating location: $error');
      }
      rethrow;
    } finally {
      _isLoadingLocations = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> assignLocationToEmployees(
    List<String> employeeIds,
    String locationId,
  ) async {
    for (final employeeId in employeeIds) {
      await ApiService.hrPut(
        '/employees/$employeeId/locations',
        {'locationIds': [locationId]},
      );
    }
  }

  // ربط الأجهزة
  Future<void> fetchDeviceEnrollmentRequests({String status = 'pending'}) async {
    _isLoadingDeviceRequests = true;
    notifyListeners();

    try {
      _deviceRequestsStatusFilter = status;
      final response = await ApiService.hrGet(
        '/attendance/enroll-requests?status=$status',
      );

      if (response['success']) {
        _deviceEnrollmentRequests = (response['data'] as List)
            .map((json) => DeviceEnrollmentRequest.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching device enrollment requests: $error');
      }
    } finally {
      _isLoadingDeviceRequests = false;
      notifyListeners();
    }
  }

  Future<void> approveDeviceEnrollmentRequest(String requestId) async {
    _isLoadingDeviceRequests = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost(
        '/attendance/enroll-requests/$requestId/approve',
        {},
      );
      if (response['success']) {
        _deviceEnrollmentRequests =
            _deviceEnrollmentRequests.where((r) => r.id != requestId).toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error approving device enrollment: $error');
      }
      rethrow;
    } finally {
      _isLoadingDeviceRequests = false;
      notifyListeners();
    }
  }

  Future<void> rejectDeviceEnrollmentRequest(
    String requestId,
    String reason,
  ) async {
    _isLoadingDeviceRequests = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost(
        '/attendance/enroll-requests/$requestId/reject',
        {'reason': reason},
      );
      if (response['success']) {
        _deviceEnrollmentRequests =
            _deviceEnrollmentRequests.where((r) => r.id != requestId).toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error rejecting device enrollment: $error');
      }
      rethrow;
    } finally {
      _isLoadingDeviceRequests = false;
      notifyListeners();
    }
  }

  Future<void> updateDeviceEnrollmentStatus(
    String requestId,
    String status, {
    String? reason,
  }) async {
    _isLoadingDeviceRequests = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPut(
        '/attendance/enroll-requests/$requestId/status',
        {
          'status': status,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      if (response['success']) {
        await fetchDeviceEnrollmentRequests(status: _deviceRequestsStatusFilter);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error updating device enrollment status: $error');
      }
      rethrow;
    } finally {
      _isLoadingDeviceRequests = false;
      notifyListeners();
    }
  }

  // لوحة التحكم
  Future<void> fetchDashboardStats() async {
    _isLoadingDashboard = true;
    notifyListeners();

    try {
      final response = await ApiService.hrGet('/dashboard');

      if (response['success']) {
        _dashboardStats = HRDashboardStats.fromJson(response['data']['stats']);
        _expiringContracts = (response['data']['expiringContracts'] as List)
            .map((json) => Employee.fromJson(json))
            .toList();
        _expiringResidencies = (response['data']['expiringResidencies'] as List)
            .map((json) => Employee.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching dashboard stats: $error');
      }
    } finally {
      _isLoadingDashboard = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodayAttendance() async {
    try {
      final response = await ApiService.hrGet(
        '/attendance?date=${DateTime.now().toIso8601String()}',
      );

      if (response['success']) {
        _todayAttendance = (response['data'] as List)
            .map((json) => Attendance.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching today attendance: $error');
      }
    }
  }

  Future<void> fetchUpcomingEvents() async {
    try {
      final response = await ApiService.hrGet('/employees/upcoming-events');

      if (response['success']) {
        _upcomingEvents = (response['data'] as List)
            .map((json) => Employee.fromJson(json))
            .toList();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching upcoming events: $error');
      }
    }
  }

  Future<void> fetchSalarySummary() async {
    try {
      final now = DateTime.now();
      final response = await ApiService.hrGet(
        '/salaries?month=${now.month}&year=${now.year}',
      );

      if (response['success']) {
        _salarySummary = response['stats'] ?? {};
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching salary summary: $error');
      }
    }
  }

  // تصدير
  Future<void> exportEmployees() async {
    try {
      final response = await ApiService.hrGet('/employees/export');

      if (response['success']) {
        // Handle file download
        final data = response['data'];
        // Save file logic here
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error exporting employees: $error');
      }
      rethrow;
    }
  }

  Future<void> exportAttendance({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) queryParams['date'] = date.toIso8601String();
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await ApiService.hrGet(
        '/attendance/export?${_buildQueryString(queryParams)}',
      );

      if (response['success']) {
        // Handle file download
        final data = response['data'];
        // Save file logic here
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error exporting attendance: $error');
      }
      rethrow;
    }
  }

  // خدمات إضافية
  Future<void> sendContractReminder(String employeeId) async {
    try {
      await ApiService.hrPost('/employees/$employeeId/contract-reminder', {});
    } catch (error) {
      if (kDebugMode) {
        print('Error sending contract reminder: $error');
      }
      rethrow;
    }
  }

  Future<void> sendResidencyReminder(String employeeId) async {
    try {
      await ApiService.hrPost('/employees/$employeeId/residency-reminder', {});
    } catch (error) {
      if (kDebugMode) {
        print('Error sending residency reminder: $error');
      }
      rethrow;
    }
  }

  Future<void> assignEmployeeDevice(
    String id,
    String deviceId, {
    String? deviceLabel,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost(
        '/employees/$id/device',
        {
          'deviceId': deviceId,
          if (deviceLabel != null && deviceLabel.isNotEmpty)
            'deviceLabel': deviceLabel,
        },
      );

      if (response['success']) {
        // تحديث القائمة إن كانت موجودة
        final index = _employees.indexWhere((e) => e.id == id);
        if (index != -1) {
          final existing = _employees[index];
          _employees[index] = Employee(
            id: existing.id,
            employeeId: existing.employeeId,
            name: existing.name,
            nameEnglish: existing.nameEnglish,
            nationalId: existing.nationalId,
            gender: existing.gender,
            dateOfBirth: existing.dateOfBirth,
            nationality: existing.nationality,
            city: existing.city,
            phone: existing.phone,
            email: existing.email,
            address: existing.address,
            department: existing.department,
            position: existing.position,
            jobTitle: existing.jobTitle,
            employmentType: existing.employmentType,
            hireDate: existing.hireDate,
            contractStartDate: existing.contractStartDate,
            contractEndDate: existing.contractEndDate,
            probationPeriodEnd: existing.probationPeriodEnd,
            workSchedule: existing.workSchedule,
            weeklyHours: existing.weeklyHours,
            residencyNumber: existing.residencyNumber,
            residencyIssueDate: existing.residencyIssueDate,
            residencyExpiryDate: existing.residencyExpiryDate,
            passportNumber: existing.passportNumber,
            passportExpiryDate: existing.passportExpiryDate,
            basicSalary: existing.basicSalary,
            housingAllowance: existing.housingAllowance,
            transportationAllowance: existing.transportationAllowance,
            otherAllowances: existing.otherAllowances,
            bankName: existing.bankName,
            iban: existing.iban,
            accountNumber: existing.accountNumber,
            fingerprintEnrolled: existing.fingerprintEnrolled,
            faceEnrolled: existing.faceEnrolled,
            assignedDeviceId: deviceId,
            assignedDeviceLabel: deviceLabel ?? existing.assignedDeviceLabel,
            deviceAssignedAt: DateTime.now(),
            status: existing.status,
            terminationDate: existing.terminationDate,
            terminationReason: existing.terminationReason,
            allowedLocations: existing.allowedLocations,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          );
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error assigning device: $error');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearEmployeeDevice(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.hrDelete('/employees/$id/device');
      if (response['success']) {
        final index = _employees.indexWhere((e) => e.id == id);
        if (index != -1) {
          final existing = _employees[index];
          _employees[index] = Employee(
            id: existing.id,
            employeeId: existing.employeeId,
            name: existing.name,
            nameEnglish: existing.nameEnglish,
            nationalId: existing.nationalId,
            gender: existing.gender,
            dateOfBirth: existing.dateOfBirth,
            nationality: existing.nationality,
            city: existing.city,
            phone: existing.phone,
            email: existing.email,
            address: existing.address,
            department: existing.department,
            position: existing.position,
            jobTitle: existing.jobTitle,
            employmentType: existing.employmentType,
            hireDate: existing.hireDate,
            contractStartDate: existing.contractStartDate,
            contractEndDate: existing.contractEndDate,
            probationPeriodEnd: existing.probationPeriodEnd,
            workSchedule: existing.workSchedule,
            weeklyHours: existing.weeklyHours,
            residencyNumber: existing.residencyNumber,
            residencyIssueDate: existing.residencyIssueDate,
            residencyExpiryDate: existing.residencyExpiryDate,
            passportNumber: existing.passportNumber,
            passportExpiryDate: existing.passportExpiryDate,
            basicSalary: existing.basicSalary,
            housingAllowance: existing.housingAllowance,
            transportationAllowance: existing.transportationAllowance,
            otherAllowances: existing.otherAllowances,
            bankName: existing.bankName,
            iban: existing.iban,
            accountNumber: existing.accountNumber,
            fingerprintEnrolled: existing.fingerprintEnrolled,
            faceEnrolled: existing.faceEnrolled,
            assignedDeviceId: null,
            assignedDeviceLabel: null,
            deviceAssignedAt: null,
            status: existing.status,
            terminationDate: existing.terminationDate,
            terminationReason: existing.terminationReason,
            allowedLocations: existing.allowedLocations,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          );
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error clearing device: $error');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> enrollFace(String id, String imageBase64) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.hrPost(
        '/employees/$id/face',
        {'imageBase64': imageBase64},
      );
      if (!response['success']) {
        throw Exception(response['message'] ?? 'Face enrollment failed');
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error enrolling face: $error');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _simulateNetworkDelay() async =>
      Future.delayed(const Duration(milliseconds: 200));

  Future<void> paySalary(
    String salaryId,
    String paymentMethod,
    DateTime paymentDate,
  ) async {
    _isLoadingSalaries = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingSalaries = false;
      notifyListeners();
    }
  }

  Future<void> approveSalary(String salaryId) async {
    _isLoadingSalaries = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingSalaries = false;
      notifyListeners();
    }
  }

  Future<void> exportSalaries({int? month, int? year}) async {
    _isLoadingSalaries = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingSalaries = false;
      notifyListeners();
    }
  }

  Future<void> approveAdvance(String advanceId, String notes) async {
    _isLoadingAdvances = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  Future<void> rejectAdvance(String advanceId, String reason) async {
    _isLoadingAdvances = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  Future<void> payAdvance(
    String advanceId,
    String paymentMethod,
    DateTime paymentDate,
  ) async {
    _isLoadingAdvances = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  Future<void> recordRepayment(
    String advanceId,
    double amount,
    int month,
    int year,
  ) async {
    _isLoadingAdvances = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  Future<void> exportAdvances() async {
    _isLoadingAdvances = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingAdvances = false;
      notifyListeners();
    }
  }

  Future<void> approvePenalty(String penaltyId, String notes) async {
    _isLoadingPenalties = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  Future<void> cancelPenalty(String penaltyId, String reason) async {
    _isLoadingPenalties = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  Future<void> appealPenalty(String penaltyId, String reason) async {
    _isLoadingPenalties = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  Future<void> deductPenaltyFromSalary(String penaltyId) async {
    _isLoadingPenalties = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  Future<void> exportPenalties() async {
    _isLoadingPenalties = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingPenalties = false;
      notifyListeners();
    }
  }

  Future<void> recordFingerprintAttendance(
    Map<String, dynamic> attendanceData,
  ) async {
    _isLoadingAttendance = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
    } finally {
      _isLoadingAttendance = false;
      notifyListeners();
    }
  }

  Future<void> toggleLocationStatus(String locationId, bool isActive) async {
    _isLoadingLocations = true;
    notifyListeners();
    try {
      await _simulateNetworkDelay();
      final index = _locations.indexWhere((loc) => loc.id == locationId);
      if (index != -1) {
        final location = _locations[index];
        _locations[index] = WorkLocation(
          id: location.id,
          name: location.name,
          code: location.code,
          type: location.type,
          address: location.address,
          coordinates: location.coordinates,
          radius: location.radius,
          workingHours: location.workingHours,
          offDays: location.offDays,
          settings: location.settings,
          isActive: isActive,
          createdAt: location.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    } finally {
      _isLoadingLocations = false;
      notifyListeners();
    }
  }

  Future<List<Employee>> getLocationEmployees(String locationId) async {
    await _simulateNetworkDelay();
    return _employees;
  }

  // وظيفة مساعدة لبناء query string
  String _buildQueryString(Map<String, dynamic> params) {
    return params.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${entry.key}=${Uri.encodeComponent(entry.value.toString())}',
        )
        .join('&');
  }
}
