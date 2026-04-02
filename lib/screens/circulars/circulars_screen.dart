import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/services/circular_number_service.dart';
import 'package:order_tracker/services/circular_template_pdf_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/helpers.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class CircularsScreen extends StatefulWidget {
  const CircularsScreen({super.key});

  @override
  State<CircularsScreen> createState() => _CircularsScreenState();
}

class _CircularsScreenState extends State<CircularsScreen> {
  static const List<double> _subjectFontSizeOptions = <double>[
    14,
    16,
    18,
    20,
    24,
    28,
  ];
  static const List<double> _bodyFontSizeOptions = <double>[
    10,
    11,
    12,
    13,
    14,
    16,
    18,
  ];

  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _includeMetaRow = false;
  bool _loadingNumber = true;
  bool _publishing = false;
  bool _autoPreview = false;
  bool _shouldRepaintPreview = false;
  DateTime? _lastPreviewRefreshedAt;
  Timer? _previewDebounce;
  String? _lastCopiedNumber;
  late final LayoutCallback _previewBuildCallback = _buildPreviewPdfBytes;
  Uint8List? _previewCacheBytes;
  String? _previewCacheKey;

  TextAlign _subjectAlign = TextAlign.center;
  TextAlign _bodyAlign = TextAlign.right;
  double _subjectFontSize = 18;
  double _bodyFontSize = 12;
  bool _subjectBold = true;
  bool _subjectUnderline = false;
  bool _bodyBold = false;
  bool _bodyUnderline = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reserveAndSetNumber(clearFields: false));
    _numberController.addListener(_maybeAutoRefreshPreview);
    _subjectController.addListener(_maybeAutoRefreshPreview);
    _bodyController.addListener(_maybeAutoRefreshPreview);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _numberController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _maybeAutoRefreshPreview() {
    if (!_autoPreview) return;
    _refreshPreview(debounce: true);
  }

  void _refreshPreview({bool debounce = false}) {
    if (!mounted) return;

    if (debounce) {
      _previewDebounce?.cancel();
      _previewDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _refreshPreview(debounce: false);
      });
      return;
    }

    setState(() {
      _shouldRepaintPreview = true;
      _lastPreviewRefreshedAt = DateTime.now();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_shouldRepaintPreview) {
        setState(() => _shouldRepaintPreview = false);
      }
    });
  }

  String _alignToApiValue(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return 'left';
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
        return 'right';
      case TextAlign.justify:
        return 'justify';
      default:
        return 'right';
    }
  }

  TextStyle _editorStyle({
    required double fontSize,
    required bool bold,
    required bool underline,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      height: 1.6,
    );
  }

  Widget _buildAlignToggleButtons({
    required TextAlign value,
    required List<TextAlign> options,
    required List<IconData> icons,
    required ValueChanged<TextAlign> onChanged,
  }) {
    return ToggleButtons(
      constraints: const BoxConstraints(minHeight: 36, minWidth: 40),
      isSelected: options.map((o) => o == value).toList(growable: false),
      onPressed: (index) => onChanged(options[index]),
      children: [for (final icon in icons) Icon(icon, size: 18)],
    );
  }

  Widget _buildInlineStyleToggleButtons({
    required bool bold,
    required bool underline,
    required ValueChanged<bool> onBoldChanged,
    required ValueChanged<bool> onUnderlineChanged,
  }) {
    return ToggleButtons(
      constraints: const BoxConstraints(minHeight: 36, minWidth: 40),
      isSelected: [bold, underline],
      onPressed: (index) {
        if (index == 0) {
          onBoldChanged(!bold);
          return;
        }
        if (index == 1) {
          onUnderlineChanged(!underline);
        }
      },
      children: const [
        Icon(Icons.format_bold, size: 18),
        Icon(Icons.format_underline, size: 18),
      ],
    );
  }

  Widget _buildFontSizeDropdown({
    required double value,
    required List<double> options,
    required ValueChanged<double> onChanged,
    String labelText = 'حجم',
  }) {
    return SizedBox(
      width: 120,
      child: DropdownButtonFormField<double>(
        value: options.contains(value) ? value : options.first,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        items: options
            .map(
              (size) => DropdownMenuItem<double>(
                value: size,
                child: Text(size.toStringAsFixed(0)),
              ),
            )
            .toList(growable: false),
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }

  Future<void> _reserveAndSetNumber({required bool clearFields}) async {
    setState(() => _loadingNumber = true);
    String nextNumber;
    try {
      final response = await ApiService.get('/circulars/next-number');
      final decoded = ApiService.decodeJson(response);
      final serverNumber = decoded is Map
          ? decoded['number']?.toString()
          : null;
      if (serverNumber == null || serverNumber.trim().isEmpty) {
        throw Exception('Invalid circular number from server');
      }
      nextNumber = serverNumber.trim();
    } catch (_) {
      nextNumber = await CircularNumberService.reserveNextNumber();
    }
    if (!mounted) return;
    _numberController.text = nextNumber;
    if (clearFields) {
      _subjectController.clear();
      _bodyController.clear();
      _subjectAlign = TextAlign.center;
      _bodyAlign = TextAlign.right;
      _subjectFontSize = 18;
      _bodyFontSize = 12;
      _subjectBold = true;
      _subjectUnderline = false;
      _bodyBold = false;
      _bodyUnderline = false;
    }
    setState(() => _loadingNumber = false);
    _refreshPreview();
  }

  Future<void> _publishCircular() async {
    final number = _numberController.text.trim();
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (body.isEmpty) {
      Helpers.showErrorSnackBar(context, 'يرجى إدخال نص التعميم');
      return;
    }

    final confirmed = await Helpers.showConfirmationDialog(
      context,
      'نشر التعميم',
      'سيتم إرسال التعميم لجميع الموظفين عبر الإشعارات والبريد الإلكتروني. هل تريد المتابعة؟',
    );
    if (!confirmed || !mounted) return;

    setState(() => _publishing = true);
    try {
      await ApiService.post('/circulars', {
        'number': number,
        'subject': subject,
        'body': body,
        'includeMetaRow': _includeMetaRow,
        'subjectAlign': _alignToApiValue(_subjectAlign),
        'bodyAlign': _alignToApiValue(_bodyAlign),
        'subjectFontSize': _subjectFontSize,
        'bodyFontSize': _bodyFontSize,
        'subjectBold': _subjectBold,
        'subjectUnderline': _subjectUnderline,
        'bodyBold': _bodyBold,
        'bodyUnderline': _bodyUnderline,
        'requiresAcceptance': true,
      });

      if (!mounted) return;
      Helpers.showSuccessSnackBar(context, 'تم نشر التعميم وإرساله بنجاح');
      await _reserveAndSetNumber(clearFields: true);
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnackBar(context, 'فشل نشر التعميم: $e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<Uint8List> _buildPreviewPdfBytes(PdfPageFormat format) async {
    final circularNumber = _numberController.text.trim().isEmpty
        ? 'BHR00001'
        : _numberController.text.trim();

    final subject = _subjectController.text;
    final body = _bodyController.text;
    final includeMetaRow = _includeMetaRow;
    final subjectAlign = _alignToApiValue(_subjectAlign);
    final bodyAlign = _alignToApiValue(_bodyAlign);
    final subjectFontSize = _subjectFontSize;
    final bodyFontSize = _bodyFontSize;
    final subjectBold = _subjectBold;
    final subjectUnderline = _subjectUnderline;
    final bodyBold = _bodyBold;
    final bodyUnderline = _bodyUnderline;

    final cacheKey = <Object?>[
      circularNumber,
      subject,
      body,
      includeMetaRow,
      subjectAlign,
      bodyAlign,
      subjectFontSize,
      bodyFontSize,
      subjectBold,
      subjectUnderline,
      bodyBold,
      bodyUnderline,
    ].join('|');

    final cachedBytes = _previewCacheBytes;
    if (_previewCacheKey == cacheKey && cachedBytes != null) {
      return cachedBytes;
    }

    final bytes = await CircularTemplatePdfService.buildCircularPdfBytes(
      circularNumber: circularNumber,
      subject: subject,
      body: body,
      includeMetaRow: includeMetaRow,
      subjectAlign: subjectAlign,
      bodyAlign: bodyAlign,
      subjectFontSize: subjectFontSize,
      bodyFontSize: bodyFontSize,
      subjectBold: subjectBold,
      subjectUnderline: subjectUnderline,
      bodyBold: bodyBold,
      bodyUnderline: bodyUnderline,
    );

    _previewCacheKey = cacheKey;
    _previewCacheBytes = bytes;
    return bytes;
  }

  Future<void> _copyNumber() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    setState(() => _lastCopiedNumber = number);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم نسخ رقم التعميم: $number')));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final role = authProvider.role?.trim().toLowerCase();
    final canAccess = role == 'owner' || role == 'manager';

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('التعاميم')),
        body: const Center(
          child: Text('هذه الصفحة متاحة للمالك والمدير العام فقط.'),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      appBar: AppBar(title: const Text('التعاميم')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                children: [
                  SizedBox(width: 360, child: _buildForm(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPreview(context)),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  var previewHeight = constraints.maxHeight * 0.62;
                  if (previewHeight < 320) previewHeight = 320;
                  if (previewHeight > 720) previewHeight = 720;
                  final bottomSpace = MediaQuery.of(context).padding.bottom + 24;

                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _buildForm(context),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: previewHeight,
                        child: _buildPreview(context),
                      ),
                      SizedBox(height: bottomSpace),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'رقم التعميم',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'نسخ',
                        onPressed: _copyNumber,
                        icon: Icon(
                          (_lastCopiedNumber == _numberController.text.trim())
                              ? Icons.check
                              : Icons.copy,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _loadingNumber
                      ? null
                      : () => _reserveAndSetNumber(clearFields: true),
                  icon: _loadingNumber
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('تعميم جديد'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              textAlign: _subjectAlign,
              style: _editorStyle(
                fontSize: _subjectFontSize,
                bold: _subjectBold,
                underline: _subjectUnderline,
              ),
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تنسيق العنوان',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAlignToggleButtons(
                  value: _subjectAlign,
                  options: const [
                    TextAlign.right,
                    TextAlign.center,
                    TextAlign.left,
                  ],
                  icons: const [
                    Icons.format_align_right,
                    Icons.format_align_center,
                    Icons.format_align_left,
                  ],
                  onChanged: (align) {
                    setState(() => _subjectAlign = align);
                    _refreshPreview();
                  },
                ),
                _buildInlineStyleToggleButtons(
                  bold: _subjectBold,
                  underline: _subjectUnderline,
                  onBoldChanged: (v) {
                    setState(() => _subjectBold = v);
                    _refreshPreview();
                  },
                  onUnderlineChanged: (v) {
                    setState(() => _subjectUnderline = v);
                    _refreshPreview();
                  },
                ),
                _buildFontSizeDropdown(
                  value: _subjectFontSize,
                  options: _subjectFontSizeOptions,
                  labelText: 'حجم العنوان',
                  onChanged: (v) {
                    setState(() => _subjectFontSize = v);
                    _refreshPreview();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'تنسيق النص',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAlignToggleButtons(
                  value: _bodyAlign,
                  options: const [
                    TextAlign.right,
                    TextAlign.center,
                    TextAlign.left,
                    TextAlign.justify,
                  ],
                  icons: const [
                    Icons.format_align_right,
                    Icons.format_align_center,
                    Icons.format_align_left,
                    Icons.format_align_justify,
                  ],
                  onChanged: (align) {
                    setState(() => _bodyAlign = align);
                    _refreshPreview();
                  },
                ),
                _buildInlineStyleToggleButtons(
                  bold: _bodyBold,
                  underline: _bodyUnderline,
                  onBoldChanged: (v) {
                    setState(() => _bodyBold = v);
                    _refreshPreview();
                  },
                  onUnderlineChanged: (v) {
                    setState(() => _bodyUnderline = v);
                    _refreshPreview();
                  },
                ),
                _buildFontSizeDropdown(
                  value: _bodyFontSize,
                  options: _bodyFontSizeOptions,
                  labelText: 'حجم النص',
                  onChanged: (v) {
                    setState(() => _bodyFontSize = v);
                    _refreshPreview();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              textAlign: _bodyAlign,
              style: _editorStyle(
                fontSize: _bodyFontSize,
                bold: _bodyBold,
                underline: _bodyUnderline,
              ),
              minLines: 10,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'نص التعميم',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refreshPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث المعاينة'),
            ),
            SwitchListTile.adaptive(
              value: _autoPreview,
              onChanged: (v) => setState(() => _autoPreview = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('تحديث تلقائي (قد يكون أبطأ)'),
            ),
            if (_lastPreviewRefreshedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'آخر تحديث: ${_lastPreviewRefreshedAt!.toLocal().toString().split('.').first}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _includeMetaRow,
              onChanged: (v) {
                setState(() => _includeMetaRow = v);
                _refreshPreview();
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('إظهار رقم التعميم والتاريخ أعلى الصفحة'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _publishing ? null : _publishCircular,
              icon: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('نشر وإرسال التعميم'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return PdfPreview(
      initialPageFormat: PdfPageFormat.a4,
      canChangeOrientation: false,
      canChangePageFormat: false,
      allowPrinting: true,
      allowSharing: true,
      shouldRepaint: _shouldRepaintPreview,
      build: _previewBuildCallback,
    );
  }
}
