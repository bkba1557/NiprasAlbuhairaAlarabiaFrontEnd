import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:order_tracker/models/station_maintenance_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_maintenance_provider.dart';
import 'package:order_tracker/utils/constants.dart';

class StationMaintenanceDetailScreen extends StatefulWidget {
  const StationMaintenanceDetailScreen({super.key});

  @override
  State<StationMaintenanceDetailScreen> createState() =>
      _StationMaintenanceDetailScreenState();
}

class _StationMaintenanceDetailScreenState
    extends State<StationMaintenanceDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  StationMaintenanceRequest? _request;
  bool _loading = true;
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _mapPrompted = false;

  final List<XFile> _beforeImages = [];
  final List<XFile> _afterImages = [];
  final List<XFile> _videos = [];
  final List<_InvoiceDraft> _invoiceDrafts = [];

  String _decision = 'approved';
  final TextEditingController _reviewNotesController = TextEditingController();
  final TextEditingController _ratingNoteController = TextEditingController();
  double _ratingScore = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequest();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    _reviewNotesController.dispose();
    _ratingNoteController.dispose();
    for (final invoice in _invoiceDrafts) {
      invoice.dispose();
    }
    super.dispose();
  }

  bool _isTechnicianRole(String? role) {
    return role == 'maintenance_technician' ||
        role == 'Maintenance_Technician' ||
        role == 'maintenance_station' ||
        role == 'maintenance';
  }

  bool _isManagerRole(String? role) {
    return role == 'admin' ||
        role == 'owner' ||
        role == 'manager' ||
        role == 'supervisor' ||
        role == 'maintenance' ||
        role == 'maintenance_car_management';
  }

  Future<void> _loadRequest() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) {
      setState(() => _loading = false);
      return;
    }

    final id = args is String ? args : args.toString();
    final provider = context.read<StationMaintenanceProvider>();
    final request = await provider.fetchRequestById(id);

    if (!mounted) return;

    if (request != null) {
      _request = request;
      _notesController.text = request.technicianNotes ?? '';
      if (_invoiceDrafts.isEmpty) {
        _invoiceDrafts.add(_InvoiceDraft());
      }

      final authProvider = context.read<AuthProvider>();
      final role = authProvider.user?.role;
      final shouldAutoStart = role != 'maintenance_station';
      if (shouldAutoStart &&
          _isTechnicianRole(role) &&
          request.assignedTo == authProvider.user?.id &&
          request.status == 'assigned') {
        final started = await provider.startRequest(request.id);
        if (started != null && mounted) {
          _request = started;
        }
      }
    }

    _startTimer();
    _maybePromptMap();
    setState(() => _loading = false);
  }

  void _startTimer() {
    _timer?.cancel();
    if (_request == null) return;
    if (_request!.closedAt != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  Future<void> _maybePromptMap() async {
    if (_mapPrompted || _request == null) return;
    final authProvider = context.read<AuthProvider>();
    final isTechnician = _isTechnicianRole(authProvider.user?.role);
    final isAssigned = _request?.assignedTo == authProvider.user?.id;
    final mapUrl = _buildMapUrl(_request!);

    if (!isTechnician || !isAssigned || mapUrl == null) return;

    _mapPrompted = true;
    if (!mounted) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فتح المسار'),
        content: const Text('هل تريد فتح مسار المحطة في خرائط Google؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فتح'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await _launchMap(mapUrl);
    }
  }

  Future<void> _pickBeforeImages({required ImageSource source}) async {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file != null) {
        setState(() => _beforeImages.add(file));
      }
      return;
    }

    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _beforeImages.addAll(files));
    }
  }

  Future<void> _pickAfterImages({required ImageSource source}) async {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file != null) {
        setState(() => _afterImages.add(file));
      }
      return;
    }

    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _afterImages.addAll(files));
    }
  }

  Future<void> _pickVideo({required ImageSource source}) async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: source);
    if (file != null) {
      setState(() => _videos.add(file));
    }
  }

  Future<void> _pickInvoiceFile(_InvoiceDraft invoice) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => invoice.attachment = result.files.first);
    }
  }

  Future<void> _submitTechnician() async {
    if (_request == null) return;
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<StationMaintenanceProvider>();

    final invoiceFiles = <PlatformFile>[];
    final invoicesPayload = <Map<String, dynamic>>[];

    for (final invoice in _invoiceDrafts) {
      final items = invoice.items
          .where((item) => item.description.text.trim().isNotEmpty)
          .map((item) => {
                'description': item.description.text.trim(),
                'quantity': _toDouble(item.quantity.text),
                'unitPrice': _toDouble(item.unitPrice.text),
              })
          .toList();

      if (items.isEmpty) {
        _showSnack('يرجى إضافة بنود للفاتورة', isError: true);
        return;
      }

      if (invoice.attachment == null) {
        _showSnack('يرجى إرفاق ملف لكل فاتورة', isError: true);
        return;
      }

      invoiceFiles.add(invoice.attachment!);
      invoicesPayload.add({
        'invoiceNumber': invoice.invoiceNumber.text.trim(),
        'vendorName': invoice.vendorName.text.trim(),
        'notes': invoice.notes.text.trim(),
        'items': items,
      });
    }

    final updated = await provider.submitRequest(
      id: _request!.id,
      technicianNotes: _notesController.text.trim(),
      beforeImages: _beforeImages,
      afterImages: _afterImages,
      videos: _videos,
      invoiceFiles: invoiceFiles,
      invoices: invoicesPayload,
    );

    if (!mounted) return;

    if (updated != null) {
      setState(() => _request = updated);
      _showSnack('تم إرسال التقرير للمراجعة');
    } else {
      _showSnack(provider.error ?? 'حدث خطأ أثناء الإرسال', isError: true);
    }
  }

  Future<void> _submitReview() async {
    if (_request == null) return;
    final provider = context.read<StationMaintenanceProvider>();

    final updated = await provider.reviewRequest(
      id: _request!.id,
      decision: _decision,
      notes: _reviewNotesController.text.trim(),
      ratingScore: _ratingScore,
      ratingNote: _ratingNoteController.text.trim(),
    );

    if (!mounted) return;

    if (updated != null) {
      setState(() => _request = updated);
      _showSnack('تم اعتماد القرار');
    } else {
      _showSnack(provider.error ?? 'حدث خطأ أثناء المراجعة', isError: true);
    }
  }

  void _addInvoice() {
    setState(() => _invoiceDrafts.add(_InvoiceDraft()));
  }

  void _removeInvoice(int index) {
    setState(() {
      final draft = _invoiceDrafts.removeAt(index);
      draft.dispose();
    });
  }

  double _invoiceSubtotal(_InvoiceDraft invoice) {
    return invoice.items.fold<double>(0, (sum, item) {
      final qty = _toDouble(item.quantity.text);
      final price = _toDouble(item.unitPrice.text);
      return sum + (qty * price);
    });
  }

  double _overallSubtotal() {
    return _invoiceDrafts.fold<double>(
      0,
      (sum, invoice) => sum + _invoiceSubtotal(invoice),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final role = authProvider.user?.role;
    final isTechnician = _isTechnicianRole(role);
    final isManager = _isManagerRole(role);
    final isAssignedToMe = _request?.assignedTo == authProvider.user?.id;
    final showStartButton =
        isTechnician && isAssignedToMe && _request?.status == 'assigned';

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return const Scaffold(
        body: Center(child: Text('الطلب غير موجود')),
      );
    }

    final request = _request!;

    return Scaffold(
      appBar: AppBar(
        title: Text(request.title.isNotEmpty ? request.title : 'تفاصيل الطلب'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth < 1200 ? constraints.maxWidth : 1200.0;
          final horizontalPadding = constraints.maxWidth < 700 ? 16.0 : 24.0;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                children: [
                  _buildHeaderCard(request, showStartButton),
                  const SizedBox(height: 16),
                  if (request.status == 'under_review' && !isManager)
                    _buildInfoBanner('تم إرسال الطلب ويجري مراجعته الآن'),
                  if ((request.status == 'assigned' ||
                          request.status == 'in_progress') &&
                      isTechnician &&
                      isAssignedToMe)
                    _buildTechnicianForm(request),
                  if (request.status == 'under_review' && isManager)
                    _buildReviewSection(),
                  if (request.review != null || request.rating != null)
                    _buildReviewSummary(request),
                  if (request.beforePhotos.isNotEmpty ||
                      request.afterPhotos.isNotEmpty ||
                      request.videos.isNotEmpty ||
                      request.invoiceFiles.isNotEmpty)
                    _buildAttachments(request),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(StationMaintenanceRequest request, bool showStart) {
    final elapsed = _formatElapsed(_calculateElapsed(request));
    final summary = request.summary;
    final role = context.read<AuthProvider>().user?.role;
    final startLabel =
        role == 'maintenance_station' ? 'قبول الطلب' : 'بدء العمل';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _typeLabel(request.type),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildStatusChip(request.status),
              ],
            ),
            const SizedBox(height: 12),
            if (request.requestNumber != null &&
                request.requestNumber!.trim().isNotEmpty)
              Text('رقم الطلب: ${request.requestNumber}'),
            Text('المحطة: ${request.stationName.isNotEmpty ? request.stationName : 'غير محدد'}'),
            Text('الفني: ${request.assignedToName ?? 'غير محدد'}'),
            Text('المنشئ: ${request.createdByName ?? 'غير محدد'}'),
            if (request.stationLocation?.address?.isNotEmpty == true)
              Text('العنوان: ${request.stationLocation?.address}'),
            if (_buildMapUrl(request) != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _launchMap(_buildMapUrl(request)!),
                icon: const Icon(Icons.map_outlined),
                label: const Text('فتح المسار في خرائط Google'),
              ),
            ],
            if (request.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(request.description),
            ],
            const Divider(height: 24),
            Text('الوقت المستغرق: $elapsed'),
            const SizedBox(height: 8),
            if (summary.total > 0) ...[
              Text('الإجمالي قبل الضريبة: ${summary.subtotal.toStringAsFixed(2)}'),
              Text('ضريبة 15%: ${summary.taxAmount.toStringAsFixed(2)}'),
              Text('الإجمالي: ${summary.total.toStringAsFixed(2)}'),
            ],
            if (showStart) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final provider =
                      context.read<StationMaintenanceProvider>();
                  final started = await provider.startRequest(request.id);
                  if (!mounted) return;
                  if (started != null) {
                    setState(() => _request = started);
                  } else {
                    _showSnack(
                      provider.error ?? 'تعذر بدء العمل',
                      isError: true,
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(startLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: AppColors.warningOrange),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildTechnicianForm(StationMaintenanceRequest request) {
    final provider = context.watch<StationMaintenanceProvider>();
    final tax = _overallSubtotal() * 0.15;
    final total = _overallSubtotal() + tax;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تقرير الفني',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'وصف الأعمال المنجزة',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildImageSection(
                title: 'صور قبل العمل',
                images: _beforeImages,
                onCamera: () => _pickBeforeImages(source: ImageSource.camera),
                onGallery: () => _pickBeforeImages(source: ImageSource.gallery),
              ),
              const SizedBox(height: 16),
              _buildImageSection(
                title: 'صور بعد العمل',
                images: _afterImages,
                onCamera: () => _pickAfterImages(source: ImageSource.camera),
                onGallery: () => _pickAfterImages(source: ImageSource.gallery),
              ),
              const SizedBox(height: 16),
              _buildVideoSection(
                title: 'فيديوهات العمل',
                videos: _videos,
                onCamera: () => _pickVideo(source: ImageSource.camera),
                onGallery: () => _pickVideo(source: ImageSource.gallery),
              ),
              const SizedBox(height: 16),
              _buildInvoicesSection(),
              const SizedBox(height: 12),
              Text('الإجمالي قبل الضريبة: ${_overallSubtotal().toStringAsFixed(2)}'),
              Text('الضريبة 15%: ${tax.toStringAsFixed(2)}'),
              Text('الإجمالي النهائي: ${total.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: provider.isLoading ? null : () => _submitTechnician(),
                icon: const Icon(Icons.send),
                label: Text(provider.isLoading ? 'جارٍ الإرسال...' : 'إرسال للمراجعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required List<XFile> images,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera),
              label: const Text('التقاط صورة'),
            ),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('اختيار صور'),
            ),
          ],
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('تم اختيار ${images.length} صورة'),
        ],
      ],
    );
  }

  Widget _buildVideoSection({
    required String title,
    required List<XFile> videos,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.videocam),
              label: const Text('تسجيل فيديو'),
            ),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.video_library),
              label: const Text('اختيار فيديو'),
            ),
          ],
        ),
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('تم اختيار ${videos.length} فيديو'),
        ],
      ],
    );
  }

  Widget _buildInvoicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'الفواتير وبنودها',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addInvoice,
              icon: const Icon(Icons.add),
              label: const Text('إضافة فاتورة'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._invoiceDrafts.asMap().entries.map(
              (entry) => _buildInvoiceCard(entry.key, entry.value),
            ),
      ],
    );
  }

  Widget _buildInvoiceCard(int index, _InvoiceDraft invoice) {
    final subtotal = _invoiceSubtotal(invoice);
    final tax = subtotal * 0.15;
    final total = subtotal + tax;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'فاتورة ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_invoiceDrafts.length > 1)
                  IconButton(
                    onPressed: () => _removeInvoice(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            TextFormField(
              controller: invoice.invoiceNumber,
              decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: invoice.vendorName,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: invoice.notes,
              decoration: const InputDecoration(labelText: 'ملاحظات الفاتورة'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickInvoiceFile(invoice),
              icon: const Icon(Icons.attach_file),
              label: Text(invoice.attachment?.name ?? 'إرفاق ملف الفاتورة'),
            ),
            const SizedBox(height: 8),
            Text(
              'بنود الفاتورة',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...invoice.items.asMap().entries.map(
                  (entry) => _buildInvoiceItem(invoice, entry.key, entry.value),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => invoice.items.add(_InvoiceItemDraft())),
                icon: const Icon(Icons.add),
                label: const Text('إضافة بند'),
              ),
            ),
            const Divider(),
            Text('الإجمالي قبل الضريبة: ${subtotal.toStringAsFixed(2)}'),
            Text('الضريبة 15%: ${tax.toStringAsFixed(2)}'),
            Text('الإجمالي: ${total.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(
    _InvoiceDraft invoice,
    int index,
    _InvoiceItemDraft item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.description,
              decoration: const InputDecoration(labelText: 'الوصف'),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'مطلوب';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: item.quantity,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'مطلوب';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: item.unitPrice,
              decoration: const InputDecoration(labelText: 'السعر'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'مطلوب';
                }
                return null;
              },
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                final removed = invoice.items.removeAt(index);
                removed.dispose();
              });
            },
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    final provider = context.watch<StationMaintenanceProvider>();
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مراجعة الإدارة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _decision,
              decoration: const InputDecoration(labelText: 'القرار'),
              items: const [
                DropdownMenuItem(value: 'approved', child: Text('قبول')),
                DropdownMenuItem(value: 'rejected', child: Text('رفض')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _decision = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reviewNotesController,
              decoration: const InputDecoration(labelText: 'ملاحظات الإدارة'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Text('تقييم الإدارة: ${_ratingScore.toStringAsFixed(0)} / 5'),
            Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: _ratingScore,
              label: _ratingScore.toStringAsFixed(0),
              onChanged: (value) => setState(() => _ratingScore = value),
            ),
            TextFormField(
              controller: _ratingNoteController,
              decoration: const InputDecoration(labelText: 'ملاحظة التقييم'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : _submitReview,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(provider.isLoading ? 'جارٍ الحفظ...' : 'حفظ القرار'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSummary(StationMaintenanceRequest request) {
    final review = request.review;
    final rating = request.rating;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نتيجة المراجعة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (review != null) ...[
              Text('القرار: ${review.decision == 'approved' ? 'مقبول' : 'مرفوض'}'),
              if (review.notes != null && review.notes!.isNotEmpty)
                Text('ملاحظات: ${review.notes}'),
              if (review.reviewedByName != null)
                Text('تم بواسطة: ${review.reviewedByName}'),
            ],
            if (rating != null) ...[
              const SizedBox(height: 8),
              Text('التقييم: ${rating.score.toStringAsFixed(1)} / 5'),
              if (rating.note != null && rating.note!.isNotEmpty)
                Text('ملاحظة: ${rating.note}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments(StationMaintenanceRequest request) {
    final before = request.beforePhotos;
    final after = request.afterPhotos;
    final videos = request.videos;
    final invoices = request.invoiceFiles;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المرفقات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (before.isEmpty &&
                after.isEmpty &&
                videos.isEmpty &&
                invoices.isEmpty)
              Text(
                'لا توجد مرفقات بعد',
                style: TextStyle(color: AppColors.mediumGray),
              ),
            if (before.isNotEmpty) ...[
              const Text('صور قبل العمل',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _imageGrid(before),
              const SizedBox(height: 12),
            ],
            if (after.isNotEmpty) ...[
              const Text('صور بعد العمل',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _imageGrid(after),
              const SizedBox(height: 12),
            ],
            if (videos.isNotEmpty) ...[
              const Text('الفيديوهات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _videoList(videos),
              const SizedBox(height: 12),
            ],
            if (invoices.isNotEmpty) ...[
              const Text('ملفات الفواتير',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _attachmentList(invoices, icon: Icons.receipt_long),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imageGrid(List<StationMaintenanceAttachment> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 3;
        if (width >= 1200) {
          columns = 6;
        } else if (width >= 900) {
          columns = 5;
        } else if (width >= 700) {
          columns = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final attachment = images[index];
            final url = _resolveFileUrl(attachment.path);
            return InkWell(
              onTap: () => _openAttachment(url),
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.backgroundGray,
                      child:
                          const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.backgroundGray,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: AppColors.mediumGray,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'تعذر التحميل',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _attachmentList(
    List<StationMaintenanceAttachment> attachments, {
    required IconData icon,
  }) {
    return Column(
      children: attachments.map((attachment) {
        final url = _resolveFileUrl(attachment.path);
        final name = attachment.filename.isNotEmpty
            ? attachment.filename
            : 'ملف';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.primaryBlue),
          title: Text(name),
          subtitle: Text(url),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openAttachment(url),
          ),
        );
      }).toList(),
    );
  }

  Widget _videoList(List<StationMaintenanceAttachment> videos) {
    return Column(
      children: videos.map((attachment) {
        final url = _resolveFileUrl(attachment.path);
        final name = attachment.filename.isNotEmpty
            ? attachment.filename
            : 'فيديو';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _InlineVideoPlayer(url: url, title: name),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Duration _calculateElapsed(StationMaintenanceRequest request) {
    final start = request.openedAt ?? request.assignedAt ?? request.createdAt;
    if (start == null) return Duration.zero;
    final end = request.closedAt ?? _now;
    return end.difference(start);
  }

  String _formatElapsed(Duration duration) {
    if (duration.isNegative) return '0 ثانية';
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0 || days > 0) parts.add('$hours ساعة');
    if (minutes > 0 || hours > 0 || days > 0) parts.add('$minutes دقيقة');
    parts.add('$seconds ثانية');
    return parts.join(' ');
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'مسند';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'under_review':
        return 'تحت المراجعة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'closed':
        return 'مغلق';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blueGrey;
      case 'in_progress':
        return Colors.orange;
      case 'under_review':
        return Colors.amber;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'closed':
        return Colors.grey;
      default:
        return AppColors.mediumGray;
    }
  }

  String _typeLabel(String type) {
    if (type == 'development') {
      return 'تطوير محطة';
    }
    if (type == 'other') {
      return 'أخرى';
    }
    return 'صيانة محطة';
  }

  double _toDouble(String value) {
    final sanitized = value.replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 0;
  }

  String _resolveFileUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/uploads')) {
      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/+$'), '');
      return '$base$path';
    }
    return '${ApiEndpoints.baseUrl}$path';
  }

  String? _buildMapUrl(StationMaintenanceRequest request) {
    final location = request.stationLocation;
    final googleUrl = location?.googleMapsUrl;
    if (googleUrl != null && googleUrl.trim().isNotEmpty) {
      return googleUrl.trim();
    }
    final lat = location?.lat;
    final lng = location?.lng;
    if (lat == null || lng == null) return null;
    return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
  }

  Future<void> _launchMap(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      _showSnack('تعذر فتح خرائط Google', isError: true);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      _showSnack('تعذر فتح المرفق', isError: true);
    }
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  final String title;

  const _InlineVideoPlayer({
    required this.url,
    required this.title,
  });

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _isReady ? _controller.value.aspectRatio : 16 / 9;
    final maxWidth = MediaQuery.of(context).size.width >= 900 ? 420.0 : 320.0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: maxWidth,
              child: GestureDetector(
                onTap: _isReady ? _openFullScreen : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isReady)
                          VideoPlayer(_controller)
                        else
                          Container(
                            color: AppColors.backgroundGray,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        IconButton(
                          iconSize: 36,
                          color: Colors.white,
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                          ),
                          onPressed: _isReady
                              ? () {
                                  setState(() {
                                    if (_controller.value.isPlaying) {
                                      _controller.pause();
                                    } else {
                                      _controller.play();
                                    }
                                  });
                                }
                              : null,
                        ),
                      ],
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

  Future<void> _openFullScreen() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
      if (mounted) setState(() {});
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenVideoPlayer(
          url: widget.url,
          title: widget.title,
        ),
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final String url;
  final String title;

  const _FullScreenVideoPlayer({
    required this.url,
    required this.title,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isReady = true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _isReady ? _controller.value.aspectRatio : 16 / 9;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isReady)
                VideoPlayer(_controller)
              else
                const Center(child: CircularProgressIndicator()),
              IconButton(
                iconSize: 64,
                color: Colors.white,
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: _isReady
                    ? () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceDraft {
  final TextEditingController invoiceNumber = TextEditingController();
  final TextEditingController vendorName = TextEditingController();
  final TextEditingController notes = TextEditingController();
  final List<_InvoiceItemDraft> items = [_InvoiceItemDraft()];
  PlatformFile? attachment;

  void dispose() {
    invoiceNumber.dispose();
    vendorName.dispose();
    notes.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

class _InvoiceItemDraft {
  final TextEditingController description = TextEditingController();
  final TextEditingController quantity = TextEditingController();
  final TextEditingController unitPrice = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
