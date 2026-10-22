import 'package:dio/dio.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;
  Future<Map<String, dynamic>> getMine() async {
    final r = await _dio.get<Map<String, dynamic>>('/profile/me');
    final v = r.data?['data'];
    if (v is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response');
    }
    return v;
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> values) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/profile/me',
      data: values,
    );
    final v = r.data?['data'];
    if (v is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response');
    }
    return v;
  }
}
