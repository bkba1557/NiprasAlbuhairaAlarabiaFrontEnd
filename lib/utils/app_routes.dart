import 'package:flutter/material.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/custody_document_provider.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/screens/activities_screen.dart';
import 'package:order_tracker/screens/fuel_stations/approval_request_screen.dart';
import 'package:order_tracker/screens/fuel_stations/fuel_station_details_screen.dart';
import 'package:order_tracker/screens/fuel_stations/fuel_station_form_screen.dart';
import 'package:order_tracker/screens/fuel_stations/maintenance_form_fuel_screen.dart';
import 'package:order_tracker/screens/fuel_stations/send_alert_screen.dart';
import 'package:order_tracker/screens/fuel_stations/technician_report_screen.dart';
import 'package:order_tracker/screens/hr/advance/penalties_screen.dart';
import 'package:order_tracker/screens/maintenance/daily_check_screen.dart';
import 'package:order_tracker/screens/maintenance/custody_document_form_screen.dart';
import 'package:order_tracker/screens/maintenance/custody_document_list_screen.dart';
import 'package:order_tracker/screens/maintenance/custody_dashboard_screen.dart';
import 'package:order_tracker/screens/maintenance/custody_return_screen.dart';
import 'package:order_tracker/screens/maintenance/maintenance_dashboard_screen.dart';
import 'package:order_tracker/screens/maintenance/maintenance_detail_screen.dart';
import 'package:order_tracker/screens/maintenance/maintenance_form_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_dashboard_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_driver_report_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_supplies_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_supply_form_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_supply_details_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_refuel_form_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_readings_screen.dart';
import 'package:order_tracker/screens/maintenance/workshop_fuel_report_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_screen.dart';
import 'package:order_tracker/screens/archive/archive_document_form_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_list_screen.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/order/costomer_order/customer_form_screen.dart';
import 'package:order_tracker/screens/order/costomer_order/customer_order_form.dart';
import 'package:order_tracker/screens/order/costomer_order/customers_screen.dart';
import 'package:order_tracker/screens/circulars/circulars_screen.dart';
import 'package:order_tracker/screens/circulars/daily_reports_screen.dart';
import 'package:order_tracker/screens/dashboard_screen.dart';
import 'package:order_tracker/screens/auth_devices_screen.dart';
import 'package:order_tracker/screens/blocked_devices_screen.dart';
import 'package:order_tracker/screens/driver_form_screen.dart';
import 'package:order_tracker/screens/driver_home_screen.dart';
import 'package:order_tracker/screens/drivers_screen.dart';
import 'package:order_tracker/screens/login_screen.dart';
import 'package:order_tracker/screens/notifications_screen.dart';
import 'package:order_tracker/screens/order/merge/merge_orders_screen.dart';
import 'package:order_tracker/screens/order/supplier_order/supplier_order_form_screen.dart';
import 'package:order_tracker/screens/order_management/customer_liters_report_screen.dart';
import 'package:order_tracker/screens/order_management/customer_pricing_screen.dart';
import 'package:order_tracker/screens/order_management/movement_dashboard_screen.dart';
import 'package:order_tracker/screens/order_management/order_management_dashboard_screen.dart';
import 'package:order_tracker/screens/order_management/tax_settings_screen.dart';
import 'package:order_tracker/screens/order_management/transport_orders_screen.dart';
import 'package:order_tracker/screens/order_management/treasury/customer_accounts_screen.dart';
import 'package:order_tracker/screens/order_management/treasury/customer_treasury_screen.dart';
import 'package:order_tracker/screens/order_details_screen.dart';
import 'package:order_tracker/screens/orders_screen.dart';
import 'package:order_tracker/screens/profile_screen.dart';
import 'package:order_tracker/screens/support_screen.dart';
import 'package:order_tracker/screens/register_screen.dart';
import 'package:order_tracker/screens/account/system_pause_screen.dart';
import 'package:order_tracker/screens/reports/customer_report_screen.dart';
import 'package:order_tracker/screens/reports/driver_report_screen.dart';
import 'package:order_tracker/screens/reports/invoice_report_screen.dart';
import 'package:order_tracker/screens/reports/reports_screen.dart';
import 'package:order_tracker/screens/reports/supplier_report_screen.dart';
import 'package:order_tracker/screens/reports/user_report_screen.dart';
import 'package:order_tracker/screens/settings_screen.dart';
import 'package:order_tracker/screens/fuel_stations/fuel_stations_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/close_session_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/daily_inventory_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/inventory_details_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/inventory_list_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/main_home_screen.dart';
import 'package:order_tracker/screens/tracking/tracking_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/monthly_station_report_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/open_session_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/session_details_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/session_edit_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/sessions_list_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/station_details_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/station_form_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/station_warehouses_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/station_treasury_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/stations_dashboard_screen.dart';
import 'package:order_tracker/screens/stations_mangaments/stations_list_screen.dart';
import 'package:order_tracker/screens/trading/trade.dart';
import 'package:order_tracker/screens/user_management_screen.dart';
import 'package:order_tracker/screens/splash_screen.dart';
import 'package:order_tracker/screens/suppliers_screen/supplier_details_screen.dart';
import 'package:order_tracker/screens/suppliers_screen/supplier_form_screen.dart';
import 'package:order_tracker/screens/suppliers_screen/suppliers_screen.dart';
import 'package:order_tracker/screens/front_page.dart';
import 'package:order_tracker/screens/station_marketing/marketing_dashboard_screen.dart';
import 'package:order_tracker/screens/qualification/qualification_dashboard_screen.dart';
import 'package:order_tracker/screens/qualification/qualification_details_screen.dart';
import 'package:order_tracker/screens/qualification/qualification_form_screen.dart';
import 'package:order_tracker/screens/qualification/qualification_map_screen.dart';
import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/screens/tasks/tasks_screen.dart';
import 'package:order_tracker/screens/contracts/contracts_management_screen.dart';
import 'package:order_tracker/screens/inventory/inventory_dashboard_screen.dart';
import 'package:order_tracker/screens/inventory/inventory_invoice_form_screen.dart';
import 'package:order_tracker/screens/inventory/inventory_stock_screen.dart';
import 'package:order_tracker/screens/chat/chat_list_screen.dart';
import 'package:order_tracker/screens/chat/chat_conversation_screen.dart';
import 'package:order_tracker/screens/station_maintenance/station_maintenance_dashboard_screen.dart';
import 'package:order_tracker/screens/station_maintenance/station_maintenance_form_screen.dart';
import 'package:order_tracker/screens/station_maintenance/station_maintenance_detail_screen.dart';
import 'package:order_tracker/screens/station_maintenance/station_maintenance_technician_screen.dart';
import 'package:order_tracker/models/chat_models.dart';

