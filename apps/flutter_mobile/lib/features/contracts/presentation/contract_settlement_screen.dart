import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_ui.dart';
import '../data/contract_repository.dart';

class ContractSettlementScreen extends StatefulWidget {
  const ContractSettlementScreen({
    super.key,
    required this.contractId,
    this.dio,
    this.repository,
    this.onChanged,
  }) : assert(dio != null || repository != null);
  final String contractId;
  final Dio? dio;
  final ContractRepository? repository;
  final VoidCallback? onChanged;
  @override
  State<ContractSettlementScreen> createState() =>
      _ContractSettlementScreenState();
}

class _ContractSettlementScreenState extends State<ContractSettlementScreen> {
  late final ContractRepository _repository =
      widget.repository ?? ContractRepository(widget.dio!);
  late Future<Map<String, dynamic>> _future;
  late Future<Map<String, dynamic>> _refunds;
  int _refundPage = 1;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _repository.detail(widget.contractId);
    _refunds = _repository.refunds(widget.contractId);
  }

  void _reload() =>
      setState(() => _future = _repository.detail(widget.contractId));

  void _reloadRefunds() => setState(
    () => _refunds = _repository.refunds(widget.contractId, page: _refundPage),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quyết toán tiền cọc')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppErrorState(
            message: 'Không thể tải quyết toán từ máy chủ.',
            onRetry: _reload,
          );
        }
        final contract = snapshot.data!;
        final eligible =
            contract['status'] == 'completed' &&
            contract['settlementConfirmedAt'] == null &&
            contract['depositStatus'] != 'disputed';
        final facility = contract['facility'];
        final facilityName = facility is Map
            ? facility['name']?.toString()
            : null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract['contractCode']?.toString() ?? 'Hợp đồng',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (facilityName?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(facilityName!),
                    ],
                    const SizedBox(height: 12),
                    _row('Tiền cọc', contract['depositAmount']),
                    _row(
                      'Trạng thái tiền cọc',
                      _depositLabel(contract['depositStatus']?.toString()),
                    ),
                    _row('Phí hư hỏng', contract['damageFee']),
                    _row('Phí quá hạn', contract['overdueFee']),
                    _row('Số tiền bị khấu trừ', contract['forfeitedAmount']),
                    _row('Số tiền hoàn theo máy chủ', contract['refundAmount']),
                    _row(
                      'Cần thanh toán thêm',
                      contract['additionalPaymentRequired'],
                    ),
                    if (contract['inspectionNotes']?.toString().isNotEmpty ==
                        true)
                      _row('Ghi chú kiểm tra', contract['inspectionNotes']),
                    if (contract['disputeReason']?.toString().isNotEmpty ==
                        true)
                      _row('Nội dung khiếu nại', contract['disputeReason']),
                    if (contract['settlementConfirmedAt'] != null)
                      _row(
                        'Đã xác nhận lúc',
                        _time(contract['settlementConfirmedAt']),
                      ),
                    if (contract['disputedAt'] != null)
                      _row(
                        'Đã gửi khiếu nại lúc',
                        _time(contract['disputedAt']),
                      ),
                  ],
                ),
              ),
            ),
            if (contract['status'] != 'completed')
              const _Notice(
                text: 'Quyết toán chỉ khả dụng khi hợp đồng đã hoàn tất theo trạng thái máy chủ.',
              ),
            if (contract['depositStatus'] == 'disputed')
              const _Notice(
                text: 'Máy chủ đã ghi nhận khiếu nại quyết toán. Vui lòng chờ cơ sở phản hồi.',
              ),
            if (eligible) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : () => _confirm(contract),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Xác nhận quyết toán'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _dispute,
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Khiếu nại quyết toán'),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _reload,
                child: const Text('Tải lại trạng thái'),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Theo dõi hoàn tiền',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _refunds,
              builder: (context, refundSnapshot) {
                if (refundSnapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (refundSnapshot.hasError || refundSnapshot.data == null) {
                  return TextButton.icon(
                    onPressed: _reloadRefunds,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Không tải được yêu cầu hoàn tiền. Thử lại',
                    ),
                  );
                }
                final data = refundSnapshot.data!;
                final items = (data['items'] as List)
                    .whereType<Map<String, dynamic>>()
                    .toList();
                final pagination = data['pagination'] as Map;
                return Column(
                  children: [
                    if (items.isEmpty)
                      const ListTile(title: Text('Chưa có yêu cầu hoàn tiền.')),
                    for (final item in items)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${item['refundCode'] ?? 'Yêu cầu hoàn tiền'}',
                          ),
                          subtitle: Text(
                            '${_refundReasonLabel(item['reason']?.toString())} · ${_refundStatusLabel(item['status']?.toString())} · ${_money(item['amount'] ?? 0)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await context.push(
                              '/refunds/${Uri.encodeComponent('${item['id']}')}',
                            );
                            if (mounted) _reloadRefunds();
                          },
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _refundPage > 1
                              ? () {
                                  _refundPage--;
                                  _reloadRefunds();
                                }
                              : null,
                          child: const Text('Trước'),
                        ),
                        Text('Trang $_refundPage'),
                        TextButton(
                          onPressed: pagination['hasNextPage'] == true
                              ? () {
                                  _refundPage++;
                                  _reloadRefunds();
                                }
                              : null,
                          child: const Text('Tiếp'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    ),
  );

  Widget _row(String label, Object? value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    final text = value is num ? _money(value) : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(child: Text(text, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Future<void> _confirm(Map<String, dynamic> contract) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận quyết toán?'),
        content: const Text(
          'Xác nhận sẽ ghi nhận bạn đồng ý với kết quả quyết toán do máy chủ cung cấp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Xem lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await _submit(() => _repository.confirmSettlement(widget.contractId));
    }
  }

  Future<void> _dispute() async {
    var reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khiếu nại quyết toán'),
        content: TextField(
          onChanged: (value) => reasonText = value,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Lý do khiếu nại',
            hintText: 'Nhập nội dung cần cơ sở xem xét',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonText.trim()),
            child: const Text('Gửi khiếu nại'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reason == null) return;
    if (reason.isEmpty || reason.length > 1000) {
      setState(
        () => _error = 'Lý do khiếu nại là bắt buộc và tối đa 1000 ký tự.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi khiếu nại?'),
        content: const Text(
          'Cơ sở sẽ xem xét lại nội dung quyết toán. Bạn không thể chỉnh sửa yêu cầu sau khi gửi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await _submit(
        () => _repository.disputeSettlement(widget.contractId, reason),
      );
    }
  }

  Future<void> _submit(Future<Map<String, dynamic>> Function() mutation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await mutation();
      if (!mounted) return;
      setState(() => _future = Future.value(response));
      widget.onChanged?.call();
    } catch (error) {
      final backendError = _backendError(error);
      // An uncertain POST is reconciled with GET; it is never resent automatically.
      try {
        final fresh = await _repository.detail(widget.contractId);
        if (!mounted) return;
        setState(() {
          _future = Future.value(fresh);
          _error =
              fresh['settlementConfirmedAt'] != null ||
                  fresh['depositStatus'] == 'disputed'
              ? null
              : 'Yêu cầu chưa được xác nhận: $backendError. Trạng thái mới nhất đã được tải; không tự gửi lại yêu cầu.';
        });
        widget.onChanged?.call();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Chưa xác định được kết quả và chưa thể đồng bộ trạng thái. Hãy tải lại trước khi thử lại.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFE5F4EE),
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
  );
}

String _money(Object value) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(value is num ? value : double.tryParse('$value') ?? 0);
String _backendError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      final code = data['messageCode']?.toString();
      if (message?.isNotEmpty == true && code?.isNotEmpty == true) {
        return '$message ($code)';
      }
      if (message?.isNotEmpty == true) return message!;
    }
    return error.message ?? 'Lỗi kết nối máy chủ';
  }
  return 'Không thể gửi yêu cầu';
}

