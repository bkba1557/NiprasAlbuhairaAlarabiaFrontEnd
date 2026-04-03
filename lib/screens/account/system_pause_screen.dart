import 'package:flutter/material.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/system_pause_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class SystemPauseScreen extends StatefulWidget {
  const SystemPauseScreen({super.key});

  @override
  State<SystemPauseScreen> createState() => _SystemPauseScreenState();
}

class _SystemPauseScreenState extends State<SystemPauseScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _developerController = TextEditingController();

  bool _primedFromServer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _primeDefaults();
      context.read<SystemPauseProvider>().refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _developerController.dispose();
    super.dispose();
  }

  void _primeDefaults() {
    final auth = context.read<AuthProvider>();
    final name = auth.user?.name.trim() ?? '';

    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'تنبيه: توقف مؤقت للنظام';
    }
    if (_messageController.text.trim().isEmpty) {
      _messageController.text =
          'النظام متوقف مؤقتاً بسبب أعمال تطوير/تحديث.\nيرجى الانتظار حتى يتم استئناف العمل.';
    }
    if (_developerController.text.trim().isEmpty && name.isNotEmpty) {
      _developerController.text = name;
    }
  }

  Future<void> _primeFromNoticeIfNeeded() async {
    if (_primedFromServer) return;
    final notice = context.read<SystemPauseProvider>().notice;
    if (notice == null) return;

    _titleController.text =
        notice.title.trim().isEmpty ? _titleController.text : notice.title;
    _messageController.text =
        notice.message.trim().isEmpty ? _messageController.text : notice.message;
    _developerController.text = notice.developerName.trim().isEmpty
        ? _developerController.text
        : notice.developerName;

    _primedFromServer = true;
  }

  Future<void> _activate() async {
    final provider = context.read<SystemPauseProvider>();

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final developer = _developerController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة نص الإشعار قبل التفعيل'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final ok = await provider.activate(
      title: title,
      message: message,
      developerName: developer,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'تم تفعيل التوقف المؤقت وإرسال الإشعار للجميع'
            : (provider.error ?? 'تعذر تفعيل التوقف المؤقت')),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  Future<void> _deactivate() async {
    final provider = context.read<SystemPauseProvider>();

    final defaultResume =
        'تم الانتهاء من أعمال التطوير.\nالنظام يعمل الآن بشكل طبيعي.\nشكراً لتفهمكم.';
    final resumeController = TextEditingController(text: defaultResume);

    final resumeMessage = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء التوقف المؤقت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('سيتم إرسال إشعار لطيف للجميع عند الاستئناف:'),
            const SizedBox(height: 10),
            TextField(
              controller: resumeController,
              maxLines: 4,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, resumeController.text),
            child: const Text('إلغاء التوقف'),
          ),
        ],
      ),
    );

    resumeController.dispose();
    if (resumeMessage == null) return;

    final ok = await provider.deactivate(resumeMessage: resumeMessage);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'تم إلغاء التوقف المؤقت وإرسال إشعار الاستئناف'
            : (provider.error ?? 'تعذر إلغاء التوقف المؤقت')),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = (auth.user?.role ?? '').trim().toLowerCase() == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('إشعار التوقف المؤقت للنظام'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => context.read<SystemPauseProvider>().refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isOwner ? _buildOwnerBody(context) : _buildUnauthorizedBody(),
    );
  }

  Widget _buildUnauthorizedBody() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'غير مصرح – هذه الصفحة متاحة للمالك فقط.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildOwnerBody(BuildContext context) {
    return Consumer<SystemPauseProvider>(
      builder: (context, provider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _primeFromNoticeIfNeeded();
        });

        final notice = provider.notice;
        final isActive = notice?.isActive ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.pause_circle_filled_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isActive
                            ? AppColors.warningOrange
                            : AppColors.successGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isActive ? 'الحالة: مفعل' : 'الحالة: غير مفعل',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDarkBlue,
                          ),
                        ),
                      ),
                      if (provider.isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'محتوى الإشعار',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'العنوان (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        maxLines: 6,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'نص الإشعار',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _developerController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'اسم المطور (يظهر للجميع)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'عند التفعيل سيتم إرسال: إشعار داخل النظام + Push + بريد إلكتروني للجميع.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!isActive)
                FilledButton.icon(
                  onPressed: provider.isLoading ? null : _activate,
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: const Text('تفعيل التوقف المؤقت'),
                )
              else
                FilledButton.icon(
                  onPressed: provider.isLoading ? null : _deactivate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('إلغاء التوقف واستئناف النظام'),
                ),
              if (provider.error != null && provider.error!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    provider.error!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