// ===========================================
// 📌 شاشات نظام شؤون الموظفين
// ===========================================
import 'package:order_tracker/screens/hr/employee/employees_screen.dart';
import 'package:order_tracker/screens/hr/employee/employee_form_screen.dart';
import 'package:order_tracker/screens/hr/employee/employee_details_screen.dart';
import 'package:order_tracker/screens/hr/attendance/attendance_screen.dart';
import 'package:order_tracker/screens/hr/attendance/attendance_report_screen.dart';
import 'package:order_tracker/screens/hr/salary/salaries_screen.dart';
import 'package:order_tracker/screens/hr/salary/salary_details_screen.dart';
import 'package:order_tracker/screens/hr/advance/advances_screen.dart';
import 'package:order_tracker/screens/hr/advance/advance_form_screen.dart';
import 'package:order_tracker/screens/hr/penalty/penalties_screen.dart';
import 'package:order_tracker/screens/hr/penalty/penalty_form_screen.dart';
import 'package:order_tracker/screens/hr/location/locations_screen.dart';
import 'package:order_tracker/screens/hr/location/location_form_screen.dart';
import 'package:order_tracker/screens/hr/dashboard/hr_dashboard_screen.dart';
import 'package:order_tracker/screens/hr/fingerprint/fingerprint_attendance_screen.dart';
import 'package:order_tracker/screens/hr/fingerprint/fingerprint_enrollment_screen.dart';
import 'package:order_tracker/screens/hr/face/face_enrollment_screen.dart';
import 'package:order_tracker/screens/hr/device/device_assignment_screen.dart';
import 'package:order_tracker/screens/hr/device/device_enrollment_requests_screen.dart';

class AppRoutes {
  // Front Page (الصفحة الأولى الجديدة)
  static const front = '/front'; // ✅ أضف هذا المسار

  // Auth
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Main
  static const dashboard = '/dashboard';
  static const tracking = '/tracking';
  static const circulars = '/circulars';
  static const dailyReports = '/daily-reports';

  // Orders
  static const driverHome = '/driver/home';
  static const orders = '/orders';
  static const orderForm = '/orders/form';
  static const orderDetails = '/orders/details';

  // Customers
  static const customerForm = '/customer/form';
  static const customers = '/customers';

  static const String driverForm = '/driver/form';
  static const String drivers = '/drivers';
  static const String fuelStationManagement = '/fuel-station/management';

  static const String reports = '/reports';
  static const String customerReport = '/reports/customers';
  static const String driverReport = '/reports/drivers';
  static const String supplierReport = '/reports/suppliers';
  static const String userReport = '/reports/users';
  static const String invoiceReport = '/reports/invoice';
  static const String advancedFilter = '/reports/filter';
  static const String userManagement = '/users/manage';
  static const String authDevices = '/auth/devices';
  static const String blockedDevices = '/auth/blocked-devices';

  // Other
  static const activities = '/activities';
  static const profile = '/profile';
  static const settings = '/settings';
  static const support = '/support';
  static const notifications = '/notifications';
  static const systemPause = '/system-pause';
  static const String suppliers = '/suppliers';
  static const String supplierForm = '/supplier/form';
  static const String supplierOrderForm = '/supplier/order/form';
  static const String customerOrderForm = '/customer/order/form';
  static const String supplierDetails = '/supplier/details';
  static const String mergeOrders = '/merge-orders';
  static const String movement = '/movement';

  // Order Management
  static const String orderManagementDashboard = '/orders/management';
  static const String orderManagementCustomerAccounts =
      '/orders/management/customers/accounts';
  static const String orderManagementFuelPricing =
      '/orders/management/customers/fuel-pricing';
  static const String orderManagementTransportPricing =
      '/orders/management/customers/transport-pricing';
  static const String orderManagementTransportOrders =
      '/orders/management/transport/orders';
  static const String orderManagementCustomerLitersReport =
      '/orders/management/reports/customer-liters';
  static const String orderManagementTaxSettings = '/orders/management/tax';
  static const String orderManagementTreasury = '/orders/management/treasury';

