import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../reservations/data/repositories/reservation_repository.dart';
import '../../data/models/facility.dart';
import '../../data/repositories/facility_repository.dart';
import '../../../amenities/amenity_repository.dart';

class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.facilityId,
    required this.repository,
    required this.availabilityRepository,
    required this.onBook,
    this.amenityRepository,
  });

  final String facilityId;
  final FacilityRepository repository;
  final ReservationRepository availabilityRepository;
  final ValueChanged<({Facility facility, FacilityOffering offering})> onBook;
  final AmenityRepository? amenityRepository;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  late Future<FacilityDetail> _future;
  final Map<String, Future<List<Map<String, dynamic>>>> _availability = {};
  late Future<List<FacilityAmenityOffering>>? _amenitiesFuture;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getDetail(widget.facilityId);
    _amenitiesFuture = widget.amenityRepository?.availableAt(widget.facilityId);
  }

  void _reload() => setState(() {
    _future = widget.repository.getDetail(widget.facilityId);
    _availability.clear();
    _amenitiesFuture = widget.amenityRepository?.availableAt(widget.facilityId);
  });

  Future<List<Map<String, dynamic>>> _unitsFor(FacilityOffering offering) {
    return _availability.putIfAbsent(offering.id, () {
      if (offering.unitTypeId.isEmpty) {
        return Future.error(
          const FormatException('Unit type identifier is missing.'),
        );
      }
      return widget.availabilityRepository.getAvailableUnits(
        widget.facilityId,
        unitTypeId: offering.unitTypeId,
      );
    });
  }

  void _retryOffering(FacilityOffering offering) => setState(() {
    _availability.remove(offering.id);
    _unitsFor(offering);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết cơ sở')),
    body: FutureBuilder<FacilityDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return AppErrorState(
            message: 'Không thể tải thông tin kho. Vui lòng kiểm tra kết nối.',
            onRetry: _reload,
          );
        }

        final detail = snapshot.data!;
        final facility = detail.facility;
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            SizedBox(
              height: 248,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView(
                    children: facility.images.isEmpty
                        ? const [FacilityImage(url: null, height: 248)]
                        : facility.images
                              .map(
                                (url) => FacilityImage(url: url, height: 248),
                              )
                              .toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 19,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${facility.city} · ${facility.address}'),
                      ),
                    ],
                  ),
                  if (facility.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(facility.description!),
                  ],
                  if (facility.phone?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text('Điện thoại: ${facility.phone}'),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: AppSectionHeader(
                title: 'Loại kho khả dụng',
                subtitle: 'Chọn kích thước phù hợp với nhu cầu của bạn',
                trailing: Text('${detail.offerings.length}'),
              ),
            ),
            if (detail.offerings.isEmpty)
              const SizedBox(
                height: 240,
                child: AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Chưa có loại kho',
                  message: 'Vui lòng quay lại sau để xem các lựa chọn tại cơ sở này.',
                ),
              ),
            ...detail.offerings.map(
              (offering) => _offeringCard(facility, offering),
            ),
            if (_amenitiesFuture != null) _amenitiesSection(),
          ],
        );
      },
    ),
  );

  Widget _amenitiesSection() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: AppSectionHeader(
            title: 'Tiện ích tại cơ sở',
            subtitle: 'Thông tin và giá do cơ sở cung cấp',
          ),
        ),
        FutureBuilder<List<FacilityAmenityOffering>>(
          future: _amenitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Không tải được tiện ích · Thử lại'),
                ),
              );
            }
            final offerings =
                snapshot.data ?? const <FacilityAmenityOffering>[];
            if (offerings.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Cơ sở chưa công bố tiện ích.'),
              );
            }
            return Column(
              children: offerings
                  .map(
                    (item) => Card(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: ListTile(
                        leading: Icon(
                          item.isAvailable
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                          color: item.isAvailable
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(item.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.description?.trim().isNotEmpty == true)
                              Text(item.description!),
                            Text(
                              '${NumberFormat('#,##0', 'vi_VN').format(item.pricePerUnit)} ₫ / ${_billingLabel(item.billingUnit)}',
                            ),
                            if (item.notes?.trim().isNotEmpty == true)
                              Text(item.notes!),
                            if (!item.isAvailable)
                              const Text('Hiện không còn số lượng khả dụng.'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _offeringCard(Facility facility, FacilityOffering offering) => Card(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offering.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (offering.area != null)
                          _DetailTag('${offering.area!.toStringAsFixed(1)} m²'),
                        if (offering.category?.trim().isNotEmpty == true)
                          _DetailTag(offering.category!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${NumberFormat('#,##0', 'vi_VN').format(offering.pricePerUnit)} ₫ / ${_billingLabel(offering.billingUnit)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Đặt cọc × ${offering.depositMultiplier} · Tối thiểu ${offering.minRentalDays} ngày',
          ),
          if (offering.dimensions != null) ...[
            const SizedBox(height: 8),
            Text(_dimensions(offering.dimensions!)),
          ],
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _unitsFor(offering),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Đang kiểm tra kho trống'),
                    ],
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _availabilityError(snapshot.error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _retryOffering(offering),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ),
                  ],
                );
              }

              final units = snapshot.data!;
              if (units.isEmpty) {
                return const _AvailabilityLabel(
                  icon: Icons.event_busy_outlined,
                  label: 'Hết phòng trống',
                  available: false,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvailabilityLabel(
                    icon: Icons.check_circle_outline,
                    label: '${units.length} kho trống',
                    available: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          offering.id.isEmpty ||
                              offering.unitTypeId.isEmpty ||
                              facility.id.isEmpty
                          ? null
                          : () => widget.onBook((
                              facility: facility,
                              offering: offering,
                            )),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Chọn loại kho này'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  String _availabilityError(Object? error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Kết nối quá thời gian. Vui lòng thử lại.';
      }
      if (status == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (status == 403) {
        return 'Bạn không có quyền xem tình trạng kho.';
      }
      if (status == 404) {
        return 'Không tìm thấy thông tin kho trống.';
      }
      if (status != null && status >= 500) {
        return 'Máy chủ chưa thể tải tình trạng kho.';
      }
      if (status == null) {
        return 'Không thể kết nối. Hãy kiểm tra mạng và thử lại.';
      }
    }
    if (error is ApiError) {
      if (error.statusCode == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (error.statusCode == 403) {
        return 'Bạn không có quyền xem tình trạng kho.';
      }
      if (error.statusCode == 404) {
        return 'Không tìm thấy thông tin kho trống.';
      }
      if ((error.statusCode ?? 0) >= 500) {
        return 'Máy chủ chưa thể tải tình trạng kho.';
      }
    }
    if (error is FormatException || error is TypeError) {
      return 'Dữ liệu tình trạng kho không đúng định dạng.';
    }
    return 'Không thể tải tình trạng kho. Vui lòng thử lại.';
  }

  String _billingLabel(String value) => switch (value) {
    'day' => 'ngày',
    'week' => 'tuần',
    'month' => 'tháng',
    'year' => 'năm',
    'one_time' => 'một lần',
    _ => 'đơn vị',
  };

  String _dimensions(Map<String, dynamic> dimensions) {
    final values = [
      dimensions['length'],
      dimensions['width'],
      dimensions['height'],
    ];
    if (values.any((value) => value == null)) return '';
    return '${values.join(' × ')} m';
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel({
    required this.icon,
    required this.label,
    required this.available,
  });
  final IconData icon;
  final String label;
  final bool available;
  @override
  Widget build(BuildContext context) {
    final color = available
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
