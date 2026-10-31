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
    final data = response.data?['data'];
    if (data is! List) {
      throw const FormatException(
        'Backend availability response did not include a data array.',
      );
    }
    return data.map((item) {
      if (item is! Map) {
        throw const FormatException(
          'Backend availability response contained an invalid time slot.',
        );
      }
      final json = Map<String, dynamic>.from(item);
      const requiredFields = [
        'id',
        'facilityId',
        'slotName',
        'startTime',
        'endTime',
        'maxCapacity',
        'bookedCount',
        'availableCapacity',
        'isAvailable',
      ];
      if (requiredFields.any((field) => !json.containsKey(field)) ||
          json['id'] is! String ||
          json['facilityId'] is! String ||
          json['slotName'] is! String ||
          json['startTime'] is! String ||
          json['endTime'] is! String ||
          json['maxCapacity'] is! num ||
          json['bookedCount'] is! num ||
          json['availableCapacity'] is! num ||
          json['isAvailable'] is! bool) {
        throw const FormatException(
          'Backend availability response contained an incomplete time slot.',
        );
      }
      return AvailableTimeSlot.fromJson(json);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAvailableUnits(
    String facilityId, {
    String? unitTypeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/storage-units/facility/$facilityId/available',
      queryParameters: {'unitTypeId': ?unitTypeId},
    );
    final data = response.data?['data'];
    if (data is! List) {
      throw const FormatException(
        'Backend unit availability response did not include a data array.',
      );
    }
    return data
        .map((item) {
          if (item is! Map) {
            throw const FormatException(
              'Backend unit availability response contained an invalid unit.',
            );
          }
          final unit = Map<String, dynamic>.from(item);
          if (unit['id'] is! String ||
              (unit['id'] as String).isEmpty ||
              unit['status'] is! String) {
            throw const FormatException(
              'Backend unit availability response contained an incomplete unit.',
            );
          }
          return unit;
        })
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
    required bool termsAccepted,
    DateTime? startDate,
    List<Map<String, dynamic>> amenities = const [],
    String? notes,
  }) async {
    if (facilityId.isEmpty ||
        storageUnitId.isEmpty ||
        facilityUnitTypeOfferingId.isEmpty ||
        checkInTimeSlot.trim().isEmpty ||
        rentalDuration < 1 ||
        !termsAccepted) {
      throw ArgumentError(
        'Facility, storage unit, unit offering, check-in slot, a positive rental duration, and explicit terms acceptance are required.',
      );
    }
    if (checkInDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
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
        'termsAccepted': termsAccepted,
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