  static const String tasks = '/tasks';
  static const String contractsManagement = '/contracts';
  static const String chat = '/chat';
  static const String chatConversation = '/chat/conversation';

  static const String maintenanceDashboard = '/maintenance/dashboard';
  static const String periodicMaintenance = '/maintenance/periodic';
  static const String maintenanceForm = '/maintenance/new';
  static const String maintenanceEdit = '/maintenance/edit';
  static const String maintenanceDetails = '/maintenance/details';
  static const String dailyCheck = '/maintenance/daily-check';
  static const String dailyCheckView = '/maintenance/daily-check/view';
  static const String custodyDocuments = '/maintenance/custody-documents';
  static const String custodyDocumentForm =
      '/maintenance/custody-documents/form';
  static const String custodyDashboard = '/maintenance/custody-dashboard';
  static const String custodyReturn = '/maintenance/custody-return';
  static const String workshopFuelDashboard = '/maintenance/workshop-fuel';
  static const String workshopFuelSupplies =
      '/maintenance/workshop-fuel/supplies';
  static const String workshopFuelSupplyForm =
      '/maintenance/workshop-fuel/supplies/new';
  static const String workshopFuelSupplyDetails =
      '/maintenance/workshop-fuel/supplies/details';
  static const String workshopFuelRefuelForm =
      '/maintenance/workshop-fuel/refuel';
  static const String workshopFuelReport = '/maintenance/workshop-fuel/report';
  static const String workshopFuelReadings =
      '/maintenance/workshop-fuel/readings';
  static const String workshopFuelDriverReport =
      '/maintenance/workshop-fuel/driver-report';
  static const String archiveDocuments = '/archive/documents';
  static const String archiveDocumentsCreate = '/archive/documents/create';
  static const String archiveDocumentsList = '/archive/documents/list';
  static const String archiveDocumentDetails = '/archive/documents/details';

  static const String fuelStations = '/fuel-stations';
  static const String fuelStationForm = '/fuel-station/form';
  static const String fuelStationDetails = '/fuel-station/details';
  static const String technicianReport = '/technician-report';
  static const String sendAlert = '/send-alert';
  static const String approvalRequest = '/approval-request';
  static const String maintenanceFuelForms = '/maintenanceFuel/form';
  static const String mainHome = '/main-home';
  static const String stationsDashboard = '/stations/dashboard';
  static const String stationsList = '/stations/list';
  static const String stationForm = '/station/form';
  static const String stationDetails = '/station/details';
  static const String sessionsList = '/sessions/list';
  static const String openSession = '/sessions/open';
  static const String closeSession = '/sessions/close';
  static const String sessionDetails = '/session/details';
  static const String inventoryList = '/inventory/list';
  static const String inventoryCreate = '/inventory/create';
  static const String inventoryDetails = '/inventory/details';
  static const String stationWarehouses = '/stations/warehouses';
  static const String stationTreasury = '/stations/treasury';
  static const String reportsStations = '/reports/stations';
  static const String monthlyStationsReport = '/reports/stations/monthly';
  static const String trading = '/trading';
  static const String marketingStations = '/station-marketing';
  static const String inventoryDashboard = '/inventory/dashboard';
  static const String inventoryInvoiceForm = '/inventory/invoice/new';
  static const String inventoryStock = '/inventory/stock';
  static const String qualificationDashboard = '/qualification/dashboard';
  static const String qualificationForm = '/qualification/form';
  static const String qualificationMap = '/qualification/map';
  static const String qualificationDetails = '/qualification/details';
  static const String stationMaintenanceDashboard =
      '/station-maintenance/dashboard';
  static const String stationMaintenanceForm = '/station-maintenance/form';
  static const String stationMaintenanceDetails =
      '/station-maintenance/details';
  static const String stationMaintenanceTechnician =
      '/station-maintenance/technician';

  // ===========================================
  // 📌 مسارات نظام شؤون الموظفين
  // ===========================================
  static const String hrDashboard = '/hr/dashboard';
  static const String employees = '/hr/employees';
  static const String employeeForm = '/hr/employees/form';
  static const String employeeDetails = '/hr/employees/details';
  static const String attendance = '/hr/attendance';
  static const String attendanceReport = '/hr/attendance/report';
  static const String salaries = '/hr/salaries';
  static const String salaryDetails = '/hr/salaries/details';
  static const String advances = '/hr/advances';
  static const String advanceForm = '/hr/advances/form';
  static const String penalties = '/hr/penalties';
  static const String penaltyForm = '/hr/penalties/form';
  static const String sessionEdit = '/sessions/edit';
  static const String locations = '/hr/locations';
  static const String locationForm = '/hr/locations/form';
  static const String fingerprintAttendance = '/hr/fingerprint/attendance';
  static const String fingerprintEnrollment = '/hr/fingerprint/enrollment';
  static const String faceEnrollment = '/hr/face/enrollment';
  static const String deviceAssignment = '/hr/device/assignment';
  static const String deviceEnrollmentRequests = '/hr/device/enroll-requests';

