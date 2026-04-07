import 'package:flutter/material.dart';
import 'package:order_tracker/utils/api_config.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF1A2980);
  static const Color primaryDarkBlue = Color(0xFF0F1A5C);
  static const Color accentBlue = Color(0xFF4A6EE0);
  static const Color glassBlue = Color(0x664A6EE0);

  static const Color secondaryTeal = Color(0xFF26D0CE);
  static const Color lightTeal = Color(0xFF6DF5F4);

  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);
  static const Color pendingYellow = Color(0xFFFFC107);
  static const Color statusGold = Color(0xFFD4AF37);

  static const Color darkGray = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightGray = Color(0xFF999999);
  static const Color backgroundGray = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color silver = Color(0xFFC2C6CC);
  static const Color silverLight = Color(0xFFE5E7EB);
  static const Color silverDark = Color(0xFFA6ABB2);
  static const Color silverGlow = Color(0xFFF7F8FA);
  static const Color appBarBlue = Color(0xFF1D4ED8);
  static const Color appBarNavy = Color(0xFF0B1F4B);
  static const Color appBarWaterDeep = Color(0xFF071B3F);
  static const Color appBarWaterMid = Color(0xFF0F4C9A);
  static const Color appBarWaterBright = Color(0xFF2F7CFF);
  static const Color appBarWaterGlow = Color(0xFF6BCBFF);

  static const Color hrPurple = Color(0xFF9C27B0);
  static const Color hrLightPurple = Color(0xFFE1BEE7);
  static const Color hrDarkPurple = Color(0xFF7B1FA2);
  static const Color hrCyan = Color(0xFF00BCD4);
  static const Color hrLightCyan = Color(0xFFB2EBF2);
  static const Color hrAmber = Color(0xFFFFC107);
  static const Color hrLightAmber = Color(0xFFFFECB3);
  static const Color hrDeepOrange = Color(0xFFFF5722);
  static const Color hrLightOrange = Color(0xFFFFCCBC);
  static const Color hrPink = Color(0xFFE91E63);
  static const Color hrLightPink = Color(0xFFF8BBD0);
  static const Color hrIndigo = Color(0xFF3F51B5);
  static const Color hrLightIndigo = Color(0xFFC5CAE9);
  static const Color hrTeal = Color(0xFF009688);
  static const Color hrLightTeal = Color(0xFFB2DFDB);

  static const Color attendancePresent = Color(0xFF4CAF50);
  static const Color attendanceLate = Color(0xFFFF9800);
  static const Color attendanceAbsent = Color(0xFFF44336);
  static const Color attendanceLeave = Color(0xFF2196F3);
  static const Color attendanceEarly = Color(0xFFFFC107);
  static const Color attendancePending = Color(0xFF9E9E9E);

  static const Color salaryDraft = Color(0xFF9E9E9E);
  static const Color salaryApproved = Color(0xFF2196F3);
  static const Color salaryPaid = Color(0xFF4CAF50);
  static const Color salaryCancelled = Color(0xFFF44336);

  static const Color advancePending = Color(0xFFFFC107);
  static const Color advanceApproved = Color(0xFF2196F3);
  static const Color advancePaid = Color(0xFF4CAF50);
  static const Color advanceInstallment = Color(0xFF9C27B0);
  static const Color advanceOverdue = Color(0xFFF44336);
  static const Color advanceRejected = Color(0xFF9E9E9E);

  static const Color penaltyPending = Color(0xFFFFC107);
  static const Color penaltyApplied = Color(0xFF2196F3);
  static const Color penaltyCancelled = Color(0xFF9E9E9E);
  static const Color penaltyRefunded = Color(0xFF4CAF50);

  static const Color employeeActive = Color(0xFF4CAF50);
  static const Color employeeSuspended = Color(0xFFFF9800);
  static const Color employeeResigned = Color(0xFF2196F3);
  static const Color employeeTerminated = Color(0xFFF44336);
  static const Color employeeOnLeave = Color(0xFF9C27B0);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [primaryBlue, primaryDarkBlue],
  );

  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [appBarWaterDeep, appBarWaterMid, appBarWaterBright],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [appBarWaterDeep, appBarWaterMid, appBarWaterBright],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentBlue, secondaryTeal],
  );

  static const LinearGradient silverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [silverGlow, silverLight, silver],
  );

  static const LinearGradient hrGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [hrPurple, hrDarkPurple],
  );

  static const LinearGradient attendanceGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [hrCyan, hrTeal],
  );
}

