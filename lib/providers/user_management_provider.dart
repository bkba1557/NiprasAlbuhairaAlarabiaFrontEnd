import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/utils/api_service.dart';

class UserManagementProvider with ChangeNotifier {
  final List<User> _users = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = false;

  List<User> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get currentPage => _currentPage;

  Future<void> fetchUsers({
    int page = 1,
    bool append = false,
    String? search,
    int limit = 50,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final body = await _requestUsersPage(
        page: page,
        search: search,
        limit: limit,
      );
      final rawUsers = (body['users'] as List<dynamic>? ?? []);
      final fetched = rawUsers.map((user) => User.fromJson(user)).toList();

      if (!append) {
        _users
          ..clear()
          ..addAll(fetched);
      } else {
        _users.addAll(fetched);
      }

      final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
      final totalPages = pagination['pages'] is int
          ? pagination['pages'] as int
          : int.tryParse(pagination['pages']?.toString() ?? '') ?? page;

      _currentPage = page;
      _hasMore = page < totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllUsers({String? search, int batchSize = 200}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final initialBody = await _requestUsersPage(
        page: 1,
        search: search,
        limit: 0,
      );
      final initialPagination =
          initialBody['pagination'] as Map<String, dynamic>? ?? {};
      final initialPages = initialPagination['pages'] is int
          ? initialPagination['pages'] as int
          : int.tryParse(initialPagination['pages']?.toString() ?? '') ?? 1;

      if (initialPages <= 1) {
        final fetched = (initialBody['users'] as List<dynamic>? ?? [])
            .map((user) => User.fromJson(user))
            .toList();
        _users
          ..clear()
          ..addAll(fetched);
        _currentPage = 1;
        _hasMore = false;
        return;
      }

      final collected = <User>[];
      final seenIds = <String>{};
      var page = 1;
      var totalPages = 1;

      do {
        final body = await _requestUsersPage(
          page: page,
          search: search,
          limit: batchSize,
        );
        final rawUsers = (body['users'] as List<dynamic>? ?? []);
        for (final rawUser in rawUsers) {
          final user = User.fromJson(rawUser);
          if (seenIds.add(user.id)) {
            collected.add(user);
          }
        }

        final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
        totalPages = pagination['pages'] is int
            ? pagination['pages'] as int
            : int.tryParse(pagination['pages']?.toString() ?? '') ?? page;
        page += 1;
      } while (page <= totalPages);

      _users
        ..clear()
        ..addAll(collected);
      _currentPage = totalPages;
      _hasMore = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => fetchUsers(page: 1);

  Future<void> createUser(Map<String, dynamic> payload) async {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/users', payload);
      final userData = ApiService.decodeJsonMap(response)['user'];
      _users.insert(0, User.fromJson(userData));
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> payload) async {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();

    try {
      final response = await ApiService.put('/users/$userId', payload);
      final userData = ApiService.decodeJsonMap(response)['user'];
      final updated = User.fromJson(userData);
      final index = _users.indexWhere((user) => user.id == userId);
      if (index != -1) {
        _users[index] = updated;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await ApiService.delete('/users/$userId');
      _users.removeWhere((user) => user.id == userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleBlock(String userId, bool block) async {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();

    try {
      final response = await ApiService.patch('/users/$userId/block', {
        'block': block,
      });
      final userData = ApiService.decodeJsonMap(response)['user'];
      final updated = User.fromJson(userData);
      final index = _users.indexWhere((user) => user.id == userId);
      if (index != -1) {
        _users[index] = updated;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _requestUsersPage({
    required int page,
    required int limit,
    String? search,
  }) async {
    final queryBuffer = StringBuffer('/users?page=$page&limit=$limit');
    if (search != null && search.trim().isNotEmpty) {
      queryBuffer.write('&search=${Uri.encodeQueryComponent(search.trim())}');
    }
    final response = await ApiService.get(queryBuffer.toString());
    return ApiService.decodeJsonMap(response);
  }
}
