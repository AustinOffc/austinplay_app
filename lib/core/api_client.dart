import 'package:dio/dio.dart';
import 'config.dart';
import 'storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Klien HTTP tunggal. Auth lewat header Bearer (bukan cookie).
class ApiClient {
  ApiClient(this._tokens) {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = _tokens.cached;
        if (t != null && t.isNotEmpty) options.headers['Authorization'] = 'Bearer $t';
        handler.next(options);
      },
      onError: (e, handler) {
        final soft = e.requestOptions.extra['soft401'] == true;
        if (e.response?.statusCode == 401 && !soft && _tokens.hasToken) {
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));
  }

  final TokenStore _tokens;
  late final Dio dio;

  /// Dipanggil saat server menjawab 401 untuk sesi yang valid-sebelumnya.
  void Function()? onUnauthorized;

  static String messageOf(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException) {
      final code = e.response?.statusCode;
      final d = e.response?.data;
      if (d is Map) {
        final m = d['message'] ?? d['error'];
        if (m is String && m.isNotEmpty) return m;
      }
      if (code == 429) return 'Terlalu banyak permintaan, coba lagi sebentar.';
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Koneksi lambat, coba lagi.';
        case DioExceptionType.connectionError:
          return 'Tidak bisa terhubung ke server.';
        default:
          break;
      }
      if (code != null && code >= 500) return 'Server sedang bermasalah, coba lagi nanti.';
      return 'Terjadi kesalahan jaringan.';
    }
    return 'Terjadi kesalahan.';
  }

  Map<String, dynamic> _unwrap(Response<dynamic> res) {
    final d = res.data;
    final map = d is Map<String, dynamic> ? d : <String, dynamic>{};
    if (map['success'] == false || map['status'] == false) {
      final m = map['message'] ?? map['error'];
      throw ApiException(m is String && m.isNotEmpty ? m : 'Permintaan gagal.',
          status: res.statusCode);
    }
    return map;
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query, bool soft401 = false}) async {
    try {
      final r = await dio.get<dynamic>(path,
          queryParameters: query, options: Options(extra: {'soft401': soft401}));
      return _unwrap(r);
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> post(String path,
      {Object? data, bool soft401 = false}) async {
    try {
      final r = await dio.post<dynamic>(path,
          data: data, options: Options(extra: {'soft401': soft401}));
      return _unwrap(r);
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> put(String path, {Object? data, bool soft401 = false}) async {
    try {
      final r = await dio.put<dynamic>(path,
          data: data, options: Options(extra: {'soft401': soft401}));
      return _unwrap(r);
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> delete(String path, {Object? data, bool soft401 = false}) async {
    try {
      final r = await dio.delete<dynamic>(path,
          data: data, options: Options(extra: {'soft401': soft401}));
      return _unwrap(r);
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }

  /// GET tanpa pembungkus (mis. /api/suggest yang membalas array).
  Future<dynamic> getRaw(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await dio.get<dynamic>(path,
          queryParameters: query, options: Options(extra: {'soft401': true}));
      return r.data;
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }

  /// POST yang mengembalikan Response apa adanya (status 4xx/5xx tidak dilempar),
  /// dipakai /api/ytplay supaya `code` & `retryable` bisa dibaca.
  Future<Response<dynamic>> rawPost(String path, {Object? data, Duration? timeout}) async {
    try {
      return await dio.post<dynamic>(path,
          data: data,
          options: Options(
            receiveTimeout: timeout,
            validateStatus: (s) => s != null && s < 600,
            extra: {'soft401': true},
          ));
    } on DioException catch (e) {
      throw ApiException(messageOf(e), status: e.response?.statusCode);
    }
  }
}