class _ModernPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ModernPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primaryBlue,
    primaryColorDark: AppColors.primaryDarkBlue,
    primaryColorLight: AppColors.accentBlue,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _ModernPageTransitionsBuilder(),
        TargetPlatform.iOS: _ModernPageTransitionsBuilder(),
        TargetPlatform.linux: _ModernPageTransitionsBuilder(),
        TargetPlatform.macOS: _ModernPageTransitionsBuilder(),
        TargetPlatform.windows: _ModernPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _ModernPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryBlue,
      secondary: AppColors.secondaryTeal,
      background: AppColors.backgroundGray,
      surface: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.backgroundGray,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
      ),
      iconTheme: IconThemeData(color: AppColors.white),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 32,
        fontWeight: FontWeight.w500,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 24,
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(fontFamily: 'Cairo', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'Cairo', fontSize: 14),
      bodySmall: TextStyle(fontFamily: 'Cairo', fontSize: 12),
      labelLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(fontFamily: 'Cairo', fontSize: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.mediumGray),
      labelStyle: const TextStyle(color: AppColors.primaryBlue),
      errorStyle: const TextStyle(color: AppColors.errorRed),
    ),
    buttonTheme: const ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            backgroundColor: AppColors.appBarWaterMid,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.appBarWaterMid.withOpacity(0.35),
            disabledForegroundColor: AppColors.white.withOpacity(0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            overlayColor: MaterialStateProperty.all(
              AppColors.appBarWaterGlow.withOpacity(0.22),
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.appBarWaterMid,
        side: const BorderSide(color: AppColors.appBarWaterMid, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.appBarWaterMid,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.appBarWaterMid,
      foregroundColor: AppColors.white,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightGray,
      thickness: 1,
      space: 1,
    ),
  );

  static final ThemeData darkTheme = lightTheme;
}

class AppStrings {
  static const String appName = 'نظام متابعة طلبات الوقود';
  static const String hrSystemName = 'نظام شؤون الموظفين';
  static const String login = 'تسجيل الدخول';
  static const String register = 'تسجيل حساب جديد';
  static const String email = 'البريد الإلكتروني';
  static const String password = 'كلمة المرور';
  static const String name = 'الاسم الكامل';
  static const String suppliers = 'الموردين';
  static const String newSupplier = 'مورد جديد';
  static const String supplierDetails = 'تفاصيل المورد';
  static const String supplierType = 'نوع المورد';
  static const String contactPerson = 'جهة الاتصال';
  static const String company = 'الشركة';
  static const String phone = 'رقم الهاتف';
  static const String confirmPassword = 'تأكيد كلمة المرور';
  static const String forgotPassword = 'نسيت كلمة المرور؟';
  static const String dontHaveAccount = 'ليس لديك حساب؟';
  static const String alreadyHaveAccount = 'لديك حساب بالفعل؟';
  static const String loginNow = 'تسجيل الدخول الآن';
  static const String registerNow = 'إنشاء حساب جديد';
  static const String dashboard = 'لوحة التحكم';
  static const String orders = 'الطلبات';
  static const String newOrder = 'طلب جديد';
  static const String editOrder = 'تعديل طلب';
  static const String orderDetails = 'تفاصيل الطلب';
  static const String activities = 'الحركات';
  static const String reports = 'التقارير';
  static const String settings = 'الإعدادات';
  static const String profile = 'الملف الشخصي';
  static const String logout = 'تسجيل الخروج';
  static const String search = 'بحث...';
  static const String filter = 'تصفية';
  static const String clearFilter = 'مسح الفلاتر';
  static const String export = 'تصدير';
  static const String print = 'طباعة';
  static const String pdf = 'PDF';
  static const String save = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String view = 'عرض';
  static const String add = 'إضافة';
  static const String update = 'تحديث';
  static const String create = 'إنشاء';
  static const String submit = 'إرسال';
  static const String back = 'رجوع';
  static const String next = 'التالي';
  static const String previous = 'السابق';
  static const String loading = 'جاري التحميل...';
  static const String noData = 'لا توجد بيانات';
  static const String error = 'حدث خطأ';
  static const String success = 'تم بنجاح';
  static const String warning = 'تحذير';
  static const String info = 'معلومة';
  static const String confirm = 'تأكيد';
  static const String areYouSure = 'هل أنت متأكد؟';
  static const String yes = 'نعم';
  static const String no = 'لا';
  static const String ok = 'موافق';
  static const String close = 'إغلاق';
  static const String select = 'اختر';
  static const String date = 'التاريخ';
  static const String time = 'الوقت';
  static const String from = 'من';
  static const String to = 'إلى';
  static const String all = 'الكل';
  static const String status = 'الحالة';
  static const String type = 'النوع';
  static const String quantity = 'الكمية';
  static const String unit = 'الوحدة';
  static const String notes = 'ملاحظات';
  static const String attachment = 'مرفق';
  static const String attachments = 'المرفقات';
  static const String upload = 'رفع';
  static const String download = 'تحميل';
  static const String preview = 'معاينة';
  static const String deleteAttachment = 'حذف المرفق';
  static const String logo = 'الشعار';
  static const String uploadLogo = 'رفع شعار';
  static const String changeLogo = 'تغيير الشعار';
  static const String removeLogo = 'إزالة الشعار';
  static const String driver = 'السائق';
  static const String driverName = 'اسم السائق';
  static const String driverPhone = 'هاتف السائق';
  static const String vehicle = 'المركبة';
  static const String vehicleNumber = 'رقم المركبة';
  static const String fuelType = 'نوع الوقود';
  static const String orderNumber = 'رقم الطلب';
  static const String orderDate = 'تاريخ الطلب';
  static const String supplier = 'المورد';
  static const String supplierName = 'اسم المورد';
  static const String requestType = 'نوع الطلب';
  static const String loadingDate = 'تاريخ التحميل';
  static const String orderStatus = 'حالة الطلب';
  static const String createdBy = 'تم الإنشاء بواسطة';
  static const String createdAt = 'تاريخ الإنشاء';
  static const String updatedAt = 'تاريخ التحديث';
  static const String activityLog = 'سجل الحركات';
  static const String activityType = 'نوع الحركة';
  static const String activityDescription = 'وصف الحركة';
  static const String performedBy = 'تمت بواسطة';
  static const String performedAt = 'تاريخ التنفيذ';
  static const String changes = 'التغييرات';
  static const String exportToPdf = 'تصدير إلى PDF';
  static const String exportToExcel = 'تصدير إلى Excel';
  static const String printReport = 'طباعة التقرير';
  static const String totalOrders = 'إجمالي الطلبات';
  static const String pendingOrders = 'الطلبات المعلقة';
  static const String completedOrders = 'الطلبات المكتملة';
  static const String todayOrders = 'طلبات اليوم';
  static const String thisWeekOrders = 'طلبات هذا الأسبوع';
  static const String thisMonthOrders = 'طلبات هذا الشهر';
  static const String statistics = 'إحصائيات';
  static const String charts = 'الرسوم البيانية';
  static const String summary = 'ملخص';
  static const String details = 'تفاصيل';
  static const String actions = 'الإجراءات';

