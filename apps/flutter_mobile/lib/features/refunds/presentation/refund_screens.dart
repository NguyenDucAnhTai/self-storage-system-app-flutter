import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/refund_repository.dart';
import '../data/refund_request.dart';

class RefundListScreen extends StatefulWidget {
  const RefundListScreen({super.key, required this.dio});
  final Dio dio;
  @override
  State<RefundListScreen> createState() => _RefundListScreenState();
}

class _RefundListScreenState extends State<RefundListScreen> {
  late final RefundRepository _repository = RefundRepository(widget.dio);
  final List<RefundRequest> _items = [];
  bool _loading = true, _loadingMore = false, _hasMore = false;
  int _page = 1;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore) {
      return;
    }
    setState(() {
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final result = await _repository.list(page: reset ? 1 : _page + 1);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(result.items.where((item) => !ids.contains(item.id)));
        _page = result.page;
        _hasMore = result.hasNextPage;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể tải yêu cầu hoàn tiền. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Theo dõi hoàn tiền'),
      actions: [
        IconButton(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được dữ liệu hoàn tiền.'),
                TextButton(
                  onPressed: () => _load(reset: true),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_items.isEmpty)
                  const _EmptyRefunds()
                else
                  ..._items.map(
                    (item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.currency_exchange_rounded),
                        title: Text(
                          _reasonLabel(item.reason),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_statusLabel(item.status)} · ${_time(item.requestedAt)}',
                        ),
                        trailing: Text(
                          _money(item.amount),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => context.push(
                          '/refunds/${Uri.encodeComponent(item.id)}',
                        ),
                      ),
                    ),
                  ),
                if (_error != null) Text(_error!),
                if (_hasMore)
                  OutlinedButton(
                    onPressed: _loadingMore ? null : () => _load(reset: false),
                    child: Text(_loadingMore ? 'Đang tải…' : 'Tải thêm'),
                  ),
              ],
            ),
          ),
  );
}

class RefundDetailScreen extends StatefulWidget {
  const RefundDetailScreen({
    super.key,
    required this.dio,
    required this.refundId,
  });
  final Dio dio;
  final String refundId;
  @override
  State<RefundDetailScreen> createState() => _RefundDetailScreenState();
}

