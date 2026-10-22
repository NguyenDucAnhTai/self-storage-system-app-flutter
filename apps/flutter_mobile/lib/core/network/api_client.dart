import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:async';

import '../config/app_config.dart';
import 'api_error.dart';

class ApiClient {
  Future<void>? _refreshing;
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage() {
    this.dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await this.storage.read(key: _accessKey);
          if (token != null &&
              token.isNotEmpty &&
              !options.path.startsWith('/auth/')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true &&
              !error.requestOptions.path.startsWith('/auth/')) {
            try {
              await _refreshTokens();
              final access = await this.storage.read(key: _accessKey);
              if (access == null) {
                throw StateError(
                  'Session refresh did not return an access token',
                );
              }
              final retry = error.requestOptions
                ..extra['retried'] = true
                ..headers['Authorization'] = 'Bearer $access';
              final response = await this.dio.fetch<dynamic>(retry);
              handler.resolve(response);
              return;
            } catch (_) {
              await clearSession();
            }
          }
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: ApiError.fromDio(error),
              message: ApiError.fromDio(error).message,
            ),
          );
        },
      ),
    );
  }
  late final Dio dio;
  final FlutterSecureStorage storage;
  static const _accessKey = 'storagehub.accessToken';
  static const _refreshKey = 'storagehub.refreshToken';
  Future<void> saveTokens(Map<String, dynamic> tokens) async {
    final access = tokens['accessToken']?.toString();
    final refresh = tokens['refreshToken']?.toString();
    if (access == null || refresh == null) {
      throw const FormatException('Backend did not return both auth tokens.');
    }
    await storage.write(key: _accessKey, value: access);
    await storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> _refreshTokens() {
    return _refreshing ??= _performRefresh().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _performRefresh() async {
    final refresh = await storage.read(key: _refreshKey);
    if (refresh == null) throw StateError('No refresh token');
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refresh},
      options: Options(extra: {'skipAuth': true}),
    );
    await saveTokens(_payload(response.data));
  }

  Future<String?> get accessToken => storage.read(key: _accessKey);
  Future<String?> get refreshToken => storage.read(key: _refreshKey);
  Future<void> clearSession() async {
    await storage.delete(key: _accessKey);
    await storage.delete(key: _refreshKey);
  }

  static Map<String, dynamic> _payload(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is Map<String, dynamic> &&
        data['tokens'] is Map<String, dynamic>) {
      return data['tokens'] as Map<String, dynamic>;
    }
    if (data is Map<String, dynamic>) return data;
    throw const FormatException(
      'Backend response did not include auth tokens.',
    );
  }

  static ApiError normalize(Object error) => error is DioException
      ? ApiError.fromDio(error)
      : ApiError(error.toString());
}
