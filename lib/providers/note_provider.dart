import 'package:flutter/foundation.dart';
import 'package:order_tracker/models/note_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

/// Provider يدير كل ما يخص الملاحظات.
class NoteProvider with ChangeNotifier {
  /* ---------- المتغيّرات الداخلية ---------- */
  List<NoteModel> _notes = [];

  // حالة تحميل البيانات (GET)
  bool _isFetching = false;

  // حالة تحميل أو حفظ بيانات داخل الـ Dialog (تُستَخدم حالياً فقط في UI)
  bool _isLoading = false;
  bool get isLoading => _isLoading; // ✅ Getter المطلوب من الـ UI

  // حالة تنفيذ عمليات الكتابة (POST / PUT / DELETE)
  bool _isSubmitting = false;

  String? _error; // لتخزين رسائل الأخطاء.

  /* ---------- Getters العامة ---------- */
  List<NoteModel> get notes => List.unmodifiable(_notes);
  bool get isFetching => _isFetching;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  int get activeNotesCount => _notes.where((n) => n.active).length;

  /* ---------- مساعدة لتحديث الـ loading ---------- */
  void _setLoading({
    bool fetching = false,
    bool submitting = false,
    bool loading = false,
  }) {
    _isFetching = fetching;
    _isSubmitting = submitting;
    _isLoading = loading;
    notifyListeners();
  }

  /* ---------- جلب الملاحظات من الـ API ---------- */
  Future<void> fetchNotes() async {
    _setLoading(fetching: true, loading: true);
    try {
      final response = await ApiService.get(ApiEndpoints.notes);
      final data = ApiService.decodeJson(response);

      // نتوقع: { "notes": [ {...}, {...} ] }
      final List<dynamic> rawList = data['notes'] as List<dynamic>;
      final fetched = rawList
          .map(
            (e) => NoteModel.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList();

      _notes = fetched;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(fetching: false, loading: false);
    }
  }

  /* ---------- إنشاء ملاحظة جديدة ---------- */
  Future<bool> createNote(NoteModel note) async {
    _setLoading(submitting: true, loading: true);
    try {
      final body = note.toJson(); // يحتوي على colorHex إذا كان موجوداً
      final response = await ApiService.post(ApiEndpoints.notes, body);
      final data = ApiService.decodeJson(response);

      final created = NoteModel.fromJson(
        Map<String, dynamic>.from(data['note'] as Map<dynamic, dynamic>),
      );

      // أضف الملاحظة في أعلى القائمة لتظهر أولاً
      _notes.insert(0, created);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(submitting: false, loading: false);
    }
  }

  /* ---------- تعديل ملاحظة موجودة ---------- */
  Future<bool> updateNote(NoteModel note) async {
    _setLoading(submitting: true, loading: true);
    try {
      final body = note.toJson();
      final response = await ApiService.put(
        ApiEndpoints.noteById(note.id),
        body,
      );
      final data = ApiService.decodeJson(response);

      final updated = NoteModel.fromJson(
        Map<String, dynamic>.from(data['note'] as Map<dynamic, dynamic>),
      );

      final int index = _notes.indexWhere((n) => n.id == updated.id);
      if (index != -1) {
        _notes[index] = updated;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(submitting: false, loading: false);
    }
  }

  /* ---------- حذف ملاحظة ---------- */
  Future<bool> deleteNote(String noteId) async {
    _setLoading(submitting: true, loading: true);
    try {
      await ApiService.delete(ApiEndpoints.noteById(noteId));
      _notes.removeWhere((note) => note.id == noteId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(submitting: false, loading: false);
    }
  }

  /* ---------- مساعدة: إخلاء الأخطاء (اختياري) ---------- */
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
