import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/utils/constants.dart';

class PumpCard extends StatelessWidget {
  final Pump pump;
  final VoidCallback? onTap;

  const PumpCard({super.key, required this.pump, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 600;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 350;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 16 : 8,
        vertical: 6,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 20 : 16,
            vertical: isLargeScreen ? 16 : 12,
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 12 : 10),
                decoration: BoxDecoration(
                  color: pump.isActive
                      ? AppColors.primaryBlue.withOpacity(0.1)
                      : AppColors.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_gas_station,
                  color: pump.isActive
                      ? AppColors.primaryBlue
                      : AppColors.errorRed,
                  size: isLargeScreen ? 24 : 20,
                ),
              ),

              SizedBox(width: isLargeScreen ? 16 : 12),

              // Main Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pump.pumpNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isLargeScreen ? 18 : 16,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        if (!isSmallScreen) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pump.isActive
                                  ? AppColors.successGreen.withOpacity(0.1)
                                  : AppColors.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pump.isActive ? 'نشطة' : 'معطلة',
                              style: TextStyle(
                                color: pump.isActive
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                                fontSize: isLargeScreen ? 13 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: isLargeScreen ? 6 : 4),

                    Text(
                      pump.fuelType,
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: isLargeScreen ? 15 : 14,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),

                    if (isLargeScreen) ...[
                      SizedBox(height: 8),
                      Text(
                        'عدد الفتحات: ${pump.nozzleCount}',
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Side Info (for larger screens or fallback)
              if (!isLargeScreen || isSmallScreen) ...[
                SizedBox(width: isLargeScreen ? 20 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSmallScreen) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pump.isActive
                              ? AppColors.successGreen.withOpacity(0.1)
                              : AppColors.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pump.isActive ? 'نشطة' : 'معطلة',
                          style: TextStyle(
                            color: pump.isActive
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                    Text(
                      '${pump.nozzleCount} فتحة',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: isLargeScreen ? 14 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
