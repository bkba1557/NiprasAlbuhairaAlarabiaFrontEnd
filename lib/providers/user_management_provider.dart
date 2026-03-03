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

  Future<void> fetchUsers({int page = 1, bool append = false, String? search}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryBuffer = StringBuffer('/users?page=$page&limit=50');
      if (search != null && search.trim().isNotEmpty) {
        queryBuffer.write('&search=${Uri.encodeQueryComponent(search.trim())}');
      }
      final response = await ApiService.get(queryBuffer.toString());
      final body = json.decode(response.body) as Map<String, dynamic>;
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

  Future<void> refresh() => fetchUsers(page: 1);

  Future<void> createUser(Map<String, dynamic> payload) async {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/users', payload);
      final userData = json.decode(response.body)['user'];
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
      final userData = json.decode(response.body)['user'];
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
      final response = await ApiService.patch('/users/$userId/block', {'block': block});
      final userData = json.decode(response.body)['user'];
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
}