  static const String hrDashboard = 'لوحة تحكم شؤون الموظفين';
  static const String employees = 'الموظفين';
  static const String employee = 'الموظف';
  static const String newEmployee = 'موظف جديد';
  static const String editEmployee = 'تعديل بيانات الموظف';
  static const String employeeDetails = 'تفاصيل الموظف';
  static const String employeeNumber = 'رقم الموظف';
  static const String nationalId = 'رقم الهوية الوطنية';
  static const String dateOfBirth = 'تاريخ الميلاد';
  static const String nationality = 'الجنسية';
  static const String city = 'المدينة';
  static const String gender = 'الجنس';
  static const String male = 'ذكر';
  static const String female = 'أنثى';
  static const String department = 'القسم';
  static const String position = 'الوظيفة';
  static const String jobTitle = 'المسمى الوظيفي';
  static const String employmentType = 'نوع التوظيف';
  static const String permanent = 'دائم';
  static const String temporary = 'مؤقت';
  static const String contract = 'عقد';
  static const String training = 'تدريب';
  static const String hireDate = 'تاريخ التعيين';
  static const String contractStartDate = 'تاريخ بداية العقد';
  static const String contractEndDate = 'تاريخ نهاية العقد';
  static const String probationPeriodEnd = 'نهاية فترة التجربة';
  static const String workSchedule = 'جدول العمل';
  static const String fullTime = 'دوام كامل';
  static const String partTime = 'دوام جزئي';
  static const String shifts = 'ورديات';
  static const String weeklyHours = 'ساعات العمل الأسبوعية';
  static const String basicSalary = 'الراتب الأساسي';
  static const String housingAllowance = 'بدل السكن';
  static const String transportationAllowance = 'بدل المواصلات';
  static const String otherAllowances = 'بدلات أخرى';
  static const String totalSalary = 'إجمالي الراتب';
  static const String bankName = 'اسم البنك';
  static const String iban = 'رقم الآيبان';
  static const String accountNumber = 'رقم الحساب';
  static const String fingerprint = 'البصمة';
  static const String fingerprintEnrollment = 'تسجيل البصمة';
  static const String fingerprintEnrolled = 'مسجلة';
  static const String fingerprintNotEnrolled = 'غير مسجلة';
  static const String allowedLocations = 'مواقع العمل المسموح بها';
  static const String employeeStatus = 'حالة الموظف';
  static const String active = 'نشط';
  static const String suspended = 'موقف';
  static const String resigned = 'استقال';
  static const String terminated = 'مفصول';
  static const String onLeave = 'إجازة';
  static const String terminationDate = 'تاريخ الفصل';
  static const String terminationReason = 'سبب الفصل';
  static const String attendance = 'الحضور والانصراف';
  static const String checkIn = 'تسجيل الحضور';
  static const String checkOut = 'تسجيل الانصراف';
  static const String todayAttendance = 'حضور اليوم';
  static const String attendanceReport = 'تقرير الحضور';
  static const String attendanceStatus = 'حالة الحضور';
  static const String present = 'حاضر';
  static const String absent = 'غائب';
  static const String late = 'متأخر';
  static const String early = 'مبكر';
  static const String halfDay = 'نصف يوم';
  static const String leave = 'إجازة';
  static const String holiday = 'عطلة';
  static const String attendanceTime = 'وقت الحضور';
  static const String departureTime = 'وقت الانصراف';
  static const String totalHours = 'إجمالي الساعات';
  static const String overtimeHours = 'ساعات العمل الإضافي';
  static const String effectiveHours = 'الساعات الفعالة';
  static const String lateMinutes = 'دقائق التأخير';
  static const String earlyMinutes = 'دقائق الانصراف المبكر';
  static const String locationStatus = 'حالة الموقع';
  static const String allowed = 'مسموح';
  static const String outsideRange = 'خارج النطاق';
  static const String notRecorded = 'غير مسجل';
  static const String salaries = 'الرواتب';
  static const String salarySlip = 'كشف الراتب';
  static const String salaryDetails = 'تفاصيل الراتب';
  static const String month = 'الشهر';
  static const String year = 'السنة';
  static const String earnings = 'الإيرادات';
  static const String deductions = 'الخصومات';
  static const String netSalary = 'صافي الراتب';
  static const String salaryStatus = 'حالة الراتب';
  static const String draft = 'مسودة';
  static const String approved = 'معتمد';
  static const String paid = 'مصرف';
  static const String cancelled = 'ملغي';
  static const String paymentDate = 'تاريخ الدفع';
  static const String paymentMethod = 'طريقة الدفع';
  static const String bankTransfer = 'تحويل بنكي';
  static const String cheque = 'شيك';
  static const String cash = 'نقدي';
  static const String transactionReference = 'رقم المرجع';
  static const String advances = 'السلف';
  static const String advance = 'سلفة';
  static const String newAdvance = 'سلفة جديدة';
  static const String advanceAmount = 'مبلغ السلفة';
  static const String advanceReason = 'سبب السلفة';
  static const String repaymentMonths = 'أشهر التسديد';
  static const String monthlyInstallment = 'القسط الشهري';
  static const String remainingAmount = 'المبلغ المتبقي';
  static const String nextDueDate = 'تاريخ الاستحقاق التالي';
  static const String advanceStatus = 'حالة السلفة';
  static const String pending = 'معلق';
  static const String installment = 'قسط';
  static const String repaid = 'مسدد';
  static const String overdue = 'متأخر';
  static const String rejected = 'مرفوض';
  static const String repayments = 'التسديدات';
  static const String penalties = 'الجزاءات';
  static const String penalty = 'جزاء';
  static const String newPenalty = 'جزاء جديد';
  static const String penaltyType = 'نوع الجزاء';
  static const String delay = 'تأخير';
  static const String absence = 'غياب';
  static const String behavior = 'سلوك';
  static const String performance = 'أداء';
  static const String other = 'أخرى';
  static const String penaltyDescription = 'وصف الجزاء';
  static const String penaltyAmount = 'مبلغ الجزاء';
  static const String deducted = 'مخصوم';
  static const String notDeducted = 'غير مخصوم';
  static const String appeal = 'استئناف';
  static const String locations = 'المواقع';
  static const String location = 'موقع';
  static const String newLocation = 'موقع جديد';
  static const String locationCode = 'كود الموقع';
  static const String locationType = 'نوع الموقع';
  static const String office = 'مكتب';
  static const String factory = 'مصنع';
  static const String site = 'موقع';
  static const String branch = 'فرع';
  static const String address = 'العنوان';
  static const String coordinates = 'الإحداثيات';
  static const String latitude = 'خط العرض';
  static const String longitude = 'خط الطول';
  static const String radius = 'نصف القطر';
  static const String workingHours = 'ساعات العمل';
  static const String startTime = 'وقت البدء';
  static const String endTime = 'وقت الانتهاء';
  static const String flexible = 'مرن';
  static const String offDays = 'أيام العطلة';
  static const String saturday = 'السبت';
  static const String sunday = 'الأحد';
  static const String monday = 'الإثنين';
  static const String tuesday = 'الثلاثاء';
  static const String wednesday = 'الأربعاء';
  static const String thursday = 'الخميس';
  static const String friday = 'الجمعة';
  static const String requireLocation = 'يتطلب تحديد الموقع';
  static const String allowRemote = 'يسمح بالعمل عن بعد';
  static const String maxDistance = 'الحد الأقصى للمسافة';
  static const String meters = 'أمتار';
  static const String activeLocation = 'نشط';
  static const String inactiveLocation = 'غير نشط';
  static const String residencyNumber = 'رقم الإقامة';
  static const String residencyIssueDate = 'تاريخ إصدار الإقامة';
  static const String residencyExpiryDate = 'تاريخ انتهاء الإقامة';
  static const String passportNumber = 'رقم الجواز';
  static const String passportExpiryDate = 'تاريخ انتهاء الجواز';
  static const String totalEmployees = 'إجمالي الموظفين';
  static const String presentToday = 'الحاضرين اليوم';
  static const String absentToday = 'الغائبين اليوم';
  static const String lateToday = 'المتأخرين اليوم';
  static const String totalSalariesThisMonth = 'إجمالي الرواتب هذا الشهر';
  static const String totalAdvancesDue = 'إجمالي السلف المستحقة';
  static const String contractExpiringThisMonth = 'العقود المنتهية هذا الشهر';
  static const String residencyExpiringThisMonth =
      'الإقامات المنتهية هذا الشهر';
  static const String fingerprintAttendance = 'تسجيل الحضور بالبصمة';
  static const String fingerprintDevice = 'جهاز البصمة';
  static const String scanFingerprint = 'امسح البصمة';
  static const String fingerprintRegistered = 'البصمة مسجلة بنجاح';
  static const String fingerprintRegistrationFailed = 'فشل تسجيل البصمة';
  static const String attendanceRecorded = 'تم تسجيل الحضور';
  static const String attendanceFailed = 'فشل تسجيل الحضور';
  static const String goToWorkLocation = 'يرجى التوجه إلى موقع العمل';
  static const String outsideWorkLocation = 'خارج موقع العمل';
}