  /// Routes بدون arguments
  static final Map<String, Widget Function(BuildContext)> routes = {
    front: (context) => FrontPage(
      onEmployeeLogin: () {
        Navigator.pushNamed(context, AppRoutes.login);
      },
    ),

    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    drivers: (context) => const DriversScreen(),
    tasks: (_) => const TasksScreen(),
    contractsManagement: (_) => const ContractsManagementScreen(),
    chat: (_) => const ChatListScreen(),

    dashboard: (_) => const DashboardScreen(),
    circulars: (_) => const CircularsScreen(),
    dailyReports: (_) => const DailyReportsScreen(),
    driverHome: (_) => const DriverHomeScreen(),
    tracking: (_) => const TrackingScreen(),
    trading: (_) => const TraderScreen(),
    suppliers: (context) => const SuppliersScreen(),

    orders: (_) => const OrdersScreen(),
    customers: (_) => const CustomersScreen(),
    orderManagementDashboard: (_) => const OrderManagementDashboardScreen(),
    movement: (_) => const MovementDashboardScreen(),
    orderManagementCustomerAccounts: (_) => const CustomerAccountsScreen(),
    orderManagementFuelPricing: (_) =>
        const CustomerPricingScreen(mode: CustomerPricingMode.fuel),
    orderManagementTransportPricing: (_) =>
        const CustomerPricingScreen(mode: CustomerPricingMode.transport),
    orderManagementTransportOrders: (_) => const TransportOrdersScreen(),
    orderManagementCustomerLitersReport: (_) =>
        const CustomerLitersReportScreen(),
    orderManagementTaxSettings: (_) => const TaxSettingsScreen(),
    orderManagementTreasury: (_) => const CustomerTreasuryScreen(),

    maintenanceDashboard: (context) => const MaintenanceDashboardScreen(),
    workshopFuelDashboard: (context) => const WorkshopFuelDashboardScreen(),
    workshopFuelSupplies: (context) => const WorkshopFuelSuppliesScreen(),
    workshopFuelSupplyForm: (context) => const WorkshopFuelSupplyFormScreen(),
    workshopFuelSupplyDetails: (context) =>
        const WorkshopFuelSupplyDetailsScreen(),
    workshopFuelRefuelForm: (context) => const WorkshopFuelRefuelFormScreen(),
    workshopFuelReport: (context) => const WorkshopFuelReportScreen(),
    workshopFuelReadings: (context) => const WorkshopFuelReadingsScreen(),
    workshopFuelDriverReport: (context) =>
        const WorkshopFuelDriverReportScreen(),
    archiveDocuments: (context) => const ArchiveDocumentsScreen(),
    archiveDocumentsCreate: (context) => const ArchiveDocumentFormScreen(),
    archiveDocumentsList: (context) => const ArchiveDocumentsListScreen(),
    periodicMaintenance: (context) => const MaintenanceDashboardScreen(),
    maintenanceForm: (context) => const MaintenanceFormScreen(),
    dailyCheck: (context) => DailyCheckScreen(
      args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
    ),
    custodyDocuments: (context) {
      final provider = context.read<CustodyDocumentProvider>();
      return ChangeNotifierProvider.value(
        value: provider,
        child: const CustodyDocumentListScreen(),
      );
    },
    custodyDashboard: (context) {
      final provider = context.read<CustodyDocumentProvider>();
      return ChangeNotifierProvider.value(
        value: provider,
        child: const CustodyDashboardScreen(),
      );
    },
    custodyReturn: (context) {
      final provider = context.read<CustodyDocumentProvider>();
      return ChangeNotifierProvider.value(
        value: provider,
        child: const CustodyReturnScreen(),
      );
    },
    custodyDocumentForm: (context) {
      final provider = context.read<CustodyDocumentProvider>();
      return ChangeNotifierProvider.value(
        value: provider,
        child: const CustodyDocumentFormScreen(),
      );
    },

    activities: (_) => const ActivitiesScreen(),
    profile: (_) => const ProfileScreen(),
    settings: (_) => const SettingsScreen(),
    support: (_) => const SupportScreen(),
    notifications: (_) => const NotificationsScreen(),
    systemPause: (_) => const SystemPauseScreen(),
    fuelStations: (context) => const FuelStationsScreen(),
    fuelStationForm: (context) => const FuelStationFormScreen(),

    technicianReport: (context) => const TechnicianReportScreen(),
    sendAlert: (context) => const SendAlertScreen(),
    approvalRequest: (context) => const ApprovalRequestScreen(),
    maintenanceFuelForms: (context) => const MaintenanceFuelFormScreen(),

    reports: (_) => const ReportsScreen(),
    customerReport: (_) => const CustomerReportScreen(),
    driverReport: (_) => const DriverReportScreen(),
    supplierReport: (_) => const SupplierReportScreen(),
    userReport: (_) => const UserReportScreen(),
    userManagement: (_) => const UserManagementScreen(),
    authDevices: (_) => const AuthDevicesScreen(),
    blockedDevices: (_) => const BlockedDevicesScreen(),
    invoiceReport: (_) => const InvoiceReportScreen(),

    mainHome: (context) => const MainHomeScreen(),
    stationsDashboard: (context) => const StationsDashboardScreen(),
    stationsList: (context) => const StationsListScreen(),
    stationForm: (context) => const StationFormScreen(),
    marketingStations: (context) => const MarketingStationsScreen(),
    inventoryDashboard: (context) => const InventoryDashboardScreen(),
    inventoryInvoiceForm: (context) => const InventoryInvoiceFormScreen(),
    inventoryStock: (context) => const InventoryStockScreen(),
    qualificationDashboard: (context) => const QualificationDashboardScreen(),
    qualificationForm: (context) => const QualificationStationFormScreen(),
    qualificationMap: (context) => QualificationStationsMapScreen(
      initialStation:
          ModalRoute.of(context)!.settings.arguments as QualificationStation?,
    ),
    qualificationDetails: (context) => QualificationStationDetailsScreen(
      initialStation:
          ModalRoute.of(context)!.settings.arguments as QualificationStation?,
    ),
    stationMaintenanceDashboard: (context) =>
        const StationMaintenanceDashboardScreen(),
    stationMaintenanceTechnician: (context) =>
        const StationMaintenanceTechnicianScreen(),
    stationMaintenanceForm: (context) => const StationMaintenanceFormScreen(),
    stationMaintenanceDetails: (context) =>
        const StationMaintenanceDetailScreen(),

    sessionsList: (context) => const SessionsListScreen(),
    openSession: (context) => const OpenSessionScreen(),
    closeSession: (context) => const CloseSessionScreen(),
    inventoryList: (context) => const InventoryListScreen(),
    inventoryCreate: (context) => const DailyInventoryScreen(),
    stationWarehouses: (context) => const StationWarehousesScreen(),
    stationTreasury: (context) => const StationTreasuryScreen(),
    monthlyStationsReport: (context) => const MonthlyStationReportScreen(),

    // ===========================================
    // 📌 شاشات نظام شؤون الموظفين
    // ===========================================
    hrDashboard: (context) => const HRDashboardScreen(),
    employees: (context) => const EmployeesScreen(),
    employeeForm: (context) => const EmployeeFormScreen(),
    attendance: (context) => const AttendanceScreen(),
    salaries: (context) => const SalariesScreen(),
    salaryDetails: (context) => SalaryDetailsScreen(
      salaryId: ModalRoute.of(context)!.settings.arguments as String,
    ),
    advances: (context) => const AdvancesScreen(),
    advanceForm: (context) => const AdvanceFormScreen(),
    penalties: (context) => const PenaltiesScreen(),
    penaltyForm: (context) => const PenaltyFormScreen(),
    locations: (context) => const LocationsScreen(),
    locationForm: (context) => const LocationFormScreen(),
    fingerprintAttendance: (context) => const FingerprintAttendanceScreen(),
    fingerprintEnrollment: (context) => const FingerprintEnrollmentScreen(),
    deviceEnrollmentRequests: (context) =>
        const DeviceEnrollmentRequestsScreen(),
  };

