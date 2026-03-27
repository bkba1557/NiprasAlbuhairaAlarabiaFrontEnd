// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'package:order_tracker/screens/tasks/task_form_screen.dart';
import 'package:order_tracker/screens/tasks/task_route_screen.dart';
import 'package:order_tracker/screens/tasks/task_tracking_map_screen.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
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

enum _TaskOwnerMenuAction { edit, status, delete }

class _TaskStatusChangeRequest {
  final String status;
  final String reason;

  const _TaskStatusChangeRequest(this.status, this.reason);
}

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
  Timer? _deadlineTicker;
  List<TaskTrackingPoint> _trackingPoints = [];
  Timer? _chatTimer;
  bool _loadingMessages = true;
  bool _sendingMessage = false;
  bool _markingRead = false;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _reportSummaryController =
      TextEditingController();
  final TextEditingController _reportNotesController = TextEditingController();
  bool _savingReport = false;
  final ScrollController _chatScrollController = ScrollController();
  List<TaskMessage> _messages = [];
  bool _participantsSaving = false;
  bool _deletingTask = false;
  bool _updatingStatus = false;

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
    _deadlineTicker?.cancel();
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
    _syncTaskUiState();
    await _loadMessages();
  }

  void _syncTaskUiState() {
    _setupTrackingTimers();
    _setupChatTimer();
    _setupDeadlineTicker();
  }

  void _applyTaskUpdate(TaskModel updated) {
    if (!mounted) return;
    setState(() => _task = updated);
    _syncTaskUiState();
  }

  Future<void> _handleOwnerMenuAction(_TaskOwnerMenuAction action) async {
    switch (action) {
      case _TaskOwnerMenuAction.edit:
        await _openEditTask();
        break;
      case _TaskOwnerMenuAction.status:
        await _openStatusSheet();
        break;
      case _TaskOwnerMenuAction.delete:
        await _confirmDeleteTask();
        break;
    }
  }

  Future<void> _openEditTask() async {
    final task = _task;
    if (task == null) return;

    final updated = await Navigator.push<TaskModel?>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );

    if (!mounted) return;
    if (updated != null) {
      _applyTaskUpdate(updated);
    } else {
      await _loadTask();
    }
  }

  Future<void> _openStatusSheet() async {
    final task = _task;
    if (task == null || _updatingStatus) return;

    final statuses = <String>[
      'assigned',
      'accepted',
      'in_progress',
      'completed',
      'approved',
      'rejected',
      'overdue',
    ];

    String selected = task.status;
    final reasonController = TextEditingController();

    try {
      final request = await showModalBottomSheet<_TaskStatusChangeRequest>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final needsReason = selected == 'rejected';
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'تغيير حالة المهمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: statuses.contains(selected)
                            ? selected
                            : statuses.first,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'الحالة',
                        ),
                        items: statuses
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(_statusLabel(status)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => selected = value);
                        },
                      ),
                      if (needsReason) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'سبب الرفض',
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                if (selected == 'rejected' &&
                                    reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('أدخل سبب الرفض'),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(
                                  context,
                                  _TaskStatusChangeRequest(
                                    selected,
                                    reasonController.text.trim(),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('تحديث'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (request == null) return;
      if (request.status == task.status) return;

      setState(() => _updatingStatus = true);
      final provider = context.read<TaskProvider>();
      final updated = await provider.setTaskStatus(
        task.id,
        status: request.status,
        reason: request.reason,
      );
      if (!mounted) return;
      setState(() => _updatingStatus = false);

      if (updated != null) {
        _applyTaskUpdate(updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث حالة المهمة')),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _confirmDeleteTask() async {
    final task = _task;
    if (task == null || _deletingTask) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: const Text('هل أنت متأكد من حذف المهمة؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingTask = true);
    final provider = context.read<TaskProvider>();
    final ok = await provider.deleteTask(task.id);
    if (!mounted) return;
    setState(() => _deletingTask = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف المهمة')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _setupTrackingTimers() {
    _trackingTimer?.cancel();
    _refreshTimer?.cancel();
    if (_task == null) return;

    final auth = context.read<AuthProvider>();
    final canViewAllTasks =
        auth.user?.hasPermission('tasks_view_all') ?? false;
    final isPrimaryAssignee = _task!.assignedTo == auth.user?.id;

    if (canViewAllTasks && _task!.trackingConsent) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _loadTrackingPoints();
      });
      _loadTrackingPoints();
    }

    if (isPrimaryAssignee &&
        _task!.trackingConsent &&
        (_task!.status == 'accepted' || _task!.status == 'in_progress')) {
      _trackingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _sendLocationPoint();
      });
    }
  }

  void _setupDeadlineTicker() {
    _deadlineTicker?.cancel();
    final task = _task;
    if (task == null || task.dueDate == null || task.isDone) return;
    _deadlineTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool _isTaskWorker(String? userId) {
    final task = _task;
    final normalizedUserId = userId?.trim() ?? '';
    if (task == null || normalizedUserId.isEmpty) return false;
    if (task.assignedTo == normalizedUserId) return true;
    return task.participants.any((participant) {
      return participant.userId == normalizedUserId;
    });
  }

  bool _isTaskOverdue(TaskModel task) {
    return task.status == 'overdue' || task.isDeadlineExpired;
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
    final query = StringBuffer('/users?limit=0');
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
                      : () => Navigator.pop(context, selected.values.toList()),
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
    setState(() => _participantsSaving = false);
    if (updated != null) {
      _applyTaskUpdate(updated);
    }
  }

  Future<void> _removeParticipant(String userId) async {
    if (_task == null || _participantsSaving) return;
    setState(() => _participantsSaving = true);
    final provider = context.read<TaskProvider>();
    final updated = await provider.removeTaskParticipant(_task!.id, userId);
    if (!mounted) return;
    setState(() => _participantsSaving = false);
    if (updated != null) {
      _applyTaskUpdate(updated);
    }
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

  Future<void> _pickAndSendChatFiles(
    FileType type, {
    String? messageType,
  }) async {
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
    setState(() => _savingReport = false);
    if (updated != null) {
      _applyTaskUpdate(updated);
    }
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
      _applyTaskUpdate(updated);
    }
  }

  Future<void> _startTask() async {
    final provider = context.read<TaskProvider>();
    final updated = await provider.startTask(widget.taskId);
    if (updated != null) {
      _applyTaskUpdate(updated);
    }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء'),
          ),
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
    if (updated != null) {
      _applyTaskUpdate(updated);
    }
  }

  Future<void> _approveTask() async {
    final provider = context.read<TaskProvider>();
    final updated = await provider.approveTask(widget.taskId);
    if (updated != null) {
      _applyTaskUpdate(updated);
    }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (result != true) return;
    final provider = context.read<TaskProvider>();
    final updated = await provider.rejectTask(
      widget.taskId,
      reasonController.text.trim(),
    );
    if (updated != null) {
      _applyTaskUpdate(updated);
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
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تصدير PDF: $e')));
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
                  pw.Text(
                    'رقم المهمة: ${task.taskCode}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'الحالة: $status',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'تاريخ الإصدار: $date',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
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
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
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
    final summary = task.report?.summary.trim().isNotEmpty == true
        ? task.report!.summary
        : '-';
    final notes = task.report?.completedNotes?.trim().isNotEmpty == true
        ? task.report!.completedNotes!
        : '-';

    final rows = <Map<String, String>>[
      {'label': 'عنوان المهمة', 'value': task.title},
      {'label': 'رقم المهمة', 'value': task.taskCode},
      {
        'label': 'القسم',
        'value': task.department.isEmpty ? '-' : task.department,
      },
      {'label': 'الحالة', 'value': _statusLabel(task.status)},
      {'label': 'الموظف', 'value': task.assignedToName},
      if (task.description.isNotEmpty)
        {'label': 'وصف المهمة', 'value': task.description},
      {'label': 'الموقع', 'value': locationText},
      if (task.assignedAt != null)
        {'label': 'تاريخ الإسناد', 'value': _formatDate(task.assignedAt)},
      if (task.acceptedAt != null)
        {'label': 'تاريخ الاستلام', 'value': _formatDate(task.acceptedAt)},
      if (task.startedAt != null)
        {'label': 'تاريخ البدء', 'value': _formatDate(task.startedAt)},
      if (task.dueDate != null)
        {'label': 'تاريخ الاستحقاق', 'value': _formatDate(task.dueDate)},
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
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  row['value']?.isNotEmpty == true ? row['value']! : '-',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                alignment: pw.Alignment.centerRight,
                color: PdfColors.grey200,
                child: pw.Text(
                  row['label'] ?? '',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
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

  String _formatCountdown(Duration duration) {
    final absolute = duration.isNegative ? duration.abs() : duration;
    final days = absolute.inDays;
    final hours = absolute.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = absolute.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = absolute.inSeconds.remainder(60).toString().padLeft(2, '0');
    return days > 0
        ? '$days يوم $hours:$minutes:$seconds'
        : '$hours:$minutes:$seconds';
  }

  String _formatDurationSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0 ثانية';
    return _formatCountdown(Duration(seconds: totalSeconds));
  }

  void _showSnackBarMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _surfaceFieldDecoration({
    required String label,
    String? hintText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.appBarWaterBright.withValues(alpha: 0.10),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.appBarWaterBright,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationTextField(
    TextEditingController controller,
    String label,
  ) {
    return SizedBox(
      width: 82,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<_TaskDurationActionResult?> _showDurationDialog({
    required String title,
    required String confirmLabel,
    String reasonLabel = 'السبب',
    String? helperText,
    bool requireReason = false,
  }) async {
    final daysController = TextEditingController(text: '0');
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '0');
    final secondsController = TextEditingController(text: '0');
    final reasonController = TextEditingController();

    try {
      return await showDialog<_TaskDurationActionResult>(
        context: context,
        builder: (context) {
          String? errorText;

          int parseValue(TextEditingController controller) {
            final parsed = int.tryParse(controller.text.trim()) ?? 0;
            return parsed < 0 ? 0 : parsed;
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (helperText != null && helperText.isNotEmpty) ...[
                        Text(
                          helperText,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildDurationTextField(daysController, 'أيام'),
                          _buildDurationTextField(hoursController, 'ساعات'),
                          _buildDurationTextField(minutesController, 'دقائق'),
                          _buildDurationTextField(secondsController, 'ثواني'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(labelText: reasonLabel),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
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
                      final days = parseValue(daysController);
                      final hours = parseValue(hoursController);
                      final minutes = parseValue(minutesController);
                      final seconds = parseValue(secondsController);
                      final totalSeconds =
                          (days * 24 * 60 * 60) +
                          (hours * 60 * 60) +
                          (minutes * 60) +
                          seconds;
                      final reason = reasonController.text.trim();

                      if (totalSeconds <= 0) {
                        setDialogState(() {
                          errorText =
                              'حدد مدة صالحة بالأيام أو الساعات أو الدقائق أو الثواني';
                        });
                        return;
                      }
                      if (requireReason && reason.isEmpty) {
                        setDialogState(() {
                          errorText = 'سبب الإجراء مطلوب';
                        });
                        return;
                      }

                      Navigator.pop(
                        context,
                        _TaskDurationActionResult(
                          days: days,
                          hours: hours,
                          minutes: minutes,
                          seconds: seconds,
                          reason: reason,
                        ),
                      );
                    },
                    child: Text(confirmLabel),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      daysController.dispose();
      hoursController.dispose();
      minutesController.dispose();
      secondsController.dispose();
      reasonController.dispose();
    }
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String label,
    required String confirmLabel,
    bool allowEmpty = true,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (context) {
          String? errorText;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: label,
                        errorText: errorText,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (!allowEmpty && value.isEmpty) {
                        setDialogState(() {
                          errorText = 'هذا الحقل مطلوب';
                        });
                        return;
                      }
                      Navigator.pop(context, value);
                    },
                    child: Text(confirmLabel),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<_TaskPenaltyActionResult?> _showPenaltyDialog() async {
    final task = _task;
    if (task == null) return null;

    final amountController = TextEditingController(
      text: task.overduePenalty?.amount.toStringAsFixed(2) ?? '',
    );
    final notesController = TextEditingController(
      text: task.overduePenalty?.notes ?? '',
    );

    try {
      return await showDialog<_TaskPenaltyActionResult>(
        context: context,
        builder: (context) {
          String? errorText;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('اعتماد استقطاع'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'مبلغ الاستقطاع بالريال السعودي',
                          suffixText: 'SAR',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات السند',
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
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
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0) {
                        setDialogState(() {
                          errorText = 'أدخل مبلغًا صحيحًا أكبر من صفر';
                        });
                        return;
                      }
                      Navigator.pop(
                        context,
                        _TaskPenaltyActionResult(
                          amount: amount,
                          notes: notesController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('اعتماد الاستقطاع'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      amountController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _requestExtension() async {
    final task = _task;
    if (task == null) return;
    final input = await _showDurationDialog(
      title: 'طلب تمديد المهمة',
      confirmLabel: 'إرسال الطلب',
      reasonLabel: 'سبب طلب التمديد',
      helperText: 'حدد المدة المطلوبة ثم أرسل الطلب إلى المالك للموافقة.',
      requireReason: true,
    );
    if (input == null) return;

    final updated = await context.read<TaskProvider>().requestTaskExtension(
      task.id,
      days: input.days,
      hours: input.hours,
      minutes: input.minutes,
      seconds: input.seconds,
      reason: input.reason,
    );

    if (updated == null) {
      _showSnackBarMessage('تعذر إرسال طلب التمديد');
      return;
    }

    _applyTaskUpdate(updated);
    _showSnackBarMessage('تم إرسال طلب التمديد');
  }

  Future<void> _extendDeadlineDirectly() async {
    final task = _task;
    if (task == null) return;
    final input = await _showDurationDialog(
      title: 'تمديد مهلة المهمة',
      confirmLabel: 'تمديد',
      reasonLabel: 'سبب التمديد',
      helperText:
          'سيتم إضافة المدة الجديدة على المهلة الحالية أو من وقت الانتهاء.',
    );
    if (input == null) return;

    final updated = await context.read<TaskProvider>().extendTaskDeadline(
      task.id,
      days: input.days,
      hours: input.hours,
      minutes: input.minutes,
      seconds: input.seconds,
      reason: input.reason,
    );

    if (updated == null) {
      _showSnackBarMessage('تعذر تمديد مهلة المهمة');
      return;
    }

    _applyTaskUpdate(updated);
    _showSnackBarMessage('تم تمديد مهلة المهمة');
  }

  Future<void> _approveExtensionRequest() async {
    final reason = await _showReasonDialog(
      title: 'اعتماد طلب التمديد',
      label: 'ملاحظة الاعتماد',
      confirmLabel: 'اعتماد',
    );
    if (reason == null) return;

    final updated = await context
        .read<TaskProvider>()
        .approveTaskExtensionRequest(widget.taskId, reason: reason);

    if (updated == null) {
      _showSnackBarMessage('تعذر اعتماد طلب التمديد');
      return;
    }

    _applyTaskUpdate(updated);
    _showSnackBarMessage('تم اعتماد طلب التمديد');
  }

  Future<void> _rejectExtensionRequest() async {
    final reason = await _showReasonDialog(
      title: 'رفض طلب التمديد',
      label: 'سبب الرفض',
      confirmLabel: 'رفض',
      allowEmpty: false,
    );
    if (reason == null) return;

    final updated = await context
        .read<TaskProvider>()
        .rejectTaskExtensionRequest(widget.taskId, reason);

    if (updated == null) {
      _showSnackBarMessage('تعذر رفض طلب التمديد');
      return;
    }

    _applyTaskUpdate(updated);
    _showSnackBarMessage('تم رفض طلب التمديد');
  }

  Future<void> _applyPenalty() async {
    final task = _task;
    if (task == null) return;
    final input = await _showPenaltyDialog();
    if (input == null) return;

    final updated = await context.read<TaskProvider>().applyTaskPenalty(
      task.id,
      amount: input.amount,
      notes: input.notes,
    );

    if (updated == null) {
      _showSnackBarMessage('تعذر اعتماد الاستقطاع');
      return;
    }

    _applyTaskUpdate(updated);
    _showSnackBarMessage('تم إنشاء سند الاستقطاع وإرسال الإشعارات');
  }

  Future<void> _openPenaltyVoucher() async {
    final voucherPath = _task?.overduePenalty?.voucherPath ?? '';
    if (voucherPath.isEmpty) return;
    final url = _resolveFileUrl(voucherPath);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBarMessage('تعذر فتح سند الاستقطاع');
    }
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
              _recordingFileName ??
              'task-audio-${DateTime.now().millisecondsSinceEpoch}.webm';
          await provider.uploadTaskMessageAttachmentsBytes(
            widget.taskId,
            [bytes],
            [fileName],
            messageType: 'audio',
          );
        } else {
          await provider.uploadTaskMessageAttachments(widget.taskId, [
            path,
          ], messageType: 'audio');
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

    await _recorder.start(recordSettings.config, path: filePath);
    if (mounted) setState(() => _isRecording = true);
  }

  Future<_RecordSettings> _buildRecordSettings() async {
    var encoder = AudioEncoder.aacLc;
    var extension = 'm4a';

    if (kIsWeb) {
      final aacSupported = await _recorder.isEncoderSupported(
        AudioEncoder.aacLc,
      );
      if (!aacSupported) {
        final opusSupported = await _recorder.isEncoderSupported(
          AudioEncoder.opus,
        );
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
      RecordConfig(encoder: encoder, bitRate: 128000, sampleRate: 44100),
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
    final canViewAllTasks =
        auth.user?.hasPermission('tasks_view_all') ?? false;
    final canApproveTask =
        auth.user?.hasPermission('tasks_approve') ?? false;
    final canExtendTask =
        auth.user?.hasPermission('tasks_extend') ?? false;
    final canApplyTaskPenalty =
        auth.user?.hasPermission('tasks_penalty') ?? false;
    final canManageParticipants =
        auth.user?.hasPermission('tasks_manage_participants') ?? false;
    final canEditTask = auth.user?.hasPermission('tasks_edit') ?? false;
    final isOwnerRole = (auth.user?.role ?? '').trim().toLowerCase() == 'owner';
    final currentUserId = auth.user?.id;
    final isWorker = _isTaskWorker(currentUserId);
    final isPrimaryAssignee = _task?.assignedTo == currentUserId;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('تفاصيل المهمة'),
        flexibleSpace: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
        actions: [
          if (_task != null && (canEditTask || isOwnerRole))
            PopupMenuButton<_TaskOwnerMenuAction>(
              enabled: !_deletingTask && !_updatingStatus,
              tooltip: 'خيارات المالك',
              onSelected: _handleOwnerMenuAction,
              itemBuilder: (context) => [
                if (canEditTask)
                  const PopupMenuItem(
                    value: _TaskOwnerMenuAction.edit,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('تعديل المهمة'),
                    ),
                  ),
                if (isOwnerRole)
                  const PopupMenuItem(
                    value: _TaskOwnerMenuAction.status,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.sync_alt_rounded),
                      title: Text('تغيير الحالة'),
                    ),
                  ),
                if (isOwnerRole) const PopupMenuDivider(),
                if (isOwnerRole)
                  PopupMenuItem(
                    value: _TaskOwnerMenuAction.delete,
                    child: const ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        'حذف المهمة',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
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
        if (isOpen) {
          _markMessagesRead();
        }
      },
      body: Stack(
        children: [
          const AppSoftBackground(),
          if (_loading)
            const Center(
              child: AppSurfaceCard(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text(
                      'جارٍ تحميل تفاصيل المهمة...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_task == null)
            const Center(
              child: AppSurfaceCard(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Text(
                  'لا توجد مهمة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            )
          else
            _buildDetailsView(
              canViewAllTasks,
              isWorker,
              isPrimaryAssignee,
              canApproveTask: canApproveTask,
              canExtendTask: canExtendTask,
              canApplyTaskPenalty: canApplyTaskPenalty,
              canManageParticipants: canManageParticipants,
              canEditTask: canEditTask,
              isOwnerRole: isOwnerRole,
            ),
        ],
      ),
    );
  }

  Widget _buildChatDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.85;
    return Drawer(
      width: drawerWidth > 360 ? 360 : drawerWidth,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFF), Color(0xFFF1F5FF), Color(0xFFF6FAFE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  gradient: AppColors.appBarGradient,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'محادثة المهمة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildChatMessages()),
              _buildChatComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsView(
    bool canViewAllTasks,
    bool isWorker,
    bool isPrimaryAssignee, {
    required bool canApproveTask,
    required bool canExtendTask,
    required bool canApplyTaskPenalty,
    required bool canManageParticipants,
    required bool canEditTask,
    required bool isOwnerRole,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > 1240
            ? 1240.0
            : constraints.maxWidth;
        final horizontalPadding = constraints.maxWidth > 900 ? 24.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                120,
              ),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildDeadlineCard(
                  canExtendTask: canExtendTask,
                  canApproveTask: canApproveTask,
                  canApplyTaskPenalty: canApplyTaskPenalty,
                  isWorker: isWorker,
                ),
                const SizedBox(height: 16),
                _buildParticipantsCard(canManageParticipants),
                const SizedBox(height: 16),
                AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'المحادثة الخاصة بالمهمة متاحة من الزر الجانبي ويمكن فتحها من هنا أيضًا.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('فتح المحادثة'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTaskAttachmentsCard(),
                const SizedBox(height: 16),
                _buildTaskReportCard(),
                if (_task!.report?.pdfPath.isNotEmpty == true)
                  const SizedBox(height: 16),
                AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _exportTaskPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('تصدير PDF (عربي)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isWorker) _buildEmployeeActions(),
                _buildOwnerActions(
                  canApproveTask: canApproveTask,
                  canEditTask: canEditTask,
                  isOwnerRole: isOwnerRole,
                ),
                const SizedBox(height: 16),
                _buildTrackingSection(canViewAllTasks, isPrimaryAssignee),
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
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(12),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _pickAndSendChatFiles(
                      FileType.image,
                      messageType: 'image',
                    ),
                    icon: const Icon(Icons.image),
                    tooltip: 'صورة',
                  ),
                  IconButton(
                    onPressed: () => _pickAndSendChatFiles(
                      FileType.video,
                      messageType: 'video',
                    ),
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
                      decoration: _surfaceFieldDecoration(
                        label: 'رسالة',
                        hintText: 'اكتب رسالة...',
                        icon: Icons.chat_bubble_outline,
                      ),
                      onSubmitted: (_) => _sendTextMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sendingMessage ? null : _sendTextMessage,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(54, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _sendingMessage
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
      ),
    );
  }

  Widget _buildMessageBubble(TaskMessage message, bool isMe) {
    final bubbleColor = isMe
        ? AppColors.primaryBlue.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: (isMe ? AppColors.primaryBlue : Colors.black).withValues(
                alpha: isMe ? 0.10 : 0.05,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe && (message.senderName?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
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
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'مرفقات المهمة',
            'إدارة الصور والفيديوهات والملفات المرتبطة بسير تنفيذ المهمة.',
            Icons.attach_file_rounded,
            const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildTaskAttachmentItem(TaskAttachment attachment) {
    final fileName = attachment.filename;
    final uploadedAt = attachment.uploadedAt != null
        ? DateFormat(
            'yyyy/MM/dd HH:mm',
          ).format(attachment.uploadedAt!.toLocal())
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
    if (type.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg')) {
      return Icons.image;
    }
    if (type.startsWith('video/') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov')) {
      return Icons.videocam;
    }
    if (type.startsWith('audio/') ||
        name.endsWith('.m4a') ||
        name.endsWith('.mp3')) {
      return Icons.audiotrack;
    }
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }

  Widget _buildTaskReportCard() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'تقرير التنفيذ',
            'حدّث ملخص التنفيذ والملاحظات النهائية المرتبطة بإغلاق المهمة.',
            Icons.summarize_outlined,
            AppColors.successGreen,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reportSummaryController,
            minLines: 2,
            maxLines: 3,
            decoration: _surfaceFieldDecoration(
              label: 'ملخص التنفيذ',
              icon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reportNotesController,
            minLines: 2,
            maxLines: 4,
            decoration: _surfaceFieldDecoration(
              label: 'ملاحظات إضافية',
              icon: Icons.edit_note_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _savingReport ? null : _saveTaskReport,
              icon: _savingReport
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('حفظ التقرير'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
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
        child: Image.network(url, width: 220, height: 160, fit: BoxFit.cover),
      );
    }

    IconData icon = Icons.insert_drive_file;
    if (messageType == 'audio' || attachment.fileType.startsWith('audio/')) {
      return _AudioMessagePlayer(url: url, fileName: attachment.filename);
    } else if (messageType == 'video' ||
        attachment.fileType.startsWith('video/')) {
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
            child: Text(attachment.filename, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineCard({
    required bool canExtendTask,
    required bool canApproveTask,
    required bool canApplyTaskPenalty,
    required bool isWorker,
  }) {
    final task = _task!;
    final remaining = task.deadlineRemaining;
    final penalty = task.overduePenalty;
    final extensionRequest = task.extensionRequest;
    final isOverdue = _isTaskOverdue(task);
    final isClosed = task.isDone;

    final statusText = task.dueDate == null
        ? 'بدون مهلة'
        : isClosed
        ? 'تم إغلاق المهمة'
        : isOverdue
        ? 'متأخرة منذ ${_formatCountdown(remaining ?? Duration.zero)}'
        : 'متبقي ${_formatCountdown(remaining ?? Duration.zero)}';

    final statusColor = task.dueDate == null
        ? Colors.grey.shade700
        : isClosed
        ? AppColors.successGreen
        : isOverdue
        ? AppColors.errorRed
        : AppColors.primaryBlue;

    final actionButtons = <Widget>[];
    final hasPendingExtension = extensionRequest?.isPending == true;
    final canRequestExtension =
        isWorker && task.hasDeadline && !isClosed && !hasPendingExtension;
    final canDirectExtend = canExtendTask && task.hasDeadline && !isClosed;
    final canApplyPenalty =
        canApplyTaskPenalty &&
        penalty?.enabled == true &&
        isOverdue &&
        !(penalty?.isApplied ?? false);
    final canOpenVoucher = (penalty?.voucherPath ?? '').isNotEmpty;

    if (canRequestExtension) {
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _requestExtension,
          icon: const Icon(Icons.schedule_send_outlined),
          label: const Text('طلب تمديد'),
        ),
      );
    }

    if (canDirectExtend) {
      actionButtons.add(
        ElevatedButton.icon(
          onPressed: _extendDeadlineDirectly,
          icon: const Icon(Icons.timer_outlined),
          label: const Text('تمديد المهلة'),
        ),
      );
    }

    if (canApproveTask && hasPendingExtension) {
      actionButtons.add(
        ElevatedButton.icon(
          onPressed: _approveExtensionRequest,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('اعتماد التمديد'),
        ),
      );
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _rejectExtensionRequest,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('رفض التمديد'),
        ),
      );
    }

    if (canApplyPenalty) {
      actionButtons.add(
        ElevatedButton.icon(
          onPressed: _applyPenalty,
          icon: const Icon(Icons.money_off_csred_outlined),
          label: const Text('اعتماد الاستقطاع'),
        ),
      );
    }

    if (canOpenVoucher) {
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _openPenaltyVoucher,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('فتح سند الاستقطاع'),
        ),
      );
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'المهلة والاستقطاع',
            'تفاصيل العدّ التنازلي، الاستقطاعات المحتملة، وحالة طلبات التمديد.',
            Icons.timer_rounded,
            statusColor,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.16)),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          _buildDeadlineInfoRow(
            icon: Icons.event_available_outlined,
            label: 'آخر موعد',
            value: _formatDate(task.dueDate),
          ),
          if (task.countdownDurationSeconds > 0) ...[
            const SizedBox(height: 8),
            _buildDeadlineInfoRow(
              icon: Icons.timelapse_outlined,
              label: 'المدة الأصلية',
              value: _formatDurationSeconds(task.countdownDurationSeconds),
            ),
          ],
          if (task.overdueNotifiedAt != null) ...[
            const SizedBox(height: 8),
            _buildDeadlineInfoRow(
              icon: Icons.notification_important_outlined,
              label: 'إشعار انتهاء المهلة',
              value: _formatDate(task.overdueNotifiedAt),
            ),
          ],
          if ((task.statusBeforeOverdue ?? '').trim().isNotEmpty &&
              task.status == 'overdue') ...[
            const SizedBox(height: 8),
            _buildDeadlineInfoRow(
              icon: Icons.history_toggle_off,
              label: 'قبل انتهاء المهلة',
              value: _statusLabel(task.statusBeforeOverdue!),
            ),
          ],
          if (penalty != null && penalty.enabled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (penalty.isApplied
                            ? AppColors.errorRed
                            : AppColors.warningOrange)
                        .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (penalty.isApplied
                              ? AppColors.errorRed
                              : AppColors.warningOrange)
                          .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    penalty.isApplied
                        ? 'تم اعتماد الاستقطاع'
                        : 'استقطاع جاهز عند انتهاء المهلة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'القيمة: ${penalty.amount.toStringAsFixed(2)} ${penalty.currency}',
                  ),
                  if (penalty.appliedAt != null)
                    Text('تاريخ الاعتماد: ${_formatDate(penalty.appliedAt)}'),
                  if ((penalty.appliedByName ?? '').trim().isNotEmpty)
                    Text('اعتمد بواسطة: ${penalty.appliedByName}'),
                  if (penalty.voucherNumber.trim().isNotEmpty)
                    Text('رقم السند: ${penalty.voucherNumber}'),
                  if (penalty.notes.trim().isNotEmpty)
                    Text('ملاحظات: ${penalty.notes}'),
                ],
              ),
            ),
          ],
          if (extensionRequest != null && extensionRequest.hasRequest) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (extensionRequest.isRejected
                            ? AppColors.errorRed
                            : extensionRequest.isApproved
                            ? AppColors.successGreen
                            : AppColors.infoBlue)
                        .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (extensionRequest.isRejected
                              ? AppColors.errorRed
                              : extensionRequest.isApproved
                              ? AppColors.successGreen
                              : AppColors.infoBlue)
                          .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    extensionRequest.isPending
                        ? 'طلب تمديد بانتظار المالك'
                        : extensionRequest.isApproved
                        ? 'تم اعتماد التمديد'
                        : 'تم رفض طلب التمديد',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if ((extensionRequest.requestedByName ?? '')
                      .trim()
                      .isNotEmpty)
                    Text('مقدم الطلب: ${extensionRequest.requestedByName}'),
                  if (extensionRequest.requestedAt != null)
                    Text(
                      'تاريخ الطلب: ${_formatDate(extensionRequest.requestedAt)}',
                    ),
                  Text(
                    'المدة المطلوبة: ${_formatDurationSeconds(extensionRequest.requestedSeconds)}',
                  ),
                  if (extensionRequest.requestedReason.trim().isNotEmpty)
                    Text('سبب الطلب: ${extensionRequest.requestedReason}'),
                  if ((extensionRequest.decidedByName ?? '').trim().isNotEmpty)
                    Text('القرار بواسطة: ${extensionRequest.decidedByName}'),
                  if (extensionRequest.decidedAt != null)
                    Text(
                      'تاريخ القرار: ${_formatDate(extensionRequest.decidedAt)}',
                    ),
                  if (extensionRequest.decisionReason.trim().isNotEmpty)
                    Text('ملاحظة القرار: ${extensionRequest.decisionReason}'),
                ],
              ),
            ),
          ],
          if (actionButtons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
          ],
        ],
      ),
    );
  }

  Widget _buildDeadlineInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value.isEmpty ? '-' : value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final task = _task!;
    final workers = task.workerNames;
    final isOverdue = _isTaskOverdue(task);
    final statusColor = isOverdue
        ? AppColors.errorRed
        : task.isDone
        ? AppColors.successGreen
        : AppColors.primaryBlue;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF22C1C3)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInfoPill('رقم ${task.taskCode}'),
                        _buildInfoPill(_statusLabel(task.status)),
                        _buildInfoPill(
                          task.department.isEmpty
                              ? 'بدون قسم'
                              : task.department,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'المكلفون: ${workers.isEmpty ? task.assignedToName : workers.join('، ')}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              task.description,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ],
          if (task.dueDate != null) ...[
            const SizedBox(height: 10),
            Text(
              'الاستحقاق: ${_formatDate(task.dueDate)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (task.location?.latitude != null &&
              task.location?.longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('الاتجاه إلى الموقع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
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
    );
  }

  Widget _buildParticipantsCard(bool canManageParticipants) {
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
    if (task.assignedToName.isNotEmpty && task.assignedTo != task.createdBy) {
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
            participant.name.isNotEmpty ? participant.name : participant.userId,
          ),
          onDeleted: canManageParticipants && !_participantsSaving
              ? () => _removeParticipant(participant.userId)
              : null,
        ),
      );
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'أطراف المهمة',
            'المالك، المسؤول، وباقي المشاركين في التنفيذ أو المتابعة.',
            Icons.group_rounded,
            AppColors.primaryBlue,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              if (_participantsSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (canManageParticipants)
                TextButton.icon(
                  onPressed: _participantsSaving
                      ? null
                      : _openParticipantsDialog,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('إضافة'),
                ),
            ],
          ),
          if (chips.isEmpty)
            const Text('لا يوجد مشاركون حالياً')
          else
            Wrap(spacing: 8, runSpacing: 6, children: chips),
        ],
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
            if (updated != null) {
              _applyTaskUpdate(updated);
            }
          },
          child: const Text('استلام المهمة'),
        ),
      );
    }

    if (task.status == 'accepted' || task.status == 'rejected') {
      actions.add(
        ElevatedButton(onPressed: _startTask, child: const Text('بدء التنفيذ')),
      );
    }

    if (task.status == 'accepted' ||
        task.status == 'in_progress' ||
        task.status == 'rejected') {
      actions.add(
        ElevatedButton(
          onPressed: _completeTask,
          child: const Text('إنهاء المهمة'),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'إجراءات الموظف',
            'الاستلام، بدء التنفيذ، وإنهاء المهمة حسب حالتها الحالية.',
            Icons.engineering_outlined,
            AppColors.primaryBlue,
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  Widget _buildOwnerActions({
    required bool canApproveTask,
    required bool canEditTask,
    required bool isOwnerRole,
  }) {
    final task = _task!;

    final managementActions = <Widget>[];
    if (canEditTask) {
      managementActions.add(
        ElevatedButton.icon(
          onPressed: _openEditTask,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('تعديل'),
        ),
      );
    }

    if (isOwnerRole) {
      managementActions.add(
        OutlinedButton.icon(
          onPressed: _updatingStatus ? null : _openStatusSheet,
          icon: const Icon(Icons.sync_alt_rounded),
          label: const Text('تغيير الحالة'),
        ),
      );
      managementActions.add(
        OutlinedButton.icon(
          onPressed: _deletingTask ? null : _confirmDeleteTask,
          icon: const Icon(Icons.delete_outline),
          label: const Text('حذف'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.errorRed,
            side: BorderSide(
              color: AppColors.errorRed.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    final approvalActions = <Widget>[];
    if (canApproveTask && task.status == 'completed') {
      approvalActions.addAll([
        ElevatedButton(
          onPressed: _approveTask,
          child: const Text('اعتماد'),
        ),
        OutlinedButton(onPressed: _rejectTask, child: const Text('رفض')),
      ]);
    }

    if (managementActions.isEmpty && approvalActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'إجراءات المالك',
            'تعديل المهمة، تغيير الحالة، أو حذف المهمة. تظهر خيارات الاعتماد بعد إغلاق المهمة.',
            Icons.admin_panel_settings_outlined,
            AppColors.primaryBlue,
          ),
          const SizedBox(height: 14),
          if (managementActions.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: managementActions),
          if (approvalActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildSectionTitle(
              'اعتماد المهمة',
              'يمكن اعتماد المهمة أو رفضها بعد مراجعة تقرير التنفيذ والمرفقات.',
              Icons.verified_user_outlined,
              AppColors.successGreen,
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: approvalActions),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingSection(bool canViewAllTasks, bool isAssigned) {
    if (_task == null) return const SizedBox.shrink();

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'التتبع الحي',
            'متابعة موقع المنفذ عند تفعيل التتبع أثناء تنفيذ المهمة.',
            Icons.location_searching_rounded,
            AppColors.infoBlue,
          ),
          const SizedBox(height: 14),
          if (isAssigned)
            SwitchListTile(
              value: _task!.trackingConsent,
              onChanged: _toggleTracking,
              title: const Text('موافقة على التتبع أثناء المهمة'),
              subtitle: const Text('يمكن إيقاف التتبع في أي وقت'),
            ),
          if (canViewAllTasks && _trackingPoints.isNotEmpty) ...[
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
          if (canViewAllTasks && _trackingPoints.isEmpty)
            const Text('لا توجد نقاط تتبع حالياً'),
        ],
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

  const _AudioMessagePlayer({required this.url, required this.fileName});

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
      return Text(_error!, style: const TextStyle(color: Colors.redAccent));
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
                  final isLoading =
                      !_ready ||
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

class _TaskDurationActionResult {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  final String reason;

  const _TaskDurationActionResult({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.reason,
  });
}

class _TaskPenaltyActionResult {
  final double amount;
  final String notes;

  const _TaskPenaltyActionResult({required this.amount, required this.notes});
}
