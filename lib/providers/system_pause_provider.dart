import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:order_tracker/models/system_pause_notice_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class SystemPauseProvider with ChangeNotifier {
  static const Duration _pollInterval = Duration(seconds: 20);

  SystemPauseNotice? _notice;
  bool _isLoading = false;
  String? _error;

  Timer? _poller;
  bool _fetching = false;

  SystemPauseNotice? get notice => _notice;
  bool get isActive => _notice?.isActive ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void initialize() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) {
      unawaited(refresh(silent: true));
    });

    unawaited(refresh(silent: true));
  }

  Future<void> refresh({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;

    final previous = _notice;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await ApiService.get(ApiEndpoints.systemPauseStatus);
      final data = ApiService.decodeJsonMap(response);
      final noticeJson = data['notice'];

      SystemPauseNotice? parsed;
      if (noticeJson is Map) {
        parsed = SystemPauseNotice.fromJson(
          Map<String, dynamic>.from(noticeJson),
        );
      }

      _notice = parsed;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _fetching = false;

      if (!silent || previous != _notice) {
        notifyListeners();
      }
    }
  }

  Future<bool> activate({
    required String title,
    required String message,
    required String actorName,
    required String targetScope,
    List<String> targetUserIds = const <String>[],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final normalizedActorName = actorName.trim();
      final normalizedTargetUserIds = targetUserIds
          .map((userId) => userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet()
          .toList();

      final response = await ApiService.post(ApiEndpoints.systemPauseActivate, <
        String,
        dynamic
      >{
        'title': title.trim(),
        'message': message.trim(),
        'developerName': normalizedActorName,
        if (normalizedActorName.isNotEmpty)
          'createdByName': normalizedActorName,
        'targetScope': targetScope.trim().isEmpty ? 'all' : targetScope.trim(),
        if (targetScope.trim() == 'selected')
          'targetUserIds': normalizedTargetUserIds,
      });
      final data = ApiService.decodeJsonMap(response);
      final noticeJson = data['notice'];
      if (noticeJson is Map) {
        _notice = SystemPauseNotice.fromJson(
          Map<String, dynamic>.from(noticeJson),
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deactivate({String? resumeMessage}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        ApiEndpoints.systemPauseDeactivate,
        <String, dynamic>{
          if (resumeMessage != null && resumeMessage.trim().isNotEmpty)
            'resumeMessage': resumeMessage.trim(),
        },
      );
      final data = ApiService.decodeJsonMap(response);
      final noticeJson = data['notice'];
      if (noticeJson is Map) {
        _notice = SystemPauseNotice.fromJson(
          Map<String, dynamic>.from(noticeJson),
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }
}