  /// Routes اللي تعتمد على arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name;
    if (routeName != null) {
      final uri = Uri.tryParse(routeName);
      if (uri != null && uri.path == chatConversation) {
        final conversationId = uri.queryParameters['conversationId'];
        final peerId = uri.queryParameters['peerId'];
        final hasQueryArgs =
            (conversationId?.isNotEmpty ?? false) ||
            (peerId?.isNotEmpty ?? false);
        if (hasQueryArgs && settings.arguments == null) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: chatConversation),
            builder: (_) => ChatConversationScreen(
              initialConversationId: conversationId,
              initialPeerId: peerId,
            ),
          );
        }
      }
      if (uri != null && uri.path == tasks) {
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return MaterialPageRoute(
            builder: (_) => TasksScreen(initialTaskCode: code),
          );
        }
        return MaterialPageRoute(builder: (_) => const TasksScreen());
      }
    }

    switch (settings.name) {
      case contractsManagement:
        return MaterialPageRoute(
          builder: (_) => const ContractsManagementScreen(),
        );
      case chatConversation:
        final chatArgs = settings.arguments;
        String? conversationId;
        String? peerId;
        ChatUser? peer;

        if (chatArgs is String) {
          conversationId = chatArgs;
        } else if (chatArgs is Map) {
          conversationId = chatArgs['conversationId']?.toString();
          peerId = chatArgs['peerId']?.toString();
          final peerRaw = chatArgs['peer'];
          if (peerRaw is Map<String, dynamic>) {
            peer = ChatUser.fromJson(peerRaw);
          }
        }

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChatConversationScreen(
            initialConversationId: conversationId,
            initialPeerId: peerId,
            initialPeer: peer,
          ),
        );

      /// ➕ إنشاء طلب / ✏️ تعديل طلب
      case archiveDocumentDetails:
        final args = settings.arguments;
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => ArchiveDocumentDetailsScreen(documentId: args),
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => ArchiveDocumentDetailsScreen(
              documentId: '${args['_id'] ?? ''}',
              initialDocument: args,
            ),
          );
        }
        return null;
      case orderForm:
        final Order? order = settings.arguments as Order?;
        return MaterialPageRoute(
          builder: (_) => CustomerOrderFormScreen(orderToEdit: order),
        );

      case AppRoutes.sessionDetails:
        final String sessionId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => SessionDetailsScreen(sessionId: sessionId),
        );

      case AppRoutes.marketingStations:
        return MaterialPageRoute(
          builder: (_) => const MarketingStationsScreen(),
        );

      case AppRoutes.stationMaintenanceTechnician:
        return MaterialPageRoute(
          builder: (_) => const StationMaintenanceTechnicianScreen(),
        );

      case AppRoutes.sessionEdit:
        final args = settings.arguments;
        if (args is PumpSession) {
          return MaterialPageRoute(
            builder: (_) => SessionEditScreen(session: args),
          );
        }
        return null;

      case AppRoutes.maintenanceEdit:
        final record = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MaintenanceFormScreen(maintenanceRecord: record),
        );

      case AppRoutes.stationDetails:
        final String stationId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => StationDetailsScreen(stationId: stationId),
        );

      case AppRoutes.inventoryDetails:
        final String inventoryId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => InventoryDetailsScreen(inventoryId: inventoryId),
        );

      case fuelStationDetails:
        final String stationId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => FuelStationDetailsScreen(stationId: stationId),
        );

      case AppRoutes.supplierOrderForm:
        final order = settings.arguments as Order?;
        return MaterialPageRoute(
          builder: (_) => SupplierOrderFormScreen(orderToEdit: order),
        );
      case AppRoutes.customerOrderForm:
        final order = settings.arguments as Order?;
        return MaterialPageRoute(
          builder: (_) => CustomerOrderFormScreen(orderToEdit: order),
        );
      case AppRoutes.mergeOrders:
        final args = settings.arguments;

        if (args is Order) {
          return MaterialPageRoute(
            builder: (_) => MergeOrdersScreen(orderToEdit: args),
          );
        }

        // fallback (دمج جديد)
        return MaterialPageRoute(builder: (_) => const MergeOrdersScreen());

      /// 📄 تفاصيل الطلب
      case orderDetails:
        final String orderId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: orderId),
        );

      case maintenanceDetails:
        final String maintenanceId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => MaintenanceDetailScreen(maintenanceId: maintenanceId),
        );

      /// ➕ إنشاء عميل / ✏️ تعديل عميل
      case customerForm:
        final Customer? customer = settings.arguments as Customer?;
        return MaterialPageRoute(
          builder: (_) => CustomerFormScreen(customerToEdit: customer),
        );

      case driverForm:
        final Driver? driver = settings.arguments as Driver?;
        return MaterialPageRoute(
          builder: (_) => DriverFormScreen(driverToEdit: driver),
        );

      case supplierForm:
        final Supplier? supplier = settings.arguments as Supplier?;
        return MaterialPageRoute(
          builder: (_) => SupplierFormScreen(supplierToEdit: supplier),
        );

      case supplierDetails:
        final args = settings.arguments;
        final supplierId = args is Supplier ? args.id : args as String?;
        return MaterialPageRoute(
          builder: (_) => SupplierDetailsScreen(
            supplierId: supplierId ?? '',
            supplier: args is Supplier ? args : null,
          ),
        );

      // ===========================================
      // 📌 مسارات نظام شؤون الموظفين مع arguments
      // ===========================================
      case employeeDetails:
        final String employeeId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => EmployeeDetailsScreen(employeeId: employeeId),
        );

      case attendanceReport:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AttendanceReportScreen(
            employeeId: args['employeeId'],
            month: args['month'],
            year: args['year'],
          ),
        );

      case faceEnrollment:
        final String employeeId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => FaceEnrollmentScreen(employeeId: employeeId),
        );

      case deviceAssignment:
        final Employee employee = settings.arguments as Employee;
        return MaterialPageRoute(
          builder: (_) => DeviceAssignmentScreen(employee: employee),
        );
      case deviceEnrollmentRequests:
        return MaterialPageRoute(
          builder: (_) => const DeviceEnrollmentRequestsScreen(),
        );

      case custodyDocuments:
        return MaterialPageRoute(
          builder: (_) => const CustodyDocumentListScreen(),
        );

      case custodyDocumentForm:
        return MaterialPageRoute(
          builder: (_) => const CustodyDocumentFormScreen(),
        );
      case custodyReturn:
        return MaterialPageRoute(builder: (_) => const CustodyReturnScreen());

      default:
        return null;
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:order_tracker/models/customer_model.dart';
// import 'package:order_tracker/models/driver_model.dart';
// import 'package:order_tracker/models/order_model.dart';
// import 'package:order_tracker/models/station_models.dart';
// import 'package:order_tracker/models/supplier_model.dart';
// import 'package:order_tracker/screens/activities_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/approval_request_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/fuel_station_details_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/fuel_station_form_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/maintenance_form_fuel_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/send_alert_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/technician_report_screen.dart';
// import 'package:order_tracker/screens/maintenance/daily_check_screen.dart';
// import 'package:order_tracker/screens/maintenance/maintenance_dashboard_screen.dart';
// import 'package:order_tracker/screens/maintenance/maintenance_detail_screen.dart';
// import 'package:order_tracker/screens/maintenance/maintenance_form_screen.dart';
// import 'package:order_tracker/screens/order/costomer_order/customer_form_screen.dart';
// import 'package:order_tracker/screens/order/costomer_order/customer_order_form.dart';
// import 'package:order_tracker/screens/order/costomer_order/customers_screen.dart';
// import 'package:order_tracker/screens/dashboard_screen.dart';
// import 'package:order_tracker/screens/driver_form_screen.dart';
// import 'package:order_tracker/screens/drivers_screen.dart';
// import 'package:order_tracker/screens/login_screen.dart';
// import 'package:order_tracker/screens/notifications_screen.dart';
// import 'package:order_tracker/screens/order/merge/merge_orders_screen.dart';
// import 'package:order_tracker/screens/order/supplier_order/supplier_order_form_screen.dart';
// import 'package:order_tracker/screens/order_details_screen.dart';
// import 'package:order_tracker/screens/orders_screen.dart';
// import 'package:order_tracker/screens/profile_screen.dart';
// import 'package:order_tracker/screens/register_screen.dart';
// import 'package:order_tracker/screens/reports/customer_report_screen.dart';
// import 'package:order_tracker/screens/reports/driver_report_screen.dart';
// import 'package:order_tracker/screens/reports/invoice_report_screen.dart';
// import 'package:order_tracker/screens/reports/reports_screen.dart';
// import 'package:order_tracker/screens/reports/supplier_report_screen.dart';
// import 'package:order_tracker/screens/reports/user_report_screen.dart';
// import 'package:order_tracker/screens/settings_screen.dart';
// import 'package:order_tracker/screens/fuel_stations/fuel_stations_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/close_session_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/daily_inventory_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/inventory_details_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/inventory_list_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/main_home_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/open_session_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/session_details_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/session_edit_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/sessions_list_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/station_details_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/station_form_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/stations_dashboard_screen.dart';
// import 'package:order_tracker/screens/stations_mangaments/stations_list_screen.dart';
// import 'package:order_tracker/screens/trading/trade.dart';
// import 'package:order_tracker/screens/user_management_screen.dart';
// import 'package:order_tracker/screens/suppliers_screen/supplier_details_screen.dart';
// import 'package:order_tracker/screens/suppliers_screen/supplier_form_screen.dart';
// import 'package:order_tracker/screens/suppliers_screen/suppliers_screen.dart';
// import 'package:order_tracker/screens/front_page.dart';

