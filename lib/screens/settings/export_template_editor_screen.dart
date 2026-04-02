import 'dart:async';

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/helpers.dart';

class ExportTemplateEditorScreen extends StatefulWidget {
  final String templateKey;
  final String title;

  const ExportTemplateEditorScreen({
    super.key,
    required this.templateKey,
    required this.title,
  });

  @override
  State<ExportTemplateEditorScreen> createState() =>
      _ExportTemplateEditorScreenState();
}

class _ExportTemplateEditorScreenState extends State<ExportTemplateEditorScreen> {
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  final _nameController = TextEditingController();
  final _companyArabicController = TextEditingController();
  final _companyEnglishController = TextEditingController();
  final _unifiedNumberController = TextEditingController();
  final _footerTextController = TextEditingController();
  final _darkController = TextEditingController();
  final _mediumController = TextEditingController();
  final _lightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyArabicController.dispose();
    _companyEnglishController.dispose();
    _unifiedNumberController.dispose();
    _footerTextController.dispose();
    _darkController.dispose();
    _mediumController.dispose();
    _lightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.get('/templates/${widget.templateKey}');
      final decoded = ApiService.decodeJson(response);
      final templateJson = decoded is Map ? decoded['template'] : null;
      if (templateJson is! Map) {
        throw Exception('Invalid template response');
      }

      final map = Map<String, dynamic>.from(templateJson);
      final colors = map['colors'] is Map ? Map<String, dynamic>.from(map['colors'] as Map) : const <String, dynamic>{};

      _nameController.text = (map['name'] ?? widget.title).toString();
      _companyArabicController.text = (map['companyArabicName'] ?? '').toString();
      _companyEnglishController.text = (map['companyEnglishName'] ?? '').toString();
      _unifiedNumberController.text = (map['unifiedNumber'] ?? '').toString();
      _footerTextController.text = (map['footerText'] ?? '').toString();
      _darkController.text = (colors['dark'] ?? '').toString();
      _mediumController.text = (colors['medium'] ?? '').toString();
      _lightController.text = (colors['light'] ?? '').toString();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ApiService.put('/templates/${widget.templateKey}', {
        'name': _nameController.text.trim(),
        'companyArabicName': _companyArabicController.text.trim(),
        'companyEnglishName': _companyEnglishController.text.trim(),
        'unifiedNumber': _unifiedNumberController.text.trim(),
        'footerText': _footerTextController.text.trim(),
        'colors': {
          'dark': _darkController.text.trim(),
          'medium': _mediumController.text.trim(),
          'light': _lightController.text.trim(),
        },
      });

      if (!mounted) return;
      Helpers.showSuccessSnackBar(context, 'تم حفظ القالب');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      Helpers.showErrorSnackBar(context, 'تعذر حفظ القالب: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color? _tryParseHexColor(String value) {
    var hex = value.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length != 6) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  Widget _buildColorField({
    required TextEditingController controller,
    required String label,
  }) {
    final preview = _tryParseHexColor(controller.text);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixText: controller.text.trim().startsWith('#') ? '' : '#',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: preview ?? Colors.transparent,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: preview == null
              ? const Icon(Icons.color_lens_outlined, size: 18)
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'تعذر تحميل القالب',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم القالب',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _companyArabicController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الشركة (عربي)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _companyEnglishController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الشركة (English)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _unifiedNumberController,
                        decoration: const InputDecoration(
                          labelText: 'الرقم الموحد',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _footerTextController,
                        decoration: const InputDecoration(
                          labelText: 'نص التذييل (Footer)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'الألوان',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _buildColorField(controller: _darkController, label: 'غامق'),
                      const SizedBox(height: 12),
                      _buildColorField(
                          controller: _mediumController, label: 'متوسط'),
                      const SizedBox(height: 12),
                      _buildColorField(controller: _lightController, label: 'فاتح'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('حفظ'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

