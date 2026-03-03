import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/utils/constants.dart';

class FuelPriceCard extends StatelessWidget {
  final FuelPrice price;

  const FuelPriceCard({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 👈 مهم لمنع overflow
        children: [
          // 💲 أيقونة
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.attach_money,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // 🛢️ نوع الوقود + التاريخ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.fuelType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: web ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy/MM/dd').format(price.effectiveDate),
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: web ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 💰 السعر
          Text(
            '${price.price.toStringAsFixed(2)} ريال/لتر',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: web ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: AppColors.warningOrange,
            ),
          ),
        ],
      ),
    );
  }
}
