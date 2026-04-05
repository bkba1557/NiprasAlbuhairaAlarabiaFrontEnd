import 'package:order_tracker/utils/permission_definitions.dart';

const Set<String> _destructivePermissions = {
  'orders_delete',
  'customers_delete',
  'drivers_delete',
  'suppliers_delete',
  'users_delete',
};

const Set<String> _adminExcludedPermissions = {
  'users_create',
  'users_edit',
  'users_delete',
  'orders_delete',
  'customers_delete',
  'drivers_delete',
  'suppliers_delete',
};

const Set<String> _supervisorExcludedPermissions = {
  'orders_edit',
  'orders_delete',
  'orders_manage',
  'customers_edit',
  'customers_delete',
  'customers_manage',
  'drivers_edit',
  'drivers_delete',
  'drivers_manage',
  'suppliers_edit',
  'suppliers_delete',
  'suppliers_manage',
  'users_create',
  'users_edit',
  'users_delete',
  'users_block',
  'users_manage',
  'tasks_edit',
  'tasks_approve',
  'tasks_extend',
  'tasks_penalty',
  'tasks_manage_participants',
  'inventory_manage',
  'station_maintenance_manage',
  'maintenance_periodic_manage',
  'fuel_sales_manage',
  'marketing_stations_manage',
  'qualification_manage',
  'hr_manage',
  'contracts_manage',
  'archive_manage',
  'custody_documents_manage',
};

const Set<String> _viewerAllowedPermissions = {
  'orders_view',
  'orders_view_assigned_only',
  'customers_view',
  'drivers_view',
  'suppliers_view',
  'reports_view',
  'tracking_view',
  'inventory_view',
  'activities_view',
  'tasks_view',
  'tasks_view_all',
  'station_maintenance_view',
  'maintenance_periodic_view',
  'fuel_sales_view',
  'marketing_stations_view',
  'qualification_view',
  'hr_view',
  'contracts_view',
  'archive_view',
  'custody_documents_view',
  'users_view',
  'blocked_devices_view',
  'auth_devices_view',
  'stats_total_orders',
  'stats_supplier_pending',
  'stats_supplier_merged',
  'stats_customer_waiting',
  'stats_customer_assigned',
  'stats_merged_orders',
  'stats_completed_orders',
  'stats_today_orders',
  'stats_week_orders',
  'stats_month_orders',
  'stats_cancelled_orders',
};

const Set<String> _driverDefaultPermissions = {
  'orders_view',
  'orders_view_assigned_only',
  'tasks_view',
};

const Set<String> _supplierDefaultPermissions = {
  'orders_view',
  'orders_create_supplier',
  'suppliers_view',
};

const Set<String> _employeeDefaultPermissions = {'tasks_view'};

List<String> defaultPermissionsForRole(String role) {
  switch (role.trim().toLowerCase()) {
    case 'owner':
      return List<String>.from(permissionKeys);
    case 'admin':
    case 'manager':
      return permissionKeys
          .where((key) => !_adminExcludedPermissions.contains(key))
          .toList();
    case 'supervisor':
      return permissionKeys
          .where(
            (key) =>
                !_supervisorExcludedPermissions.contains(key) &&
                !_destructivePermissions.contains(key),
          )
          .toList();
    case 'viewer':
      return permissionKeys.where(_viewerAllowedPermissions.contains).toList();
    case 'employee':
      return permissionKeys
          .where(_employeeDefaultPermissions.contains)
          .toList();
    case 'driver':
      return permissionKeys.where(_driverDefaultPermissions.contains).toList();
    case 'supplier':
      return permissionKeys.where(_supplierDefaultPermissions.contains).toList();
    default:
      return const <String>[];
  }
}

Set<String> effectivePermissionsForRole(
  String role,
  Iterable<String> assignedPermissions,
) {
  if (role.trim().toLowerCase() == 'owner') {
    return permissionKeys.toSet();
  }

  final explicit = assignedPermissions
      .map((permission) => permission.trim())
      .where((permission) => permission.isNotEmpty)
      .toSet();

  if (explicit.isNotEmpty) {
    return explicit;
  }

  return defaultPermissionsForRole(role).toSet();
}

bool roleHasPermission({
  required String role,
  required Iterable<String> assignedPermissions,
  required String key,
}) {
  if (role.trim().toLowerCase() == 'owner') {
    return true;
  }

  final permissions = effectivePermissionsForRole(role, assignedPermissions);
  if (permissions.contains(key)) {
    return true;
  }

  if (key.startsWith('orders_') && permissions.contains('orders_manage')) {
    return true;
  }

  if (key.startsWith('customers_') &&
      permissions.contains('customers_manage')) {
    return true;
  }

  if (key.startsWith('drivers_') && permissions.contains('drivers_manage')) {
    return true;
  }

  if (key.startsWith('suppliers_') &&
      permissions.contains('suppliers_manage')) {
    return true;
  }

  if (key.startsWith('users_') && permissions.contains('users_manage')) {
    return true;
  }

  if (key == 'tasks_view' &&
      (permissions.contains('tasks_view_all') ||
          permissions.contains('tasks_create') ||
          permissions.contains('tasks_edit') ||
          permissions.contains('tasks_approve'))) {
    return true;
  }

  return false;
}

bool roleHasAnyPermission({
  required String role,
  required Iterable<String> assignedPermissions,
  required Iterable<String> keys,
}) {
  return keys.any(
    (key) => roleHasPermission(
      role: role,
      assignedPermissions: assignedPermissions,
      key: key,
    ),
  );
}