class ApiEndpoints {
  static String get baseUrl => ApiConfig.baseUrl;
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String logout = '/auth/logout';
  static const String requestLoginOtp = '/auth/request-login-otp';
  static const String verifyLoginOtp = '/auth/verify-login-otp';
  static const String authDevices = '/auth/devices';
  static const String logoutAllAuthDevices = '/auth/devices/logout-all';
  static const String blockedDevices = '/auth/blocked-devices';

  // System pause / maintenance notice (Owner only for activate/deactivate)
  static const String systemPauseStatus = '/system-pause';
  static const String systemPauseActivate = '/system-pause/activate';
  static const String systemPauseDeactivate = '/system-pause/deactivate';

  static const String notes = '/notes';
  static String noteById(String id) => '/notes/$id';

  static const String statements = '/statements';
  static const String statementRenew = '/statements/renew';
  static String statementRenewalById(String id) => '/statements/renewals/$id';

  static const String orders = '/orders';
  static const String orderAutofillDocument = '/orders/autofill/document';
  static const String orderImportDocuments = '/orders/import/documents';
  static const String tankers = '/tankers';
  static const String trackingDrivers = '/tracking/drivers';
  static const String driverLocations = '/driver-locations';
  static const String activities = '/activities';
  static const String suppliers = '/suppliers';
  static const String suppliersSearch = '/suppliers/search';
  static const String suppliersStatistics = '/suppliers/statistics';
  static const String tasks = '/tasks';
  static const String tasksMy = '/tasks/my';
  static const String taskLookup = '/tasks/lookup';
  static const String taskAccept = '/tasks/accept-by-code';
  static const String archiveDocuments = '/archive-documents';
  static const String inventoryBranches = '/inventory/branches';
  static const String inventoryWarehouses = '/inventory/warehouses';
  static const String inventorySuppliers = '/inventory/suppliers';
  static const String inventoryInvoices = '/inventory/invoices';
  static const String inventoryStock = '/inventory/stock';
  static const String chatUsers = '/chat/users';
  static const String chatConversations = '/chat/conversations';
  static const String chatDirectConversation = '/chat/conversations/direct';
  static const String chatGroupConversation = '/chat/conversations/group';
  static const String aiAssistantChat = '/ai-assistant/chat';

