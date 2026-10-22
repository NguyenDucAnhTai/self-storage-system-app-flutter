import 'package:dio/dio.dart';

import '../models/facility.dart';

class FacilityRepository {
  FacilityRepository(this._dio);
  final Dio _dio;
  Future<List<Facility>> search({
    String? search,
    String? city,
    int page = 1,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/facilities',
      queryParameters: {
        'page': page,
        'limit': 20,
        'status': 'active',
        'sortBy': 'name',
        'sortOrder': 'asc',
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      },
    );
    final data = res.data?['data'];
    final items = data is Map ? data['items'] : null;
    return (items is List
            ? items.whereType<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[])
        .map(Facility.fromJson)
        .toList();
  }

  Future<FacilityDetail> getDetail(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/facilities/$id/public-detail',
    );
    final data = res.data?['data'];
    if (data is! Map<String, dynamic> ||
        data['facility'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid facility detail response.');
    }
    final offerings = data['unitTypeOfferings'];
    return FacilityDetail(
      facility: Facility.fromJson(data['facility'] as Map<String, dynamic>),
      offerings:
          (offerings is List
                  ? offerings.whereType<Map<String, dynamic>>()
                  : const <Map<String, dynamic>>[])
              .map(FacilityOffering.fromJson)
              .toList(),
    );
  }
}
