import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._client);
  final Dio _dio;
  final ApiClient _client;
  AuthUser? _user;
  AuthUser? get currentUser => _user;
  Future<AuthUser> login(String email, String password) async => _complete(
    await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
    ),
  );
  Future<AuthUser> register({
    required String email,
    required String otp,
    required String password,
    required String name,
    String? phoneNumber,
  }) async => _complete(
    await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email.trim(),
        'otp': otp.trim(),
        'password': password,
        'name': name.trim(),
        if (phoneNumber?.isNotEmpty == true) 'phoneNumber': phoneNumber,
      },
    ),
  );
  Future<void> sendOtp(String email) async {
    await _dio.post('/auth/send-otp', data: {'email': email.trim()});
  }

  Future<AuthUser?> restore() async {
    if (await _client.accessToken == null && await _client.refreshToken == null) {
      return null;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Profile missing');
      }
      _user = AuthUser.fromJson(data);
      return _user;
    } catch (_) {
      await _client.clearSession();
      return null;
    }
  }

  Future<void> logout() async {
    final refresh = await _client.refreshToken;
    try {
      await _dio.post(
        '/auth/logout',
        data: {'refreshToken': ?refresh},
      );
    } finally {
      await _client.clearSession();
      _user = null;
    }
  }

  Future<AuthUser> _complete(Response<Map<String, dynamic>> response) async {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic> ||
        data['user'] is! Map<String, dynamic> ||
        data['tokens'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid authentication response.');
    }
    await _client.saveTokens(data['tokens'] as Map<String, dynamic>);
    _user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    return _user!;
  }
}
