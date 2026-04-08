import 'package:flutter/material.dart';
import 'package:order_tracker/screens/tracking/drivers_tracking_screen.dart';
import 'package:order_tracker/screens/tracking/tankers_tracking_screen.dart';
import 'package:order_tracker/screens/tracking/vehicles_tracking_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';

class TrackingScreen extends StatelessWidget {
  final int initialTabIndex;

  const TrackingScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          title: const Text('المتابعة'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(74),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x66FFFFFF), Color(0x33FFFFFF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.70),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.local_shipping_outlined),
                      text: 'الصهاريج',
                    ),
                    Tab(
                      icon: Icon(Icons.directions_car_outlined),
                      text: 'السيارات',
                    ),
                    Tab(
                      icon: Icon(Icons.person_pin_circle_outlined),
                      text: 'السائقين',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const Stack(
          children: [
            AppSoftBackground(),
            Positioned.fill(
              child: TabBarView(
                children: [
                  TankersTrackingScreen(),
                  VehiclesTrackingScreen(),
                  DriversTrackingScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
