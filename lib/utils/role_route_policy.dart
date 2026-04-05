import 'package:order_tracker/utils/app_routes.dart';

const String employeeRoleKey = 'employee';
const String movementRoleKey = 'movement';

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
};

String normalizeRoutePath(String routeName) {
  final uri = Uri.tryParse(routeName);
  return uri?.path ?? routeName;
}

String normalizeRoleKey(String? role) => role?.trim().toLowerCase() ?? '';

bool isEmployeeRole(String? role) => normalizeRoleKey(role) == employeeRoleKey;

bool isMovementRole(String? role) => normalizeRoleKey(role) == movementRoleKey;

Set<String>? _allowedRoutesForRole(String? role) {
  switch (normalizeRoleKey(role)) {
    case employeeRoleKey:
      return employeeAllowedRoutePaths;
    case movementRoleKey:
      return movementAllowedRoutePaths;
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
