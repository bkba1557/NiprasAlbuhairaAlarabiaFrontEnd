import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/services/firebase_storage_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/employee/form_sections/personal_info_section.dart';
import 'package:order_tracker/widgets/hr/employee/form_sections/employment_info_section.dart';
import 'package:order_tracker/widgets/hr/employee/form_sections/financial_info_section.dart';
import 'package:order_tracker/widgets/hr/employee/form_sections/documents_section.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employeeToEdit;

  const EmployeeFormScreen({super.key, this.employeeToEdit});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  late HRProvider _hrProvider;
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // معلومات شخصية
  String _name = '';
  String _nameEnglish = '';
  String _nationalId = '';
  String _gender = 'ذكر';
  DateTime? _dateOfBirth;
  String _nationality = '';
  String _city = '';
  String _phone = '';
  String _email = '';
  String? _address;

  // معلومات التوظيف
  String _department = '';
  String _position = '';
  String? _jobTitle;
  String _employmentType = 'دائم';
  DateTime? _hireDate;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  DateTime? _probationPeriodEnd;
  String _workSchedule = 'دوام كامل';
  int _weeklyHours = 48;

  // معلومات الإقامة
  String? _residencyNumber;
  DateTime? _residencyIssueDate;
  DateTime? _residencyExpiryDate;
  String? _passportNumber;
  DateTime? _passportExpiryDate;

  // معلومات مالية
  double _basicSalary = 0;
  double _housingAllowance = 0;
  double _transportationAllowance = 0;
  double _otherAllowances = 0;
  String? _bankName;
  String? _iban;
  String? _accountNumber;

  // الوثائق
  List<Map<String, dynamic>> _documents = [];

  // مواقع العمل
  List<String> _selectedLocationIds = [];

  bool _isLoading = false;
  bool _isUploadingDocuments = false;
  late final String _documentUploadKey;

  @override
  void initState() {
    super.initState();
    _documentUploadKey = widget.employeeToEdit?.id ??
        'draft_${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFormData();
      _loadLocations();
    });
  }

  Future<void> _loadLocations() async {
    final provider = Provider.of<HRProvider>(context, listen: false);
    await provider.fetchLocations();

    if (widget.employeeToEdit != null) {
      final allowedNames = widget.employeeToEdit!.allowedLocations
          .map((loc) => loc.locationName)
          .toSet();
      _selectedLocationIds = provider.locations
          .where((loc) => allowedNames.contains(loc.name))
          .map((loc) => loc.id)
          .toList();
    }

    if (mounted) setState(() {});
  }

  void _initializeFormData() {
    if (widget.employeeToEdit != null) {
      final employee = widget.employeeToEdit!;

      // معلومات شخصية
      _name = employee.name;
      _nameEnglish = employee.nameEnglish;
      _nationalId = employee.nationalId;
      _gender = employee.gender;
      _dateOfBirth = employee.dateOfBirth;
      _nationality = employee.nationality;
      _city = employee.city;
      _phone = employee.phone;
      _email = employee.email;
      _address = employee.address;

      // معلومات التوظيف
      _department = employee.department;
      _position = employee.position;
      _jobTitle = employee.jobTitle;
      _employmentType = employee.employmentType;
      _hireDate = employee.hireDate;
      _contractStartDate = employee.contractStartDate;
      _contractEndDate = employee.contractEndDate;
      _probationPeriodEnd = employee.probationPeriodEnd;
      _workSchedule = employee.workSchedule;
      _weeklyHours = employee.weeklyHours;

      // معلومات الإقامة
      _residencyNumber = employee.residencyNumber;
      _residencyIssueDate = employee.residencyIssueDate;
      _residencyExpiryDate = employee.residencyExpiryDate;
      _passportNumber = employee.passportNumber;
      _passportExpiryDate = employee.passportExpiryDate;

      // معلومات مالية
      _basicSalary = employee.basicSalary;
      _housingAllowance = employee.housingAllowance;
      _transportationAllowance = employee.transportationAllowance;
      _otherAllowances = employee.otherAllowances;
      _bankName = employee.bankName;
      _iban = employee.iban;
      _accountNumber = employee.accountNumber;

      // مواقع العمل
      // سيتم تحميلها من API
    }
  }


    String _docTypeLabel(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'PDF';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '????';
      case 'doc':
      case 'docx':
        return 'Word';
      default:
        return '?????';
    }
  }


  String? _contentTypeForFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return null;
    }
  }

  Future<void> _pickAndUploadDocuments() async {
    if (_isUploadingDocuments) return;
    setState(() {
      _isUploadingDocuments = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final updated = List<Map<String, dynamic>>.from(_documents);

      for (final file in result.files) {
        final fileName = file.name;
        final contentType = _contentTypeForFile(fileName);

        late final String url;
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes == null) {
            throw Exception('???? ????? ?????');
          }
          url = await FirebaseStorageService.uploadEmployeeDocument(
            employeeKey: _documentUploadKey,
            fileName: fileName,
            webBytes: bytes,
            contentType: contentType,
          );
        } else {
          final path = file.path;
          if (path == null) {
            throw Exception('???? ????? ??? ?????');
          }
          url = await FirebaseStorageService.uploadEmployeeDocument(
            employeeKey: _documentUploadKey,
            fileName: fileName,
            filePath: path,
            contentType: contentType,
          );
        }

        updated.add({
          'name': fileName,
          'type': _docTypeLabel(fileName),
          'url': url,
          'size': file.size,
        });
      }

      if (!mounted) return;
      setState(() {
        _documents = updated;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('??? ??? ?????????: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDocuments = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _hrProvider = Provider.of<HRProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.employeeToEdit == null
              ? 'إضافة موظف جديد'
              : 'تعديل بيانات الموظف',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 4,
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _previousStep,
              tooltip: 'الخطوة السابقة',
            ),
          if (_currentStep < 3)
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _nextStep,
              tooltip: 'الخطوة التالية',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // مؤشر الخطوات
            _buildStepIndicator(),

            // محتوى النموذج
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                children: [
                  // الخطوة 1: المعلومات الشخصية
                  PersonalInfoSection(
                    name: _name,
                    nameEnglish: _nameEnglish,
                    nationalId: _nationalId,
                    gender: _gender,
                    dateOfBirth: _dateOfBirth,
                    nationality: _nationality,
                    city: _city,
                    phone: _phone,
                    email: _email,
                    address: _address,
                    onNameChanged: (value) => _name = value,
                    onNameEnglishChanged: (value) => _nameEnglish = value,
                    onNationalIdChanged: (value) => _nationalId = value,
                    onGenderChanged: (value) => _gender = value,
                    onDateOfBirthChanged: (value) {
                    setState(() {
                      _dateOfBirth = value;
                    });
                  },
                    onNationalityChanged: (value) => _nationality = value,
                    onCityChanged: (value) => _city = value,
                    onPhoneChanged: (value) => _phone = value,
                    onEmailChanged: (value) => _email = value,
                    onAddressChanged: (value) => _address = value,
                  ),

                  // الخطوة 2: معلومات التوظيف
                  EmploymentInfoSection(
                    department: _department,
                    position: _position,
                    jobTitle: _jobTitle,
                    employmentType: _employmentType,
                    hireDate: _hireDate,
                    contractStartDate: _contractStartDate,
                    contractEndDate: _contractEndDate,
                    probationPeriodEnd: _probationPeriodEnd,
                    workSchedule: _workSchedule,
                    weeklyHours: _weeklyHours,
                    residencyNumber: _residencyNumber,
                    residencyIssueDate: _residencyIssueDate,
                    residencyExpiryDate: _residencyExpiryDate,
                    passportNumber: _passportNumber,
                    passportExpiryDate: _passportExpiryDate,
                    onDepartmentChanged: (value) => _department = value,
                    onPositionChanged: (value) => _position = value,
                    onJobTitleChanged: (value) => _jobTitle = value,
                    onEmploymentTypeChanged: (value) => _employmentType = value,
                    onHireDateChanged: (value) {
                        setState(() {
                          _hireDate = value;
                        });
                      },
                    onContractStartDateChanged: (value) {
                        setState(() {
                          _contractStartDate = value;
                        });
                      },
                    onContractEndDateChanged: (value) {
                        setState(() {
                          _contractEndDate = value;
                        });
                      },
                    onProbationPeriodEndChanged: (value) {
                        setState(() {
                          _probationPeriodEnd = value;
                        });
                      },
                    onWorkScheduleChanged: (value) => _workSchedule = value,
                    onWeeklyHoursChanged: (value) => _weeklyHours = value,
                    onResidencyNumberChanged: (value) =>
                        _residencyNumber = value,
                    onResidencyIssueDateChanged: (value) {
                        setState(() {
                          _residencyIssueDate = value;
                        });
                      },
                    onResidencyExpiryDateChanged: (value) {
                        setState(() {
                          _residencyExpiryDate = value;
                        });
                      },
                    onPassportNumberChanged: (value) => _passportNumber = value,
                    onPassportExpiryDateChanged: (value) {
                        setState(() {
                          _passportExpiryDate = value;
                        });
                      },
                  ),

                  // الخطوة 3: المعلومات المالية
                  FinancialInfoSection(
                    basicSalary: _basicSalary,
                    housingAllowance: _housingAllowance,
                    transportationAllowance: _transportationAllowance,
                    otherAllowances: _otherAllowances,
                    bankName: _bankName,
                    iban: _iban,
                    accountNumber: _accountNumber,
                    selectedLocationIds: _selectedLocationIds,
                    availableLocations: _hrProvider.locations,
                    onBasicSalaryChanged: (value) => _basicSalary = value,
                    onHousingAllowanceChanged: (value) =>
                        _housingAllowance = value,
                    onTransportationAllowanceChanged: (value) =>
                        _transportationAllowance = value,
                    onOtherAllowancesChanged: (value) =>
                        _otherAllowances = value,
                    onBankNameChanged: (value) => _bankName = value,
                    onIbanChanged: (value) => _iban = value,
                    onAccountNumberChanged: (value) => _accountNumber = value,
                    onLocationsChanged: (value) => _selectedLocationIds = value,
                  ),

                  // الخطوة 4: الوثائق
                  DocumentsSection(
                    documents: _documents,
                    onDocumentsChanged: (value) {
                      setState(() {
                        _documents = value;
                      });
                    },
                    onAddDocument: _pickAndUploadDocuments,
                    isUploading: _isUploadingDocuments,
                  ),
                ],
              ),
            ),

            // أزرار التنقل
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = [
      'المعلومات الشخصية',
      'معلومات التوظيف',
      'المعلومات المالية',
      'الوثائق',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.hrPurple
                            : isCompleted
                            ? AppColors.successGreen
                            : AppColors.lightGray,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.darkGray,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.successGreen
                              : AppColors.lightGray,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppColors.hrPurple : AppColors.mediumGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.lightGray)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.hrPurple),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, size: 20),
                    SizedBox(width: 8),
                    Text('السابق'),
                  ],
                ),
              ),
            ),

          if (_currentStep > 0) const SizedBox(width: 12),

          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hrPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: AppColors.hrPurple.withOpacity(0.5),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == 3 ? 'حفظ' : 'التالي',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_currentStep < 3) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _handleSubmit();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_name.isEmpty ||
            _nationalId.isEmpty ||
            _phone.isEmpty ||
            _email.isEmpty ||
            _nationality.isEmpty ||
            _city.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('???? ??? ???? ?????? ????????'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        if (_dateOfBirth == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('????? ??????? ?????'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        if (_nationalId.length != 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('??? ?????? ??? ?? ???? 10 ?????'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        return true;
      case 1:
        if (_department.isEmpty ||
            _position.isEmpty ||
            _employmentType.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('???? ??? ???? ?????? ????????'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        if (_hireDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('????? ??????? ?????'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        if (_contractStartDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('????? ????? ??????'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        return true;

      case 2:


        if (_basicSalary <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الراتب الأساسي يجب أن يكون أكبر من صفر'),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return false;
        }
        return true;

      case 3:
        return true;

      default:
        return false;
    }
  }


  void _goToStep(int step) {
    if (_currentStep == step) return;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

      bool _validateAllRequired() {
    if (_name.isEmpty ||
        _nationalId.isEmpty ||
        _phone.isEmpty ||
        _email.isEmpty ||
        _nationality.isEmpty ||
        _city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('???? ??? ???? ?????? ????????'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(0);
      return false;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('????? ??????? ?????'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(0);
      return false;
    }

    if (_nationalId.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('??? ?????? ??? ?? ???? 10 ?????'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(0);
      return false;
    }

    if (_department.isEmpty ||
        _position.isEmpty ||
        _employmentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('???? ??? ???? ?????? ????????'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(1);
      return false;
    }

    if (_hireDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('????? ??????? ?????'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(1);
      return false;
    }

    if (_contractStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('????? ????? ??????'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(1);
      return false;
    }

    if (_basicSalary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('?????? ??????? ??? ?? ???? ???? ?? ???'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _goToStep(2);
      return false;
    }

    return true;
  }



  Future<void> _handleSubmit() async {
    if (_currentStep < 3) {
      if (!_validateCurrentStep()) {
        return;
      }
      _nextStep();
      return;
    }

    if (!_validateAllRequired()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final employeeData = {
        // معلومات شخصية
        'name': _name,
        'nameEnglish': _nameEnglish,
        'nationalId': _nationalId,
        'gender': _gender,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'nationality': _nationality,
        'city': _city,
        'phone': _phone,
        'email': _email,
        'address': _address,

        // معلومات التوظيف
        'department': _department,
        'position': _position,
        'jobTitle': _jobTitle,
        'employmentType': _employmentType,
        'hireDate': _hireDate?.toIso8601String(),
        'contractStartDate': _contractStartDate?.toIso8601String(),
        'contractEndDate': _contractEndDate?.toIso8601String(),
        'probationPeriodEnd': _probationPeriodEnd?.toIso8601String(),
        'workSchedule': _workSchedule,
        'weeklyHours': _weeklyHours,

        // معلومات الإقامة
        'residencyNumber': _residencyNumber,
        'residencyIssueDate': _residencyIssueDate?.toIso8601String(),
        'residencyExpiryDate': _residencyExpiryDate?.toIso8601String(),
        'passportNumber': _passportNumber,
        'passportExpiryDate': _passportExpiryDate?.toIso8601String(),

        // معلومات مالية
        'basicSalary': _basicSalary,
        'housingAllowance': _housingAllowance,
        'transportationAllowance': _transportationAllowance,
        'otherAllowances': _otherAllowances,
        'bankName': _bankName,
        'iban': _iban,
        'accountNumber': _accountNumber,

        // مواقع العمل
        'locationIds': _selectedLocationIds,

        // الوثائق
        'documents': _documents
            .where((doc) => (doc['url'] ?? '').toString().isNotEmpty)
            .map((doc) => {
                  'name': doc['name'],
                  'type': doc['type'],
                  'url': doc['url'],
                })
            .toList(),
      };

      if (widget.employeeToEdit == null) {
        await _hrProvider.createEmployee(employeeData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الموظف بنجاح'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } else {
        await _hrProvider.updateEmployee(
          widget.employeeToEdit!.id,
          employeeData,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث بيانات الموظف بنجاح'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