  static String orderById(String id) => '/orders/$id';
  static String orderMovementDispatch(String id) => '/orders/$id/movement/dispatch';
  static String orderMovementRequestById(String id) => '/orders/$id/movement/request';
  static String orderSupplierReview(String id) => '/orders/$id/supplier-review';
  static String orderWhatsAppDriver(String id) => '/orders/$id/whatsapp/driver';
  static String trackingDriverById(String id) => '/tracking/drivers/$id';
  static String driverLocationHistory(String id) =>
      '/driver-locations/$id/history';
  static String orderPdf(String id) => '/orders/$id/export/pdf';
  static String orderUnmerge(String id) => '/orders/$id/unmerge';
  static String orderMergeLinks(String id) => '/orders/$id/merge-links';
  static String deleteAttachment(String orderId, String attachmentId) =>
      '/orders/$orderId/attachments/$attachmentId';
  static String chatConversationById(String id) => '/chat/conversations/$id';
  static String chatConversationParticipants(String id) =>
      '/chat/conversations/$id/participants';
  static String chatConversationParticipant(String id, String userId) =>
      '/chat/conversations/$id/participants/$userId';
  static String chatConversationMessages(String id) =>
      '/chat/conversations/$id/messages';
  static String chatConversationMessage(String id, String messageId) =>
      '/chat/conversations/$id/messages/$messageId';
  static String chatConversationMessageReactions(String id, String messageId) =>
      '/chat/conversations/$id/messages/$messageId/reactions';
  static String chatForwardMessage(String messageId) =>
      '/chat/messages/$messageId/forward';
  static String chatConversationRead(String id) =>
      '/chat/conversations/$id/read';
  static String chatConversationTyping(String id) =>
      '/chat/conversations/$id/typing';
  static String chatConversationCalls(String id) =>
      '/chat/conversations/$id/calls';
  static String chatConversationActiveCall(String id) =>
      '/chat/conversations/$id/calls/active';
  static String chatCallRespond(String callId) => '/chat/calls/$callId/respond';
  static String chatCallEnd(String callId) => '/chat/calls/$callId/end';
  static const String chatPresencePing = '/chat/presence/ping';
  static const String chatPresenceOffline = '/chat/presence/offline';

  static String customerDocuments(String customerId) =>
      '/customers/$customerId/documents';
  static String customerDocument(String customerId, String documentId) =>
      '/customers/$customerId/documents/$documentId';

  static String supplierById(String id) => '/suppliers/$id';
  static String deleteSupplierDocument(String supplierId, String documentId) =>
      '/suppliers/$supplierId/documents/$documentId';
  static String taskById(String id) => '/tasks/$id';
  static String taskStart(String id) => '/tasks/$id/start';
  static String taskComplete(String id) => '/tasks/$id/complete';
  static String taskApprove(String id) => '/tasks/$id/approve';
  static String taskReject(String id) => '/tasks/$id/reject';
  static String taskStatus(String id) => '/tasks/$id/status';
  static String taskExtend(String id) => '/tasks/$id/extend';
  static String taskPenaltyApply(String id) => '/tasks/$id/penalty/apply';
  static String taskExtensionRequest(String id) => '/tasks/$id/extension-request';
  static String taskExtensionApprove(String id) =>
      '/tasks/$id/extension-request/approve';
  static String taskExtensionReject(String id) =>
      '/tasks/$id/extension-request/reject';
  static String taskReportPdf(String id) => '/tasks/$id/report/pdf';
  static String taskReportUpdate(String id) => '/tasks/$id/report';
  static String taskAttachments(String id) => '/tasks/$id/attachments';
  static String taskMessages(String id) => '/tasks/$id/messages';
  static String taskMessageAttachments(String id) =>
      '/tasks/$id/messages/attachments';
  static String taskMessagesRead(String id) => '/tasks/$id/messages/read';
  static String taskParticipants(String id) => '/tasks/$id/participants';
  static String authDeviceBlock(String id) => '/auth/devices/$id/block';
  static String authDeviceUnblock(String id) => '/auth/devices/$id/unblock';
  static String authDeviceLogout(String id) => '/auth/devices/$id/logout';
  static String taskParticipant(String id, String userId) =>
      '/tasks/$id/participants/$userId';
  static String taskTrackingConsent(String id) => '/tasks/$id/tracking/consent';
  static String taskTrackingPoints(String id) => '/tasks/$id/tracking/points';
  static String archiveDocumentById(String id) => '/archive-documents/$id';
  static const String mapsDirections = '/maps/directions';

