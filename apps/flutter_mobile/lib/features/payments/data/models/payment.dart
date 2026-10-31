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
  final DateTime createdAt;
  final DateTime updatedAt;

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
    bankInfo: json['bankInfo'] is Map<String, dynamic>
        ? json['bankInfo'] as Map<String, dynamic>
        : null,
    createdAt: DateTime.parse('${json['createdAt']}'),
    updatedAt: DateTime.parse('${json['updatedAt']}'),
  );

  bool get isTerminal =>
      const {'paid', 'expired', 'cancelled'}.contains(status);
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value.toString());
  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
