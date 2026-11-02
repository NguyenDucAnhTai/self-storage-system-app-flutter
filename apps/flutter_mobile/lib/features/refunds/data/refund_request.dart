class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.code,
    required this.amount,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.reservationId,
    this.contractId,
    this.paymentId,
    this.facilityName,
    this.referenceCode,
    this.proofImageUrl,
    this.rejectionReason,
    this.cancellationReason,
    this.note,
    this.approvedAt,
    this.paidAt,
    this.cancelledAt,
    this.refundBankName,
    this.refundAccountNumberMasked,
    this.refundAccountHolder,
  });

  final String id;
  final String code;
  final double amount;
  final String reason;
  final String status;
  final DateTime? requestedAt;
  final String? reservationId;
  final String? contractId;
  final String? paymentId;
  final String? facilityName;
  final String? referenceCode;
  final String? proofImageUrl;
  final String? rejectionReason;
  final String? cancellationReason;
  final String? note;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final String? refundBankName;
  final String? refundAccountNumberMasked;
  final String? refundAccountHolder;

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    Object? value(Object? raw, String key) => raw is Map ? raw[key] : null;
    return RefundRequest(
      id: '${json['id'] ?? ''}',
      code: '${json['refundCode'] ?? ''}',
      amount: _number(json['amount']),
      reason: '${json['reason'] ?? ''}',
      status: '${json['status'] ?? ''}',
      requestedAt: _date(json['requestedAt'] ?? json['createdAt']),
      reservationId: json['reservationId']?.toString(),
      contractId: json['contractId']?.toString(),
      paymentId: json['paymentId']?.toString(),
      facilityName: value(json['facility'], 'name')?.toString(),
      referenceCode: json['referenceCode']?.toString(),
      proofImageUrl: json['proofImageUrl']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      cancellationReason: json['cancellationReason']?.toString(),
      note: json['note']?.toString(),
      approvedAt: _date(json['approvedAt']),
      paidAt: _date(json['paidAt']),
      cancelledAt: _date(json['cancelledAt']),
      refundBankName: json['refundBankName']?.toString(),
      refundAccountNumberMasked: json['refundAccountNumberMasked']?.toString(),
      refundAccountHolder: json['refundAccountHolder']?.toString(),
    );
  }

  bool get canCancel => status == 'pending_approval';
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class RefundPage {
  const RefundPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.hasNextPage,
  });
  final List<RefundRequest> items;
  final int page;
  final int totalPages;
  final bool hasNextPage;

  factory RefundPage.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List || json['pagination'] is! Map) {
      throw const FormatException('Invalid refund request list response.');
    }
    final pagination = Map<String, dynamic>.from(json['pagination'] as Map);
    final items = (json['items'] as List).map((entry) {
      if (entry is! Map) throw const FormatException('Invalid refund request.');
      return RefundRequest.fromJson(Map<String, dynamic>.from(entry));
    }).toList();
    int number(String key, int fallback) =>
        int.tryParse('${pagination[key] ?? ''}') ?? fallback;
    final current = number('page', 1);
    final total = number('totalPages', 0);
    return RefundPage(
      items: items,
      page: current,
      totalPages: total,
      hasNextPage: pagination['hasNextPage'] is bool
          ? pagination['hasNextPage'] as bool
          : current < total,
    );
  }
}