  static const String hrEmployees = '/hr/employees';
  static const String hrAttendance = '/hr/attendance';
  static const String hrSalaries = '/hr/salaries';
  static const String hrAdvances = '/hr/advances';
  static const String hrPenalties = '/hr/penalties';
  static const String hrLocations = '/hr/locations';
  static const String hrDashboard = '/hr/dashboard';
  static const String fingerprintAttendance = '/hr/attendance/fingerprint';

  static String hrEmployeeById(String id) => '/hr/employees/$id';
  static String hrEmployeeFingerprint(String id) =>
      '/hr/employees/$id/fingerprint';
  static String hrEmployeeLocations(String id) => '/hr/employees/$id/locations';
  static String hrEmployeeAttendanceReport(String id) =>
      '/hr/attendance/employee/$id';
  static String hrEmployeeSalaries(String id) => '/hr/salaries/employee/$id';
  static String hrEmployeeAdvances(String id) => '/hr/advances/employee/$id';
  static String hrEmployeePenalties(String id) => '/hr/penalties/employee/$id';
  static String hrSalaryById(String id) => '/hr/salaries/$id';
  static String hrAdvanceById(String id) => '/hr/advances/$id';
  static String hrPenaltyById(String id) => '/hr/penalties/$id';
  static String hrLocationById(String id) => '/hr/locations/$id';
  static String hrLocationEmployees(String id) => '/hr/locations/$id/employees';
  static String hrLocationVerify = '/hr/locations/verify';

  static String hrExportEmployees = '/hr/employees/export';
  static String hrExportSalaries = '/hr/salaries/export';
  static String hrExportAttendance = '/hr/attendance/export';

  static String hrCreateSalarySheet = '/hr/salaries/create';
  static String hrApproveSalarySheet = '/hr/salaries/approve';
  static String hrPaySalaries = '/hr/salaries/pay';

  static String hrApproveAdvance(String id) => '/hr/advances/$id/approve';
  static String hrRejectAdvance(String id) => '/hr/advances/$id/reject';
  static String hrPayAdvance(String id) => '/hr/advances/$id/pay';
  static String hrUpdateRepayment(String id) => '/hr/advances/$id/repayment';

  static String hrApprovePenalty(String id) => '/hr/penalties/$id/approve';
  static String hrCancelPenalty(String id) => '/hr/penalties/$id/cancel';
  static String hrAppealPenalty(String id) => '/hr/penalties/$id/appeal';
  static String hrDecideAppeal(String id) => '/hr/penalties/$id/appeal/decide';

  static String hrToggleLocationStatus(String id) => '/hr/locations/$id/status';

  static const String marketingStations = '/station-marketing/stations';
  static String marketingStationById(String id) =>
      '/station-marketing/stations/$id';
  static String marketingStationStatus(String id) =>
      '/station-marketing/stations/$id/status';
  static String marketingStationLease(String id) =>
      '/station-marketing/stations/$id/lease';
  static String marketingStationLeaseTerminate(String id) =>
      '/station-marketing/stations/$id/lease/terminate';
  static String marketingStationPumps(String id) =>
      '/station-marketing/stations/$id/pumps';
  static String marketingStationPumpById(String id, String pumpId) =>
      '/station-marketing/stations/$id/pumps/$pumpId';
  static String marketingStationPumpClosing(String id, String pumpId) =>
      '/station-marketing/stations/$id/pumps/$pumpId/closing';
  static String marketingStationAttachments(String id) =>
      '/station-marketing/stations/$id/attachments';

  static const String stationInspections = '/station-inspections';
  static String stationInspectionById(String id) => '/station-inspections/$id';
  static String stationInspectionStatus(String id) =>
      '/station-inspections/$id/status';
  static String stationInspectionAttachments(String id) =>
      '/station-inspections/$id/attachments';

  static const String qualificationStations = '/qualification-stations';
  static String qualificationStationById(String id) =>
      '/qualification-stations/$id';
  static String qualificationStationStatus(String id) =>
      '/qualification-stations/$id/status';

  static const String stationMaintenance = '/station-maintenance';
  static const String stationMaintenanceMyActive =
      '/station-maintenance/my-active';
  static String stationMaintenanceById(String id) => '/station-maintenance/$id';
  static String stationMaintenanceStart(String id) =>
      '/station-maintenance/$id/start';
  static String stationMaintenanceSubmit(String id) =>
      '/station-maintenance/$id/submit';
  static String stationMaintenanceReview(String id) =>
      '/station-maintenance/$id/review';
  static String stationMaintenanceAssign(String id) =>
      '/station-maintenance/$id/assign';
}

