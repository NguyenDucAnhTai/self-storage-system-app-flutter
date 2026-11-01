import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_ui.dart';
import '../data/contract_repository.dart';

class ContractSettlementScreen extends StatefulWidget {
  const ContractSettlementScreen({
    super.key,
    required this.contractId,
    required this.dio,
    this.onChanged,
  });
  final String contractId;
  final Dio dio;
  final VoidCallback? onChanged;
  @override
  State<ContractSettlementScreen> createState() =>
      _ContractSettlementScreenState();
}

class _ContractSettlementScreenState extends State<ContractSettlementScreen> {
  late final ContractRepository _repository = ContractRepository(widget.dio);
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _repository.detail(widget.contractId);
  }

  void _reload() =>
      setState(() => _future = _repository.detail(widget.contractId));

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
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khiếu nại quyết toán'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gửi khiếu nại'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    } catch (_) {
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
              : 'Chưa xác định được kết quả. Trạng thái mới nhất đã được tải; không tự gửi lại yêu cầu.';
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
