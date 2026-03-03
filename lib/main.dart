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
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/providers/inventory_provider.dart';
import 'package:order_tracker/providers/language_provider.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/providers/station_inspection_provider.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/providers/station_maintenance_provider.dart';
import 'package:order_tracker/providers/theme_provider.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:order_tracker/services/local_notification_service.dart';
import 'package:order_tracker/widgets/app_shell.dart';

import 'package:order_tracker/localization/app_localizations.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await LocalNotificationService.init();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
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
      title: 'نظام نبراس لإدارة وتتبع الطلبات | شركة البحيرة العربية',

      // 🎨 Theme
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProvider.themeMode,

      // 🌍 Localization
      locale: languageProvider.locale,
      supportedLocales: AppLanguage.values.map((e) => e.locale).toList(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
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
      navigatorObservers: [appNavigationObserver],

      // 🔔 Notifications
      builder: (context, child) {
        return AppShell(
          observer: appNavigationObserver,
          child: _AppWithNotifications(child: child!),
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
  switch (role) {
    case 'station_boy':
      return AppRoutes.sessionsList;
    case 'maintenance':
    case 'maintenance_car_management':
      return AppRoutes.maintenanceDashboard;
    case 'maintenance_station':
      return AppRoutes.stationMaintenanceTechnician;
    case 'finance_manager':
      return AppRoutes.custodyDashboard;
    case 'sales_manager_statiun':
      return AppRoutes.mainHome;
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
