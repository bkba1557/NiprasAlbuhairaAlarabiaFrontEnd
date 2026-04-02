import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/daily_report_model.dart';
import 'package:order_tracker/services/circular_template_pdf_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/helpers.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class DailyReportsScreen extends StatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  State<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends State<DailyReportsScreen> {
  final TextEditingController _bodyController = TextEditingController();

  bool _sending = false;
  bool _autoPreview = false;
  bool _shouldRepaintPreview = false;
  DateTime? _lastPreviewRefreshedAt;
  Timer? _previewDebounce;
  late final LayoutCallback _previewBuildCallback = _buildPreviewPdfBytes;
  Uint8List? _previewCacheBytes;
  String? _previewCacheKey;

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(_maybeAutoRefreshPreview);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
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

  String _subjectForNow() {
    final now = DateTime.now();
    final formatted = DateFormat('yyyy/MM/dd').format(now);
    return 'تقرير يومي - $formatted';
  }

  Future<Uint8List> _buildPreviewPdfBytes(PdfPageFormat format) async {
    final subject = _subjectForNow();
    final body = _bodyController.text.trim();

    final cacheKey = <Object?>[
      subject,
      body,
    ].join('|');

    final cachedBytes = _previewCacheBytes;
    if (_previewCacheKey == cacheKey && cachedBytes != null) {
      return cachedBytes;
    }

    final bytes = await CircularTemplatePdfService.buildCircularPdfBytes(
      circularNumber: 'DAILY',
      subject: subject,
      body: body,
      issuedAt: DateTime.now(),
      includeMetaRow: false,
      subjectAlign: 'center',
      bodyAlign: 'right',
      subjectFontSize: 18,
      bodyFontSize: 12,
      subjectBold: true,
      subjectUnderline: false,
      bodyBold: false,
      bodyUnderline: false,
    );

    _previewCacheKey = cacheKey;
    _previewCacheBytes = bytes;
    return bytes;
  }

  String _snippet(String value) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 160) return text;
    return '${text.substring(0, 157)}...';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(date.toLocal());
  }

  Future<void> _sendDailyReport() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      Helpers.showErrorSnackBar(context, 'يرجى كتابة التقرير اليومي');
      return;
    }

    final confirmed = await Helpers.showConfirmationDialog(
      context,
      'إرسال التقرير اليومي',
      'سيتم إرسال التقرير إلى الإدارة (المالك والمدير العام) عبر الإشعارات والبريد الإلكتروني. هل تريد المتابعة؟',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);

    try {
      final issuedAt = DateTime.now();
      final subject = _subjectForNow();
      final pdfBytes = await CircularTemplatePdfService.buildCircularPdfBytes(
        circularNumber: 'DAILY',
        subject: subject,
        body: body,
        issuedAt: issuedAt,
        includeMetaRow: false,
        subjectAlign: 'center',
        bodyAlign: 'right',
        subjectFontSize: 18,
        bodyFontSize: 12,
        subjectBold: true,
        subjectUnderline: false,
        bodyBold: false,
        bodyUnderline: false,
      );

      await ApiService.post('/daily-reports', {
        'subject': subject,
        'body': body,
        'issuedAt': issuedAt.toIso8601String(),
        'pdfBase64': base64Encode(pdfBytes),
      });

      if (!mounted) return;
      Helpers.showSuccessSnackBar(context, 'تم إرسال التقرير اليومي بنجاح');
      _bodyController.clear();
      _refreshPreview();
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnackBar(context, 'فشل إرسال التقرير: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var initialized = false;
        var loading = false;
        String? error;
        List<DailyReportModel> history = const [];

        Future<void> loadHistory(void Function(VoidCallback) setSheetState) async {
          if (loading) return;
          setSheetState(() {
            loading = true;
            error = null;
          });

          try {
            final response = await ApiService.get('/daily-reports?limit=50&page=1');
            final decoded = ApiService.decodeJson(response);

            final list =
                decoded is Map ? (decoded['reports'] ?? decoded['items']) : null;
            final reports = (list is List)
                ? list
                    .whereType<Map>()
                    .map(
                      (e) => DailyReportModel.fromJson(
                        Map<String, dynamic>.from(e),
                      ),
                    )
                    .toList()
                : <DailyReportModel>[];

            setSheetState(() => history = reports);
          } catch (e) {
            setSheetState(() => error = e.toString());
          } finally {
            setSheetState(() => loading = false);
          }
        }

        Future<void> printHistoryPdf(
          DailyReportModel report,
          void Function(VoidCallback) setSheetState,
        ) async {
          try {
            final response =
                await ApiService.download('/daily-reports/${report.id}/pdf');
            final bytes = response.bodyBytes;
            await Printing.layoutPdf(
              name: 'تقرير_يومي_${report.id}.pdf',
              onLayout: (_) async => bytes,
            );
          } catch (e) {
            if (!context.mounted) return;
            Helpers.showErrorSnackBar(context, 'تعذر طباعة التقرير: $e');
          } finally {
            setSheetState(() {});
          }
        }

        final height = MediaQuery.of(context).size.height;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!initialized) {
              initialized = true;
              unawaited(loadHistory(setSheetState));
            }

            return SafeArea(
              child: SizedBox(
                height: height * 0.86,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'سجل التقارير اليومية',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'تحديث',
                            onPressed:
                                loading ? null : () => loadHistory(setSheetState),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (loading) const LinearProgressIndicator(),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => loadHistory(setSheetState),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ] else if (history.isEmpty && !loading) ...[
                        const SizedBox(height: 12),
                        const Center(child: Text('لا يوجد تقارير مرسلة بعد.')),
                      ] else ...[
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: history.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final report = history[index];
                              final subject = report.subject.trim();
                              final baseTitle =
                                  subject.isEmpty ? 'تقرير يومي' : subject;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  report.createdByName.trim().isEmpty
                                      ? baseTitle
                                      : '$baseTitle - ${report.createdByName}',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'التاريخ: ${_formatDate(report.issuedAt ?? report.createdAt)}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(_snippet(report.body)),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: 'طباعة',
                                  onPressed: () => printHistoryPdf(
                                    report,
                                    setSheetState,
                                  ),
                                  icon: const Icon(Icons.print_outlined),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير اليومي'),
        actions: [
          IconButton(
            tooltip: 'سجل التقارير',
            onPressed: _openHistorySheet,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                children: [
                  SizedBox(width: 360, child: _buildForm()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPreview()),
                ],
              )
            : Column(
                children: [
                  _buildForm(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildPreview()),
                ],
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _subjectForNow(),
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bodyController,
              minLines: 12,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'نص التقرير اليومي',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _sending ? null : _sendDailyReport,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('إرسال التقرير'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openHistorySheet,
              icon: const Icon(Icons.history),
              label: const Text('سجل التقارير'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return PdfPreview(
      initialPageFormat: PdfPageFormat.a4,
      canChangeOrientation: false,
      canChangePageFormat: false,
      allowPrinting: true,
      allowSharing: true,
      shouldRepaint: _shouldRepaintPreview,
      build: _previewBuildCallback,
      pdfFileName: 'التقرير_اليومي.pdf',
    );
  }
}
