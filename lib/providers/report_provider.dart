import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class ReportProvider {
  Future<Map<String, dynamic>> customerReports({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url =
          '${ApiEndpoints.baseUrl}/reports/customers?page=$page&limit=$limit';

      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            url += '&$key=$value';
          }
        });
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل جلب تقرير العملاء');
      }
    } catch (e) {
      debugPrint('Customer reports error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> driverReports({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url =
          '${ApiEndpoints.baseUrl}/reports/drivers?page=$page&limit=$limit';

      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            url += '&$key=$value';
          }
        });
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل جلب تقرير السائقين');
      }
    } catch (e) {
      debugPrint('Driver reports error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> supplierReports({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url =
          '${ApiEndpoints.baseUrl}/reports/suppliers?page=$page&limit=$limit';

      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            url += '&$key=$value';
          }
        });
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل جلب تقرير الموردين');
      }
    } catch (e) {
      debugPrint('Supplier reports error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> userReports({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url =
          '${ApiEndpoints.baseUrl}/reports/users?page=$page&limit=$limit';

      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            url += '&$key=$value';
          }
        });
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل جلب تقرير المستخدمين');
      }
    } catch (e) {
      debugPrint('User reports error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> invoiceReport(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/reports/invoice/$orderId'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل جلب تقرير الفاتورة');
      }
    } catch (e) {
      debugPrint('Invoice report error: $e');
      rethrow;
    }
  }

  Future<Uint8List> exportPDF({
    required String reportType,
    Map<String, dynamic>? filters,
  }) async {
    String endpoint = '/reports/export/pdf?reportType=$reportType';

    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          endpoint += '&$key=$value';
        }
      });
    }

    debugPrint('EXPORT PDF ENDPOINT => $endpoint');
    debugPrint('HEADERS => ${ApiService.headers}');

    final response = await ApiService.download(endpoint);
    return response.bodyBytes;
  }

  Future<Uint8List> exportExcel({
    required String reportType,
    Map<String, dynamic>? filters,
  }) async {
    String endpoint = '/reports/export/excel?reportType=$reportType';

    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          endpoint += '&$key=$value';
        }
      });
    }

    debugPrint('EXPORT EXCEL ENDPOINT => $endpoint');
    debugPrint('HEADERS => ${ApiService.headers}');

    final response = await ApiService.download(endpoint);
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> getFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/filters/options'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل جلب خيارات الفلاتر');
      }
    } catch (e) {
      debugPrint('Filter options error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> smartSearch(String query, {String? type}) async {
    try {
      String url = '${ApiEndpoints.baseUrl}/filters/search?q=$query';
      if (type != null) {
        url += '&type=$type';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل البحث');
      }
    } catch (e) {
      debugPrint('Smart search error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFilterStats(
    Map<String, dynamic> filters,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/filters/stats'),
        headers: ApiService.headers,
        body: json.encode({'filters': filters}),
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      } else {
        throw Exception('فشل حساب الإحصائيات');
      }
    } catch (e) {
      debugPrint('Filter stats error: $e');
      rethrow;
    }
  }
}
