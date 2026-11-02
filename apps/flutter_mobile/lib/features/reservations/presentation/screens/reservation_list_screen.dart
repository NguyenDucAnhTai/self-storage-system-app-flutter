import 'package:flutter/material.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../data/models/reservation.dart';
import '../../data/repositories/reservation_repository.dart';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({
    super.key,
    required this.repository,
    required this.onSelect,
  });
  final ReservationRepository repository;
  final ValueChanged<Reservation> onSelect;
  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  late Future<List<Reservation>> _reservations;
  @override
  void initState() {
    super.initState();
    _reservations = widget.repository.list();
  }

  void _reload() => setState(() => _reservations = widget.repository.list());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đơn đặt kho')),
    body: FutureBuilder<List<Reservation>>(
      future: _reservations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Không thể tải đơn đặt kho. Vui lòng kiểm tra kết nối và thử lại.',
            onRetry: _reload,
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Chưa có đơn đặt kho',
            message: 'Đơn đặt kho sẽ hiển thị tại đây sau khi bạn xác nhận đặt kho.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final facilityName = item.facility?['name']?.toString();
              final unitNumber = item.storageUnit?['unitNumber']?.toString();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onSelect(item),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.reservationCode,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Chip(label: Text(_statusLabel(item.status))),
                          ],
                        ),
                        if (facilityName != null &&
                            facilityName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            facilityName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(item.checkInDate.toLocal()),
                              ),
                            ),
                            const Icon(Icons.schedule_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text(item.checkInTimeSlot),
                          ],
                        ),
                        if (unitNumber != null && unitNumber.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text('Kho $unitNumber'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Xem chi tiết  →',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  String _statusLabel(String status) => switch (status.toLowerCase()) {
    'pending' => 'Chờ xác nhận',
    'pending_payment' => 'Chờ thanh toán',
    'confirmed' => 'Đã xác nhận',
    'active' => 'Đang sử dụng',
    'completed' => 'Hoàn tất',
    'cancelled' => 'Đã hủy',
    'expired' => 'Hết hạn',
    _ => status,
  };
}
