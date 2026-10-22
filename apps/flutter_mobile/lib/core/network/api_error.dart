import 'package:dio/dio.dart';

class ApiError implements Exception {
  const ApiError(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  factory ApiError.fromDio(DioException error) {
    final body = error.response?.data;
    if (body is Map) {
      return ApiError(
        '${body['message'] ?? error.message ?? 'Request failed'}',
        statusCode: error.response?.statusCode,
        code: body['messageCode']?.toString(),
      );
    }
    return ApiError(
      error.response == null
          ? 'Unable to connect. Check your network and API address.'
          : 'Request failed (${error.response?.statusCode}).',
      statusCode: error.response?.statusCode,
    );
  }
  @override
  String toString() => message;
}
