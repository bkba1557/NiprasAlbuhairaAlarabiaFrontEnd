import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/device_performance.dart';
import 'package:order_tracker/utils/role_route_policy.dart';

import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

enum LoginIdentifierType { phone, username, email }

extension on LoginIdentifierType {
  String get apiValue {
    switch (this) {
      case LoginIdentifierType.phone:
        return 'phone';
      case LoginIdentifierType.username:
        return 'username';
      case LoginIdentifierType.email:
        return 'email';
    }
  }

  String get label {
    switch (this) {
      case LoginIdentifierType.phone:
        return 'رقم الجوال';
      case LoginIdentifierType.username:
        return 'اسم المستخدم';
      case LoginIdentifierType.email:
        return 'البريد الإلكتروني';
    }
  }

  String get helperText {
    switch (this) {
      case LoginIdentifierType.phone:
        return 'سيصل رمز التحقق إلى البريد المسجل لهذا الجوال';
      case LoginIdentifierType.username:
        return 'سيصل رمز التحقق إلى البريد المرتبط باسم المستخدم';
      case LoginIdentifierType.email:
        return 'سيصل رمز التحقق إلى نفس البريد الإلكتروني';
    }
  }

  IconData get icon {
    switch (this) {
      case LoginIdentifierType.phone:
        return Icons.phone_android_outlined;
      case LoginIdentifierType.username:
        return Icons.alternate_email;
      case LoginIdentifierType.email:
        return Icons.email_outlined;
    }
  }

