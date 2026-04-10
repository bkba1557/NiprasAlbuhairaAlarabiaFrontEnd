import 'package:order_tracker/utils/app_routes.dart';

const String employeeRoleKey = 'employee';
const String movementRoleKey = 'movement';
const String archiveRoleKey = 'archive';
const String supplierRoleKey = 'supplier';

const Set<String> employeeAllowedRoutePaths = <String>{
  AppRoutes.marketingStations,
  AppRoutes.tasks,
  AppRoutes.qualificationDashboard,
  AppRoutes.qualificationForm,
  AppRoutes.qualificationDetails,
  AppRoutes.qualificationMap,
  AppRoutes.chat,
  AppRoutes.chatConversation,
  AppRoutes.notifications,
  AppRoutes.profile,
  AppRoutes.settings,
  AppRoutes.support,
};

const Set<String> movementAllowedRoutePaths = <String>{
  AppRoutes.movement,
  AppRoutes.supplierPortal,
};

const Set<String> archiveAllowedRoutePaths = <String>{
  AppRoutes.movementArchiveOrders,
};

const Set<String> supplierAllowedRoutePaths = <String>{
  AppRoutes.supplierPortal,
};

String normalizeRoutePath(String routeName) {
  final uri = Uri.tryParse(routeName);
  return uri?.path ?? routeName;
}

String normalizeRoleKey(String? role) => role?.trim().toLowerCase() ?? '';

bool isEmployeeRole(String? role) => normalizeRoleKey(role) == employeeRoleKey;

bool isMovementRole(String? role) => normalizeRoleKey(role) == movementRoleKey;

bool isArchiveRole(String? role) => normalizeRoleKey(role) == archiveRoleKey;

bool isSupplierRole(String? role) => normalizeRoleKey(role) == supplierRoleKey;

Set<String>? _allowedRoutesForRole(String? role) {
  switch (normalizeRoleKey(role)) {
    case employeeRoleKey:
      return employeeAllowedRoutePaths;
    case movementRoleKey:
      return movementAllowedRoutePaths;
    case archiveRoleKey:
      return archiveAllowedRoutePaths;
    case supplierRoleKey:
      return supplierAllowedRoutePaths;
    default:
      return null;
  }
}

String? restrictedRoleHomeRoute(String? role) {
  switch (normalizeRoleKey(role)) {
    case employeeRoleKey:
      return AppRoutes.marketingStations;
    case movementRoleKey:
      return AppRoutes.movement;
    case archiveRoleKey:
      return AppRoutes.movementArchiveOrders;
    case supplierRoleKey:
      return AppRoutes.supplierPortal;
    default:
      return null;
  }
}

bool isRestrictedSingleRouteRole(String? role) =>
    restrictedRoleHomeRoute(role) != null;

bool isRouteAllowedForRole({required String? role, required String routeName}) {
  final allowedRoutes = _allowedRoutesForRole(role);
  if (allowedRoutes == null) {
    return true;
  }

  final path = normalizeRoutePath(routeName);
  return allowedRoutes.contains(path);
}
