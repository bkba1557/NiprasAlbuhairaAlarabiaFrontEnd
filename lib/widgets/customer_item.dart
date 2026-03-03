import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';
import '../models/customer_model.dart';

enum _CustomerStatusType { active, suspended, banned }

const Set<String> _activeStatusKeywords = {
  'active',
  'نشط',
  'نشيط',
  'فعال',
  'مفعل',
  'enabled',
};

const Set<String> _suspendedStatusKeywords = {
  'suspended',
  'موقوف',
  'معلق',
  'تعليق',
  'متوقف',
  'inactive',
  'غير نشط',
  'مؤقت',
};

const Set<String> _bannedStatusKeywords = {
  'banned',
  'blocked',
  'محظور',
  'ممنوع',
  'معاقب',
  'مغلق',
  'محجوز',
};

bool _matchesStatus(String normalized, Set<String> keywords) {
  return keywords.any((keyword) => normalized.contains(keyword));
}

_CustomerStatusType _resolveCustomerStatus(Customer customer) {
  final normalized = customer.status.toLowerCase().trim();
  if (normalized.isEmpty) {
    return customer.isActive
        ? _CustomerStatusType.active
        : _CustomerStatusType.banned;
  }

  if (_matchesStatus(normalized, _bannedStatusKeywords)) {
    return _CustomerStatusType.banned;
  }
  if (_matchesStatus(normalized, _suspendedStatusKeywords)) {
    return _CustomerStatusType.suspended;
  }
  if (_matchesStatus(normalized, _activeStatusKeywords)) {
    return _CustomerStatusType.active;
  }

  return customer.isActive
      ? _CustomerStatusType.active
      : _CustomerStatusType.banned;
}

String _customerStatusLabel(_CustomerStatusType type) {
  switch (type) {
    case _CustomerStatusType.suspended:
      return 'موقوف';
    case _CustomerStatusType.banned:
      return 'محظور';
    case _CustomerStatusType.active:
    default:
      return 'نشط';
  }
}

Color _customerStatusColor(_CustomerStatusType type) {
  switch (type) {
    case _CustomerStatusType.suspended:
      return AppColors.warningOrange;
    case _CustomerStatusType.banned:
      return AppColors.errorRed;
    case _CustomerStatusType.active:
    default:
      return AppColors.successGreen;
  }
}

class CustomerItem extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CustomerItem({
    super.key,
    required this.customer,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusType = _resolveCustomerStatus(customer);
    final statusColor = _customerStatusColor(statusType);
    final statusLabel = _customerStatusLabel(statusType);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 20,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.code,
                                    size: 16,
                                    color: AppColors.mediumGray,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    customer.code,
                                    style: TextStyle(
                                      color: AppColors.mediumGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (customer.phone != null &&
                                  customer.phone!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: AppColors.mediumGray,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        customer.phone!,
                                        style: TextStyle(
                                          color: AppColors.mediumGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status and actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Action buttons
                      Row(
                        children: [
                          if (onEdit != null)
                            IconButton(
                              onPressed: onEdit,
                              icon: Icon(
                                Icons.edit,
                                size: 20,
                                color: AppColors.primaryBlue,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          if (onDelete != null)
                            IconButton(
                              onPressed: onDelete,
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.errorRed,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Additional info
              if (customer.contactPerson != null ||
                  customer.email != null ||
                  customer.notes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (customer.contactPerson != null &&
                          customer.contactPerson!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.contact_page,
                                size: 16,
                                color: AppColors.lightGray,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'مسؤول الاتصال: ${customer.contactPerson!}',
                                  style: TextStyle(
                                    color: AppColors.mediumGray,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (customer.email != null && customer.email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 16,
                                color: AppColors.lightGray,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customer.email!,
                                  style: TextStyle(
                                    color: AppColors.mediumGray,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (customer.notes != null && customer.notes!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.note,
                                size: 16,
                                color: AppColors.lightGray,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customer.notes!,
                                  style: TextStyle(
                                    color: AppColors.mediumGray,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              // Footer with creation info
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 40),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.lightGray,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تم الإنشاء: ${DateFormat('yyyy/MM/dd').format(customer.createdAt)}',
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (customer.createdByName != null)
                      Text(
                        'بواسطة: ${customer.createdByName!}',
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Customer Item Compact (للـ ListView)
  class CustomerItemCompact extends StatelessWidget {
    final Customer customer;
    final VoidCallback onTap;
    final bool showActions;

  const CustomerItemCompact({
    super.key,
    required this.customer,
    required this.onTap,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusType = _resolveCustomerStatus(customer);
    final statusColor = _customerStatusColor(statusType);
    final statusLabel = _customerStatusLabel(statusType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              customer.code.substring(0, 2).toUpperCase(),
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'كود: ${customer.code}',
              style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
            ),
            if (customer.phone != null && customer.phone!.isNotEmpty)
              Text(
                customer.phone!,
                style: TextStyle(color: AppColors.lightGray, fontSize: 12),
              ),
          ],
        ),
        trailing: showActions
            ? PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    // TODO: Handle edit
                  } else if (value == 'delete') {
                    // TODO: Handle delete
                  }
                },
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

// Customer Chip للاستخدام في AutoComplete
class CustomerChip extends StatelessWidget {
  final Customer customer;
  final VoidCallback onSelected;
  final VoidCallback? onRemove;

  const CustomerChip({
    super.key,
    required this.customer,
    required this.onSelected,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(customer.displayName),
      avatar: CircleAvatar(
        backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
        child: Text(
          customer.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      deleteIcon: onRemove != null ? const Icon(Icons.close, size: 16) : null,
      onDeleted: onRemove,
      onPressed: onSelected,
      backgroundColor: AppColors.backgroundGray,
      selectedColor: AppColors.primaryBlue.withOpacity(0.2),
      checkmarkColor: AppColors.primaryBlue,
    );
  }
}
