enum PermissionCategory { page, action }

class PermissionDefinition {
  final String key;
  final String label;
  final PermissionCategory category;

  const PermissionDefinition({
    required this.key,
    required this.label,
    required this.category,
  });
}

const List<PermissionDefinition> pagePermissions = [
  PermissionDefinition(
    key: 'orders_view',
    label: 'عرض الطلبات',
    category: PermissionCategory.page,
  ),
  PermissionDefinition(
    key: 'customers_view',
    label: 'عرض العملاء',
    category: PermissionCategory.page,
  ),
  PermissionDefinition(
    key: 'drivers_view',
    label: 'عرض السائقين',
    category: PermissionCategory.page,
  ),
  PermissionDefinition(
    key: 'suppliers_view',
    label: 'عرض الموردين',
    category: PermissionCategory.page,
  ),
  PermissionDefinition(
    key: 'reports_view',
    label: 'عرض التقارير',
    category: PermissionCategory.page,
  ),
  PermissionDefinition(
    key: 'settings_access',
    label: 'الدخول إلى الإعدادات',
    category: PermissionCategory.page,
  ),
];

const List<PermissionDefinition> actionPermissions = [
  PermissionDefinition(
    key: 'orders_create_customer',
    label: 'إضافة طلب عميل',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'orders_create_supplier',
    label: 'إضافة طلب مورد',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'orders_merge',
    label: 'دمج الطلبات',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'orders_edit',
    label: 'تعديل الطلبات',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'orders_delete',
    label: 'حذف الطلبات',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'orders_manage',
    label: 'إدارة كاملة للطلبات',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'customers_manage',
    label: 'إضافة وتعديل وحذف العملاء',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'drivers_manage',
    label: 'إضافة وتعديل وحذف السائقين',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'suppliers_manage',
    label: 'إضافة وتعديل وحذف الموردين',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'users_manage',
    label: 'إدارة المستخدمين',
    category: PermissionCategory.action,
  ),
];

const List<PermissionDefinition> statsPermissions = [
  PermissionDefinition(
    key: 'stats_total_orders',
    label: 'عرض إجمالي الطلبات',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_supplier_pending',
    label: 'عرض طلبات المورد في الانتظار',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_supplier_merged',
    label: 'عرض طلبات المورد المدمجة',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_customer_waiting',
    label: 'عرض طلبات العميل في الانتظار',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_customer_assigned',
    label: 'عرض الطلبات المخصصة للعملاء',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_merged_orders',
    label: 'عرض الطلبات المدمجة',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_completed_orders',
    label: 'عرض الطلبات المكتملة',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_today_orders',
    label: 'عرض طلبات اليوم',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_week_orders',
    label: 'عرض طلبات الأسبوع',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_month_orders',
    label: 'عرض طلبات الشهر',
    category: PermissionCategory.action,
  ),
  PermissionDefinition(
    key: 'stats_cancelled_orders',
    label: 'عرض الطلبات المرفوضة',
    category: PermissionCategory.action,
  ),
];

const List<PermissionDefinition> permissionDefinitions = [
  ...pagePermissions,
  ...actionPermissions,
  ...statsPermissions,
];

final Map<String, PermissionDefinition> _permissionLookup = Map.fromEntries(
  permissionDefinitions.map(
    (permission) => MapEntry(permission.key, permission),
  ),
);

String permissionLabel(String key) => _permissionLookup[key]?.label ?? key;

const List<String> permissionKeys = [
  'orders_view',
  'customers_view',
  'drivers_view',
  'suppliers_view',
  'reports_view',
  'settings_access',
  'orders_create_customer',
  'orders_create_supplier',
  'orders_merge',
  'orders_edit',
  'orders_delete',
  'orders_manage',
  'customers_manage',
  'drivers_manage',
  'suppliers_manage',
  'users_manage',
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
];
