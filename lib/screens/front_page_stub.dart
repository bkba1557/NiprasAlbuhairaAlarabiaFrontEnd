import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/device_performance.dart';

class FrontPage extends StatelessWidget {
  final VoidCallback onEmployeeLogin;

  const FrontPage({super.key, required this.onEmployeeLogin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceEffects = DevicePerformance.reduceEffects;
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          const _FrontPageBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isPhone ? 14 : 24,
                    isPhone ? 12 : 24,
                    isPhone ? 14 : 24,
                    isPhone ? 18 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isPhone ? 24 : 48),
                    ),
                    child: Align(
                      alignment: isPhone
                          ? Alignment.topCenter
                          : Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isPhone ? 430 : 540,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isPhone ? 24 : 26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: reduceEffects ? 0 : 18,
                              sigmaY: reduceEffects ? 0 : 18,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isPhone ? 18 : 28,
                                vertical: isPhone ? 20 : 30,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.80),
                                borderRadius: BorderRadius.circular(
                                  isPhone ? 24 : 26,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                                boxShadow: reduceEffects
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: isPhone ? 18 : 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                              ),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FrontPageHeader(
                                      theme: theme,
                                      isPhone: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 14 : 18),
                                    Text(
                                      'منصة موحدة تساعد على إدارة المحطات ومتابعة التشغيل اليومي والمبيعات والمخزون والتقارير من واجهة واضحة وسريعة.',
                                      textAlign: isPhone
                                          ? TextAlign.center
                                          : TextAlign.start,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontSize: isPhone ? 13.5 : 17,
                                            color: const Color(0xFF314744),
                                            height: isPhone ? 1.65 : 1.75,
                                          ),
                                    ),
                                    SizedBox(height: isPhone ? 14 : 18),
                                    Wrap(
                                      spacing: isPhone ? 8 : 10,
                                      runSpacing: isPhone ? 8 : 10,
                                      alignment: isPhone
                                          ? WrapAlignment.center
                                          : WrapAlignment.start,
                                      children: [
                                        _FrontPageChip(
                                          label: 'إدارة المحطات',
                                          compact: isPhone,
                                        ),
                                        _FrontPageChip(
                                          label: 'المخزون والجرد',
                                          compact: isPhone,
                                        ),
                                        _FrontPageChip(
                                          label: 'المهام والإشعارات',
                                          compact: isPhone,
                                        ),
                                        _FrontPageChip(
                                          label: 'التقارير والمتابعة',
                                          compact: isPhone,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isPhone ? 14 : 18),
                                    _FrontPageFeature(
                                      icon: Icons.local_gas_station_rounded,
                                      title: 'تشغيل المحطات',
                                      description:
                                          'متابعة المحطات والمضخات والجلسات اليومية ومراقبة حركة المبيعات بشكل مباشر.',
                                      compact: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 12),
                                    _FrontPageFeature(
                                      icon: Icons.inventory_2_rounded,
                                      title: 'مخزون وجرد الوقود',
                                      description:
                                          'عرض الأرصدة اليومية والجرد والتوريد مع قراءة أوضح لحالة الوقود داخل المحطة.',
                                      compact: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 12),
                                    _FrontPageFeature(
                                      icon: Icons.analytics_rounded,
                                      title: 'تقارير وقرارات أسرع',
                                      description:
                                          'لوحات مختصرة للتقارير والإحصائيات والتنبيهات لدعم الإدارة في اتخاذ القرار.',
                                      compact: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 18 : 22),
                                 SizedBox(
                                      width: double.infinity,
                                      height: isPhone ? 50 : 54,
                                      child: ElevatedButton.icon(
                                        onPressed: onEmployeeLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1F7A6C,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.login_rounded,
                                          size: 22,
                                        ),
                                        label: Text(
                                          'تسجيل الدخول',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Cairo', // 🔥 مهم جدا
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            height:
                                                1.2, // ✅ يمنع الحروف تنزل لتحت
                                          ),
                                        ),
                                      ),
                                    ),
                                   
                                    SizedBox(height: isPhone ? 8 : 10),
                                    Text(
                                      'يمكنك تسجيل الدخول للوصول إلى جميع خدمات التطبيق وإدارة العمليات اليومية من حسابك.',
                                      textAlign: isPhone
                                          ? TextAlign.center
                                          : TextAlign.start,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: isPhone ? 11.5 : 12.5,
                                            color: Colors.black54,
                                            height: 1.6,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontPageHeader extends StatelessWidget {
  final ThemeData theme;
  final bool isPhone;

  const _FrontPageHeader({required this.theme, required this.isPhone});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: isPhone ? 66 : 76,
      height: isPhone ? 66 : 76,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(isPhone ? 18 : 20),
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: isPhone ? 80 : 54,
          height: isPhone ? 70 : 54,
          errorBuilder: (_, __, ___) => Icon(
            Icons.local_gas_station_rounded,
            size: isPhone ? 30 : 34,
            color: const Color(0xFF1F7A6C),
          ),
        ),
      ),
    );

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 10 : 12,
        vertical: isPhone ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1F7A6C).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'بوابة التطبيق',
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: isPhone ? 11 : 12,
          color: const Color(0xFF0B4F4A),
          fontFamily: 'Cairo', 
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final title = Text(
      'نظام متابعة طلبات الوقود',
      textAlign: isPhone ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontSize: isPhone ? 18 : 30,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF0F2F2B),
        height: 1.15,
      ),
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(child: logo),
          const SizedBox(height: 10),
          Center(child: badge),
          const SizedBox(height: 10),
          title,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logo,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge,
              const SizedBox(height: 10),
              title,
            ],
          ),
        ),
      ],
    );
  }
}

class _FrontPageChip extends StatelessWidget {
  final String label;
  final bool compact;

  const _FrontPageChip({required this.label, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: compact ? 12.5 : 14,
              color: const Color(0xFF164C44),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FrontPageFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool compact;

  const _FrontPageFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1F7A6C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1F7A6C),
              size: compact ? 20 : 24,
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF113531),
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: compact ? 12.5 : 14,
                    height: compact ? 1.55 : 1.65,
                    color: const Color(0xFF4B5B58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontPageBackground extends StatelessWidget {
  const _FrontPageBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B4F4A),
                Color(0xFF1F7A6C),
                Color(0xFF1E3A5F),
              ],
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -40,
          child: _GlowCircle(
            size: 220,
            color: Colors.amber.withValues(alpha: 0.25),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -60,
          child: _GlowCircle(
            size: 260,
            color: Colors.tealAccent.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 10)],
      ),
    );
  }
}
