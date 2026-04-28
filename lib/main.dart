import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/firebase_options.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/custody_document_provider.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/providers/driver_tracking_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/providers/inventory_provider.dart';
import 'package:order_tracker/providers/language_provider.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/providers/tanker_provider.dart';
import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/providers/station_inspection_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/providers/circular_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/note_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/providers/station_maintenance_provider.dart';
import 'package:order_tracker/providers/statement_provider.dart';
import 'package:order_tracker/providers/system_pause_provider.dart';
import 'package:order_tracker/providers/tax_provider.dart';
import 'package:order_tracker/providers/theme_provider.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/providers/vehicle_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:order_tracker/services/local_notification_service.dart';
import 'package:order_tracker/widgets/app_shell.dart';
import 'package:order_tracker/widgets/system_pause_gate.dart';

import 'package:order_tracker/localization/app_localizations.dart' as l10n;
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/device_performance.dart';
import 'package:order_tracker/utils/role_route_guard_observer.dart';
import 'package:order_tracker/utils/role_route_policy.dart';

/// 🔑 Navigator Key (ضروري لـ Flutter Web + iframe)
final NavigationLoadingObserver appNavigationObserver =
    NavigationLoadingObserver();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.init();
  await LocalNotificationService.showFromRemoteMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevicePerformance.init();
  DevicePerformance.tuneFlutterCaches();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    unawaited(
      LocalNotificationService.init().catchError((error, stackTrace) {
        debugPrint('Local notifications init skipped on startup: $error');
      }),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),

        ChangeNotifierProxyProvider<AuthProvider, LanguageProvider>(
          create: (_) => LanguageProvider(),
          update: (_, auth, languageProvider) {
            languageProvider ??= LanguageProvider();
            languageProvider.updateDefaultForRole(auth.user?.role);
            return languageProvider;
          },
        ),

        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => TaxProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => CircularProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
        ChangeNotifierProvider(create: (_) => DriverTrackingProvider()),
        ChangeNotifierProvider(create: (_) => TankerProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
        ChangeNotifierProvider(create: (_) => SystemPauseProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => WorkshopFuelProvider()),
        ChangeNotifierProvider(create: (_) => CustodyDocumentProvider()),
        ChangeNotifierProvider(create: (_) => FuelStationProvider()),
        ChangeNotifierProvider(create: (_) => StationProvider()),
        ChangeNotifierProvider(create: (_) => QualificationProvider()),
        ChangeNotifierProvider(create: (_) => MarketingStationProvider()),
        ChangeNotifierProvider(create: (_) => StationInspectionProvider()),
        ChangeNotifierProvider(create: (_) => HRProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => StationMaintenanceProvider()),
        ChangeNotifierProvider(create: (_) => StatementProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final authProvider = context.watch<AuthProvider>();

    /// ⛔ مهم جدًا: ننتظر التهيئة
    if (!authProvider.isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,

      // 🎨 Theme
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProvider.themeMode,

      // 🌍 Localization
      locale: languageProvider.locale,
      supportedLocales: l10n.AppLanguage.values.map((e) => e.locale).toList(),
      localizationsDelegates: const [
        l10n.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      /// ✅ الحل الجذري
      /// لا home ❌
      /// لا push هنا ❌
      /// أول Route فقط
      initialRoute: getInitialRoute(authProvider),

      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [appNavigationObserver, RoleRouteGuardObserver()],

      // 🔔 Notifications
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return _SelectionOverlay(
          child: SystemPauseGate(
            child: AppShell(
              observer: appNavigationObserver,
              child: _AppWithNotifications(child: child),
            ),
          ),
        );
      },
    );
  }
}

/// ===================================
/// 🎯 تحديد أول Route حسب حالة المستخدم
/// ===================================
String? _getInitialDeepLink() {
  if (!kIsWeb) return null;
  final fragment = Uri.base.fragment;
  String? candidate;
  if (fragment.isNotEmpty) {
    candidate = fragment.startsWith('/') ? fragment : '/$fragment';
  } else {
    final path = Uri.base.path;
    if (path.isNotEmpty && path != '/') {
      candidate = path;
      if (Uri.base.hasQuery) {
        candidate = '$candidate?${Uri.base.query}';
      }
    }
  }
  if (candidate == null || candidate.isEmpty || candidate == '/') return null;
  return candidate;
}

