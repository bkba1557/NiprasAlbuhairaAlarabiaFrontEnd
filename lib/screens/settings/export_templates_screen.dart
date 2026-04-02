import 'dart:async';

import 'package:flutter/material.dart';
import 'package:order_tracker/screens/settings/export_template_editor_screen.dart';
import 'package:order_tracker/utils/api_service.dart';

class ExportTemplatesScreen extends StatefulWidget {
  const ExportTemplatesScreen({super.key});

  @override
  State<ExportTemplatesScreen> createState() => _ExportTemplatesScreenState();
}

class _ExportTemplatesScreenState extends State<ExportTemplatesScreen> {
  bool _loading = true;
  Object? _error;
  List<_TemplateItem> _templates = const <_TemplateItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.get('/templates');
      final decoded = ApiService.decodeJson(response);
      final items = <_TemplateItem>[];

      final templatesJson = decoded is Map ? decoded['templates'] : null;
      if (templatesJson is List) {
        for (final item in templatesJson) {
          if (item is Map) {
            items.add(_TemplateItem.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _templates = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قوالب التصدير'),
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
                          'تعذر تحميل القوالب',
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
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        backgroundColor: template.isCustomized
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        child: Icon(
                          template.isCustomized ? Icons.check : Icons.tune,
                          color: template.isCustomized
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                      title: Text(template.name),
                      subtitle: Text(
                        template.isCustomized
                            ? 'تم تخصيص القالب'
                            : 'القالب الافتراضي',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExportTemplateEditorScreen(
                              templateKey: template.key,
                              title: template.name,
                            ),
                          ),
                        );
                        if (mounted) {
                          unawaited(_load());
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _TemplateItem {
  final String key;
  final String name;
  final bool isCustomized;

  const _TemplateItem({
    required this.key,
    required this.name,
    required this.isCustomized,
  });

  factory _TemplateItem.fromJson(Map<String, dynamic> json) {
    return _TemplateItem(
      key: (json['key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isCustomized: json['isCustomized'] == true,
    );
  }
}