// class AppRoutes {
//   // Front Page (الصفحة الأولى الجديدة)
//   static const front = '/front'; // ✅ أضف هذا المسار

//   // Auth
//   // static const splash = '/';
//   static const login = '/login';
//   static const register = '/register';

//   // Main
//   static const dashboard = '/dashboard';

//   // Orders
//   static const orders = '/orders';
//   static const orderForm = '/orders/form';
//   static const orderDetails = '/orders/details';

//   // Customers
//   static const customerForm = '/customer/form';
//   static const customers = '/customers';

//   static const String driverForm = '/driver/form';
//   static const String drivers = '/drivers';
//   static const String fuelStationManagement = '/fuel-station/management';

//   static const String reports = '/reports';
//   static const String customerReport = '/reports/customers';
//   static const String driverReport = '/reports/drivers';
//   static const String supplierReport = '/reports/suppliers';
//   static const String userReport = '/reports/users';
//   static const String invoiceReport = '/reports/invoice';
//   static const String advancedFilter = '/reports/filter';
//   static const String userManagement = '/users/manage';

//   // Other
//   static const activities = '/activities';
//   static const profile = '/profile';
//   static const settings = '/settings';
//   static const notifications = '/notifications';
//   static const String suppliers = '/suppliers';
//   static const String supplierForm = '/supplier/form';
//   static const String supplierOrderForm = '/supplier/order/form';
//   static const String customerOrderForm = '/customer/order/form';
//   static const String supplierDetails = '/supplier/details';
//   static const String mergeOrders = '/merge-orders';