class AppKeys {
  static const String googleMapsApiKey =
      'AIzaSyCayUZhpM7kmI4rxeg-URtOBjk5137XLS4';
}

class PdfTextIcons {
  static const String user = 'USER';
  static const String supplier = 'SUPPLIER';
  static const String driver = 'DRIVER';
  static const String vehicle = 'VEHICLE';
  static const String fuel = 'FUEL';
  static const String location = 'LOCATION';
  static const String calendar = 'DATE';
  static const String clock = 'TIME';
  static const String money = 'MONEY';
  static const String attachment = 'FILE';
  static const String merge = 'MERGE';
  static const String note = 'NOTE';
  static const String stats = 'STATS';
  static const String created = 'CREATED';
  static const String done = 'DONE';
  static const String completed = 'COMPLETED';
  static const String canceled = 'CANCELED';
  static const String status = 'STATUS';
  static const String source = 'SOURCE';
  static const String quantity = 'QUANTITY';
  static const String distance = 'DISTANCE';

  static const String employee = 'EMPLOYEE';
  static const String attendance = 'ATTENDANCE';
  static const String salary = 'SALARY';
  static const String advance = 'ADVANCE';
  static const String penalty = 'PENALTY';
  static const String fingerprint = 'FINGERPRINT';
  static const String contract = 'CONTRACT';
  static const String residency = 'RESIDENCY';
  static const String passport = 'PASSPORT';
  static const String bank = 'BANK';
  static const String department = 'DEPARTMENT';
  static const String position = 'POSITION';
  static const String clockIn = 'CLOCK_IN';
  static const String clockOut = 'CLOCK_OUT';
  static const String overtime = 'OVERTIME';
  static const String deduction = 'DEDUCTION';
  static const String installment = 'INSTALLMENT';
  static const String repayment = 'REPAYMENT';
  static const String warning = 'WARNING';
}

class AppIcons {
  static const String home = 'assets/icons/home.svg';
  static const String orders = 'assets/icons/orders.svg';
  static const String add = 'assets/icons/add.svg';
  static const String edit = 'assets/icons/edit.svg';
  static const String delete = 'assets/icons/delete.svg';
  static const String view = 'assets/icons/view.svg';
  static const String search = 'assets/icons/search.svg';
  static const String supplier = 'assets/icons/supplier.svg';
  static const String filter = 'assets/icons/filter.svg';
  static const String export = 'assets/icons/export.svg';
  static const String print = 'assets/icons/print.svg';
  static const String pdf = 'assets/icons/pdf.svg';
  static const String excel = 'assets/icons/excel.svg';
  static const String attachment = 'assets/icons/attachment.svg';
  static const String download = 'assets/icons/download.svg';
  static const String upload = 'assets/icons/upload.svg';
  static const String logo = 'assets/icons/logo.svg';
  static const String profile = 'assets/icons/profile.svg';
  static const String settings = 'assets/icons/settings.svg';
  static const String logout = 'assets/icons/logout.svg';
  static const String notification = 'assets/icons/notification.svg';
  static const String calendar = 'assets/icons/calendar.svg';
  static const String clock = 'assets/icons/clock.svg';
  static const String location = 'assets/icons/location.svg';
  static const String phone = 'assets/icons/phone.svg';
  static const String email = 'assets/icons/email.svg';
  static const String company = 'assets/icons/company.svg';
  static const String driver = 'assets/icons/driver.svg';
  static const String vehicle = 'assets/icons/vehicle.svg';
  static const String fuel = 'assets/icons/fuel.svg';
  static const String quantity = 'assets/icons/quantity.svg';
  static const String status = 'assets/icons/status.svg';
  static const String type = 'assets/icons/type.svg';
  static const String supplie = 'assets/icons/supplier.svg';
  static const String activity = 'assets/icons/activity.svg';
  static const String report = 'assets/icons/report.svg';
  static const String statistics = 'assets/icons/statistics.svg';
  static const String chart = 'assets/icons/chart.svg';
  static const String summary = 'assets/icons/summary.svg';
  static const String details = 'assets/icons/details.svg';
  static const String actions = 'assets/icons/actions.svg';

