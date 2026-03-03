import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class LocationCard extends StatelessWidget {
  final WorkLocation location;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewEmployees;
  final VoidCallback onNavigate;

  const LocationCard({
    super.key,
    required this.location,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onViewEmployees,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      location.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(
                    location.isActive ? Icons.check_circle : Icons.cancel,
                    color: location.isActive ? AppColors.successGreen : AppColors.errorRed,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('الرمز: ${location.code}'),
              Text('النوع: ${location.type}'),
              Text('العنوان: ${location.address}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    onPressed: onToggleStatus,
                    icon: Icon(location.isActive ? Icons.toggle_on : Icons.toggle_off),
                    tooltip: location.isActive ? 'تعطيل' : 'تفعيل',
                  ),
                  IconButton(
                    onPressed: onViewEmployees,
                    icon: const Icon(Icons.group),
                    tooltip: 'الموظفون',
                  ),
                  IconButton(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation),
                    tooltip: 'خرائط',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