String _time(Object? value) {
  final date = DateTime.tryParse('$value');
  return date == null
      ? 'Đang cập nhật'
      : DateFormat('dd/MM/yyyy HH:mm')
            .format(date.toUtc().add(const Duration(hours: 7)));
}

String _depositLabel(String? value) => switch (value) {
  'held' => 'Đang giữ',
  'applied' => 'Đã khấu trừ',
  'partially_refunded' => 'Hoàn một phần',
  'refunded' => 'Đã hoàn',
  'forfeited' => 'Đã mất cọc',
  'disputed' => 'Đang khiếu nại',
  _ => 'Chưa có thông tin',
};

String _refundStatusLabel(String? value) => switch (value) {
  'pending_approval' => 'Chờ duyệt',
  'approved' => 'Đã duyệt',
  'paid' => 'Đã hoàn tiền',
  'rejected' => 'Bị từ chối',
  'cancelled' => 'Đã hủy',
  _ => 'Đang cập nhật',
};

String _refundReasonLabel(String? value) => switch (value) {
  'deposit_settlement' => 'Quyết toán tiền cọc',
  'facility_fault' => 'Lỗi từ cơ sở',
  'customer_cancel' => 'Khách hàng hủy',
  'facility_cancel' => 'Cơ sở hủy',
  'system_cancel' => 'Hệ thống hủy',
  'late_payment' => 'Thanh toán trễ',
  'amount_mismatch' => 'Sai lệch số tiền',
  null || '' => 'Lý do chưa cập nhật',
  _ => 'Lý do khác',
};
