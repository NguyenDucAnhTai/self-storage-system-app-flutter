class ActiveRentalSummary {
  const ActiveRentalSummary({required this.contractsByUnitId});

  final Map<String, Map<String, dynamic>> contractsByUnitId;

  int get rentedUnitCount => contractsByUnitId.length;

  List<Map<String, dynamic>> get contracts =>
      List.unmodifiable(contractsByUnitId.values);

  factory ActiveRentalSummary.fromContracts(
    Iterable<Map<String, dynamic>> contracts,
  ) {
    final byUnit = <String, Map<String, dynamic>>{};
    for (final contract in contracts) {
      if ('${contract['status'] ?? ''}'.toLowerCase() != 'active') continue;
      final target = contract['rentalTargetType']?.toString().toLowerCase();
      if (target != null && target.isNotEmpty && target != 'storage_unit') {
        continue;
      }
      final unit = contract['storageUnit'];
      final rawUnitId =
          contract['storageUnitId'] ??
          (unit is Map ? unit['id'] ?? unit['_id'] : null);
      final unitId = rawUnitId?.toString().trim();
      if (unitId == null || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(unitId)) {
        continue;
      }
      byUnit.putIfAbsent(unitId, () => contract);
    }
    return ActiveRentalSummary(contractsByUnitId: Map.unmodifiable(byUnit));
  }
}
