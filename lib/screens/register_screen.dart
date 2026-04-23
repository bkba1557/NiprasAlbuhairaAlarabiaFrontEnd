import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمات المرور غير متطابقة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _companyController.text.trim(),
      _phoneController.text.trim(),
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'فشل إنشاء الحساب'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 900;
          final bool isTablet = constraints.maxWidth >= 600;

          final double cardWidth = isDesktop || isTablet
              ? 480
              : double.infinity;

          final double outerPadding = isDesktop ? 48 : 24;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.primaryBlue.withOpacity(0.9),
                  AppColors.primaryDarkBlue,
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(outerPadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header (Back + Icon)
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back),
                                  color: AppColors.primaryBlue,
                                ),
                                const Spacer(),
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_add,
                                    size: 32,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              AppStrings.register,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'أنشئ حساب جديد للوصول إلى النظام',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.mediumGray),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'سيتم إنشاء شركتك وتعيين هذا الحساب كمسؤول (Admin).',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mediumGray),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  CustomTextField(
                                    controller: _nameController,
                                    labelText: AppStrings.name,
                                    prefixIcon: Icons.person_outline,
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? 'يرجى إدخال الاسم الكامل'
                                        : null,
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  CustomTextField(
                                    controller: _usernameController,
                                    labelText: 'اسم المستخدم',
                                    prefixIcon: Icons.alternate_email,
                                    validator: (value) {
                                      final input = value?.trim() ?? '';
                                      if (input.isEmpty) return null;
                                      if (input.length < 3) {
                                        return 'اسم المستخدم قصير';
                                      }
                                      if (input.contains(' ')) {
                                        return 'اسم المستخدم لا يجب أن يحتوي على مسافات';
                                      }
                                      return null;
                                    },
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  CustomTextField(
                                    controller: _emailController,
                                    labelText: AppStrings.email,
                                    prefixIcon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال البريد الإلكتروني';
                                      }
                                      if (!value.contains('@')) {
                                        return 'البريد الإلكتروني غير صالح';
                                      }
                                      return null;
                                    },
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

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
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال كلمة المرور';
                                      }
                                      if (value.length < 6) {
                                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                      }
                                      return null;
                                    },
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  CustomTextField(
                                    controller: _confirmPasswordController,
                                    labelText: AppStrings.confirmPassword,
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: _obscureConfirmPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? 'يرجى تأكيد كلمة المرور'
                                        : null,
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  CustomTextField(
                                    controller: _companyController,
                                    labelText: AppStrings.company,
                                    prefixIcon: Icons.business_outlined,
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? 'يرجى إدخال اسم الشركة'
                                        : null,
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  CustomTextField(
                                    controller: _phoneController,
                                    labelText: AppStrings.phone,
                                    prefixIcon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    fieldColor: AppColors.glassBlue.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  GradientButton(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : _register,
                                    text: authProvider.isLoading
                                        ? AppStrings.loading
                                        : AppStrings.register,
                                    gradient: AppColors.accentGradient,
                                    isLoading: authProvider.isLoading,
                                  ),
                                  const SizedBox(height: 24),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(AppStrings.alreadyHaveAccount),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(
                                            context,
                                            AppRoutes.login,
                                          );
                                        },
                                        child: const Text(
                                          'سجّل الدخول',
                                          style: TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
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
              ),
            ),
          );
        },
      ),
    );
  }
}
