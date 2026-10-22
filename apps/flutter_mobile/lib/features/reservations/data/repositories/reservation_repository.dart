import 'package:dio/dio.dart';

import '../models/reservation.dart';

class ReservationRepository {
  ReservationRepository(this._dio);
  final Dio _dio;

  Future<List<AvailableTimeSlot>> getAvailability(
    String facilityId,
    DateTime date,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/facility-time-slots/facility/$facilityId/available',
      queryParameters: {'date': _dateOnly(date)},
    );
    return _list(response.data?['data'])
        .map(AvailableTimeSlot.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAvailableUnits(
    String facilityId, {
    String? unitTypeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/storage-units/facility/$facilityId/available',
      queryParameters: {'unitTypeId': ?unitTypeId},
    );
    return _list(response.data?['data'])
        .where((unit) => unit['status'] == 'available')
        .toList();
  }

  Future<Reservation> create({
    required String facilityId,
    required String storageUnitId,
    required DateTime checkInDate,
    required String checkInTimeSlot,
    required int rentalDuration,
    required String facilityUnitTypeOfferingId,
    DateTime? startDate,
    List<Map<String, dynamic>> amenities = const [],
    String? notes,
  }) async {
    if (facilityId.isEmpty ||
        storageUnitId.isEmpty ||
        facilityUnitTypeOfferingId.isEmpty ||
        checkInTimeSlot.trim().isEmpty ||
        rentalDuration < 1) {
      throw ArgumentError(
        'Facility, storage unit, unit offering, check-in slot, and a positive rental duration are required.',
      );
    }
    if (checkInDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      throw ArgumentError('Check-in date cannot be in the past.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/reservations',
      data: {
        'facilityId': facilityId,
        'storageUnitId': storageUnitId,
        'checkInDate': _dateOnly(checkInDate),
        'checkInTimeSlot': checkInTimeSlot,
        'facilityUnitTypeOfferingId': facilityUnitTypeOfferingId,
        if (startDate != null) 'startDate': _dateOnly(startDate),
        'rentalDuration': rentalDuration,
        'amenities': amenities,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return Reservation.fromJson(_data(response.data));
  }

  Future<List<Reservation>> list({int page = 1, int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reservations',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
      },
    );
    final data = response.data?['data'];
    return _list(data is Map<String, dynamic> ? data['items'] : null)
        .map(Reservation.fromJson)
        .toList();
  }

  Future<Reservation> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/reservations/$id');
    return Reservation.fromJson(_data(response.data));
  }

  Future<Reservation> cancel(String id, String reason) async {
    if (reason.trim().length < 3) {
      throw ArgumentError('Cancellation reason must be at least 3 characters.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/reservations/$id/cancel',
      data: {'cancellationReason': reason.trim()},
    );
    return Reservation.fromJson(_data(response.data));
  }

  static Map<String, dynamic> _data(Map<String, dynamic>? response) {
    final value = response?['data'];
    if (value is Map<String, dynamic>) return value;
    throw const FormatException(
      'Backend response did not include an object in data.',
    );
  }

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
