class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.status,
    this.description,
    this.phone,
    this.email,
    this.images = const [],
    this.operatingHours,
  });
  final String id;
  final String name;
  final String address;
  final String city;
  final String status;
  final String? description;
  final String? phone;
  final String? email;
  final List<String> images;
  final Map<String, dynamic>? operatingHours;
  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    address: '${json['address'] ?? ''}',
    city: '${json['city'] ?? ''}',
    status: '${json['status'] ?? ''}',
    description: json['description']?.toString(),
    phone: json['phone']?.toString(),
    email: json['email']?.toString(),
    images: (json['images'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    operatingHours: json['operatingHours'] is Map<String, dynamic>
        ? json['operatingHours'] as Map<String, dynamic>
        : null,
  );
}

class FacilityOffering {
  const FacilityOffering({
    required this.id,
    required this.unitTypeId,
    required this.name,
    required this.pricePerUnit,
    required this.billingUnit,
    required this.depositMultiplier,
    required this.minRentalDays,
    required this.availableUnitsCount,
    this.area,
    this.volume,
    this.dimensions,
    this.category,
  });
  final String id;
  final String unitTypeId;
  final String name;
  final double pricePerUnit;
  final String billingUnit;
  final double depositMultiplier;
  final int minRentalDays;
  final int availableUnitsCount;
  final double? area;
  final double? volume;
  final Map<String, dynamic>? dimensions;
  final String? category;
  factory FacilityOffering.fromJson(Map<String, dynamic> j) {
    final t = j['unitType'] is Map<String, dynamic>
        ? j['unitType'] as Map<String, dynamic>
        : <String, dynamic>{};
    return FacilityOffering(
      id: '${j['id'] ?? ''}',
      unitTypeId: '${j['unitTypeId'] ?? t['id'] ?? ''}',
      name: '${t['name'] ?? 'Storage unit'}',
      pricePerUnit: _n(j['pricePerUnit']),
      billingUnit: '${j['billingUnit'] ?? ''}',
      depositMultiplier: _n(j['depositMultiplier']),
      minRentalDays: (j['minRentalDays'] as num?)?.toInt() ?? 1,
      availableUnitsCount: (j['availableUnitsCount'] as num?)?.toInt() ?? 0,
      area: t['area'] == null ? null : _n(t['area']),
      volume: t['volume'] == null ? null : _n(t['volume']),
      dimensions: t['dimensions'] is Map<String, dynamic>
          ? t['dimensions'] as Map<String, dynamic>
          : null,
      category: t['category']?.toString(),
    );
  }
  static double _n(Object? v) => v is num ? v.toDouble() : 0;
}

class FacilityDetail {
  const FacilityDetail({required this.facility, required this.offerings});
  final Facility facility;
  final List<FacilityOffering> offerings;
}
