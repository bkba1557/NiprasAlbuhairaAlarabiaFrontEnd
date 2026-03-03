import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/app_routes.dart';

class EmptyOrdersWidget extends StatelessWidget {
  final VoidCallback? onCreateOrder;
  final String title;
  final String message;
  final String? actionText;
  final IconData? icon;
  final bool showCreateButton;

  const EmptyOrdersWidget({
    super.key,
    this.onCreateOrder,
    this.title = 'لا توجد طلبات حالياً',
    this.message = 'ابدأ بإنشاء طلبك الأول',
    this.actionText,
    this.icon,
    this.showCreateButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue.withOpacity(0.1),
            ),
            child: Center(
              child: Icon(
                icon ?? Icons.inventory_2_outlined,
                size: 60,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Message
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: AppColors.mediumGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Action Buttons
          if (showCreateButton) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Create Supplier Order
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.supplierOrderForm);
                  },
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('طلب مورد جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Create Customer Order
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.customerOrderForm);
                  },
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('طلب عميل جديد'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Merge Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.mergeOrders);
              },
              icon: const Icon(Icons.merge_outlined),
              label: const Text('دمج الطلبات'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],

          // Custom action button
          if (onCreateOrder != null && actionText != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onCreateOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

// Empty state for specific sections
class EmptySectionWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final bool showBorder;

  const EmptySectionWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.iconColor = AppColors.primaryBlue,
    this.iconSize = 48,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: showBorder
            ? Border.all(color: AppColors.lightGray)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.mediumGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Empty state for search results
class EmptySearchResultsWidget extends StatelessWidget {
  final String query;

  const EmptySearchResultsWidget({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 80,
            color: AppColors.primaryBlue.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: AppColors.mediumGray),
              children: [
                const TextSpan(text: 'لم يتم العثور على طلبات تطابق '),
                TextSpan(
                  text: '"$query"',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'جرب استخدام كلمات بحث مختلفة أو قم بإنشاء طلب جديد',
            style: TextStyle(fontSize: 14, color: AppColors.lightGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Empty state for filters
class EmptyFilterResultsWidget extends StatelessWidget {
  final VoidCallback onClearFilters;

  const EmptyFilterResultsWidget({super.key, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 80,
            color: AppColors.warningOrange.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد طلبات مطابقة للفلاتر',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.warningOrange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'تعديل الفلاتر المطبقة حالياً لمشاهدة المزيد من الطلبات',
            style: TextStyle(fontSize: 16, color: AppColors.mediumGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.clear_all),
            label: const Text('مسح جميع الفلاتر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