//   static const String maintenanceDashboard = '/maintenance/dashboard';
//   static const String periodicMaintenance = '/maintenance/periodic';
//   static const String maintenanceForm = '/maintenance/new';
//   static const String maintenanceEdit = '/maintenance/edit';
//   static const String maintenanceDetails = '/maintenance/details';
//   static const String dailyCheck = '/maintenance/daily-check';
//   static const String dailyCheckView = '/maintenance/daily-check/view';

//   static const String fuelStations = '/fuel-stations';
//   static const String fuelStationForm = '/fuel-station/form';
//   static const String fuelStationDetails = '/fuel-station/details';
//   static const String technicianReport = '/technician-report';
//   static const String sendAlert = '/send-alert';
//   static const String approvalRequest = '/approval-request';
//   static const String maintenanceFuelForms = '/maintenanceFuel/form';
//   static const String mainHome = '/main-home';
//   static const String stationsDashboard = '/stations/dashboard';
//   static const String stationsList = '/stations/list';
//   static const String stationForm = '/station/form';
//   static const String stationDetails = '/station/details';
//   static const String sessionsList = '/sessions/list';
//   static const String openSession = '/sessions/open';
//   static const String closeSession = '/sessions/close';
//   static const String sessionDetails = '/session/details';
//   static const String sessionEdit = '/sessions/edit';
//   static const String inventoryList = '/inventory/list';
//   static const String inventoryCreate = '/inventory/create';
//   static const String inventoryDetails = '/inventory/details';
//   static const String reportsStations = '/reports/stations';
//   static const String trading = '/trading';

//   /// Routes بدون arguments
//   static final Map<String, Widget Function(BuildContext)> routes = {
//     front: (context) => FrontPage(
//       onEmployeeLogin: () {
//         Navigator.pushReplacementNamed(context, AppRoutes.login);
//       },
//     ),

//   login: (_) => const LoginScreen(),

//     register: (_) => const RegisterScreen(),
//     drivers: (context) => const DriversScreen(),

//     dashboard: (_) => const DashboardScreen(),
//     trading: (_) => const TraderScreen(),
//     suppliers: (context) => const SuppliersScreen(),

//     // supplierOrderForm: (context) => const SupplierOrderFormScreen(),
//     orders: (_) => const OrdersScreen(),
//     customers: (_) => const CustomersScreen(),

//     maintenanceDashboard: (context) => const MaintenanceDashboardScreen(),
//     periodicMaintenance: (context) => const MaintenanceDashboardScreen(),
//     maintenanceForm: (context) => const MaintenanceFormScreen(),
//     maintenanceDetails: (context) => MaintenanceDetailScreen(
//       maintenanceId: ModalRoute.of(context)!.settings.arguments as String,
//     ),
//     dailyCheck: (context) => DailyCheckScreen(
//       args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
//     ),

