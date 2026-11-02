import 'package:dio/dio.dart';

class Amenity {
  const Amenity({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.type,
    this.tags = const [],
  });
  final String id, name, status;
  final String? description, type;
  final List<String> tags;
  factory Amenity.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}';
    final name = '${json['name'] ?? ''}';
    final status = '${json['status'] ?? ''}';
    if (id.isEmpty || name.isEmpty || status.isEmpty) {
      throw const FormatException('Thông tin tiện ích không đầy đủ.');
    }
    return Amenity(
      id: id,
      name: name,
      status: status,
      description: json['description']?.toString(),
      type: json['type']?.toString(),
      tags: (json['tags'] as List? ?? const []).map((e) => '$e').toList(),
    );
  }
}

class FacilityAmenityOffering {
  const FacilityAmenityOffering({
    required this.id,
    required this.facilityId,
    required this.amenityId,
    required this.name,
    required this.pricePerUnit,
    required this.billingUnit,
    required this.status,
    this.description,
    this.availableQuantity,
    this.totalQuantity,
    this.notes,
    this.amenityType,
  });
  final String id, facilityId, amenityId, name, billingUnit, status;
  final double pricePerUnit;
  final String? description, notes, amenityType;
  final int? availableQuantity, totalQuantity;
  bool get isAvailable =>
      status == 'active' &&
      (availableQuantity == null || availableQuantity! > 0);
  factory FacilityAmenityOffering.fromJson(Map<String, dynamic> json) {
    final amenity = json['amenity'] is Map
        ? Map<String, dynamic>.from(json['amenity'] as Map)
        : <String, dynamic>{};
    final id = '${json['id'] ?? ''}',
        facilityId = '${json['facilityId'] ?? ''}',
        amenityId = '${json['amenityId'] ?? amenity['id'] ?? ''}';
    if (id.isEmpty ||
        facilityId.isEmpty ||
        amenityId.isEmpty ||
        json['pricePerUnit'] is! num) {
      throw const FormatException('Thông tin tiện ích tại cơ sở không hợp lệ.');
    }
    return FacilityAmenityOffering(
      id: id,
      facilityId: facilityId,
      amenityId: amenityId,
      name: '${amenity['name'] ?? 'Tiện ích'}',
      description: amenity['description']?.toString(),
      amenityType: amenity['type']?.toString(),
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      billingUnit: '${json['billingUnit'] ?? ''}',
      status: '${json['status'] ?? ''}',
      availableQuantity: _count(json['availableQuantity']),
      totalQuantity: _count(json['totalQuantity']),
      notes: json['notes']?.toString(),
    );
  }
  static int? _count(Object? v) {
    if (v == null) return null;
    if (v is! num || v < 0 || v != v.toInt()) {
      throw const FormatException('Số lượng tiện ích không hợp lệ.');
    }
    return v.toInt();
  }
}

class AmenityRepository {
  AmenityRepository(this.dio);
  final Dio dio;
  Future<List<Amenity>> listActive({int page = 1}) async {
    final r = await dio.get<Map<String, dynamic>>(
      '/amenities',
      queryParameters: {
        'page': page,
        'limit': 100,
        'status': 'active',
        'sortBy': 'name',
      },
    );
    final data = r.data?['data'];
    final items = data is Map ? data['items'] : null;
    if (items is! List) {
      throw const FormatException('Danh sách tiện ích không đúng định dạng.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(Amenity.fromJson)
        .toList();
  }

  Future<List<FacilityAmenityOffering>> availableAt(String facilityId) async {
    final r = await dio.get<Map<String, dynamic>>(
      '/facility-amenity-offerings/facility/$facilityId/available',
    );
    final data = r.data?['data'];
    if (data is! List) {
      throw const FormatException(
        'Danh sách tiện ích cơ sở không đúng định dạng.',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(FacilityAmenityOffering.fromJson)
        .toList();
  }
}
