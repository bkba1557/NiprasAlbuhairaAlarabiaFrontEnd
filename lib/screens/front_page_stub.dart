import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/device_performance.dart';

class FrontPage extends StatelessWidget {
  final VoidCallback onEmployeeLogin;

  const FrontPage({super.key, required this.onEmployeeLogin});

  static const Color navy = Color(0xFF071A2F);
  static const Color darkBlue = Color(0xFF0B2E55);
  static const Color royalBlue = Color(0xFF145DA0);
  static const Color gold = Color(0xFFD9A441);
  static const Color softGold = Color(0xFFFFD98A);

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
                    isPhone ? 16 : 28,
                    isPhone ? 16 : 28,
                    isPhone ? 16 : 28,
                    isPhone ? 20 : 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isPhone ? 32 : 56),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isPhone ? 440 : 560,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            isPhone ? 28 : 34,
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: reduceEffects ? 0 : 22,
                              sigmaY: reduceEffects ? 0 : 22,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isPhone ? 18 : 30,
                                vertical: isPhone ? 22 : 32,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  isPhone ? 28 : 34,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.18),
                                    Colors.white.withValues(alpha: 0.08),
                                    const Color(
                                      0xFF061526,
                                    ).withValues(alpha: 0.30),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1.2,
                                ),
                                boxShadow: reduceEffects
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 35,
                                          offset: const Offset(0, 18),
                                        ),
                                        BoxShadow(
                                          color: softGold.withValues(
                                            alpha: 0.10,
                                          ),
                                          blurRadius: 40,
                                          offset: const Offset(0, -8),
                                        ),
                                      ],
                              ),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _FrontPageHeader(
                                      theme: theme,
                                      isPhone: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 16 : 20),

                                    Text(
                                      'منصة تشغيل ذكية لإدارة المحطات، الطلبات، المخزون، التقارير، والعمليات اليومية من لوحة واحدة أنيقة وسريعة.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontSize: isPhone ? 13.8 : 17,
                                            color: Colors.white.withValues(
                                              alpha: 0.86,
                                            ),
                                            height: 1.75,
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),

                                    SizedBox(height: isPhone ? 18 : 22),

                                    Wrap(
                                      spacing: 9,
                                      runSpacing: 9,
                                      alignment: WrapAlignment.center,
                                      children: const [
                                        _FrontPageChip(label: 'إدارة المحطات'),
                                        _FrontPageChip(label: 'المخزون والجرد'),
                                        _FrontPageChip(label: 'التقارير'),
                                        _FrontPageChip(label: 'المهام'),
                                      ],
                                    ),

                                    SizedBox(height: isPhone ? 18 : 22),

                                    _FrontPageFeature(
                                      icon: Icons.local_gas_station_rounded,
                                      title: 'تشغيل المحطات',
                                      description:
                                          'متابعة الجلسات اليومية والمضخات وحركة المبيعات بشكل مباشر.',
                                      compact: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 12),
                                    _FrontPageFeature(
                                      icon: Icons.inventory_2_rounded,
                                      title: 'مخزون وجرد الوقود',
                                      description:
                                          'عرض الأرصدة والتوريدات والجرد اليومي بطريقة واضحة وسريعة.',
                                      compact: isPhone,
                                    ),
                                    SizedBox(height: isPhone ? 10 : 12),
                                    _FrontPageFeature(
                                      icon: Icons.analytics_rounded,
                                      title: 'تقارير احترافية',
                                      description:
                                          'إحصائيات وتنبيهات تساعد الإدارة على اتخاذ قرارات أدق.',
                                      compact: isPhone,
                                    ),

                                    SizedBox(height: isPhone ? 22 : 26),

                                    SizedBox(
                                      width: double.infinity,
                                      height: isPhone ? 52 : 56,
                                      child: ElevatedButton.icon(
                                        onPressed: onEmployeeLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: gold,
                                          foregroundColor: navy,
                                          elevation: 0,
                                          shadowColor: gold.withValues(
                                            alpha: 0.30,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.login_rounded,
                                          size: 22,
                                        ),
                                        label: const Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: isPhone ? 11 : 13),

                                    SizedBox(
                                      width: double.infinity,
                                      height: isPhone ? 52 : 56,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.register,
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: softGold.withValues(
                                              alpha: 0.75,
                                            ),
                                            width: 1.2,
                                          ),
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.07),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 22,
                                        ),
                                        label: const Text(
                                          'إنشاء حساب شركة',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: isPhone ? 12 : 14),

                                    Text(
                                      'سجّل الدخول للوصول إلى خدمات التطبيق وإدارة العمليات اليومية من حسابك.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: isPhone ? 11.5 : 12.5,
                                            color: Colors.white.withValues(
                                              alpha: 0.62,
                                            ),
                                            height: 1.6,
                                            fontFamily: 'Cairo',
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
    return Column(
      children: [
        Container(
          width: isPhone ? 78 : 92,
          height: isPhone ? 78 : 92,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.24),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: FrontPage.softGold.withValues(alpha: 0.65),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: FrontPage.gold.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_gas_station_rounded,
              color: FrontPage.gold,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 13 : 15,
            vertical: isPhone ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: FrontPage.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: FrontPage.softGold.withValues(alpha: 0.40),
            ),
          ),
          child: Text(
            'بوابة التطبيق',
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: isPhone ? 11.5 : 12.5,
              color: FrontPage.softGold,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'نظام متابعة طلبات الوقود',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: isPhone ? 22 : 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.2,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _FrontPageChip extends StatelessWidget {
  final String label;

  const _FrontPageChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12.5,
          color: Colors.white.withValues(alpha: 0.86),
          fontWeight: FontWeight.w700,
          fontFamily: 'Cairo',
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
      padding: EdgeInsets.all(compact ? 13 : 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 40 : 46,
            height: compact ? 40 : 46,
            decoration: BoxDecoration(
              color: FrontPage.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(compact ? 13 : 15),
              border: Border.all(
                color: FrontPage.softGold.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: FrontPage.softGold,
              size: compact ? 21 : 24,
            ),
          ),
          SizedBox(width: compact ? 11 : 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: compact ? 15.5 : 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: compact ? 12.5 : 14,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.68),
                    fontFamily: 'Cairo',
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
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.25,
              colors: [Color(0xFF145DA0), Color(0xFF0B2E55), Color(0xFF071A2F)],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _GlowCircle(
            size: 260,
            color: FrontPage.gold.withValues(alpha: 0.24),
          ),
        ),
        Positioned(
          bottom: -110,
          left: -80,
          child: _GlowCircle(
            size: 300,
            color: FrontPage.royalBlue.withValues(alpha: 0.35),
          ),
        ),
        Positioned(
          top: 220,
          left: -45,
          child: _GlowCircle(
            size: 150,
            color: Colors.white.withValues(alpha: 0.08),
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
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 90, spreadRadius: 25),
          ],
        ),
      ),
    );
  }
}
