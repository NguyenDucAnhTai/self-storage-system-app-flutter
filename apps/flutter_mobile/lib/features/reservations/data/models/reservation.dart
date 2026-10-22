class Reservation {
  const Reservation({
    required this.id,
    required this.reservationCode,
    required this.customerId,
    required this.facilityId,
    required this.facilityUnitTypeOfferingId,
    required this.checkInDate,
    required this.checkInTimeSlot,
    required this.startDate,
    required this.rentalDuration,
    required this.billingUnit,
    required this.basePrice,
    required this.depositAmount,
    required this.totalAmount,
    required this.status,
    required this.refundAmount,
    required this.createdAt,
    required this.updatedAt,
    this.storageUnitId,
    this.expiresAt,
    this.paidAt,
    this.paidAmount,
    this.paymentId,
    this.lastPaymentError,
    this.cancellationReason,
    this.notes,
    this.facility,
    this.storageUnit,
    this.offering,
  });

  final String id;
  final String reservationCode;
  final String customerId;
  final String facilityId;
  final String facilityUnitTypeOfferingId;
  final String? storageUnitId;
  final DateTime checkInDate;
  final String checkInTimeSlot;
  final DateTime startDate;
  final int rentalDuration;
  final String billingUnit;
  final double basePrice;
  final double depositAmount;
  final double totalAmount;
  final String status;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final double? paidAmount;
  final String? paymentId;
  final String? lastPaymentError;
  final double refundAmount;
  final String? cancellationReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? facility;
  final Map<String, dynamic>? storageUnit;
  final Map<String, dynamic>? offering;

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: _string(json['id']),
    reservationCode: _string(json['reservationCode']),
    customerId: _string(json['customerId']),
    facilityId: _string(json['facilityId']),
    facilityUnitTypeOfferingId: _string(json['facilityUnitTypeOfferingId']),
    storageUnitId: _nullableString(json['storageUnitId']),
    checkInDate: DateTime.parse(_string(json['checkInDate'])),
    checkInTimeSlot: _string(json['checkInTimeSlot']),
    startDate: DateTime.parse(_string(json['startDate'])),
    rentalDuration: _number(json['rentalDuration']).toInt(),
    billingUnit: _string(json['billingUnit']),
    basePrice: _number(json['basePrice']),
    depositAmount: _number(json['depositAmount']),
    totalAmount: _number(json['totalAmount']),
    status: _string(json['status']),
    expiresAt: _date(json['expiresAt']),
    paidAt: _date(json['paidAt']),
    paidAmount: json['paidAmount'] == null ? null : _number(json['paidAmount']),
    paymentId: _nullableString(json['paymentId']),
    lastPaymentError: _nullableString(json['lastPaymentError']),
    refundAmount: _number(json['refundAmount']),
    cancellationReason: _nullableString(json['cancellationReason']),
    notes: _nullableString(json['notes']),
    createdAt: DateTime.parse(_string(json['createdAt'])),
    updatedAt: DateTime.parse(_string(json['updatedAt'])),
    facility: _map(json['facility']),
    storageUnit: _map(json['storageUnit']),
    offering: _map(json['offering']),
  );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(_string(value));
  static Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic> ? value : null;
  static String _string(Object? value) => value?.toString() ?? '';
  static String? _nullableString(Object? value) => value?.toString();
  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class AvailableTimeSlot {
  const AvailableTimeSlot({
    required this.id,
    required this.slotName,
    required this.startTime,
    required this.endTime,
    required this.availableCapacity,
    required this.isAvailable,
  });
  final String id;
  final String slotName;
  final String startTime;
  final String endTime;
  final int availableCapacity;
  final bool isAvailable;

  factory AvailableTimeSlot.fromJson(Map<String, dynamic> json) =>
      AvailableTimeSlot(
        id: '${json['id'] ?? ''}',
        slotName: '${json['slotName'] ?? ''}',
        startTime: '${json['startTime'] ?? ''}',
        endTime: '${json['endTime'] ?? ''}',
        availableCapacity: (json['availableCapacity'] as num?)?.toInt() ?? 0,
        isAvailable: json['isAvailable'] == true,
      );
}
