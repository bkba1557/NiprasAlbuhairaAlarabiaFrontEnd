import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class TaskProvider with ChangeNotifier {
  final List<TaskModel> _tasks = [];
  final List<TaskModel> _myTasks = [];
  bool _isLoading = false;
  String? _error;

  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  List<TaskModel> get myTasks => List.unmodifiable(_myTasks);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTasks({
    bool mine = false,
    Map<String, dynamic>? filters,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uri =
          Uri.parse(
            '${ApiEndpoints.baseUrl}${mine ? ApiEndpoints.tasksMy : ApiEndpoints.tasks}',
          ).replace(
            queryParameters: filters?.map((k, v) => MapEntry(k, v?.toString())),
          );

      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = (data['tasks'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TaskModel.fromJson)
            .toList();

        if (mine) {
          _myTasks
            ..clear()
            ..addAll(list);
        } else {
          _tasks
            ..clear()
            ..addAll(list);
        }
      } else {
        throw Exception('فشل تحميل المهام');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TaskModel?> createTask(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.tasks}'),
        headers: ApiService.headers,
        body: json.encode(payload),
      );
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final task = TaskModel.fromJson(
          Map<String, dynamic>.from(data['task']),
        );
        _tasks.insert(0, task);
        notifyListeners();
        return task;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  Future<TaskModel?> lookupTaskByCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.taskLookup}'),
        headers: ApiService.headers,
        body: json.encode({'code': code}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
      }
    } catch (_) {}
    return null;
  }

  Future<TaskModel?> fetchTaskById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.taskById(id)}'),
        headers: ApiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
      }
    } catch (_) {}
    return null;
  }

  Future<TaskModel?> acceptTaskByCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.taskAccept}'),
        headers: ApiService.headers,
        body: json.encode({'code': code}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
      }
    } catch (_) {}
    return null;
  }

  Future<TaskModel?> updateTask(String id, Map<String, dynamic> payload) async {
    return _patchTask(ApiEndpoints.taskById(id), body: payload);
  }

  Future<TaskModel?> setTaskStatus(
    String id, {
    required String status,
    String? reason,
  }) async {
    return _patchTask(
      ApiEndpoints.taskStatus(id),
      body: {
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<bool> deleteTask(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.taskById(id)}'),
        headers: ApiService.headers,
      );

      final ok = response.statusCode == 200 || response.statusCode == 204;
      if (ok) {
        _tasks.removeWhere((task) => task.id == id);
        _myTasks.removeWhere((task) => task.id == id);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<TaskModel?> startTask(String id) async {
    return _patchTask(ApiEndpoints.taskStart(id));
  }

  Future<TaskModel?> completeTask(
    String id, {
    String? summary,
    String? notes,
  }) async {
    return _patchTask(
      ApiEndpoints.taskComplete(id),
      body: {'summary': summary, 'notes': notes},
    );
  }

  Future<TaskModel?> approveTask(String id) async {
    return _patchTask(ApiEndpoints.taskApprove(id));
  }

  Future<TaskModel?> rejectTask(String id, String reason) async {
    return _patchTask(ApiEndpoints.taskReject(id), body: {'reason': reason});
  }

  Future<TaskModel?> extendTaskDeadline(
    String id, {
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    String? reason,
  }) async {
    return _patchTask(
      ApiEndpoints.taskExtend(id),
      body: {
        'days': days,
        'hours': hours,
        'minutes': minutes,
        'seconds': seconds,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<TaskModel?> requestTaskExtension(
    String id, {
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.taskExtensionRequest(id)}'),
        headers: ApiService.headers,
        body: json.encode({
          'days': days,
          'hours': hours,
          'minutes': minutes,
          'seconds': seconds,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
      }
    } catch (_) {}
    return null;
  }

  Future<TaskModel?> approveTaskExtensionRequest(
    String id, {
    String? reason,
  }) async {
    return _patchTask(
      ApiEndpoints.taskExtensionApprove(id),
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<TaskModel?> rejectTaskExtensionRequest(
    String id,
    String reason,
  ) async {
    return _patchTask(
      ApiEndpoints.taskExtensionReject(id),
      body: {'reason': reason},
    );
  }

  Future<TaskModel?> applyTaskPenalty(
    String id, {
    double? amount,
    String currency = 'SAR',
    String? notes,
  }) async {
    return _patchTask(
      ApiEndpoints.taskPenaltyApply(id),
      body: {
        if (amount != null) 'amount': amount,
        'currency': currency,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<TaskModel?> updateTrackingConsent(String id, bool consent) async {
    return _patchTask(
      ApiEndpoints.taskTrackingConsent(id),
      body: {'consent': consent},
    );
  }

  Future<TaskModel?> updateTaskReport(
    String id, {
    String? summary,
    String? notes,
  }) async {
    return _patchTask(
      ApiEndpoints.taskReportUpdate(id),
      body: {'summary': summary, 'notes': notes},
    );
  }

  Future<List<TaskTrackingPoint>> fetchTrackingPoints(
    String id, {
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.taskTrackingPoints(id)}?limit=$limit',
      );
      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['locations'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TaskTrackingPoint.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addTrackingPoint(String id, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.taskTrackingPoints(id)}',
        ),
        headers: ApiService.headers,
        body: json.encode(payload),
      );
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadAttachments(
    String id,
    List<String> paths, {
    String attachmentType = 'file',
  }) async {
    try {
      final dio = Dio(
        BaseOptions(baseUrl: ApiEndpoints.baseUrl, headers: ApiService.headers),
      );

      final files = await Future.wait(
        paths.map((path) => MultipartFile.fromFile(path)),
      );

      final form = FormData.fromMap({
        'attachmentType': attachmentType,
        'attachments': files,
      });

      final response = await dio.post(
        ApiEndpoints.taskAttachments(id),
        data: form,
      );

      return response.statusCode == 201;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAttachmentsBytes(
    String id,
    List<Uint8List> bytes,
    List<String> filenames, {
    String attachmentType = 'file',
  }) async {
    if (bytes.isEmpty ||
        filenames.isEmpty ||
        bytes.length != filenames.length) {
      return false;
    }

    try {
      final dio = Dio(
        BaseOptions(baseUrl: ApiEndpoints.baseUrl, headers: ApiService.headers),
      );

      final files = <MultipartFile>[];
      for (var i = 0; i < bytes.length; i++) {
        files.add(MultipartFile.fromBytes(bytes[i], filename: filenames[i]));
      }

      final form = FormData.fromMap({
        'attachmentType': attachmentType,
        'attachments': files,
      });

      final response = await dio.post(
        ApiEndpoints.taskAttachments(id),
        data: form,
      );

      return response.statusCode == 201;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<TaskModel?> _patchTask(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: ApiService.headers,
        body: json.encode(body ?? {}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
      }
    } catch (_) {}
    return null;
  }

  Future<List<TaskMessage>> fetchTaskMessages(
    String id, {
    int limit = 100,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.taskMessages(id)}?limit=$limit',
      );
      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TaskMessage.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<TaskMessage?> sendTaskMessage(String id, String text) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.taskMessages(id)}'),
        headers: ApiService.headers,
        body: json.encode({'text': text}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] is Map<String, dynamic>) {
          return TaskMessage.fromJson(
            Map<String, dynamic>.from(data['message']),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> markTaskMessagesRead(String id) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.taskMessagesRead(id)}',
        ),
        headers: ApiService.headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadTaskMessageAttachments(
    String id,
    List<String> paths, {
    String? caption,
    String? messageType,
  }) async {
    try {
      final dio = Dio(
        BaseOptions(baseUrl: ApiEndpoints.baseUrl, headers: ApiService.headers),
      );

      final files = await Future.wait(
        paths.map((path) => MultipartFile.fromFile(path)),
      );

      final form = FormData.fromMap({
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
        if (messageType != null && messageType.trim().isNotEmpty)
          'messageType': messageType.trim(),
        'attachments': files,
      });

      final response = await dio.post(
        ApiEndpoints.taskMessageAttachments(id),
        data: form,
      );

      return response.statusCode == 201;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadTaskMessageAttachmentsBytes(
    String id,
    List<Uint8List> bytes,
    List<String> filenames, {
    String? caption,
    String? messageType,
  }) async {
    if (bytes.isEmpty ||
        filenames.isEmpty ||
        bytes.length != filenames.length) {
      return false;
    }

    try {
      final dio = Dio(
        BaseOptions(baseUrl: ApiEndpoints.baseUrl, headers: ApiService.headers),
      );

      final files = <MultipartFile>[];
      for (var i = 0; i < bytes.length; i++) {
        files.add(MultipartFile.fromBytes(bytes[i], filename: filenames[i]));
      }

      final form = FormData.fromMap({
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
        if (messageType != null && messageType.trim().isNotEmpty)
          'messageType': messageType.trim(),
        'attachments': files,
      });

      final response = await dio.post(
        ApiEndpoints.taskMessageAttachments(id),
        data: form,
      );

      return response.statusCode == 201;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<TaskModel?> addTaskParticipants(
    String id,
    List<String> userIds,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.taskParticipants(id)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'userIds': userIds}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['task'] is Map<String, dynamic>) {
          return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
        }
      }
    } catch (_) {}
    return null;
  }

  Future<TaskModel?> removeTaskParticipant(String id, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.taskParticipant(id, userId)}',
        ),
        headers: ApiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['task'] is Map<String, dynamic>) {
          return TaskModel.fromJson(Map<String, dynamic>.from(data['task']));
        }
      }
    } catch (_) {}
    return null;
  }
}
