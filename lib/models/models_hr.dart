// ===========================================
// 📌 نماذج نظام شؤون الموظفين
// ===========================================

class Employee {
  final String id;
  final String employeeId;
  final String name;
  final String nameEnglish;
  final String nationalId;
  final String gender;
  final DateTime dateOfBirth;
  final String nationality;
  final String city;
  final String phone;
  final String email;
  final String? address;
  final String department;
  final String position;
  final String? jobTitle;
  final String employmentType;
  final DateTime hireDate;
  final DateTime contractStartDate;
  final DateTime? contractEndDate;
  final DateTime? probationPeriodEnd;
  final String workSchedule;
  final int weeklyHours;
  final String? residencyNumber;
  final DateTime? residencyIssueDate;
  final DateTime? residencyExpiryDate;
  final String? passportNumber;
  final DateTime? passportExpiryDate;
  final double basicSalary;
  final double housingAllowance;
  final double transportationAllowance;
  final double otherAllowances;
  final String? bankName;
  final String? iban;
  final String? accountNumber;
  final bool fingerprintEnrolled;
  final bool faceEnrolled;
  final String? assignedDeviceId;
  final String? assignedDeviceLabel;
  final DateTime? deviceAssignedAt;
  final String status;
  final DateTime? terminationDate;
  final String? terminationReason;
  final List<AllowedLocation> allowedLocations;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.nameEnglish,
    required this.nationalId,
    required this.gender,
    required this.dateOfBirth,
    required this.nationality,
    required this.city,
    required this.phone,
    required this.email,
    this.address,
    required this.department,
    required this.position,
    this.jobTitle,
    required this.employmentType,
    required this.hireDate,
    required this.contractStartDate,
    this.contractEndDate,
    this.probationPeriodEnd,
    required this.workSchedule,
    required this.weeklyHours,
    this.residencyNumber,
    this.residencyIssueDate,
    this.residencyExpiryDate,
    this.passportNumber,
    this.passportExpiryDate,
    required this.basicSalary,
    required this.housingAllowance,
    required this.transportationAllowance,
    required this.otherAllowances,
    this.bankName,
    this.iban,
    this.accountNumber,
    required this.fingerprintEnrolled,
    required this.faceEnrolled,
    this.assignedDeviceId,
    this.assignedDeviceLabel,
    this.deviceAssignedAt,
    required this.status,
    this.terminationDate,
    this.terminationReason,
    required this.allowedLocations,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] ?? json['id'],
      employeeId: json['employeeId'],
      name: json['name'],
      nameEnglish: json['nameEnglish'] ?? '',
      nationalId: json['nationalId'],
      gender: json['gender'],
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      nationality: json['nationality'],
      city: json['city'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      department: json['department'],
      position: json['position'],
      jobTitle: json['jobTitle'],
      employmentType: json['employmentType'],
      hireDate: DateTime.parse(json['hireDate']),
      contractStartDate: DateTime.parse(json['contractStartDate']),
      contractEndDate: json['contractEndDate'] != null
          ? DateTime.parse(json['contractEndDate'])
          : null,
      probationPeriodEnd: json['probationPeriodEnd'] != null
          ? DateTime.parse(json['probationPeriodEnd'])
          : null,
      workSchedule: json['workSchedule'] ?? 'دوام كامل',
      weeklyHours: json['weeklyHours'] ?? 48,
      residencyNumber: json['residencyNumber'],
      residencyIssueDate: json['residencyIssueDate'] != null
          ? DateTime.parse(json['residencyIssueDate'])
          : null,
      residencyExpiryDate: json['residencyExpiryDate'] != null
          ? DateTime.parse(json['residencyExpiryDate'])
          : null,
      passportNumber: json['passportNumber'],
      passportExpiryDate: json['passportExpiryDate'] != null
          ? DateTime.parse(json['passportExpiryDate'])
          : null,
      basicSalary: (json['basicSalary'] as num).toDouble(),
      housingAllowance: (json['housingAllowance'] as num).toDouble(),
      transportationAllowance: (json['transportationAllowance'] as num)
          .toDouble(),
      otherAllowances: (json['otherAllowances'] as num).toDouble(),
      bankName: json['bankName'],
      iban: json['iban'],
      accountNumber: json['accountNumber'],
      fingerprintEnrolled: json['fingerprintEnrolled'] ?? false,
      faceEnrolled: json['faceEnrolled'] ?? false,
      assignedDeviceId: json['assignedDeviceId'],
      assignedDeviceLabel: json['assignedDeviceLabel'],
      deviceAssignedAt: json['deviceAssignedAt'] != null
          ? DateTime.parse(json['deviceAssignedAt'])
          : null,
      status: json['status'] ?? 'نشط',
      terminationDate: json['terminationDate'] != null
          ? DateTime.parse(json['terminationDate'])
          : null,
      terminationReason: json['terminationReason'],
      allowedLocations: (json['allowedLocations'] as List? ?? [])
          .map((loc) => AllowedLocation.fromJson(loc))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
      'nameEnglish': nameEnglish,
      'nationalId': nationalId,
      'gender': gender,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'nationality': nationality,
      'city': city,
      'phone': phone,
      'email': email,
      'address': address,
      'department': department,
      'position': position,
      'jobTitle': jobTitle,
      'employmentType': employmentType,
      'hireDate': hireDate.toIso8601String(),
      'contractStartDate': contractStartDate.toIso8601String(),
      'contractEndDate': contractEndDate?.toIso8601String(),
      'probationPeriodEnd': probationPeriodEnd?.toIso8601String(),
      'workSchedule': workSchedule,
      'weeklyHours': weeklyHours,
      'residencyNumber': residencyNumber,
      'residencyIssueDate': residencyIssueDate?.toIso8601String(),
      'residencyExpiryDate': residencyExpiryDate?.toIso8601String(),
      'passportNumber': passportNumber,
      'passportExpiryDate': passportExpiryDate?.toIso8601String(),
      'basicSalary': basicSalary,
      'housingAllowance': housingAllowance,
      'transportationAllowance': transportationAllowance,
      'otherAllowances': otherAllowances,
      'bankName': bankName,
      'iban': iban,
      'accountNumber': accountNumber,
      'fingerprintEnrolled': fingerprintEnrolled,
      'faceEnrolled': faceEnrolled,
      'assignedDeviceId': assignedDeviceId,
      'assignedDeviceLabel': assignedDeviceLabel,
      'deviceAssignedAt': deviceAssignedAt?.toIso8601String(),
      'status': status,
      'terminationDate': terminationDate?.toIso8601String(),
      'terminationReason': terminationReason,
      'allowedLocations': allowedLocations.map((loc) => loc.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get formattedSalary => '${basicSalary.toStringAsFixed(2)} ريال';
  String get totalAllowances =>
      '${(housingAllowance + transportationAllowance + otherAllowances).toStringAsFixed(2)} ريال';
  String get totalSalary =>
      '${(basicSalary + housingAllowance + transportationAllowance + otherAllowances).toStringAsFixed(2)} ريال';

  bool get isActive => status == 'نشط';
  bool get hasFingerprint => fingerprintEnrolled;
  bool get hasFace => faceEnrolled;
  bool get hasDevice => assignedDeviceId != null && assignedDeviceId!.isNotEmpty;

  String get formattedContractEnd {
    if (contractEndDate == null) return 'غير محدد';
    return '${contractEndDate!.year}-${contractEndDate!.month.toString().padLeft(2, '0')}-${contractEndDate!.day.toString().padLeft(2, '0')}';
  }
}

class AllowedLocation {
  final String locationName;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isActive;

  AllowedLocation({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isActive,
  });

  factory AllowedLocation.fromJson(Map<String, dynamic> json) {
    return AllowedLocation(
      locationName: json['locationName'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
    };
  }
}

class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeNumber;
  final DateTime date;
  final AttendanceCheck? checkIn;
  final AttendanceCheck? checkOut;
  final double? totalHours;
  final double? overtimeHours;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNumber,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.totalHours,
    this.overtimeHours,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    final employeeRef = json['employeeId'];
    final employeeMap =
        employeeRef is Map ? Map<String, dynamic>.from(employeeRef) : null;
    return Attendance(
      id: json['_id'] ?? json['id'],
      employeeId: employeeMap?['_id'] ?? employeeRef ?? '',
      employeeName: employeeMap?['name'] ?? json['employeeName'] ?? '',
      employeeNumber:
          employeeMap?['employeeId'] ?? json['employeeNumber'] ?? '',
      date: DateTime.parse(json['date']).toLocal(),
      checkIn: json['checkIn'] != null
          ? AttendanceCheck.fromJson(json['checkIn'])
          : null,
      checkOut: json['checkOut'] != null
          ? AttendanceCheck.fromJson(json['checkOut'])
          : null,
      totalHours: (json['totalHours'] as num?)?.toDouble(),
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble(),
      status: json['status'] ?? 'غياب',
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  String get formattedDate =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String get formattedCheckIn => checkIn?.formattedTime ?? '--:--';
  String get formattedCheckOut => checkOut?.formattedTime ?? '--:--';
  String get formattedTotalHours => totalHours?.toStringAsFixed(2) ?? '0.00';

  bool get isPresent => status == 'حاضر' || status == 'متأخر';
  bool get isLate => checkIn?.isLate ?? false;
  bool get isEarly => checkOut?.isEarly ?? false;
}

class AttendanceCheck {
  final DateTime time;
  final Location? location;
  final bool isLate;
  final int? lateMinutes;
  final bool isEarly;
  final int? earlyMinutes;
  final bool isOutsideLocation;
  final String locationStatus;
  final String? deviceId;
  final double? fingerprintMatchScore;

  AttendanceCheck({
    required this.time,
    this.location,
    required this.isLate,
    required this.isEarly,
    this.lateMinutes,
    this.earlyMinutes,
    required this.isOutsideLocation,
    required this.locationStatus,
    this.deviceId,
    this.fingerprintMatchScore,
  });

  factory AttendanceCheck.fromJson(Map<String, dynamic> json) {
    return AttendanceCheck(
      time: DateTime.parse(json['time']).toLocal(),
    location: json['location'] != null
        ? Location.fromJson(json['location'])
        : null,
    isLate: json['isLate'] ?? false,
    lateMinutes: json['lateMinutes'],
    isEarly: json['isEarly'] ?? false,
    earlyMinutes: json['earlyMinutes'],
    isOutsideLocation: json['isOutsideLocation'] ?? false,
      locationStatus: json['locationStatus'] ?? 'غير مسجل',
      deviceId: json['deviceId'],
      fingerprintMatchScore: (json['fingerprintMatchScore'] as num?)
          ?.toDouble(),
    );
  }

  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class Location {
  final double latitude;
  final double longitude;
  final String address;

  Location({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] ?? 'موقع غير معروف',
    );
  }
}

class Salary {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeNumber;
  final int month;
  final int year;
  final double basicSalary;
  final double housingAllowance;
  final double transportationAllowance;
  final double otherAllowances;
  final double overtimeAmount;
  final double bonuses;
  final double incentives;
  final double totalEarnings;
  final List<SalaryDeduction> deductions;
  final double totalDeductions;
  final double netSalary;
  final String status;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? transactionReference;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Salary({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNumber,
    required this.month,
    required this.year,
    required this.basicSalary,
    required this.housingAllowance,
    required this.transportationAllowance,
    required this.otherAllowances,
    required this.overtimeAmount,
    required this.bonuses,
    required this.incentives,
    required this.totalEarnings,
    required this.deductions,
    required this.totalDeductions,
    required this.netSalary,
    required this.status,
    this.paymentDate,
    this.paymentMethod,
    this.transactionReference,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Salary.fromJson(Map<String, dynamic> json) {
    final employeeRef = json['employeeId'];
    final employeeMap =
        employeeRef is Map ? Map<String, dynamic>.from(employeeRef) : null;
    return Salary(
      id: json['_id'] ?? json['id'],
      employeeId: employeeMap?['_id'] ?? employeeRef ?? '',
      employeeName: employeeMap?['name'] ?? json['employeeName'] ?? '',
      employeeNumber:
          employeeMap?['employeeId'] ?? json['employeeNumber'] ?? '',
      month: json['month'],
      year: json['year'],
      basicSalary: (json['basicSalary'] as num).toDouble(),
      housingAllowance: (json['housingAllowance'] as num).toDouble(),
      transportationAllowance: (json['transportationAllowance'] as num)
          .toDouble(),
      otherAllowances: (json['otherAllowances'] as num).toDouble(),
      overtimeAmount: (json['overtimeAmount'] as num).toDouble(),
      bonuses: (json['bonuses'] as num).toDouble(),
      incentives: (json['incentives'] as num).toDouble(),
      totalEarnings: (json['totalEarnings'] as num).toDouble(),
      deductions: (json['deductions'] as List? ?? [])
          .map((d) => SalaryDeduction.fromJson(d))
          .toList(),
      totalDeductions: (json['totalDeductions'] as num).toDouble(),
      netSalary: (json['netSalary'] as num).toDouble(),
      status: json['status'] ?? 'مسودة',
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'])
          : null,
      paymentMethod: json['paymentMethod'],
      transactionReference: json['transactionReference'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  String get formattedMonthYear => '$month/$year';
  String get formattedNetSalary => '${netSalary.toStringAsFixed(2)} ريال';
  String get formattedTotalEarnings =>
      '${totalEarnings.toStringAsFixed(2)} ريال';
  String get formattedTotalDeductions =>
      '${totalDeductions.toStringAsFixed(2)} ريال';

  bool get isPaid => status == 'مصرف';
  bool get isApproved => status == 'معتمد';
  bool get isDraft => status == 'مسودة';
}

class SalaryDeduction {
  final String type;
  final String description;
  final double amount;
  final String? reference;

  SalaryDeduction({
    required this.type,
    required this.description,
    required this.amount,
    this.reference,
  });

  factory SalaryDeduction.fromJson(Map<String, dynamic> json) {
    return SalaryDeduction(
      type: json['type'],
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
      reference: json['reference'],
    );
  }

  String get formattedAmount => '${amount.toStringAsFixed(2)} ريال';
}

class Advance {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeNumber;
  final DateTime requestDate;
  final double amount;
  final String reason;
  final int repaymentMonths;
  final double monthlyInstallment;
  final String status;
  final DateTime? approvedAt;
  final String? approvalNotes;
  final DateTime? paidAt;
  final String? paymentMethod;
  final List<Repayment> repayments;
  final double remainingAmount;
  final DateTime? nextDueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Advance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNumber,
    required this.requestDate,
    required this.amount,
    required this.reason,
    required this.repaymentMonths,
    required this.monthlyInstallment,
    required this.status,
    this.approvedAt,
    this.approvalNotes,
    this.paidAt,
    this.paymentMethod,
    required this.repayments,
    required this.remainingAmount,
    this.nextDueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Advance.fromJson(Map<String, dynamic> json) {
    final employeeRef = json['employeeId'];
    final employeeMap =
        employeeRef is Map ? Map<String, dynamic>.from(employeeRef) : null;
    return Advance(
      id: json['_id'] ?? json['id'],
      employeeId: employeeMap?['_id'] ?? employeeRef ?? '',
      employeeName: employeeMap?['name'] ?? json['employeeName'] ?? '',
      employeeNumber:
          employeeMap?['employeeId'] ?? json['employeeNumber'] ?? '',
      requestDate: DateTime.parse(json['requestDate']),
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'],
      repaymentMonths: json['repaymentMonths'] ?? 1,
      monthlyInstallment: (json['monthlyInstallment'] as num).toDouble(),
      status: json['status'] ?? 'معلق',
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
      approvalNotes: json['approvalNotes'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      paymentMethod: json['paymentMethod'],
      repayments: (json['repayments'] as List? ?? [])
          .map((r) => Repayment.fromJson(r))
          .toList(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  String get formattedAmount => '${amount.toStringAsFixed(2)} ريال';
  String get formattedMonthlyInstallment =>
      '${monthlyInstallment.toStringAsFixed(2)} ريال';
  String get formattedRemainingAmount =>
      '${remainingAmount.toStringAsFixed(2)} ريال';
  String get formattedRequestDate =>
      '${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}-${requestDate.day.toString().padLeft(2, '0')}';

  bool get isPending => status == 'معلق';
  bool get isApproved => status == 'معتمد';
  bool get isPaid => status == 'مسدد';
  bool get isInstallment => status == 'قسط';
  bool get isOverdue => status == 'متأخر';

  int get completedRepayments =>
      repayments.where((r) => r.status == 'مسدد').length;
  int get totalRepayments => repayments.length;
  double get paidAmount => amount - remainingAmount;
}

class Repayment {
  final int month;
  final int year;
  final double amount;
  final DateTime? paidAt;
  final String? salaryId;
  final String status;

  Repayment({
    required this.month,
    required this.year,
    required this.amount,
    this.paidAt,
    this.salaryId,
    required this.status,
  });

  factory Repayment.fromJson(Map<String, dynamic> json) {
    return Repayment(
      month: json['month'],
      year: json['year'],
      amount: (json['amount'] as num).toDouble(),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      salaryId: json['salaryId'],
      status: json['status'] ?? 'مستحق',
    );
  }

  String get formattedAmount => '${amount.toStringAsFixed(2)} ريال';
  String get formattedMonthYear => '$month/$year';
  bool get isPaid => status == 'مسدد';
  bool get isDue => status == 'مستحق';
  bool get isOverdue => status == 'متأخر';
}

class Penalty {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeNumber;
  final DateTime date;
  final String type;
  final String description;
  final double amount;
  final bool deducted;
  final int? deductionMonth;
  final int? deductionYear;
  final String status;
  final String? issuedByName;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? approvalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Penalty({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNumber,
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.deducted,
    this.deductionMonth,
    this.deductionYear,
    required this.status,
    this.issuedByName,
    this.approvedByName,
    this.approvedAt,
    this.approvalNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Penalty.fromJson(Map<String, dynamic> json) {
    final employeeRef = json['employeeId'];
    final employeeMap =
        employeeRef is Map ? Map<String, dynamic>.from(employeeRef) : null;
    return Penalty(
      id: json['_id'] ?? json['id'],
      employeeId: employeeMap?['_id'] ?? employeeRef ?? '',
      employeeName: employeeMap?['name'] ?? json['employeeName'] ?? '',
      employeeNumber:
          employeeMap?['employeeId'] ?? json['employeeNumber'] ?? '',
      date: DateTime.parse(json['date']),
      type: json['type'],
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
      deducted: json['deducted'] ?? false,
      deductionMonth: json['deductionMonth'],
      deductionYear: json['deductionYear'],
      status: json['status'] ?? 'معلق',
      issuedByName: json['issuedBy']?['name'] ?? json['issuedByName'],
      approvedByName: json['approvedBy']?['name'] ?? json['approvedByName'],
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
      approvalNotes: json['approvalNotes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  String get formattedAmount => '${amount.toStringAsFixed(2)} ريال';
  String get formattedDate =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool get isPending => status == 'معلق';
  bool get isApplied => status == 'مطبق';
  bool get isCancelled => status == 'ملغي';
  bool get isRefunded => status == 'مسترد';
}

class WorkLocation {
  final String id;
  final String name;
  final String code;
  final String type;
  final String address;
  final LocationCoordinates coordinates;
  final double radius;
  final WorkingHours workingHours;
  final List<String> offDays;
  final LocationSettings settings;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkLocation({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.address,
    required this.coordinates,
    required this.radius,
    required this.workingHours,
    required this.offDays,
    required this.settings,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkLocation.fromJson(Map<String, dynamic> json) {
    return WorkLocation(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      code: json['code'],
      type: json['type'],
      address: json['address'],
      coordinates: LocationCoordinates.fromJson(json['coordinates']),
      radius: (json['radius'] as num).toDouble(),
      workingHours: WorkingHours.fromJson(json['workingHours']),
      offDays: List<String>.from(json['offDays'] ?? []),
      settings: LocationSettings.fromJson(json['settings'] ?? {}),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  String get formattedWorkingHours =>
      '${workingHours.start} - ${workingHours.end}';
  String get formattedOffDays =>
      offDays.isNotEmpty ? offDays.join('، ') : 'لا توجد';
}

class LocationCoordinates {
  final double latitude;
  final double longitude;

  LocationCoordinates({required this.latitude, required this.longitude});

  factory LocationCoordinates.fromJson(Map<String, dynamic> json) {
    return LocationCoordinates(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class WorkingHours {
  final String start;
  final String end;
  final bool flexible;

  WorkingHours({
    required this.start,
    required this.end,
    required this.flexible,
  });

  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    return WorkingHours(
      start: json['start'],
      end: json['end'],
      flexible: json['flexible'] ?? false,
    );
  }
}

class LocationSettings {
  final bool requireLocation;
  final bool allowRemote;
  final double maxDistance;

  LocationSettings({
    required this.requireLocation,
    required this.allowRemote,
    required this.maxDistance,
  });

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    return LocationSettings(
      requireLocation: json['requireLocation'] ?? true,
      allowRemote: json['allowRemote'] ?? false,
      maxDistance: (json['maxDistance'] as num?)?.toDouble() ?? 500.0,
    );
  }
}

// ===========================================
// 📌 إحصائيات نظام شؤون الموظفين
// ===========================================

class HRDashboardStats {
  final int totalEmployees;
  final int activeEmployees;
  final int onLeaveEmployees;
  final int terminatedEmployees;
  final int presentToday;
  final int absentToday;
  final int lateToday;
  final double totalSalariesThisMonth;
  final double totalAdvancesDue;
  final int pendingAdvances;
  final int pendingPenalties;
  final int contractExpiringThisMonth;
  final int residencyExpiringThisMonth;

  HRDashboardStats({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.onLeaveEmployees,
    required this.terminatedEmployees,
    required this.presentToday,
    required this.absentToday,
    required this.lateToday,
    required this.totalSalariesThisMonth,
    required this.totalAdvancesDue,
    required this.pendingAdvances,
    required this.pendingPenalties,
    required this.contractExpiringThisMonth,
    required this.residencyExpiringThisMonth,
  });

  factory HRDashboardStats.fromJson(Map<String, dynamic> json) {
    return HRDashboardStats(
      totalEmployees: json['totalEmployees'] ?? 0,
      activeEmployees: json['activeEmployees'] ?? 0,
      onLeaveEmployees: json['onLeaveEmployees'] ?? 0,
      terminatedEmployees: json['terminatedEmployees'] ?? 0,
      presentToday: json['presentToday'] ?? 0,
      absentToday: json['absentToday'] ?? 0,
      lateToday: json['lateToday'] ?? 0,
      totalSalariesThisMonth:
          (json['totalSalariesThisMonth'] as num?)?.toDouble() ?? 0.0,
      totalAdvancesDue: (json['totalAdvancesDue'] as num?)?.toDouble() ?? 0.0,
      pendingAdvances: json['pendingAdvances'] ?? 0,
      pendingPenalties: json['pendingPenalties'] ?? 0,
      contractExpiringThisMonth: json['contractExpiringThisMonth'] ?? 0,
      residencyExpiringThisMonth: json['residencyExpiringThisMonth'] ?? 0,
    );
  }
}

class AttendanceStats {
  final int totalDays;
  final int workingDays;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int leaveDays;
  final double totalHours;
  final double overtimeHours;
  final String attendanceRate;

  AttendanceStats({
    required this.totalDays,
    required this.workingDays,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.leaveDays,
    required this.totalHours,
    required this.overtimeHours,
    required this.attendanceRate,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalDays: json['totalDays'] ?? 0,
      workingDays: json['workingDays'] ?? 0,
      presentDays: json['presentDays'] ?? 0,
      lateDays: json['lateDays'] ?? 0,
      absentDays: json['absentDays'] ?? 0,
      leaveDays: json['leaveDays'] ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      attendanceRate: json['attendanceRate'] ?? '0%',
    );
  }
}

// ===========================================
// 📌 طلبات نظام البصمة
// ===========================================

class FingerprintAttendanceRequest {
  final String fingerprintData;
  final double? latitude;
  final double? longitude;
  final String deviceId;
  final String type; // checkin أو checkout

  FingerprintAttendanceRequest({
    required this.fingerprintData,
    this.latitude,
    this.longitude,
    required this.deviceId,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'fingerprintData': fingerprintData,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'deviceId': deviceId,
    };
  }
}

class FingerprintAttendanceResponse {
  final bool success;
  final String message;
  final String? employeeId;
  final String? employeeName;
  final DateTime? time;
  final String? locationStatus;
  final String? attendanceId;

  FingerprintAttendanceResponse({
    required this.success,
    required this.message,
    this.employeeId,
    this.employeeName,
    this.time,
    this.locationStatus,
    this.attendanceId,
  });

  factory FingerprintAttendanceResponse.fromJson(Map<String, dynamic> json) {
    return FingerprintAttendanceResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      employeeId: json['data']?['employeeId'],
      employeeName: json['data']?['employeeName'],
      time: json['data']?['time'] != null
          ? DateTime.parse(json['data']['time'])
          : null,
      locationStatus: json['data']?['locationStatus'],
      attendanceId: json['data']?['attendanceId'],
    );
  }
}

class FingerprintEnrollmentRequest {
  final String employeeId;
  final String fingerprintData;

  FingerprintEnrollmentRequest({
    required this.employeeId,
    required this.fingerprintData,
  });

  Map<String, dynamic> toJson() {
    return {'fingerprintData': fingerprintData};
  }
}

class DeviceEnrollmentRequest {
  final String id;
  final String employeeId;
  final String? employeeRefId;
  final String? employeeName;
  final String deviceId;
  final String? deviceLabel;
  final String status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? approvedByName;
  final String? rejectedByName;

  DeviceEnrollmentRequest({
    required this.id,
    required this.employeeId,
    this.employeeRefId,
    this.employeeName,
    required this.deviceId,
    this.deviceLabel,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.approvedByName,
    this.rejectedByName,
  });

  factory DeviceEnrollmentRequest.fromJson(Map<String, dynamic> json) {
    final employeeRef = json['employeeRef'];
    final approvedBy = json['approvedBy'];
    final rejectedBy = json['rejectedBy'];
    return DeviceEnrollmentRequest(
      id: json['_id'] ?? json['id'],
      employeeId: employeeRef?['employeeId'] ?? json['employeeId'] ?? '',
      employeeRefId: employeeRef?['_id'] ?? json['employeeRef'],
      employeeName: employeeRef?['name'] ?? json['employeeName'],
      deviceId: json['deviceId'] ?? '',
      deviceLabel: json['deviceLabel'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt']),
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.parse(json['rejectedAt'])
          : null,
      rejectionReason: json['rejectionReason'],
      approvedByName: approvedBy?['name'],
      rejectedByName: rejectedBy?['name'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
