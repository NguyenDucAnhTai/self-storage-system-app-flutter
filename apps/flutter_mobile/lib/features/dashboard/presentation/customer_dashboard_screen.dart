import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/explore/data/models/facility.dart';
import '../../../features/notifications/application/notification_providers.dart';
import '../../../features/notifications/presentation/notification_bell.dart';
import '../../../features/reservations/data/models/reservation.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/data/customer_inventory_summary.dart';

class CustomerDashboardScreen extends ConsumerStatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState
    extends ConsumerState<CustomerDashboardScreen> {
  Future<void> _refresh() async {
    final requests = <Future<void>>[
      ref
          .refresh(dashboardInventorySummaryProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
      ref
          .refresh(dashboardContractsProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
      ref
          .refresh(dashboardReservationsProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
      ref
          .refresh(dashboardFacilitiesProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
      ref
          .refresh(notificationUnreadCountProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
    ];
    await Future.wait(requests);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 17) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final summary = ref.watch(dashboardInventorySummaryProvider);
    final contracts = ref.watch(dashboardContractsProvider);
    final reservations = ref.watch(dashboardReservationsProvider);
    final facilities = ref.watch(dashboardFacilitiesProvider);
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'bạn';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          const NotificationBell(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Cá nhân',
              onPressed: () => context.go('/profile'),
              icon: CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user?.name.trim().isNotEmpty == true
                      ? user!.name.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryDarkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(Icons.warehouse_outlined, size: 25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _summarySection(summary),
            const SizedBox(height: 26),
            const AppSectionHeader(
              title: 'Truy cập nhanh',
              subtitle: 'Tiếp tục sử dụng dịch vụ',
            ),
            const SizedBox(height: 12),
            _quickActions(context),
            const SizedBox(height: 26),
            AppSectionHeader(
              title: 'Việc cần lưu ý',
              subtitle: 'Các mục có thể cần bạn xử lý',
              trailing: TextButton(
                onPressed: () => context.go('/reservations'),
                child: const Text('Đơn đặt kho'),
              ),
            ),
            const SizedBox(height: 10),
            _upcomingPayment(reservations),
            const SizedBox(height: 26),
            AppSectionHeader(
              title: 'Kho đang sử dụng',
              subtitle: 'Các hợp đồng lưu trữ hiện tại',
              trailing: TextButton(
                onPressed: () => context.go('/contracts'),
                child: const Text('Tất cả hợp đồng'),
              ),
            ),
            const SizedBox(height: 10),
            _activeStorage(context, contracts),
            const SizedBox(height: 26),
            AppSectionHeader(
              title: 'Hoạt động gần đây',
              subtitle: 'Các lần xuất nhập kho mới nhất',
            ),
            const SizedBox(height: 10),
            _recentActivity(summary),
            const SizedBox(height: 26),
            AppSectionHeader(
              title: 'Khám phá cơ sở',
              subtitle: 'Các lựa chọn từ danh sách cơ sở lưu trữ',
              trailing: TextButton(
                onPressed: () => context.go('/explore'),
                child: const Text('Xem tất cả'),
              ),
            ),
            const SizedBox(height: 10),
            _facilityHighlights(context, facilities),
          ],
        ),
      ),
    );
  }

  Widget _summarySection(AsyncValue<CustomerInventorySummary> state) =>
      state.when(
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng quan kho của bạn'),
                SizedBox(height: 18),
                LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        error: (error, _) => _DashboardInlineError(
          message: 'Không thể tải tổng quan kho.',
          onRetry: () => ref.invalidate(dashboardInventorySummaryProvider),
        ),
        data: (data) => Card(
          color: AppTheme.primaryDarkGreen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tổng quan kho của bạn',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.north_east_rounded,
                      color: Colors.white.withValues(alpha: .8),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Metric(value: '${data.totalStorageUnits}', label: 'Kho'),
                    _metricDivider(),
                    _Metric(
                      value: '${data.totalActiveContracts}',
                      label: 'Hợp đồng đang dùng',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: .22), height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Metric(value: '${data.totalSkus}', label: 'Loại hàng'),
                    _metricDivider(),
                    _Metric(
                      value: NumberFormat('#,##0.##')
                          .format(data.totalQuantity),
                      label: 'Số lượng lưu kho',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _metricDivider() => Container(
    width: 1,
    height: 40,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: Colors.white.withValues(alpha: .22),
  );

  Widget _quickActions(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 360 ? 2 : 4;
      final itemWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: itemWidth,
            child: _QuickAction(
              icon: Icons.search_rounded,
              label: 'Tìm kho',
              onTap: () => context.go('/explore'),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _QuickAction(
              icon: Icons.inventory_2_outlined,
              label: 'Đơn đặt kho',
              onTap: () => context.go('/reservations'),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _QuickAction(
              icon: Icons.description_outlined,
              label: 'Hợp đồng',
              onTap: () => context.go('/contracts'),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _QuickAction(
              icon: Icons.notifications_outlined,
              label: 'Thông báo',
              onTap: () => context.go('/notifications'),
            ),
          ),
        ],
      );
    },
  );

  Widget _upcomingPayment(AsyncValue<List<Reservation>> state) => state.when(
    loading: () => const _LoadingCard(height: 74),
    error: (error, _) => _DashboardInlineError(
      message: 'Không thể tải thông tin đơn đặt kho cần xử lý.',
      onRetry: () => ref.invalidate(dashboardReservationsProvider),
    ),
    data: (items) {
      final pending = items
          .where((item) => item.status == 'pending_payment')
          .toList();
      if (pending.isEmpty) {
        return const _DashboardEmptyCard(
          icon: Icons.check_circle_outline,
          message: 'Hiện không có đơn đặt kho cần thanh toán.',
        );
      }
      return Column(
        children: pending.take(2).map((reservation) {
          final date = MaterialLocalizations.of(context)
              .formatMediumDate(reservation.checkInDate.toLocal());
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.lightMint,
                child: Icon(
                  Icons.payments_outlined,
                  color: AppTheme.primaryEmerald,
                ),
              ),
              title: Text('Chờ thanh toán · ${reservation.reservationCode}'),
              subtitle: Text('Nhận kho $date · ${reservation.checkInTimeSlot}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/payments/${reservation.id}'),
            ),
          );
        }).toList(),
      );
    },
  );

  Widget _activeStorage(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> state,
  ) => state.when(
    loading: () => const _LoadingCard(height: 92),
    error: (error, _) => _DashboardInlineError(
      message: 'Không thể tải hợp đồng đang sử dụng.',
      onRetry: () => ref.invalidate(dashboardContractsProvider),
    ),
    data: (rows) {
      final active = rows
          .where((row) => row['status']?.toString() == 'active')
          .take(3)
          .toList();
      if (active.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AppEmptyState(
              icon: Icons.warehouse_outlined,
              title: 'Chưa có kho đang sử dụng',
              message: 'Khám phá các cơ sở để tìm kho phù hợp với bạn.',
              action: FilledButton.icon(
                onPressed: () => context.go('/explore'),
                icon: const Icon(Icons.search),
                label: const Text('Khám phá cơ sở'),
              ),
            ),
          ),
        );
      }
      return Column(
        children: active.map((contract) {
          final facility = _map(contract['facility']);
          final unit = _map(contract['storageUnit']);
          final offering = _map(contract['offering']);
          final facilityName = facility?['name']?.toString();
          final unitNumber = unit?['unitNumber']?.toString();
          final typeName =
              offering?['name']?.toString() ??
              _map(offering?['unitType'])?['name']?.toString();
          final endDate = DateTime.tryParse('${contract['endDate'] ?? ''}');
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: AppTheme.primaryDarkGreen,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.go('/contracts'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warehouse_outlined,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            facilityName?.isNotEmpty == true
                                ? facilityName!
                                : '${contract['contractCode'] ?? 'Hợp đồng đang hoạt động'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6FFBBE)
                                .withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Đang sử dụng',
                            style: TextStyle(
                              color: Color(0xFFB8FFDD),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      unitNumber?.isNotEmpty == true
                          ? 'Kho $unitNumber'
                          : 'Chi tiết hợp đồng',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    if (typeName?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        typeName!,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                    if (endDate != null ||
                        contract['contractCode'] != null) ...[
                      const SizedBox(height: 15),
                      Divider(
                        color: Colors.white.withValues(alpha: .2),
                        height: 1,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (endDate != null)
                            Text(
                              'Kết thúc ${MaterialLocalizations.of(context).formatMediumDate(endDate.toLocal())}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          if (contract['contractCode'] != null)
                            Text(
                              'Hợp đồng ${contract['contractCode']}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );

  Widget _recentActivity(
    AsyncValue<CustomerInventorySummary> state,
  ) => state.when(
    loading: () => const _LoadingCard(height: 82),
    error: (error, _) => _DashboardInlineError(
      message: 'Không thể tải hoạt động kho gần đây.',
      onRetry: () => ref.invalidate(dashboardInventorySummaryProvider),
    ),
    data: (summary) {
      if (summary.recentMovements.isEmpty) {
        return const _DashboardEmptyCard(
          icon: Icons.history,
          message: 'Chưa có hoạt động kho nào được ghi nhận.',
        );
      }
      return Column(
        children: summary.recentMovements.take(3).map((movement) {
          final sku = _map(movement['sku']);
          final unit = _map(movement['storageUnit']);
          final createdAt = DateTime.tryParse('${movement['createdAt'] ?? ''}');
          final movementType = movement['type']?.toString() ?? '';
          final quantity = movement['quantity'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.lightMint,
                child: Icon(
                  _movementIcon(movementType),
                  color: AppTheme.primaryEmerald,
                ),
              ),
              title: Text('${movement['movementCode'] ?? movementType}'),
              subtitle: Text(
                [
                  if (sku?['name'] != null) '${sku!['name']}',
                  if (quantity is num)
                    'Số lượng ${NumberFormat('#,##0.##').format(quantity)}',
                  if (unit?['unitNumber'] != null) 'Kho ${unit!['unitNumber']}',
                  if (createdAt != null)
                    DateFormat('MMM d, y').format(createdAt.toLocal()),
                ].join(' · '),
              ),
              isThreeLine: true,
            ),
          );
        }).toList(),
      );
    },
  );

  Widget _facilityHighlights(
    BuildContext context,
    AsyncValue<List<Facility>> state,
  ) => state.when(
    loading: () => const _LoadingCard(height: 190),
    error: (error, _) => _DashboardInlineError(
      message: 'Không thể tải danh sách cơ sở.',
      onRetry: () => ref.invalidate(dashboardFacilitiesProvider),
    ),
    data: (items) {
      if (items.isEmpty) {
        return const _DashboardEmptyCard(
          icon: Icons.location_city_outlined,
          message: 'Hiện chưa có thông tin cơ sở.',
        );
      }
      return SizedBox(
        height: 218,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.take(3).length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final facility = items[index];
            return SizedBox(
              width: 260,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/facilities/${facility.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FacilityImage(
                        url: facility.images.isEmpty
                            ? null
                            : facility.images.first,
                        height: 128,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              facility.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${facility.city} · ${facility.address}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
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
  );

  Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  IconData _movementIcon(String type) => switch (type.toLowerCase()) {
    'in' || 'stock_in' => Icons.south_west,
    'out' || 'stock_out' => Icons.north_east,
    'move' || 'stock_move' => Icons.swap_horiz,
    _ => Icons.inventory_2_outlined,
  };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white.withValues(alpha: .78)),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardInlineError extends StatelessWidget {
  const _DashboardInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        Icons.cloud_off_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Retry',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      ),
    ),
  );
}

class _DashboardEmptyCard extends StatelessWidget {
  const _DashboardEmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}
