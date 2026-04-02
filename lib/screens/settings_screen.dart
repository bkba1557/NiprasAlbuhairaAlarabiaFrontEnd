import 'package:flutter/material.dart';
import 'package:order_tracker/screens/settings/export_templates_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoSyncEnabled = true;
  bool _biometricEnabled = false;
  String _language = 'العربية';
  String _dateFormat = 'yyyy/MM/dd';

  final List<String> _languages = ['العربية', 'English'];
  final List<String> _dateFormats = ['yyyy/MM/dd', 'dd/MM/yyyy', 'MM/dd/yyyy'];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.user?.role;
    final canEditTemplates = role == 'owner' || role == 'manager';

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المظهر',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile.adaptive(
                      title: const Text('الوضع الداكن'),
                      subtitle: const Text('تفعيل الوضع الداكن للتطبيق'),
                      value: themeProvider.themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        themeProvider.toggleTheme(value);
                      },
                      activeColor: AppColors.primaryBlue,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('لون التطبيق'),
                      subtitle: const Text('اختر اللون الرئيسي للتطبيق'),
                      trailing: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onTap: () {
                        _showColorPicker();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Notification Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإشعارات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile.adaptive(
                      title: const Text('تفعيل الإشعارات'),
                      subtitle: const Text('تلقي إشعارات عند تحديث الطلبات'),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                      activeColor: AppColors.primaryBlue,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: const Text('إشعارات البريد الإلكتروني'),
                      subtitle: const Text('إرسال إشعارات بالبريد الإلكتروني'),
                      value: _notificationsEnabled,
                      onChanged: _notificationsEnabled
                          ? (value) {
                              // TODO: Implement email notifications
                            }
                          : null,
                      activeColor: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (canEditTemplates) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قوالب التصدير',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: const Text('تعديل قوالب PDF'),
                        subtitle: const Text(
                          'تخصيص شكل ملفات التصدير مثل التعاميم والتقارير',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ExportTemplatesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Data & Sync Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'البيانات والمزامنة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile.adaptive(
                      title: const Text('المزامنة التلقائية'),
                      subtitle: const Text(
                        'مزامنة البيانات تلقائياً مع السيرفر',
                      ),
                      value: _autoSyncEnabled,
                      onChanged: (value) {
                        setState(() {
                          _autoSyncEnabled = value;
                        });
                      },
                      activeColor: AppColors.primaryBlue,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('مساحة التخزين'),
                      subtitle: const Text('إدارة مساحة التخزين المحلي'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _showStorageInfo();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('تصدير البيانات'),
                      subtitle: const Text('تصدير جميع البيانات إلى ملف'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _exportData();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Security Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الأمان',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile.adaptive(
                      title: const Text('المصادقة الحيوية'),
                      subtitle: const Text(
                        'استخدام بصمة الإصبع أو التعرف على الوجه',
                      ),
                      value: _biometricEnabled,
                      onChanged: (value) {
                        setState(() {
                          _biometricEnabled = value;
                        });
                      },
                      activeColor: AppColors.primaryBlue,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('تغيير كلمة المرور'),
                      subtitle: const Text('تغيير كلمة مرور حسابك'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('جلسات الدخول'),
                      subtitle: const Text('إدارة جلسات الدخول النشطة'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _showActiveSessions();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Language & Region Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اللغة والمنطقة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      title: const Text('اللغة'),
                      subtitle: Text(_language),
                      trailing: DropdownButton<String>(
                        value: _language,
                        underline: const SizedBox(),
                        items: _languages.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _language = value!;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('تنسيق التاريخ'),
                      subtitle: Text(_dateFormat),
                      trailing: DropdownButton<String>(
                        value: _dateFormat,
                        underline: const SizedBox(),
                        items: _dateFormats.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _dateFormat = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // About & Support
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حول التطبيق والدعم',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      title: const Text('حول التطبيق'),
                      subtitle: const Text('الإصدار 1.0.0'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _showAboutDialog();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('سياسة الخصوصية'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _showPrivacyPolicy();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('شروط الاستخدام'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _showTermsOfService();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('الدعم الفني'),
                      subtitle: const Text('تواصل مع فريق الدعم'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        _contactSupport();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Danger Zone
            Card(
              color: Colors.red.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'منطقة الخطر',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'حذف الحساب',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text(
                        'حذف حسابك وجميع بياناتك بشكل دائم',
                        style: TextStyle(color: Colors.red),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.red,
                      ),
                      onTap: () {
                        _showDeleteAccountDialog();
                      },
                    ),
                    const Divider(color: Colors.red, height: 1),
                    ListTile(
                      leading: Icon(Icons.warning, color: Colors.red),
                      title: const Text(
                        'إعادة تعيين التطبيق',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text(
                        'حذف جميع البيانات المحلية وإعادة التعيين',
                        style: TextStyle(color: Colors.red),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Colors.red,
                      ),
                      onTap: () {
                        _showResetDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لون التطبيق'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildColorOption(Colors.blue, 'أزرق'),
              _buildColorOption(Colors.green, 'أخضر'),
              _buildColorOption(Colors.purple, 'بنفسجي'),
              _buildColorOption(Colors.orange, 'برتقالي'),
              _buildColorOption(Colors.teal, 'تركواز'),
              _buildColorOption(Colors.indigo, 'كحلي'),
              _buildColorOption(Colors.pink, 'وردي'),
              _buildColorOption(Colors.brown, 'بني'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement theme color change
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color, String name) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showStorageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مساحة التخزين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المساحة المستخدمة: 125 ميجابايت'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.25,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 16),
            const Text('يمكنك مسح البيانات المخزنة محلياً لتوفير المساحة'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Clear local storage
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم مسح البيانات المخزنة محلياً'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            child: const Text('مسح البيانات'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    // TODO: Implement data export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تحضير البيانات للتصدير...')),
    );
  }

  void _showActiveSessions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('جلسات الدخول النشطة'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: ListView(
            children: const [
              ListTile(
                leading: Icon(Icons.devices),
                title: Text('جهاز Android'),
                subtitle: Text('متصل الآن'),
              ),
              ListTile(
                leading: Icon(Icons.computer),
                title: Text('جهاز Windows'),
                subtitle: Text('آخر دخول: اليوم 10:30'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Logout from all devices
              Navigator.pop(context);
            },
            child: const Text('تسجيل الخروج من جميع الأجهزة'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'نظام متابعة طلبات الوقود',
      applicationVersion: 'الإصدار 1.0.0',
      applicationLegalese: '© 2024 جميع الحقوق محفوظة',
      children: [
        const SizedBox(height: 16),
        const Text(
          'تطبيق لمتابعة وإدارة طلبات شركات تزويد الوقود بكفاءة وسهولة.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سياسة الخصوصية'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '1. جمع البيانات: نجمع فقط البيانات الضرورية لتقديم الخدمة.\n'
                '2. استخدام البيانات: نستخدم البيانات فقط للأغراض المعلنة.\n'
                '3. حماية البيانات: نستخدم تقنيات أمنية لحماية بياناتك.\n'
                '4. مشاركة البيانات: لا نشارك بياناتك مع أطراف ثالثة إلا بإذنك.\n'
                '5. حقوق المستخدم: يمكنك طلب حذف بياناتك في أي وقت.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('شروط الاستخدام'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'باستخدامك لهذا التطبيق، فإنك توافق على الشروط التالية:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '1. يجب أن تكون بيانات الدخول صحيحة وسارية.\n'
                '2. يمنع استخدام التطبيق لأغراض غير قانونية.\n'
                '3. نتحفظ الحق في تعليق الحساب في حالة المخالفة.\n'
                '4. المسؤولية عن أمان الحساب تقع على عاتق المستخدم.\n'
                '5. قد نحدث الشروط في أي وقت وسيتم إعلام المستخدمين.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الدعم الفني'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'للاتصال بفريق الدعم الفني:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.email),
              title: Text('support@fuelsystem.com'),
            ),
            const ListTile(
              leading: Icon(Icons.phone),
              title: Text('+966 123 456 789'),
            ),
            const ListTile(
              leading: Icon(Icons.access_time),
              title: Text('من الأحد إلى الخميس 8ص - 4م'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Open email client
              },
              icon: const Icon(Icons.email),
              label: const Text('إرسال بريد إلكتروني'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'هل أنت متأكد من حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه وسيتم حذف جميع بياناتك بشكل دائم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Delete account
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف الحساب بنجاح'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين التطبيق'),
        content: const Text(
          'سيتم حذف جميع البيانات المحلية وإعادة تعيين التطبيق إلى الإعدادات الافتراضية. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Reset app
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إعادة تعيين التطبيق'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }
}
