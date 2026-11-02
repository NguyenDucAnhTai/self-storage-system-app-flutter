import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/payment_history_provider.dart';
import '../../data/models/payment.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  String _status = 'all';
  String _purpose = 'all';
  bool _loadingMore = false;
  String? _loadMoreError;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(paymentHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử thanh toán')),
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          icon: Icons.wifi_off_rounded,
          title: 'Không tải được lịch sử thanh toán',
          message: 'Vui lòng kiểm tra kết nối và thử lại.',
          action: FilledButton(
            onPressed: _refresh,
            child: const Text('Thử lại'),
          ),
        ),
        data: (data) => _history(data),
      ),
    );
  }

  Widget _history(PaymentHistoryPage data) {
    final filtered = data.items.where((payment) {
      final statusMatch =
          _status == 'all' ||
          (_status == 'paid' && payment.status == 'paid') ||
          (_status == 'pending' &&
              const {'pending', 'partially_paid'}.contains(payment.status)) ||
          (_status == 'other' &&
              const {'expired', 'cancelled'}.contains(payment.status));
      final purposeMatch =
          _purpose == 'all' ||
          (_purpose == 'deposit' &&
              const {
                'reservation_deposit',
                'contract_deposit',
              }.contains(payment.purpose)) ||
          (_purpose == 'rent' && payment.purpose == 'rent_first_period');
      return statusMatch && purposeMatch;
    }).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            'Giao dịch của bạn',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Thông tin được cập nhật từ hệ thống.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _filterGroup(
            'Trạng thái',
            [
              ('all', 'Tất cả'),
              ('paid', 'Đã thanh toán'),
              ('pending', 'Đang xử lý'),
              ('other', 'Khác'),
            ],
            _status,
            (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 10),
          _filterGroup(
            'Khoản thu',
            [('all', 'Tất cả'), ('deposit', 'Tiền cọc'), ('rent', 'Tiền thuê')],
            _purpose,
            (value) => setState(() => _purpose = value),
          ),
          if (data.hasNextPage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Bộ lọc áp dụng trên ${data.items.length} giao dịch đã tải.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _MessageState(
              icon: data.items.isEmpty
                  ? Icons.receipt_long_outlined
                  : Icons.filter_list_off_rounded,
              title: data.items.isEmpty
                  ? 'Chưa có giao dịch'
                  : 'Không có giao dịch phù hợp',
              message: data.items.isEmpty
                  ? 'Các khoản thanh toán sẽ xuất hiện tại đây khi hệ thống ghi nhận.'
                  : 'Thử thay đổi bộ lọc để xem giao dịch khác.',
            )
          else
            ...filtered.map(
              (payment) => _PaymentCard(
                payment: payment,
                onTap: () {
                  final query = <String, String>{};
                  if (_validId(payment.reservationId)) {
                    query['reservationId'] = payment.reservationId!;
                  }
                  if (_validId(payment.contractId)) {
                    query['contractId'] = payment.contractId!;
                  }
                  final suffix = query.isEmpty
                      ? ''
                      : '?${Uri(queryParameters: query).query}';
                  context.push(
                    '/payments/${Uri.encodeComponent(payment.id)}/view$suffix',
                  );
                },
              ),
            ),
          if (data.hasNextPage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Tải thêm giao dịch'),
                    ),
            ),
          if (_loadMoreError != null)
            TextButton(
              onPressed: _loadMore,
              child: const Text('Không tải thêm được. Thử lại'),
            ),
        ],
      ),
    );
  }

  Widget _filterGroup(
    String label,
    List<(String, String)> values,
    String selected,
    ValueChanged<String> onSelected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: values
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: selected == item.$1,
                    selectedColor: AppTheme.primaryEmerald,
                    backgroundColor: Colors.white,
                    disabledColor: const Color(0xFFE9EEEB),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: selected == item.$1
                          ? AppTheme.primaryEmerald
                          : AppTheme.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected == item.$1
                          ? Colors.white
                          : AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => onSelected(item.$1),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  Future<void> _refresh() =>
      ref.read(paymentHistoryProvider.notifier).refresh();

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      await ref.read(paymentHistoryProvider.notifier).loadMore();
    } catch (_) {
      if (mounted) setState(() => _loadMoreError = 'error');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.onTap});
  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(payment.amount);
    final timestamp = payment.paidAt ?? payment.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _purposeLabel(payment.purpose),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _PaymentStatus(status: payment.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                amount,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (payment.facility?.name?.isNotEmpty == true)
                _CardLine(
                  icon: Icons.warehouse_outlined,
                  text: payment.facility!.name!,
                ),
              _CardLine(
                icon: Icons.account_balance_outlined,
                text: _methodLabel(payment.method),
              ),
              if (payment.paymentCode.isNotEmpty)
                _CardLine(icon: Icons.tag_rounded, text: payment.paymentCode),
              if (timestamp != null)
                _CardLine(
                  icon: Icons.schedule_rounded,
                  text: _vietnamTime(timestamp),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _PaymentStatus extends StatelessWidget {
  const _PaymentStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final label = switch (status) {
      'paid' => 'Đã thanh toán',
      'pending' => 'Chờ thanh toán',
      'partially_paid' => 'Thanh toán một phần',
      'expired' => 'Đã hết hạn',
      'cancelled' => 'Đã hủy',
      _ => 'Đang cập nhật',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: paid ? const Color(0xFFDDF7EE) : const Color(0xFFF0F3F1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

String _purposeLabel(String purpose) => switch (purpose) {
  'reservation_deposit' => 'Tiền cọc đặt kho',
  'contract_deposit' => 'Tiền cọc hợp đồng',
  'rent_first_period' => 'Tiền thuê kỳ đầu',
  _ => 'Khoản thanh toán',
};

String _methodLabel(String method) => switch (method) {
  'sepay_qr' => 'Chuyển khoản qua mã QR',
  'bank_transfer' => 'Chuyển khoản ngân hàng',
  'cash' => 'Tiền mặt',
  _ => 'Phương thức đang cập nhật',
};

String _vietnamTime(DateTime value) =>
    DateFormat('dd/MM/yyyy, HH:mm')
        .format(value.toUtc().add(const Duration(hours: 7)));

bool _validId(String? value) =>
    value != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(value);
