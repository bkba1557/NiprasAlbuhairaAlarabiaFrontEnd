import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // للتحقق من منصة الويب
import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _companyController;
  late TextEditingController _phoneController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  String? _profileImagePath;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _companyController = TextEditingController(text: user?.company ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث الملف الشخصي بنجاح'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('كلمات المرور غير متطابقة', AppColors.errorRed);
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showSnackBar(
        'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
        AppColors.errorRed,
      );
      return;
    }

    setState(() {
      _isChangingPassword = false;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
    _showSnackBar('تم تغيير كلمة المرور بنجاح', AppColors.successGreen);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing && !_isChangingPassword)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // إذا كان العرض أكبر من 600، نعتبره شاشة ويب أو تابلت
          double horizontalPadding = constraints.maxWidth > 600
              ? constraints.maxWidth * 0.2
              : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 700,
                ), // أقصى عرض للمحتوى
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(user),
                    const SizedBox(height: 24),
                    if (_isEditing) _buildEditForm(),
                    if (_isChangingPassword) _buildChangePasswordForm(),
                    if (!_isEditing && !_isChangingPassword) ...[
                      _buildAccountInfo(user),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryBlue,
                        width: 3,
                      ),
                      image: _profileImagePath != null
                          ? DecorationImage(
                              image: kIsWeb
                                  ? NetworkImage(_profileImagePath!)
                                        as ImageProvider
                                  : FileImage(File(_profileImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImagePath == null
                        ? Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.accentGradient,
                            ),
                            child: Center(
                              child: Text(
                                user?.name
                                        .split(' ')
                                        .map((n) => n[0])
                                        .take(2)
                                        .join('')
                                        .toUpperCase() ??
                                    'U',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (_isEditing)
                    CircleAvatar(
                      backgroundColor: AppColors.primaryBlue,
                      radius: 20,
                      child: IconButton(
                        onPressed: _pickProfileImage,
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user?.name ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            _buildRoleBadge(user?.role ?? 'maintenance'),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _nameController,
                labelText: 'الاسم الكامل',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _companyController,
                labelText: 'الشركة',
                prefixIcon: Icons.business_outlined,
              ),
              const SizedBox(height: 24),
              _buildFormActions(
                () => setState(() => _isEditing = false),
                _updateProfile,
                'حفظ التغييرات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangePasswordForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CustomTextField(
              controller: _currentPasswordController,
              labelText: 'كلمة المرور الحالية',
              obscureText: _obscureCurrentPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _newPasswordController,
              labelText: 'كلمة المرور الجديدة',
              obscureText: _obscureNewPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
            const SizedBox(height: 24),
            _buildFormActions(
              () => setState(() => _isChangingPassword = false),
              _changePassword,
              'تغيير كلمة المرور',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(Icons.person, 'الاسم الكامل', user?.name ?? ''),
            const Divider(),
            _buildInfoRow(Icons.email, 'البريد الإلكتروني', user?.email ?? ''),
            const Divider(),
            _buildInfoRow(Icons.business, 'الشركة', user?.company ?? ''),
            const Divider(),
            _buildInfoRow(
              Icons.security,
              'الصلاحية',
              _getRoleName(user?.role ?? 'maintenance'),
              color: _getRoleColor(user?.role ?? 'maintenance'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppColors.primaryBlue),
            title: const Text('تغيير كلمة المرور'),
            onTap: () => setState(() => _isChangingPassword = true),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildFormActions(
    VoidCallback onCancel,
    VoidCallback onConfirm,
    String confirmText,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('إلغاء'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GradientButton(
            onPressed: onConfirm,
            text: confirmText,
            gradient: AppColors.accentGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getRoleColor(role)),
      ),
      child: Text(
        _getRoleName(role),
        style: TextStyle(
          color: _getRoleColor(role),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    if (role == 'admin') return Colors.red;
    if (role == 'maintenance') return Colors.blue;
    if (role == 'maintenance_station') return const Color(0xFF1B5E20);
    if (role == 'finance_manager') return const Color(0xFF2E7D32);
    return Colors.green;
  }

  String _getRoleName(String role) {
    if (role == 'admin') return 'مدير النظام';
    if (role == 'maintenance') return 'فني صيانة';
    if (role == 'maintenance_station') return 'فني صيانة محطة';
    if (role == 'finance_manager') return 'المدير المالي';
    return 'مشاهد';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.front,
                (route) => false,
              );
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}
