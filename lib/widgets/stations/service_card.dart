import 'package:flutter/material.dart';

class ServiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onTap;
  final bool compact;

  const ServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.compact = false,
  });

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    final hover = enabled && _hovered;
    final compact = widget.compact;
    final radius = compact ? 16.0 : 22.0;
    final badgeSize = compact ? 36.0 : 46.0;
    final badgeIconSize = compact ? 18.0 : 24.0;
    final contentPadding = compact ? 10.0 : 16.0;
    final topStripHeight = compact ? 4.0 : 6.0;
    final glowSize = compact ? 96.0 : 140.0;
    final titleGap = compact ? 3.0 : 6.0;
    final betweenGap = compact ? 8.0 : 12.0;
    final trailingGap = compact ? 2.0 : 8.0;
    final chevronSize = compact ? 18.0 : 24.0;

    final accent = _accentColor(widget.gradient) ?? theme.colorScheme.primary;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: compact ? 12.5 : null,
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: enabled ? const Color(0xFF0F172A) : theme.disabledColor,
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: compact ? 9.5 : null,
      height: 1.25,
      color: enabled
          ? const Color(0xFF475569).withValues(alpha: 0.92)
          : theme.disabledColor.withValues(alpha: 0.75),
    );

    final surface = theme.colorScheme.surface;
    final background = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [surface, Color.lerp(surface, accent, hover ? 0.08 : 0.05)!],
    );

    final borderColor = hover
        ? accent.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: enabled ? 0.06 : 0.03);

    final shadowColor = Colors.black.withValues(alpha: hover ? 0.14 : 0.06);

    return AnimatedScale(
      scale: hover ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: hover ? 26 : 14,
              offset: Offset(0, hover ? 12 : 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
            ),
            child: InkWell(
              onTap: enabled ? widget.onTap : null,
              onHover: enabled ? (v) => setState(() => _hovered = v) : null,
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: accent.withValues(alpha: 0.05),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topStripHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: widget.gradient),
                    ),
                  ),
                  Positioned(
                    top: compact ? -34 : -54,
                    right: compact ? -40 : -64,
                    child: IgnorePointer(
                      child: Container(
                        width: glowSize,
                        height: glowSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.18),
                              accent.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(contentPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconBadge(
                          icon: widget.icon,
                          gradient: widget.gradient,
                          enabled: enabled,
                          size: badgeSize,
                          iconSize: badgeIconSize,
                          compact: compact,
                        ),
                        SizedBox(width: betweenGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.title,
                                style: titleStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: titleGap),
                              Text(
                                widget.subtitle,
                                style: subtitleStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: trailingGap),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          size: chevronSize,
                          color: enabled
                              ? const Color(0xFF64748B).withValues(alpha: 0.85)
                              : theme.disabledColor.withValues(alpha: 0.75),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _accentColor(Gradient gradient) {
    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
    if (gradient is RadialGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
    if (gradient is SweepGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
    return null;
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final bool enabled;
  final double size;
  final double iconSize;
  final bool compact;

  const _IconBadge({
    required this.icon,
    required this.gradient,
    required this.enabled,
    required this.size,
    required this.iconSize,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(compact ? 11 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: compact ? 10 : 16,
              offset: Offset(0, compact ? 5 : 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