class _RefundDetailScreenState extends State<RefundDetailScreen> {
  late final RefundRepository _repository = RefundRepository(widget.dio);
  late Future<RefundRequest> _future;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _future = _repository.detail(widget.refundId);
  }

  void _reload() =>
      setState(() => _future = _repository.detail(widget.refundId));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết hoàn tiền'),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<RefundRequest>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Không thể tải yêu cầu. Quyền truy cập có thể bị giới hạn.',
                ),
                TextButton(onPressed: _reload, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        final item = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.code,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _Info(
                      label: 'Trạng thái',
                      value: _statusLabel(item.status),
                    ),
                    _Info(label: 'Lý do', value: _reasonLabel(item.reason)),
                    _Info(
                      label: 'Số tiền theo máy chủ',
                      value: _money(item.amount),
                    ),
                    if (item.facilityName != null)
                      _Info(label: 'Cơ sở', value: item.facilityName!),
                    _Info(
                      label: 'Ngày yêu cầu',
                      value: _time(item.requestedAt),
                    ),
                    if (item.refundBankName != null)
                      _Info(label: 'Ngân hàng', value: item.refundBankName!),
                    if (item.refundAccountNumberMasked != null)
                      _Info(
                        label: 'Tài khoản nhận',
                        value: item.refundAccountNumberMasked!,
                      ),
                    if (item.refundAccountHolder != null)
                      _Info(
                        label: 'Chủ tài khoản',
                        value: item.refundAccountHolder!,
                      ),
                    if (item.referenceCode != null)
                      _Info(label: 'Mã tham chiếu', value: item.referenceCode!),
                    if (item.approvedAt != null)
                      _Info(label: 'Duyệt lúc', value: _time(item.approvedAt)),
                    if (item.paidAt != null)
                      _Info(label: 'Đã hoàn lúc', value: _time(item.paidAt)),
                    if (item.rejectionReason != null)
                      _Info(
                        label: 'Lý do từ chối',
                        value: item.rejectionReason!,
                      ),
                    if (item.cancellationReason != null)
                      _Info(
                        label: 'Lý do hủy',
                        value: item.cancellationReason!,
                      ),
                    if (item.note != null)
                      _Info(label: 'Ghi chú', value: item.note!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Tiến trình', style: Theme.of(context).textTheme.titleMedium),
            _TimelineItem(
              title: 'Đã gửi yêu cầu',
              date: item.requestedAt,
              complete: true,
            ),
            _TimelineItem(
              title: 'Đã duyệt',
              date: item.approvedAt,
              complete:
                  item.approvedAt != null ||
                  const {'approved', 'paid'}.contains(item.status),
            ),
            _TimelineItem(
              title: item.status == 'rejected'
                  ? 'Yêu cầu bị từ chối'
                  : item.status == 'cancelled'
                  ? 'Yêu cầu đã hủy'
                  : 'Đã hoàn tiền',
              date: item.paidAt ?? item.cancelledAt,
              complete: const {
                'paid',
                'rejected',
                'cancelled',
              }.contains(item.status),
              last: true,
            ),
            if (item.canCancel)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _cancel(item),
                  child: const Text('Hủy yêu cầu hoàn tiền'),
                ),
              ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      },
    ),
  );

  Future<void> _cancel(RefundRequest item) async {
    var reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy yêu cầu hoàn tiền?'),
        content: TextField(
          onChanged: (value) => reasonText = value,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Lý do (ít nhất 3 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonText.trim()),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reason == null) return;
    if (reason.length < 3 || reason.length > 500) {
      setState(() => _error = 'Lý do cần từ 3 đến 500 ký tự.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: const Text(
          'Yêu cầu đang chờ duyệt sẽ được hủy. Không thể khôi phục thao tác này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await _repository.cancel(item.id, reason);
      if (mounted) setState(() => _future = Future.value(updated));
    } catch (_) {
      try {
        final latest = await _repository.detail(item.id);
        if (mounted) {
          setState(() {
            _future = Future.value(latest);
            _error = latest.status == 'cancelled' ? null : 'Chưa rõ kết quả hủy. Đã đồng bộ trạng thái; không tự gửi lại.';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Không thể xác định kết quả. Hãy tải lại trước khi thử lại.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.date,
    required this.complete,
    this.last = false,
  });
  final String title;
  final DateTime? date;
  final bool complete;
  final bool last;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 32,
        child: Column(
          children: [
            Icon(
              complete ? Icons.check_circle : Icons.radio_button_unchecked,
              color: complete
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            if (!last)
              Container(width: 2, height: 30, color: const Color(0xFFD9EAE3)),
          ],
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 12),
          child: Text(
            date == null && !complete
                ? '$title · Đang chờ cập nhật'
                : '$title${date == null ? '' : ' · ${_time(date)}'}',
          ),
        ),
      ),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _EmptyRefunds extends StatelessWidget {
  const _EmptyRefunds();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Icon(Icons.currency_exchange_outlined, size: 42),
        SizedBox(height: 12),
        Text('Chưa có yêu cầu hoàn tiền'),
        Text('Yêu cầu được tạo bởi quy trình hệ thống sẽ hiển thị tại đây.'),
      ],
    ),
  );
}

String _money(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(amount);
String _time(DateTime? date) => date == null
    ? 'Đang cập nhật'
    : DateFormat('dd/MM/yyyy HH:mm')
          .format(date.toUtc().add(const Duration(hours: 7)));
String _reasonLabel(String value) => switch (value) {
  'customer_cancel' => 'Khách hàng hủy',
  'facility_cancel' => 'Cơ sở hủy',
  'system_cancel' => 'Hệ thống hủy',
  'late_payment' => 'Thanh toán trễ',
  'amount_mismatch' => 'Sai lệch số tiền',
  'deposit_settlement' => 'Quyết toán tiền cọc',
  'facility_fault' => 'Lỗi từ cơ sở',
  _ => 'Lý do khác',
};
String _statusLabel(String value) => switch (value) {
  'pending_approval' => 'Chờ duyệt',
  'approved' => 'Đã duyệt',
  'paid' => 'Đã hoàn tiền',
  'rejected' => 'Bị từ chối',
  'cancelled' => 'Đã hủy',
  _ => 'Đang cập nhật',
};