//     activities: (_) => const ActivitiesScreen(),
//     profile: (_) => const ProfileScreen(),
//     settings: (_) => const SettingsScreen(),
//     notifications: (_) => const NotificationsScreen(),
//     fuelStations: (context) => const FuelStationsScreen(),
//     fuelStationForm: (context) => const FuelStationFormScreen(),

//     technicianReport: (context) => const TechnicianReportScreen(),
//     sendAlert: (context) => const SendAlertScreen(),
//     approvalRequest: (context) => const ApprovalRequestScreen(),
//     maintenanceFuelForms: (context) => const MaintenanceFuelFormScreen(),

//     // customerOrderForm: (_) => const CustomerOrderFormScreen(),
//     reports: (_) => const ReportsScreen(),
//     customerReport: (_) => const CustomerReportScreen(),
//     driverReport: (_) => const DriverReportScreen(),
//     supplierReport: (_) => const SupplierReportScreen(),
//     userReport: (_) => const UserReportScreen(),
//     userManagement: (_) => const UserManagementScreen(),
//     invoiceReport: (_) => const InvoiceReportScreen(),

//     mainHome: (context) => const MainHomeScreen(),
//     stationsDashboard: (context) => const StationsDashboardScreen(),
//     stationsList: (context) => const StationsListScreen(),
//     stationForm: (context) => const StationFormScreen(),

//     sessionsList: (context) => const SessionsListScreen(),
//     openSession: (context) => const OpenSessionScreen(),
//     closeSession: (context) => const CloseSessionScreen(),
//     inventoryList: (context) => const InventoryListScreen(),
//     inventoryCreate: (context) => const DailyInventoryScreen(),
//   };

//   /// Routes اللي تعتمد على arguments
//   static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
//     switch (settings.name) {
//       /// ➕ إنشاء طلب / ✏️ تعديل طلب
//       case orderForm:
//         final Order? order = settings.arguments as Order?;
//         return MaterialPageRoute(
//           builder: (_) => CustomerOrderFormScreen(orderToEdit: order),
//         );

//       case AppRoutes.sessionDetails:
//         final String sessionId = settings.arguments as String;
//         return MaterialPageRoute(
//           builder: (_) => SessionDetailsScreen(sessionId: sessionId),
//         );

//       case AppRoutes.sessionEdit:
//         final args = settings.arguments;
//         if (args is PumpSession) {
//           return MaterialPageRoute(
//             builder: (_) => SessionEditScreen(session: args),
//           );
//         }
//         return null;

//       case AppRoutes.maintenanceEdit:
//         final record = settings.arguments as Map<String, dynamic>;
//         return MaterialPageRoute(
//           builder: (_) => MaintenanceFormScreen(maintenanceRecord: record),
//         );

//       case AppRoutes.stationDetails:
//         final String stationId = settings.arguments as String;
//         return MaterialPageRoute(
//           builder: (_) => StationDetailsScreen(stationId: stationId),
//         );

//       case AppRoutes.inventoryDetails:
//         final String inventoryId = settings.arguments as String;
//         return MaterialPageRoute(
//           builder: (_) => InventoryDetailsScreen(inventoryId: inventoryId),
//         );

//       case fuelStationDetails:
//         final String stationId = settings.arguments as String;
//         return MaterialPageRoute(
//           builder: (_) => FuelStationDetailsScreen(stationId: stationId),
//         );

//       case AppRoutes.supplierOrderForm:
//         final order = settings.arguments as Order?;
//         return MaterialPageRoute(
//           builder: (_) => SupplierOrderFormScreen(orderToEdit: order),
//         );
//       case AppRoutes.customerOrderForm:
//         final order = settings.arguments as Order?;
//         return MaterialPageRoute(
//           builder: (_) => CustomerOrderFormScreen(orderToEdit: order),
//         );
//       case AppRoutes.mergeOrders:
//         final args = settings.arguments;

//         if (args is Order) {
//           return MaterialPageRoute(
//             builder: (_) => MergeOrdersScreen(orderToEdit: args),
//           );
//         }

//         // fallback (دمج جديد)
//         return MaterialPageRoute(builder: (_) => const MergeOrdersScreen());

//       /// 📄 تفاصيل الطلب
//       case orderDetails:
//         final String orderId = settings.arguments as String;
//         return MaterialPageRoute(
//           builder: (_) => OrderDetailsScreen(orderId: orderId),
//         );

//       /// ➕ إنشاء عميل / ✏️ تعديل عميل
//       case customerForm:
//         final Customer? customer = settings.arguments as Customer?;
//         return MaterialPageRoute(
//           builder: (_) => CustomerFormScreen(customerToEdit: customer),
//         );

//       case driverForm:
//         final Driver? driver = settings.arguments as Driver?;
//         return MaterialPageRoute(
//           builder: (_) => DriverFormScreen(driverToEdit: driver),
//         );

//       case supplierForm:
//         final Supplier? supplier = settings.arguments as Supplier?;
//         return MaterialPageRoute(
//           builder: (_) => SupplierFormScreen(supplierToEdit: supplier),
//         );

//       case supplierDetails:
//         final args = settings.arguments;
//         final supplierId = args is Supplier ? args.id : args as String?;
//         return MaterialPageRoute(
//           builder: (_) => SupplierDetailsScreen(
//             supplierId: supplierId ?? '',
//             supplier: args is Supplier ? args : null,
//           ),
//         );

//       default:
//         return null;
//     }
//   }
// }