const Set<String> _publicRoutes = <String>{
  '/',
  AppRoutes.front,
  AppRoutes.login,
  AppRoutes.register,
};

String _roleHomeRoute(String? role) {
  switch (normalizeRoleKey(role)) {
    case 'station_boy':
      return AppRoutes.sessionsList;
    case 'maintenance':
    case 'maintenance_car_management':
      return AppRoutes.maintenanceDashboard;
    case 'maintenance_station':
      return AppRoutes.stationMaintenanceTechnician;
    case 'employee':
      return AppRoutes.marketingStations;
    case 'movement':
      return AppRoutes.movement;
    case 'archive':
      return AppRoutes.movementArchiveOrders;
    case 'supplier':
      return AppRoutes.supplierPortal;
    case 'finance_manager':
      return AppRoutes.orderManagementCustomerAccounts;
    case 'collector':
      return AppRoutes.customerDebtCollector;
    case 'sales_manager_statiun':
    case 'owner_station':
      return AppRoutes.mainHome;
    case 'driver':
      return AppRoutes.driverHome;
    default:
      return AppRoutes.dashboard;
  }
}

String getInitialRoute(AuthProvider auth) {
  final deepLink = _getInitialDeepLink();
  if (deepLink != null) {
    final deepLinkPath = Uri.tryParse(deepLink)?.path ?? deepLink;

    if (auth.isAuthenticated && auth.user != null) {
      if (_publicRoutes.contains(deepLinkPath)) {
        return _roleHomeRoute(auth.user!.role);
      }
      if (!isRouteAllowedForRole(role: auth.user?.role, routeName: deepLink)) {
        return _roleHomeRoute(auth.user!.role);
      }
      return deepLink;
    }

    if (!_publicRoutes.contains(deepLinkPath)) {
      auth.setPendingRoute(deepLink);
    }

    return AppRoutes.login;
  }

  if (!auth.isAuthenticated || auth.user == null) {
    return AppRoutes.front;
  }

  return _roleHomeRoute(auth.user!.role);
}

/// ===================================
/// 🔔 Notifications Wrapper
/// ===================================
class _AppWithNotifications extends StatefulWidget {
  final Widget child;
  const _AppWithNotifications({required this.child});

  @override
  State<_AppWithNotifications> createState() => _AppWithNotificationsState();
}

class _AppWithNotificationsState extends State<_AppWithNotifications>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeNotifications() {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final notifications = context.read<NotificationProvider>();
    final chat = context.read<ChatProvider>();

    if (auth.isAuthenticated && auth.user != null) {
      notifications.setCurrentUserId(auth.user!.id);
      notifications.fetchNotifications();
      chat.startBackgroundSync();

      final pendingPayload =
          LocalNotificationService.takePendingNavigationPayload();
      if (pendingPayload != null) {
        LocalNotificationService.openChatFromPayload(pendingPayload);
      }
    } else {
      chat.clearState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.user == null) return;

    final chat = context.read<ChatProvider>();
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(chat.pingPresence());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(chat.setPresenceOffline());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<AuthChangeNotification>(
      onNotification: (notification) {
        final auth = context.read<AuthProvider>();
        final notifications = context.read<NotificationProvider>();
        final chat = context.read<ChatProvider>();

        if (notification.isLoggedIn && auth.user != null) {
          notifications.setCurrentUserId(auth.user!.id);
          notifications.fetchNotifications();
          chat.startBackgroundSync();
        } else {
          notifications.setCurrentUserId('');
          notifications.clearAllNotifications();
          chat.clearState();
        }
        return true;
      },
      child: widget.child,
    );
  }
}

/// ===================================
/// 🔐 Auth Notification
/// ===================================
class AuthChangeNotification extends Notification {
  final bool isLoggedIn;
  AuthChangeNotification(this.isLoggedIn);
}

class _SelectionOverlay extends StatefulWidget {
  final Widget child;
  const _SelectionOverlay({required this.child});

  @override
  State<_SelectionOverlay> createState() => _SelectionOverlayState();
}

class _SelectionOverlayState extends State<_SelectionOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: _buildEntry);

  Widget _buildEntry(BuildContext context) {
    return SelectionArea(child: widget.child);
  }

  @override
  void didUpdateWidget(covariant _SelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _entry.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    if (_entry.mounted) {
      _entry.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}
