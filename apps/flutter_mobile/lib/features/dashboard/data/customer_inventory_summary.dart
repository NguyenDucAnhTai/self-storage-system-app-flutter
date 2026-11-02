class CustomerInventorySummary {
  const CustomerInventorySummary({
    required this.totalSkus,
    required this.totalQuantity,
    required this.totalStorageUnits,
    required this.totalActiveContracts,
    required this.categoryBreakdown,
    required this.recentMovements,
  });

  final int totalSkus;
  final num totalQuantity;
  final int totalStorageUnits;
  final int totalActiveContracts;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Map<String, dynamic>> recentMovements;

  factory CustomerInventorySummary.fromJson(Map<String, dynamic> json) {
    final categories = json['categoryBreakdown'];
    final movements = json['recentMovements'];
    if (json['totalSkus'] is! num ||
        json['totalQuantity'] is! num ||
        json['totalStorageUnits'] is! num ||
        json['totalActiveContracts'] is! num ||
        categories is! List ||
        movements is! List) {
      throw const FormatException(
        'The backend returned an incomplete customer inventory summary.',
      );
    }
    return CustomerInventorySummary(
      totalSkus: (json['totalSkus'] as num).toInt(),
      totalQuantity: json['totalQuantity'] as num,
      totalStorageUnits: (json['totalStorageUnits'] as num).toInt(),
      totalActiveContracts: (json['totalActiveContracts'] as num).toInt(),
      categoryBreakdown: _objectList(categories, 'categoryBreakdown'),
      recentMovements: _objectList(movements, 'recentMovements'),
    );
  }

  static List<Map<String, dynamic>> _objectList(List values, String field) =>
      values
          .map((value) {
            if (value is! Map) {
              throw FormatException('Invalid item in $field.');
            }
            return Map<String, dynamic>.from(value);
          })
          .toList(growable: false);
}
