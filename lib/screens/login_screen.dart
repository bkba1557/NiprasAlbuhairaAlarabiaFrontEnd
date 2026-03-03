import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; 

import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late VideoPlayerController _videoController;

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    // ===============================
    // 🎥 إعداد فيديو الخلفية (Web + Mobile)
    // ===============================
    _videoController = kIsWeb
        // 🌐 Flutter Web (لازم يكون داخل web/videos)
        ? VideoPlayerController.network(
            'videos/v1.mp4',
          )
        // 📱 Android / iOS (assets طبيعي)
        : VideoPlayerController.asset(
            'assets/videos/v1.mp4',
          );

    _videoController.initialize().then((_) {
      if (!mounted) return;
      _videoController.setLooping(true);
      _videoController.setVolume(0); // صامت
      _videoController.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'فشل تسجيل الدخول'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // توجيه المستخدم حسب الدور
    final pendingRoute = authProvider.consumePendingRoute();
    if (pendingRoute != null && pendingRoute.trim().isNotEmpty) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        pendingRoute,
        (_) => false,
      );
      return;
    }

    final homeRoute = getHomeRouteByRole(authProvider.role);
    Navigator.pushNamedAndRemoveUntil(
      context,
      homeRoute,
      (_) => false,
    );
  }

  String getHomeRouteByRole(String? role) {
    switch (role) {
      case 'station_boy':
        return AppRoutes.sessionsList;
      case 'maintenance':
      case 'maintenance_car_management':
        return AppRoutes.maintenanceDashboard;
      case 'maintenance_station':
        return AppRoutes.stationMaintenanceTechnician;
      case 'employee':
        return AppRoutes.marketingStations;
      case 'finance_manager':
        return AppRoutes.custodyDocuments;
      case 'sales_manager_statiun':
        return AppRoutes.mainHome;
      default:
        return AppRoutes.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. الفيديو في الخلفية
          SizedBox.expand(
            child: _videoController.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : Container(color: AppColors.primaryDarkBlue),
          ),

          // 2. تدرج لوني فوق الفيديو
        Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  AppColors.primaryDarkBlue.withOpacity(0.8),
                ],
              ),
            ),
          ),


          // 3. المحتوى الأساسي
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10,
                    sigmaY: 10,
                  ),
                  child: Container(
                    width: size.width > 500 ? 450 : size.width,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: 'logo',
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 200,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppStrings.login,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'مرحباً بك مجدداً في النظام',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 40),

                          CustomTextField(
                            controller: _emailController,
                            labelText: AppStrings.email,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                (value == null || !value.contains('@'))
                                    ? 'بريد غير صالح'
                                    : null,
                          ),

                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _passwordController,
                            labelText: AppStrings.password,
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.black,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.length < 6)
                                    ? 'كلمة المرور قصيرة'
                                    : null,
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      side: const BorderSide(
                                        color: Colors.white70,
                                      ),
                                      activeColor: AppColors.primaryBlue,
                                      onChanged: (v) =>
                                          setState(() => _rememberMe = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'تذكرني',
                                    style:
                                        TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          GradientButton(
                            onPressed:
                                authProvider.isLoading ? null : _login,
                            text: authProvider.isLoading
                                ? 'جاري التحميل...'
                                : AppStrings.login,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                Colors.blue.shade300,
                              ],
                            ),
                            isLoading: authProvider.isLoading,
                          ),

                          const SizedBox(height: 20),

                          Text(
                            "شركة البحيرة العربية © 2026",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 12,
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
        ],
      ),
    );
  }
}
