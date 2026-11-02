class Payment {
  const Payment({
    required this.id,
    required this.paymentCode,
    required this.purpose,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.method,
    required this.createdAt,
    required this.updatedAt,
    this.reservationId,
    this.contractId,
    this.qrUrl,
    this.expiresAt,
    this.paidAt,
    this.confirmedAt,
    this.referenceCode,
    this.bankInfo,
    this.facilityId,
    this.customerId,
    this.overpaidAmount = 0,
    this.confirmedBy,
    this.cancelledBy,
    this.facility,
    this.proofImageUrl,
    this.cancelledAt,
    this.cancellationReason,
    this.note,
  });
  final String id;
  final String paymentCode;
  final String purpose;
  final String? reservationId;
  final String? contractId;
  final double amount;
  final double paidAmount;
  final String status;
  final String method;
  final String? qrUrl;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime? confirmedAt;
  final String? referenceCode;
  final Map<String, dynamic>? bankInfo;
  final String? facilityId;
  final String? customerId;
  final double overpaidAmount;
  final PaymentPartySnapshot? confirmedBy;
  final PaymentPartySnapshot? cancelledBy;
  final PaymentFacilitySnapshot? facility;
  final String? proofImageUrl;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: '${json['id'] ?? ''}',
    paymentCode: '${json['paymentCode'] ?? ''}',
    purpose: '${json['purpose'] ?? ''}',
    reservationId: json['reservationId']?.toString(),
    contractId: json['contractId']?.toString(),
    amount: _number(json['amount']),
    paidAmount: _number(json['paidAmount']),
    status: '${json['status'] ?? ''}',
    method: '${json['method'] ?? ''}',
    qrUrl: json['qrUrl']?.toString(),
    expiresAt: _date(json['expiresAt']),
    paidAt: _date(json['paidAt']),
    confirmedAt: _date(json['confirmedAt']),
    referenceCode: json['referenceCode']?.toString(),
    facilityId: json['facilityId']?.toString(),
    customerId: json['customerId']?.toString(),
    overpaidAmount: _number(json['overpaidAmount']),
    confirmedBy: _party(json['confirmedBy']),
    cancelledBy: _party(json['cancelledBy']),
    facility: PaymentFacilitySnapshot.tryParse(json['facility']),
    proofImageUrl: json['proofImageUrl']?.toString(),
    cancelledAt: _date(json['cancelledAt']),
    cancellationReason: json['cancellationReason']?.toString(),
    note: json['note']?.toString(),
    bankInfo: json['bankInfo'] is Map<String, dynamic>
        ? json['bankInfo'] as Map<String, dynamic>
        : null,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  bool get isTerminal =>
      const {'paid', 'expired', 'cancelled'}.contains(status);
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value.toString());
  static PaymentPartySnapshot? _party(Object? value) =>
      value is Map ? PaymentPartySnapshot.tryParse(value) : null;
  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class PaymentPartySnapshot {
  const PaymentPartySnapshot({this.id, this.name, this.email});
  final String? id;
  final String? name;
  final String? email;

  static PaymentPartySnapshot? tryParse(Object? value) {
    if (value is! Map) return null;
    return PaymentPartySnapshot(
      id: value['id']?.toString(),
      name: value['name']?.toString(),
      email: value['email']?.toString(),
    );
  }
}

class PaymentFacilitySnapshot {
  const PaymentFacilitySnapshot({this.id, this.name, this.city, this.address});
  final String? id;
  final String? name;
  final String? city;
  final String? address;

  static PaymentFacilitySnapshot? tryParse(Object? value) {
    if (value is! Map) return null;
    return PaymentFacilitySnapshot(
      id: value['id']?.toString(),
      name: value['name']?.toString(),
      city: value['city']?.toString(),
      address: value['address']?.toString(),
    );
  }
}

class PaymentHistoryPage {
  const PaymentHistoryPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
  });
  final List<Payment> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;

  factory PaymentHistoryPage.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List || json['pagination'] is! Map) {
      throw const FormatException('Invalid paginated payment response.');
    }
    final rawPagination = Map<String, dynamic>.from(json['pagination'] as Map);
    final rawItems = json['items'] as List;
    final parsed = rawItems.map((item) {
      if (item is! Map) throw const FormatException('Invalid payment item.');
      return Payment.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    int number(String key, int fallback) =>
        int.tryParse('${rawPagination[key] ?? ''}') ?? fallback;
    final page = number('page', 1);
    final limit = number('limit', parsed.isEmpty ? 10 : parsed.length);
    final totalItems = number('totalItems', parsed.length);
    final totalPages = number(
      'totalPages',
      totalItems == 0 ? 0 : (totalItems / limit).ceil(),
    );
    return PaymentHistoryPage(
      items: parsed,
      page: page,
      limit: limit,
      totalItems: totalItems,
      totalPages: totalPages,
      hasNextPage: rawPagination['hasNextPage'] is bool
          ? rawPagination['hasNextPage'] as bool
          : page < totalPages,
    );
  }
}
