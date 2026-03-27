import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isLargeScreen;
  final bool compact;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle = '',
    required this.isLargeScreen,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(20);

    final iconBoxSize = compact
        ? 36.0
        : isLargeScreen
        ? 46.0
        : 42.0;
    final iconSize = compact
        ? 18.0
        : isLargeScreen
        ? 24.0
        : 22.0;
    final cardPadding = EdgeInsets.all(
      compact
          ? 12
          : isLargeScreen
          ? 18
          : 16,
    );

    final valueStyle = theme.textTheme.headlineSmall?.copyWith(
      fontSize: compact
          ? 18
          : isLargeScreen
          ? 30
          : 26,
      fontWeight: FontWeight.w900,
      color: AppColors.appBarWaterDeep,
      height: 1.0,
    );

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.darkGray,
      fontSize: compact ? 11 : null,
      height: compact ? 1.1 : null,
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.mediumGray.withValues(alpha: 0.92),
      height: compact ? 1.12 : 1.25,
      fontSize: compact ? 10 : null,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    color.withValues(alpha: 0.16),
                    color.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: cardPadding,
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: iconBoxSize,
                        height: iconBoxSize,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: color, size: iconSize),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          textDirection: ui.TextDirection.ltr,
                          style: valueStyle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: titleStyle,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: subtitleStyle,
                        ),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: iconBoxSize,
                            height: iconBoxSize,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: color, size: iconSize),
                          ),
                          const Spacer(),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                textDirection: ui.TextDirection.ltr,
                                style: valueStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