  TextInputType get keyboardType {
    switch (this) {
      case LoginIdentifierType.phone:
        return TextInputType.phone;
      case LoginIdentifierType.username:
        return TextInputType.text;
      case LoginIdentifierType.email:
        return TextInputType.emailAddress;
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierFormKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  VideoPlayerController? _videoController;
  LoginIdentifierType _selectedType = LoginIdentifierType.phone;
  LoginIdentifierType? _previousIdentifierTypeBeforePassword;
  bool _usePasswordLogin = false;
  bool _obscurePassword = true;
  bool _otpStep = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && !DevicePerformance.reduceEffects) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(
          const Duration(milliseconds: 450),
          _initializeBackgroundVideo,
        );
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeBackgroundVideo() async {
    if (!mounted || _videoController != null) return;

    final controller = VideoPlayerController.asset('assets/videos/v1.mp4');
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
      });
    } catch (_) {
      await controller.dispose();
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (context.read<AuthProvider>().isLoading) return;

    if (_otpStep) {
      await _verifyOtp();
      return;
    }

    if (_usePasswordLogin) {
      await _loginWithPassword();
      return;
    }

    await _requestOtp();
  }

  Future<void> _requestOtp() async {
    if (!_identifierFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.requestLoginOtp(
      loginType: _selectedType.apiValue,
      identifier: _identifierController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      _showError(authProvider.error ?? 'تعذر إرسال رمز التحقق');
      return;
    }

    setState(() {
      _otpStep = true;
      _clearOtpFields();
    });

    _otpFocusNodes.first.requestFocus();

    final maskedEmail = authProvider.pendingMaskedEmail;
    if (maskedEmail != null && maskedEmail.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال رمز التحقق إلى $maskedEmail'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _currentOtp();
    if (otp.length != 6) {
      _showError('أدخل رمز تحقق مكوّنًا من 6 أرقام');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyLoginOtp(otp);

    if (!mounted) return;

    if (!success) {
      _showError(authProvider.error ?? 'فشل التحقق من الرمز');
      return;
    }

    _completeAuthenticatedFlow(authProvider);
  }

  Future<void> _loginWithPassword() async {
    if (!_identifierFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (!success) {
      _showError(authProvider.error ?? 'تعذر تسجيل الدخول بكلمة المرور');
      return;
    }

    _completeAuthenticatedFlow(authProvider);
  }

  void _completeAuthenticatedFlow(AuthProvider authProvider) {
    final pendingRoute = authProvider.consumePendingRoute();
    if (pendingRoute != null &&
        pendingRoute.trim().isNotEmpty &&
        isRouteAllowedForRole(
          role: authProvider.role,
          routeName: pendingRoute,
        )) {
      Navigator.pushNamedAndRemoveUntil(context, pendingRoute, (_) => false);
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      _homeRouteByRole(authProvider.role),
      (_) => false,
    );
  }

  void _handlePasswordLoginToggle(bool enabled) {
    if (_usePasswordLogin == enabled) return;

    setState(() {
      _usePasswordLogin = enabled;
      _otpStep = false;
      _clearOtpFields();
      _obscurePassword = true;

      if (enabled) {
        if (_selectedType != LoginIdentifierType.email) {
          _previousIdentifierTypeBeforePassword = _selectedType;
          _selectedType = LoginIdentifierType.email;
          _identifierController.clear();
        }
      } else {
        _passwordController.clear();
        if (_previousIdentifierTypeBeforePassword != null) {
          _selectedType = _previousIdentifierTypeBeforePassword!;
          _previousIdentifierTypeBeforePassword = null;
          _identifierController.clear();
        }
      }
    });

    context.read<AuthProvider>().cancelPendingOtp();
  }

  void _resetOtpFlow() {
    context.read<AuthProvider>().cancelPendingOtp();
    setState(() {
      _otpStep = false;
      _clearOtpFields();
    });
  }

  void _clearOtpFields() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
  }

  String _currentOtp() {
    return _otpControllers.map((controller) => controller.text.trim()).join();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateIdentifier(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    switch (_selectedType) {
      case LoginIdentifierType.phone:
        return input.length < 8 ? 'رقم الجوال غير صحيح' : null;
      case LoginIdentifierType.username:
        return input.contains(' ')
            ? 'اسم المستخدم لا يجب أن يحتوي على مسافات'
            : null;
      case LoginIdentifierType.email:
        return input.contains('@') ? null : 'البريد الإلكتروني غير صالح';
    }
  }

  String? _validatePassword(String? value) {
    if (!_usePasswordLogin) return null;

    final input = value ?? '';
    if (input.trim().isEmpty) {
      return 'كلمة المرور مطلوبة';
    }

    if (input.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    return null;
  }

  String _descriptionText() {
    if (_otpStep) {
      return 'أدخل رمز التحقق المكوّن من 6 أرقام لإكمال تسجيل الدخول';
    }

    if (_usePasswordLogin) {
      return 'يمكنك تسجيل الدخول مباشرة بالبريد الإلكتروني وكلمة المرور بدون طلب رمز تحقق';
    }

    return 'اختر طريقة الدخول ثم أرسل رمز التحقق إلى البريد المسجل';
  }

  String _helperText() {
    if (_usePasswordLogin) {
      return 'تسجيل الدخول بكلمة المرور متاح حالياً عبر البريد الإلكتروني فقط، ولن يُطلب رمز تحقق';
    }

    return _selectedType.helperText;
  }

  String _primaryButtonText(AuthProvider authProvider) {
    if (authProvider.isLoading) {
      return 'جاري التحميل...';
    }

    if (_otpStep) {
      return 'تحقق من الرمز';
    }

    if (_usePasswordLogin) {
      return 'تسجيل الدخول';
    }

    return 'إرسال رمز التحقق';
  }

  void _handleOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  String _homeRouteByRole(String? role) {
    switch (normalizeRoleKey(role)) {
      case 'station_boy':
        return AppRoutes.sessionsList;
      case 'maintenance':
      case 'maintenance_car_management':
        return AppRoutes.maintenanceDashboard;
      case 'maintenance_station':
        return AppRoutes.stationMaintenanceTechnician;
      case 'employee':
        return AppRoutes.marketingStations;
      case 'movement':
        return AppRoutes.movement;
      case 'archive':
        return AppRoutes.movementArchiveOrders;
      case 'finance_manager':
        return AppRoutes.custodyDocuments;
      case 'sales_manager_statiun':
      case 'owner_station':
        return AppRoutes.mainHome;
      case 'driver':
        return AppRoutes.driverHome;
      default:
        return AppRoutes.dashboard;
    }
  }

  Widget _buildResponsiveScaffold({
    required AuthProvider authProvider,
    required String? maskedEmail,
    required VideoPlayerController? videoController,
    required Size size,
  }) {
    final isCompact = size.width < 520;
    final isWide = size.width >= 980;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBackgroundLayer(
            videoController: videoController,
            useVideo: !kIsWeb && !isWide && !DevicePerformance.reduceEffects,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 28,
                  vertical: isCompact ? 14 : 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 1180 : 410),
                  child: isWide
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 6, child: _buildWebSidePanel()),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 5,
                                child: _buildLoginCard(
                                  authProvider: authProvider,
                                  maskedEmail: maskedEmail,
                                  isCompact: isCompact,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildLoginCard(
                          authProvider: authProvider,
                          maskedEmail: maskedEmail,
                          isCompact: isCompact,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayer({
    required VideoPlayerController? videoController,
    required bool useVideo,
  }) {
    final background =
        useVideo &&
            videoController != null &&
            videoController.value.isInitialized
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoController.value.size.width,
              height: videoController.value.size.height,
              child: VideoPlayer(videoController),
            ),
          )
        : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF091735),
                  Color(0xFF10295E),
                  Color(0xFF0D4D91),
                ],
              ),
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        Positioned(
          top: -140,
          right: -90,
          child: _BackgroundOrb(
            size: 420,
            color: AppColors.secondaryTeal.withOpacity(0.16),
          ),
        ),
        Positioned(
          left: -120,
          bottom: -150,
          child: _BackgroundOrb(
            size: 380,
            color: AppColors.accentBlue.withOpacity(0.18),
          ),
        ),
        Positioned(
          top: 80,
          left: 120,
          child: _BackgroundOrb(
            size: 180,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        Positioned(
          right: 120,
          bottom: 90,
          child: _BackgroundOrb(
            size: 220,
            color: AppColors.lightTeal.withOpacity(0.07),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.04),
                Colors.black.withOpacity(0.18),
                const Color(0xFF020817).withOpacity(0.28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    required BorderRadius borderRadius,
    Gradient? gradient,
    Color? color,
    Border? border,
    List<BoxShadow>? boxShadow,
    EdgeInsetsGeometry? padding,
    double blur = 24,
  }) {
    final reduceEffects = DevicePerformance.reduceEffects;

    final effectiveShadow =
        reduceEffects
            ? null
            : (boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ]);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: gradient == null ? color : null,
        gradient: gradient,
        border:
            border ??
            Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child:
          reduceEffects || blur <= 0
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: content,
                ),
    );
  }

  Widget _buildLoginCard({
    required AuthProvider authProvider,
    required String? maskedEmail,
    required bool isCompact,
  }) {
    final cardRadius = BorderRadius.circular(isCompact ? 28 : 34);
    final contentTheme = Theme.of(context).copyWith(
      primaryColor: AppColors.primaryDarkBlue,
      dividerColor: const Color(0xFFAFC5E8),
      textTheme: Theme.of(context).textTheme.copyWith(
        bodyMedium: TextStyle(
          color: const Color(0xFF112347),
          fontSize: isCompact ? 14 : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Theme(
      data: contentTheme,
      child: _buildGlassCard(
        borderRadius: cardRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.74),
            Colors.white.withOpacity(0.66),
            const Color(0xFFD9E9FF).withOpacity(0.42),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF061124).withOpacity(0.34),
            blurRadius: 42,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: AppColors.accentBlue.withOpacity(0.10),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 24,
            isCompact ? 16 : 26,
            isCompact ? 14 : 24,
            isCompact ? 14 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.46),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.72)),
                  ),
                  child: const Text(
                    'بوابة الدخول',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 10 : 14),
              Hero(
                tag: 'logo',
                child: Container(
                  width: isCompact ? 76 : 104,
                  height: isCompact ? 76 : 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.92),
                        Colors.white.withOpacity(0.60),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.72)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentBlue.withOpacity(0.12),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  child: Image.asset(
                    AppImages.logo,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Text(
                AppStrings.login,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF102144),
                  fontSize: isCompact ? 22 : 30,
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _descriptionText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF4B5F7F),
                  fontSize: isCompact ? 11.8 : 13.8,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              if (!_usePasswordLogin) ...[
                _buildMethodSelector(),
                SizedBox(height: isCompact ? 12 : 14),
              ],
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 14,
                  vertical: isCompact ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.34),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.62)),
                ),
                child: Text(
                  _helperText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF556883),
                    fontSize: isCompact ? 11.5 : 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _otpStep
                    ? _buildOtpSection(maskedEmail)
                    : _buildIdentifierSection(),
              ),
              SizedBox(height: isCompact ? 16 : 20),
              GradientButton(
                onPressed: authProvider.isLoading ? null : _handlePrimaryAction,
                text: _primaryButtonText(authProvider),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF17305C),
                    Color(0xFF2563EB),
                    Color(0xFF3B82F6),
                  ],
                ),
                isLoading: authProvider.isLoading,
                width: double.infinity,
                height: isCompact ? 50 : 56,
                borderRadius: isCompact ? 16 : 18,
              ),
              if (_otpStep) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: authProvider.isLoading ? null : _requestOtp,
                      child: const Text(
                        'إعادة إرسال الرمز',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: authProvider.isLoading ? null : _resetOtpFlow,
                      child: const Text(
                        'تغيير طريقة الدخول',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () => Navigator.pushNamed(context, AppRoutes.register),
                child: const Text(
                  'إنشاء حساب شركة جديدة',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${AppStrings.appName} © 2026',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebSidePanel() {
    return _buildGlassCard(
      borderRadius: BorderRadius.circular(34),
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xFF0A1A42).withOpacity(0.70),
          const Color(0xFF123D87).withOpacity(0.62),
          const Color(0xFF18B8C9).withOpacity(0.48),
        ],
      ),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.24),
          blurRadius: 42,
          offset: const Offset(0, 24),
        ),
      ],
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -30,
            child: _BackgroundOrb(
              size: 200,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -70,
            right: -50,
            child: _BackgroundOrb(
              size: 240,
              color: AppColors.secondaryTeal.withOpacity(0.10),
            ),
          ),
          Positioned(
            top: 80,
            right: -40,
            child: Transform.rotate(
              angle: .55,
              child: Container(
                width: 260,
                height: 2,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Transform.rotate(
              angle: -.65,
              child: Container(
                width: 240,
                height: 1.4,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 34, 32, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'نظام متابعة طلبات الوقود',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'واجهة دخول أوضح، أسرع، ومبنية لتناسب العمل اليومي على الويب والجوال بدون زحمة بصرية.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 26),
                const _BrandFeatureRow(
                  icon: Icons.verified_user_outlined,
                  text: 'دخول برمز تحقق أو كلمة مرور حسب الحاجة.',
                  isCompact: false,
                ),
                const SizedBox(height: 12),
                const _BrandFeatureRow(
                  icon: Icons.phone_iphone_rounded,
                  text: 'تجربة استخدام متوازنة على الشاشات الصغيرة والكبيرة.',
                  isCompact: false,
                ),
                const SizedBox(height: 12),
                const _BrandFeatureRow(
                  icon: Icons.tune_rounded,
                  text:
                      'حقول أوضح، ألوان أهدأ، وتركيز أعلى على عملية الدخول نفسها.',
                  isCompact: false,
                ),
                const Spacer(),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _PanelStatChip(
                      title: 'طريقة الدخول',
                      value: 'OTP / Password',
                    ),
                    _PanelStatChip(title: 'التوافق', value: 'Web + Mobile'),
                    _PanelStatChip(title: 'الهوية', value: 'Al-Buhaira'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final maskedEmail = authProvider.pendingMaskedEmail;
    final videoController = _videoController;

    return _buildResponsiveScaffold(
      authProvider: authProvider,
      maskedEmail: maskedEmail,
      videoController: videoController,
      size: size,
    );
  }

  Widget _buildMethodSelector() {
    final isCompact = MediaQuery.of(context).size.width < 420;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: isCompact ? 8 : 10,
      runSpacing: isCompact ? 8 : 10,
      children: LoginIdentifierType.values.map((type) {
        final selected = _selectedType == type;
        return ChoiceChip(
          showCheckmark: false,
          label: Text(type.label),
          avatar: Icon(
            type.icon,
            size: isCompact ? 16 : 18,
            color: selected ? Colors.white : AppColors.primaryDarkBlue,
          ),
          selected: selected,
          selectedColor: AppColors.primaryDarkBlue,
          backgroundColor: Colors.white.withOpacity(0.40),
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.primaryDarkBlue,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 12.5 : 13.5,
          ),
          side: BorderSide(
            color: selected
                ? AppColors.primaryDarkBlue
                : const Color(0xFFC8D7ED),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: isCompact ? 8 : 10,
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) {
            if (_selectedType == type) return;
            setState(() {
              _selectedType = type;
              _identifierController.clear();
              _otpStep = false;
              _clearOtpFields();
            });
            context.read<AuthProvider>().cancelPendingOtp();
          },
        );
      }).toList(),
    );
  }

  Widget _buildIdentifierSection() {
    final authProvider = context.watch<AuthProvider>();

    return Form(
      key: _identifierFormKey,
      child: Column(
        key: ValueKey<String>(
          _usePasswordLogin ? 'password-login' : 'identifier-login',
        ),
        children: [
          CustomTextField(
            controller: _identifierController,
            labelText: _selectedType.label,
            prefixIcon: _selectedType.icon,
            keyboardType: _selectedType.keyboardType,
            fieldColor: Colors.white.withOpacity(0.46),
            textInputAction: _usePasswordLogin
                ? TextInputAction.next
                : TextInputAction.done,
            validator: _validateIdentifier,
            onFieldSubmitted: (_) {
              if (!_usePasswordLogin) {
                _handlePrimaryAction();
              }
            },
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.52)),
            ),
            child: CheckboxListTile(
              value: _usePasswordLogin,
              onChanged: authProvider.isLoading
                  ? null
                  : (value) => _handlePasswordLoginToggle(value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              activeColor: AppColors.primaryBlue,
              checkColor: Colors.white,
              title: const Text(
                'الدخول بكلمة المرور',
                style: TextStyle(
                  color: Color(0xFF102144),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'خيار اختياري لتسجيل الدخول المباشر بدون رمز',
                style: TextStyle(
                  color: const Color(0xFF5B6F8B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_usePasswordLogin) ...[
            const SizedBox(height: 14),
            CustomTextField(
              controller: _passwordController,
              labelText: 'كلمة المرور',
              prefixIcon: Icons.lock_outline,
              keyboardType: TextInputType.visiblePassword,
              obscureText: _obscurePassword,
              fieldColor: Colors.white.withOpacity(0.46),
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _handlePrimaryAction(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpSection(String? maskedEmail) {
    return Column(
      key: const ValueKey<String>('otp'),
      children: [
        if (maskedEmail != null && maskedEmail.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.32),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.54)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم إرسال الرمز إلى $maskedEmail',
                    style: const TextStyle(
                      color: Color(0xFF102144),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(6, _buildOtpBox),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    final isLastBox = index == _otpControllers.length - 1;
    final isCompact = MediaQuery.of(context).size.width < 420;
    final boxWidth = isCompact ? 42.0 : 48.0;
    final boxFontSize = isCompact ? 18.0 : 20.0;
    final boxVerticalPadding = isCompact ? 14.0 : 16.0;

    return SizedBox(
      width: boxWidth,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textInputAction: isLastBox
            ? TextInputAction.done
            : TextInputAction.next,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: boxFontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDarkBlue,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withOpacity(0.58),
          contentPadding: EdgeInsets.symmetric(vertical: boxVerticalPadding),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.62)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryBlue,
              width: 2,
            ),
          ),
        ),
        onChanged: (value) => _handleOtpChanged(index, value),
        onFieldSubmitted: (_) {
          if (!isLastBox) {
            _otpFocusNodes[index + 1].requestFocus();
            return;
          }
          _handlePrimaryAction();
        },
      ),
    );
  }
}

class _BrandFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isCompact;

  const _BrandFeatureRow({
    required this.icon,
    required this.text,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: isCompact ? 12.5 : 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackgroundOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

class _PanelStatChip extends StatelessWidget {
  final String title;
  final String value;

  const _PanelStatChip({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