  static const String hr = 'assets/icons/hr.svg';
  static const String employee = 'assets/icons/employee.svg';
  static const String employees = 'assets/icons/employees.svg';
  static const String attendanceIcon = 'assets/icons/attendance.svg';
  static const String salaryIcon = 'assets/icons/salary.svg';
  static const String advanceIcon = 'assets/icons/advance.svg';
  static const String penaltyIcon = 'assets/icons/penalty.svg';
  static const String locationIcon = 'assets/icons/location.svg';
  static const String fingerprintIcon = 'assets/icons/fingerprint.svg';
  static const String contractIcon = 'assets/icons/contract.svg';
  static const String residencyIcon = 'assets/icons/residency.svg';
  static const String passportIcon = 'assets/icons/passport.svg';
  static const String bankIcon = 'assets/icons/bank.svg';
  static const String departmentIcon = 'assets/icons/department.svg';
  static const String positionIcon = 'assets/icons/position.svg';
  static const String clockIn = 'assets/icons/clock-in.svg';
  static const String clockOut = 'assets/icons/clock-out.svg';
  static const String overtimeIcon = 'assets/icons/overtime.svg';
  static const String deductionIcon = 'assets/icons/deduction.svg';
  static const String installmentIcon = 'assets/icons/installment.svg';
  static const String repaymentIcon = 'assets/icons/repayment.svg';
  static const String warningIcon = 'assets/icons/warning.svg';
  static const String idCard = 'assets/icons/id-card.svg';
  static const String birthCertificate = 'assets/icons/birth-certificate.svg';
  static const String nationalityIcon = 'assets/icons/nationality.svg';
  static const String cityIcon = 'assets/icons/city.svg';
  static const String genderIcon = 'assets/icons/gender.svg';
  static const String scheduleIcon = 'assets/icons/schedule.svg';
  static const String hoursIcon = 'assets/icons/hours.svg';
  static const String moneyIcon = 'assets/icons/money.svg';
  static const String allowanceIcon = 'assets/icons/allowance.svg';
  static const String transportationIcon = 'assets/icons/transportation.svg';
  static const String housingIcon = 'assets/icons/housing.svg';
  static const String presentIcon = 'assets/icons/present.svg';
  static const String absentIcon = 'assets/icons/absent.svg';
  static const String lateIcon = 'assets/icons/late.svg';
  static const String earlyIcon = 'assets/icons/early.svg';
  static const String leaveIcon = 'assets/icons/leave.svg';
  static const String holidayIcon = 'assets/icons/holiday.svg';
  static const String halfDayIcon = 'assets/icons/half-day.svg';
  static const String earningsIcon = 'assets/icons/earnings.svg';
  static const String netSalaryIcon = 'assets/icons/net-salary.svg';
  static const String draftIcon = 'assets/icons/draft.svg';
  static const String approvedIcon = 'assets/icons/approved.svg';
  static const String paidIcon = 'assets/icons/paid.svg';
  static const String cancelledIcon = 'assets/icons/cancelled.svg';
  static const String pendingIcon = 'assets/icons/pending.svg';
  static const String repaidIcon = 'assets/icons/repaid.svg';
  static const String overdueIcon = 'assets/icons/overdue.svg';
  static const String rejectedIcon = 'assets/icons/rejected.svg';
  static const String appliedIcon = 'assets/icons/applied.svg';
  static const String refundedIcon = 'assets/icons/refunded.svg';
  static const String activeIcon = 'assets/icons/active.svg';
  static const String suspendedIcon = 'assets/icons/suspended.svg';
  static const String resignedIcon = 'assets/icons/resigned.svg';
  static const String terminatedIcon = 'assets/icons/terminated.svg';
  static const String onLeaveIcon = 'assets/icons/on-leave.svg';
  static const String officeIcon = 'assets/icons/office.svg';
  static const String factoryIcon = 'assets/icons/factory.svg';
  static const String siteIcon = 'assets/icons/site.svg';
  static const String branchIcon = 'assets/icons/branch.svg';
  static const String coordinatesIcon = 'assets/icons/coordinates.svg';
  static const String radiusIcon = 'assets/icons/radius.svg';
  static const String startTimeIcon = 'assets/icons/start-time.svg';
  static const String endTimeIcon = 'assets/icons/end-time.svg';
  static const String flexibleIcon = 'assets/icons/flexible.svg';
  static const String offDaysIcon = 'assets/icons/off-days.svg';
  static const String requireLocationIcon = 'assets/icons/require-location.svg';
  static const String allowRemoteIcon = 'assets/icons/allow-remote.svg';
  static const String maxDistanceIcon = 'assets/icons/max-distance.svg';
  static const String activeLocationIcon = 'assets/icons/active-location.svg';
  static const String inactiveLocationIcon =
      'assets/icons/inactive-location.svg';
  static const String scanFingerprint = 'assets/icons/scan-fingerprint.svg';
  static const String fingerprintDevice = 'assets/icons/fingerprint-device.svg';
  static const String checkmarkCircle = 'assets/icons/checkmark-circle.svg';
  static const String xCircle = 'assets/icons/x-circle.svg';
  static const String alertTriangle = 'assets/icons/alert-triangle.svg';
  static const String infoCircle = 'assets/icons/info-circle.svg';
  static const String whatsapp = 'assets/icons/whatsapp.svg';
}

class AppImages {
  static const String logo = 'assets/images/logo.png';
  static const String logo1 = 'assets/images/logo1.png';
  static const String splash = 'assets/images/splash.png';
  static const String loginBg = 'assets/images/login_bg.png';
  static const String noData = 'assets/images/no_data.png';
  static const String error = 'assets/images/error.png';
  static const String success = 'assets/images/success.png';
  static const String placeholder = 'assets/images/placeholder.png';

  static const String hrDashboard = 'assets/images/hr_dashboard.png';
  static const String fingerprintScanner =
      'assets/images/fingerprint_scanner.png';
  static const String attendanceSystem = 'assets/images/attendance_system.png';
  static const String salarySlip = 'assets/images/salary_slip.png';
  static const String employeeProfile = 'assets/images/employee_profile.png';
  static const String workLocation = 'assets/images/work_location.png';
  static const String noEmployees = 'assets/images/no_employees.png';
  static const String noAttendance = 'assets/images/no_attendance.png';
  static const String noSalaries = 'assets/images/no_salaries.png';
  static const String noAdvances = 'assets/images/no_advances.png';
  static const String noPenalties = 'assets/images/no_penalties.png';
  static const String noLocations = 'assets/images/no_locations.png';
}

