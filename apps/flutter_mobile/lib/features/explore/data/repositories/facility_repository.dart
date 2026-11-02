import 'package:dio/dio.dart';

import '../models/facility.dart';

class FacilityRepository {
  FacilityRepository(this._dio);
  final Dio _dio;

  Future<List<Facility>> search({
    String? search,
    String? city,
    int page = 1,
    List<String> amenityIds = const [],
    bool matchAllAmenities = true,
  }) async => (await searchPage(
    search: search,
    city: city,
    page: page,
    amenityIds: amenityIds,
    matchAllAmenities: matchAllAmenities,
  )).items;

  Future<FacilitySearchPage> searchPage({
    String? search,
    String? city,
    int page = 1,
    List<String> amenityIds = const [],
    bool matchAllAmenities = true,
  }) async {
    final ids = amenityIds.where((id) => id.isNotEmpty).toList();
    final useAmenitySearch = ids.isNotEmpty;
    final res = await _dio.get<Map<String, dynamic>>(
      useAmenitySearch ? '/facilities/search-by-amenity' : '/facilities',
      queryParameters: {
        'page': page,
        'limit': 20,
        if (!useAmenitySearch) 'status': 'active',
        'sortBy': 'name',
        'sortOrder': 'asc',
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
        if (useAmenitySearch) 'amenityIds': ids.join(','),
        if (useAmenitySearch) 'matchAll': matchAllAmenities,
      },
    );
    final data = res.data?['data'];
    if (data is! Map || data['items'] is! List) {
      throw const FormatException('Invalid facility search response.');
    }
    final rawItems = data['items'] as List;
    if (rawItems.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Invalid facility search item.');
    }
    final pagination = data['pagination'];
    final responsePage = pagination is Map ? pagination['page'] : null;
    final hasNextPage = pagination is Map && pagination['hasNextPage'] == true;
    return FacilitySearchPage(
      items: rawItems
          .cast<Map<String, dynamic>>()
          .map(Facility.fromJson)
          .toList(),
      page: responsePage is num ? responsePage.toInt() : page,
      hasNextPage: hasNextPage,
    );
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

class FacilitySearchPage {
  const FacilitySearchPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });

  final List<Facility> items;
  final int page;
  final bool hasNextPage;

  FacilitySearchPage append(FacilitySearchPage next) => FacilitySearchPage(
    items: [...items, ...next.items],
    page: next.page,
    hasNextPage: next.hasNextPage,
  );
}
