// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/task_provider.dart';
import 'package:order_tracker/screens/tasks/task_route_screen.dart';
import 'package:order_tracker/screens/tasks/task_tracking_map_screen.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:order_tracker/utils/web_platform.dart' as web_platform;

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskModel? _task;
  bool _loading = true;
  bool _sendingLocation = false;
  bool _isRecording = false;
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingFileName;
  Timer? _trackingTimer;
  Timer? _refreshTimer;
  List<TaskTrackingPoint> _trackingPoints = [];
  Timer? _chatTimer;
  bool _loadingMessages = true;
  bool _sendingMessage = false;
  bool _chatOpen = false;
  bool _markingRead = false;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _reportSummaryController = TextEditingController();
  final TextEditingController _reportNotesController = TextEditingController();
  bool _savingReport = false;
  final ScrollController _chatScrollController = ScrollController();
  List<TaskMessage> _messages = [];
  bool _participantsSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _refreshTimer?.cancel();
    _chatTimer?.cancel();
    _recorder.dispose();
    _messageController.dispose();
    _reportSummaryController.dispose();
    _reportNotesController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    final provider = context.read<TaskProvider>();
    final task = await provider.fetchTaskById(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = task;
      _loading = false;
    });
    if (task != null) {
      if (_reportSummaryController.text.trim().isEmpty &&
          task.report?.summary.trim().isNotEmpty == true) {
        _reportSummaryController.text = task.report!.summary;
      }
      if (_reportNotesController.text.trim().isEmpty &&
          task.report?.completedNotes?.trim().isNotEmpty == true) {
        _reportNotesController.text = task.report!.completedNotes!;
      }
    }
    _setupTrackingTimers();
    _setupChatTimer();
    await _loadMessages();
  }

  void _setupTrackingTimers() {
    _trackingTimer?.cancel();
    _refreshTimer?.cancel();
    if (_task == null) return;

    final auth = context.read<AuthProvider>();
    final isOwner = auth.user?.role == 'owner';
    final isAssigned = _task!.assignedTo == auth.user?.id;

    if (isOwner && _task!.trackingConsent) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _loadTrackingPoints();
      });
      _loadTrackingPoints();
    }

    if (isAssigned &&
        _task!.trackingConsent &&
        (_task!.status == 'accepted' || _task!.status == 'in_progress')) {
      _trackingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _sendLocationPoint();
      });
    }
  }

  void _setupChatTimer() {
    _chatTimer?.cancel();
    if (_task == null) return;
    _chatTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_task == null) return;
    if (!silent) {
      setState(() => _loadingMessages = true);
    }
    final provider = context.read<TaskProvider>();
    final messages = await provider.fetchTaskMessages(_task!.id, limit: 200);
    messages.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loadingMessages = false;
    });
    _scrollToBottom();
  }

  Future<void> _markMessagesRead() async {
    if (_task == null || _markingRead) return;
    _markingRead = true;
    final provider = context.read<TaskProvider>();
    await provider.markTaskMessagesRead(_task!.id);
    _markingRead = false;
    await _loadMessages(silent: true);
  }

  Set<String> _currentChatUserIds() {
    final ids = <String>{};
    final task = _task;
    if (task == null) return ids;
    if (task.createdBy.isNotEmpty) ids.add(task.createdBy);
    if (task.assignedTo.isNotEmpty) ids.add(task.assignedTo);
    for (final participant in task.participants) {
      if (participant.userId.isNotEmpty) {
        ids.add(participant.userId);
      }
    }
    return ids;
  }

  Future<List<User>> _fetchUsersForParticipants(
    String search,
    Set<String> selectedIds,
  ) async {
    final query = StringBuffer('/users?limit=200');
    final trimmed = search.trim();
    if (trimmed.isNotEmpty) {
      query.write('&search=${Uri.encodeQueryComponent(trimmed)}');
    }

    final response = await ApiService.get(query.toString());
    final data = json.decode(utf8.decode(response.bodyBytes));
    final rawUsers = (data['users'] as List<dynamic>? ?? []);
    final excluded = _currentChatUserIds()..addAll(selectedIds);

    return rawUsers
        .whereType<Map<String, dynamic>>()
        .map(User.fromJson)
        .where(
          (user) =>
              user.id.isNotEmpty &&
              !user.isBlocked &&
              !excluded.contains(user.id),
        )
        .toList();
  }

  Future<void> _openParticipantsDialog() async {
    if (_task == null) return;

    final selected = <String, User>{};
    final searchController = TextEditingController();

    final result = await showDialog<List<User>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة مشاركين'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeAheadField<User>(
                      controller: searchController,
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'ابحث عن مستخدم',
                            prefixIcon: Icon(Icons.search),
                          ),
                        );
                      },
                      suggestionsCallback: (pattern) =>
                          _fetchUsersForParticipants(
                        pattern,
                        selected.keys.toSet(),
                      ),
                      itemBuilder: (context, user) {
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                        );
                      },
                      onSelected: (user) {
                        setDialogState(() {
                          selected[user.id] = user;
                          searchController.clear();
                        });
                      },
                      emptyBuilder: (_) => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('لا توجد نتائج'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selected.isEmpty)
                      const Text('اختر مستخدمين لإضافتهم للمحادثة')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: selected.values
                            .map(
                              (user) => Chip(
                                label: Text(user.name),
                                onDeleted: () {
                                  setDialogState(() {
                                    selected.remove(user.id);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            selected.values.toList(),
                          ),
                  child: Text('إضافة (${selected.length})'),
                ),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();

    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    await _addParticipants(result);
  }

  Future<void> _addParticipants(List<User> users) async {
    if (_task == null || _participantsSaving) return;
    setState(() => _participantsSaving = true);
    final provider = context.read<TaskProvider>();
    final updated = await provider.addTaskParticipants(
      _task!.id,
      users.map((user) => user.id).toList(),
    );
    if (!mounted) return;
    setState(() {
      _participantsSaving = false;
      if (updated != null) {
        _task = updated;
      }
    });
  }

  Future<void> _removeParticipant(String userId) async {
    if (_task == null || _participantsSaving) return;
    setState(() => _participantsSaving = true);
    final provider = context.read<TaskProvider>();
    final updated = await provider.removeTaskParticipant(_task!.id, userId);
    if (!mounted) return;
    setState(() {
      _participantsSaving = false;
      if (updated != null) {
        _task = updated;
      }
    });
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      final maxScroll = _chatScrollController.position.maxScrollExtent;
      if (force) {
        _chatScrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }
      final offset = _chatScrollController.offset;
      if (maxScroll - offset < 120) {
        _chatScrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage() async {
    if (_task == null || _sendingMessage) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingMessage = true);
    final provider = context.read<TaskProvider>();
    final message = await provider.sendTaskMessage(_task!.id, text);
    if (!mounted) return;
    if (message != null) {
      setState(() {
        _messages.add(message);
        _messageController.clear();
      });
      _scrollToBottom(force: true);
    }
    setState(() => _sendingMessage = false);
  }

  Future<void> _pickAndSendChatFiles(FileType type, {String? messageType}) async {
    if (_task == null) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
      withData: kIsWeb,
    );
    if (result == null) return;
    await _sendMessageAttachmentsFromPicker(result, messageType: messageType);
  }

  Future<void> _sendMessageAttachmentsFromPicker(
    FilePickerResult result, {
    String? messageType,
  }) async {
    if (_task == null) return;
    final provider = context.read<TaskProvider>();
    var uploaded = false;
    if (kIsWeb) {
      final bytes = <Uint8List>[];
      final names = <String>[];
      for (final file in result.files) {
        if (file.bytes != null) {
          bytes.add(file.bytes!);
          names.add(file.name);
        }
      }
      if (bytes.isNotEmpty) {
        uploaded = await provider.uploadTaskMessageAttachmentsBytes(
          _task!.id,
          bytes,
          names,
          messageType: messageType,
        );
      }
    } else {
      final paths = result.paths.whereType<String>().toList();
      if (paths.isNotEmpty) {
        uploaded = await provider.uploadTaskMessageAttachments(
          _task!.id,
          paths,
          messageType: messageType,
        );
      }
    }
    if (uploaded) {
      await _loadMessages();
    }
  }

  Future<void> _pickAndUploadTaskAttachments(
    FileType type, {
    String attachmentType = 'file',
  }) async {
    if (_task == null) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
      withData: kIsWeb,
    );
    if (result == null) return;
    await _uploadTaskAttachmentsFromPicker(
      result,
      attachmentType: attachmentType,
    );
  }

  Future<void> _uploadTaskAttachmentsFromPicker(
    FilePickerResult result, {
    String attachmentType = 'file',
  }) async {
    if (_task == null) return;
    final provider = context.read<TaskProvider>();
    var uploaded = false;
    if (kIsWeb) {
      final bytes = <Uint8List>[];
      final names = <String>[];
      for (final file in result.files) {
        if (file.bytes != null) {
          bytes.add(file.bytes!);
          names.add(file.name);
        }
      }
      if (bytes.isNotEmpty) {
        uploaded = await provider.uploadAttachmentsBytes(
          _task!.id,
          bytes,
          names,
          attachmentType: attachmentType,
        );
      }
    } else {
      final paths = result.paths.whereType<String>().toList();
      if (paths.isNotEmpty) {
        uploaded = await provider.uploadAttachments(
          _task!.id,
          paths,
          attachmentType: attachmentType,
        );
      }
    }
    if (uploaded) {
      await _loadTask();
    }
  }

  Future<void> _saveTaskReport() async {
    if (_task == null || _savingReport) return;
    final summary = _reportSummaryController.text.trim();
    final notes = _reportNotesController.text.trim();
    if (summary.isEmpty && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة ملخص أو ملاحظات')),
      );
      return;
    }

    setState(() => _savingReport = true);
    final provider = context.read<TaskProvider>();
    final updated = await provider.updateTaskReport(
      _task!.id,
      summary: summary.isEmpty ? null : summary,
      notes: notes.isEmpty ? null : notes,
    );
    if (!mounted) return;
    setState(() {
      _savingReport = false;
      if (updated != null) {
        _task = updated;
      }
    });
  }

  Future<void> _loadTrackingPoints() async {
    if (_task == null) return;
    final provider = context.read<TaskProvider>();
    final points = await provider.fetchTrackingPoints(_task!.id, limit: 50);
    if (!mounted) return;
    setState(() => _trackingPoints = points);
  }

  Future<void> _sendLocationPoint() async {
    if (_sendingLocation || _task == null) return;
    setState(() => _sendingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final provider = context.read<TaskProvider>();
      await provider.addTrackingPoint(_task!.id, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } finally {
      if (mounted) setState(() => _sendingLocation = false);
    }
  }

  Future<void> _toggleTracking(bool consent) async {
    if (_task == null) return;
    final provider = context.read<TaskProvider>();
    final updated = await provider.updateTrackingConsent(_task!.id, consent);
    if (!mounted) return;
    if (updated != null) {
      setState(() => _task = updated);
      _setupTrackingTimers();
    }
  }

  Future<void> _startTask() async {
    final provider = context.read<TaskProvider>();
    final updated = await provider.startTask(widget.taskId);
    if (updated != null && mounted) setState(() => _task = updated);
  }

  Future<void> _completeTask() async {
    final summaryController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء المهمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: summaryController,
              decoration: const InputDecoration(labelText: 'ملخص التنفيذ'),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنهاء')),
        ],
      ),
    );

    if (result != true) return;
    final provider = context.read<TaskProvider>();
    final updated = await provider.completeTask(
      widget.taskId,
      summary: summaryController.text.trim(),
      notes: notesController.text.trim(),
    );
    if (updated != null && mounted) setState(() => _task = updated);
  }

  Future<void> _approveTask() async {
    final provider = context.read<TaskProvider>();
    final updated = await provider.approveTask(widget.taskId);
    if (updated != null && mounted) setState(() => _task = updated);
  }

  Future<void> _rejectTask() async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض المهمة'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('رفض')),
        ],
      ),
    );

    if (result != true) return;
    final provider = context.read<TaskProvider>();
    final updated = await provider.rejectTask(widget.taskId, reasonController.text.trim());
    if (updated != null && mounted) setState(() => _task = updated);
  }

  Future<void> _openPdf() async {
    if (_task?.report?.pdfPath == null || _task!.report!.pdfPath.isEmpty) return;
    final pdfPath = _task!.report!.pdfPath;
    final url = _resolveFileUrl(pdfPath);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  Future<void> _exportTaskPdf() async {
    final task = _task;
    if (task == null) return;

    try {
      final arabicFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
      );
      final logoData = await rootBundle.load('assets/images/logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      final now = DateTime.now();

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
            textDirection: pw.TextDirection.rtl,
          ),
          header: (context) => _buildTaskPdfHeader(logoImage, task, now),
          footer: (context) => _buildTaskPdfFooter(context),
          build: (context) => [
            pw.SizedBox(height: 12),
            _buildTaskPdfSummary(task),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          'task_${task.taskCode}_${DateFormat('yyyyMMdd').format(now)}.pdf';
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تصدير PDF: $e')),
        );
      }
    }
  }

  pw.Widget _buildTaskPdfHeader(
    pw.MemoryImage logoImage,
    TaskModel task,
    DateTime generatedAt,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(generatedAt);
    final status = _statusLabel(task.status);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'شركة البحيرة العربية للنقليات',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'الرقم الوطني الموحد: 7011144750',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Divider(color: PdfColors.grey400, height: 1),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'تقرير مهمة',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text('رقم المهمة: ${task.taskCode}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('الحالة: $status',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('تاريخ الإصدار: $date',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              width: 90,
              height: 90,
              alignment: pw.Alignment.center,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTaskPdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.8, color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'البحيرة العربية للنقليات',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTaskPdfSummary(TaskModel task) {
    final location = task.location;
    final locationText = (location?.address?.trim().isNotEmpty ?? false)
        ? location!.address!
        : (location?.latitude != null && location?.longitude != null)
            ? '${location!.latitude}, ${location.longitude}'
            : '-';
    final summary = task.report?.summary?.trim().isNotEmpty == true
        ? task.report!.summary
        : '-';
    final notes = task.report?.completedNotes?.trim().isNotEmpty == true
        ? task.report!.completedNotes!
        : '-';

    final rows = <Map<String, String>>[
      {'label': 'عنوان المهمة', 'value': task.title},
      {'label': 'رقم المهمة', 'value': task.taskCode},
      {'label': 'القسم', 'value': task.department.isEmpty ? '-' : task.department},
      {'label': 'الحالة', 'value': _statusLabel(task.status)},
      {'label': 'الموظف', 'value': task.assignedToName},
      if (task.description.isNotEmpty) {'label': 'وصف المهمة', 'value': task.description},
      {'label': 'الموقع', 'value': locationText},
      if (task.assignedAt != null)
        {'label': 'تاريخ الإسناد', 'value': _formatDate(task.assignedAt)},
      if (task.acceptedAt != null)
        {'label': 'تاريخ الاستلام', 'value': _formatDate(task.acceptedAt)},
      if (task.startedAt != null)
        {'label': 'تاريخ البدء', 'value': _formatDate(task.startedAt)},
      if (task.dueDate != null) {'label': 'تاريخ الاستحقاق', 'value': _formatDate(task.dueDate)},
      if (task.completedAt != null)
        {'label': 'تاريخ الإنهاء', 'value': _formatDate(task.completedAt)},
      {'label': 'ملخص المهمة', 'value': summary},
      {'label': 'ملاحظات التنفيذ', 'value': notes},
      if ((task.report?.completedByName ?? '').trim().isNotEmpty)
        {'label': 'تم التنفيذ بواسطة', 'value': task.report!.completedByName!},
    ];

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1.3),
        },
        children: rows.map((row) {
          return pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  row['value']?.isNotEmpty == true ? row['value']! : '-',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                alignment: pw.Alignment.centerRight,
                color: PdfColors.grey200,
                child: pw.Text(
                  row['label'] ?? '',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(date.toLocal());
  }

  Future<void> _uploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    await _sendMessageAttachmentsFromPicker(result);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        final provider = context.read<TaskProvider>();
        if (kIsWeb) {
          final bytes = await _readWebBytes(path);
          web_platform.revokeObjectUrl(path);
          if (bytes == null || bytes.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('فشل قراءة التسجيل الصوتي')),
            );
            return;
          }
          final fileName =
              _recordingFileName ?? 'task-audio-${DateTime.now().millisecondsSinceEpoch}.webm';
          await provider.uploadTaskMessageAttachmentsBytes(
            widget.taskId,
            [bytes],
            [fileName],
            messageType: 'audio',
          );
        } else {
          await provider.uploadTaskMessageAttachments(
            widget.taskId,
            [path],
            messageType: 'audio',
          );
        }
        await _loadMessages();

      }
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم منح إذن الميكروفون')),
      );
      return;
    }

    final recordSettings = await _buildRecordSettings();
    final fileName =
        'task-audio-${DateTime.now().millisecondsSinceEpoch}.${recordSettings.extension}';
    _recordingFileName = fileName;
    final filePath = kIsWeb
        ? fileName
        : '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}$fileName';

    await _recorder.start(
      recordSettings.config,
      path: filePath,
    );
    if (mounted) setState(() => _isRecording = true);
  }

  Future<_RecordSettings> _buildRecordSettings() async {
    var encoder = AudioEncoder.aacLc;
    var extension = 'm4a';

    if (kIsWeb) {
      final aacSupported = await _recorder.isEncoderSupported(AudioEncoder.aacLc);
      if (!aacSupported) {
        final opusSupported = await _recorder.isEncoderSupported(AudioEncoder.opus);
        if (opusSupported) {
          encoder = AudioEncoder.opus;
          extension = 'webm';
        } else {
          encoder = AudioEncoder.wav;
          extension = 'wav';
        }
      }
    }

    return _RecordSettings(
      RecordConfig(
        encoder: encoder,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      extension,
    );
  }

  Future<Uint8List?> _readWebBytes(String url) async {
    if (!kIsWeb) return null;
    return web_platform.readBytesFromUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.user?.role == 'owner';
    final isAssigned = _task?.assignedTo == auth.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المهمة'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'المحادثة',
            ),
          ),
        ],
      ),
      endDrawer: _buildChatDrawer(),
      onEndDrawerChanged: (isOpen) {
        setState(() => _chatOpen = isOpen);
        if (isOpen) {
          _markMessagesRead();
        }
      },
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? const Center(child: Text('لا توجد مهمة'))
              : _buildDetailsView(isOwner, isAssigned),
    );
  }


  Widget _buildChatDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.85;
    return Drawer(
      width: drawerWidth > 360 ? 360 : drawerWidth,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'محادثة المهمة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildChatMessages()),
            const Divider(height: 1),
            _buildChatComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsView(bool isOwner, bool isAssigned) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            constraints.maxWidth > 1000 ? 1000.0 : constraints.maxWidth;
        final horizontalPadding =
            constraints.maxWidth > 900 ? 24.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24,
              ),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 12),
                _buildParticipantsCard(isOwner),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('فتح المحادثة'),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTaskAttachmentsCard(),
                const SizedBox(height: 12),
                _buildTaskReportCard(),
                const SizedBox(height: 12),
                if (_task!.report?.pdfPath.isNotEmpty == true)
                  // ElevatedButton.icon(
                  //   onPressed: _openPdf,
                  //   icon: const Icon(Icons.picture_as_pdf),
                  //   label: const Text('عرض ملف PDF'),
                  // ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _exportTaskPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('تصدير PDF (عربي)'),
                ),
                const SizedBox(height: 12),
                if (isAssigned) _buildEmployeeActions(),
                if (isOwner) _buildOwnerActions(),
                const SizedBox(height: 12),
                _buildTrackingSection(isOwner, isAssigned),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildChatMessages() {
    if (_loadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('لا توجد رسائل بعد'));
    }

    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id;

    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == myId;
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildChatComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () =>
                      _pickAndSendChatFiles(FileType.image, messageType: 'image'),
                  icon: const Icon(Icons.image),
                  tooltip: 'صورة',
                ),
                IconButton(
                  onPressed: () =>
                      _pickAndSendChatFiles(FileType.video, messageType: 'video'),
                  icon: const Icon(Icons.videocam),
                  tooltip: 'فيديو',
                ),
                IconButton(
                  onPressed: () => _pickAndSendChatFiles(FileType.any),
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'ملف',
                ),
                IconButton(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
                  tooltip: _isRecording ? 'إيقاف التسجيل' : 'تسجيل صوت',
                ),
                if (_isRecording)
                  const Expanded(
                    child: Text(
                      'جاري التسجيل...',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendingMessage ? null : _sendTextMessage,
                  icon: _sendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMessageBubble(TaskMessage message, bool isMe) {
    final bubbleColor = isMe ? Colors.blue.shade50 : Colors.grey.shade200;
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isMe ? 14 : 2),
      bottomRight: Radius.circular(isMe ? 2 : 14),
    );

    final timeLabel = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!.toLocal())
        : '';

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && (message.senderName?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              if (message.text?.trim().isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(message.text!.trim()),
                ),
              if (message.attachment != null) _buildMessageAttachment(message),
              if (timeLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        _buildMessageStatusIcon(message),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskAttachmentsCard() {
    final attachments = _task?.attachments ?? [];
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مرفقات المهمة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickAndUploadTaskAttachments(
                    FileType.image,
                    attachmentType: 'image',
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text('إضافة صور'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickAndUploadTaskAttachments(
                    FileType.video,
                    attachmentType: 'video',
                  ),
                  icon: const Icon(Icons.videocam),
                  label: const Text('إضافة فيديو'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickAndUploadTaskAttachments(
                    FileType.any,
                    attachmentType: 'file',
                  ),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة ملف'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (attachments.isEmpty)
              const Text('لا توجد مرفقات بعد')
            else
              Column(
                children: attachments
                    .map((attachment) => _buildTaskAttachmentItem(attachment))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskAttachmentItem(TaskAttachment attachment) {
    final fileName = attachment.filename;
    final uploadedAt = attachment.uploadedAt != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(attachment.uploadedAt!.toLocal())
        : null;
    final subtitleParts = <String>[];
    if ((attachment.uploadedByName ?? '').trim().isNotEmpty) {
      subtitleParts.add(attachment.uploadedByName!.trim());
    }
    if (uploadedAt != null) {
      subtitleParts.add(uploadedAt);
    }
    final subtitle = subtitleParts.join(' • ');

    return InkWell(
      onTap: () async {
        final url = _resolveFileUrl(attachment.path);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(_attachmentIcon(attachment), color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 16),
          ],
        ),
      ),
    );
  }

  IconData _attachmentIcon(TaskAttachment attachment) {
    final type = attachment.fileType.toLowerCase();
    final name = attachment.filename.toLowerCase();
    if (type.startsWith('image/') || name.endsWith('.png') || name.endsWith('.jpg')) {
      return Icons.image;
    }
    if (type.startsWith('video/') || name.endsWith('.mp4') || name.endsWith('.mov')) {
      return Icons.videocam;
    }
    if (type.startsWith('audio/') || name.endsWith('.m4a') || name.endsWith('.mp3')) {
      return Icons.audiotrack;
    }
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.doc') || name.endsWith('.docx')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Widget _buildTaskReportCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقرير التنفيذ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reportSummaryController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملخص التنفيذ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reportNotesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _savingReport ? null : _saveTaskReport,
                icon: _savingReport
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('حفظ التقرير'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(TaskMessage message) {
    final hasRead = message.readAt != null;
    final hasDelivered = message.deliveredAt != null;

    if (hasRead) {
      return Icon(Icons.done_all, size: 14, color: Colors.blue.shade600);
    }
    if (hasDelivered) {
      return Icon(Icons.done_all, size: 14, color: Colors.grey.shade600);
    }
    return Icon(Icons.check, size: 14, color: Colors.grey.shade600);
  }

  Widget _buildMessageAttachment(TaskMessage message) {
    final attachment = message.attachment;
    if (attachment == null) return const SizedBox.shrink();
    final url = _resolveFileUrl(attachment.path);
    final messageType = message.messageType;

    if (messageType == 'image' || attachment.fileType.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
        ),
      );
    }

    IconData icon = Icons.insert_drive_file;
    if (messageType == 'audio' || attachment.fileType.startsWith('audio/')) {
      return _AudioMessagePlayer(
        url: url,
        fileName: attachment.filename,
      );
    } else if (messageType == 'video' || attachment.fileType.startsWith('video/')) {
      icon = Icons.videocam;
    }

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.filename,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final task = _task!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('رقم المهمة: ${task.taskCode}'),
            Text('الحاله: ${_statusLabel(task.status)}'),
            Text('القسم: ${task.department.isEmpty ? 'غير محدد' : task.department}'),
            Text('الموظف: ${task.assignedToName}'),
            if (task.description.isNotEmpty) Text('الوصف: ${task.description}'),
            if (task.dueDate != null)
              Text('الاستحقاق: ${task.dueDate!.toLocal().toString().split(' ').first}'),
            if (task.location?.latitude != null && task.location?.longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.directions),
                    label: const Text('الاتجاه إلى الموقع'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskRouteScreen(
                            latitude: task.location!.latitude!,
                            longitude: task.location!.longitude!,
                            address: task.location?.address,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(bool isOwner) {
    final task = _task!;
    final chips = <Widget>[];

    Widget roleChip(String name, String roleLabel) {
      return Chip(
        label: Text('$name ($roleLabel)'),
        backgroundColor: Colors.grey.shade200,
      );
    }

    if (task.createdByName.isNotEmpty) {
      chips.add(roleChip(task.createdByName, 'المالك'));
    }
    if (task.assignedToName.isNotEmpty &&
        task.assignedTo != task.createdBy) {
      chips.add(roleChip(task.assignedToName, 'المكلف'));
    }

    for (final participant in task.participants) {
      if (participant.userId == task.createdBy ||
          participant.userId == task.assignedTo) {
        continue;
      }
      chips.add(
        InputChip(
          label: Text(
            participant.name.isNotEmpty
                ? participant.name
                : participant.userId,
          ),
          onDeleted: isOwner && !_participantsSaving
              ? () => _removeParticipant(participant.userId)
              : null,
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'مشاركو المحادثة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_participantsSaving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (isOwner)
                  TextButton.icon(
                    onPressed:
                        _participantsSaving ? null : _openParticipantsDialog,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('إضافة'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (chips.isEmpty)
              const Text('لا يوجد مشاركون حالياً')
            else
              Wrap(spacing: 8, runSpacing: 6, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeActions() {
    final task = _task!;
    final actions = <Widget>[];

    if (task.status == 'assigned') {
      actions.add(
        ElevatedButton(
          onPressed: () async {
            final provider = context.read<TaskProvider>();
            final updated = await provider.acceptTaskByCode(task.taskCode);
            if (updated != null && mounted) setState(() => _task = updated);
          },
          child: const Text('استلام المهمة'),
        ),
      );
    }

    if (task.status == 'accepted' || task.status == 'rejected') {
      actions.add(
        ElevatedButton(
          onPressed: _startTask,
          child: const Text('بدء التنفيذ'),
        ),
      );
    }

    if (task.status == 'accepted' || task.status == 'in_progress' || task.status == 'rejected') {
      actions.add(
        ElevatedButton(
          onPressed: _completeTask,
          child: const Text('إنهاء المهمة'),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إجراءات الموظف', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: actions),
      ],
    );
  }

  Widget _buildOwnerActions() {
    final task = _task!;
    if (task.status != 'completed') return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إجراءات المالك', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: _approveTask,
              child: const Text('اعتماد'),
            ),
            OutlinedButton(
              onPressed: _rejectTask,
              child: const Text('رفض'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackingSection(bool isOwner, bool isAssigned) {
    if (_task == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('التتبع الحي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (isAssigned)
              SwitchListTile(
                value: _task!.trackingConsent,
                onChanged: _toggleTracking,
                title: const Text('موافقة على التتبع أثناء المهمة'),
                subtitle: const Text('يمكن إيقاف التتبع في أي وقت'),
              ),
            if (isOwner && _trackingPoints.isNotEmpty) ...[
              _buildMapPreview(_trackingPoints.first),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('عرض الخريطة كاملة'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskTrackingMapScreen(
                          taskId: _task!.id,
                          initialPoints: _trackingPoints,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (isOwner && _trackingPoints.isEmpty)
              const Text('لا توجد نقاط تتبع حالياً'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(TaskTrackingPoint point) {
    return SizedBox(
      height: 220,
      child: SfMaps(
        layers: [
          MapTileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            initialFocalLatLng: MapLatLng(point.latitude, point.longitude),
            initialZoomLevel: 13,
            initialMarkersCount: 1,
            markerBuilder: (context, index) {
              return MapMarker(
                latitude: point.latitude,
                longitude: point.longitude,
                size: const Size(18, 18),
                child: const Icon(Icons.location_on, color: Colors.red),
              );
            },
            markerTooltipBuilder: (context, index) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(point.userName ?? 'الموظف'),
            ),
          ),
        ],
      ),
    );
  }
  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'تم الإسناد';
      case 'accepted':
        return 'تم الاستلام';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      case 'approved':
        return 'معتمدة';
      case 'rejected':
        return 'مرفوضة';
      case 'overdue':
        return 'متأخرة';
      default:
        return status;
    }
  }
}

class _AudioMessagePlayer extends StatefulWidget {
  final String url;
  final String fileName;

  const _AudioMessagePlayer({
    required this.url,
    required this.fileName,
  });

  @override
  State<_AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<_AudioMessagePlayer> {
  late final AudioPlayer _player;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.url);
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تشغيل الصوت';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(PlayerState state) async {
    final playing = state.playing;
    final processing = state.processingState;
    if (processing == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    if (playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(color: Colors.redAccent),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data ?? _player.playerState;
                  final processing = state.processingState;
                  final playing = state.playing;
                  final isLoading = !_ready ||
                      processing == ProcessingState.loading ||
                      processing == ProcessingState.buffering;

                  return IconButton(
                    iconSize: 28,
                    onPressed: isLoading ? null : () => _togglePlay(state),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow),
                  );
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player.duration ?? Duration.zero;
                    final maxMs = math.max(duration.inMilliseconds, 1);
                    final valueMs = math.min(position.inMilliseconds, maxMs);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Slider(
                          value: valueMs.toDouble(),
                          max: maxMs.toDouble(),
                          min: 0,
                          onChanged: !_ready
                              ? null
                              : (value) async {
                                  await _player.seek(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  
}

class _RecordSettings {
  final RecordConfig config;
  final String extension;

  const _RecordSettings(this.config, this.extension);
}
