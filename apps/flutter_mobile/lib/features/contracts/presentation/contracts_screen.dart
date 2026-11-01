import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/contract_repository.dart';
import '../../payments/data/models/payment.dart';
import '../../payments/data/repositories/payment_repository.dart';
import 'contract_detail_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({
    super.key,
    required this.dio,
    this.onContractsChanged,
  });
  final Dio dio;
  final VoidCallback? onContractsChanged;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  late final ContractRepository _repo = ContractRepository(widget.dio);
  late final PaymentRepository _paymentRepo = PaymentRepository(widget.dio);
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.list());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hợp đồng của tôi')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, state) {
        if (state.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError) {
          return AppErrorState(
            message: 'Không thể tải hợp đồng. Vui lòng kiểm tra kết nối.',
            onRetry: () => setState(() => _future = _repo.list()),
          );
        }
        final contracts = state.data ?? const <Map<String, dynamic>>[];
        if (contracts.isEmpty) {
          return const AppEmptyState(
            icon: Icons.description_outlined,
            title: 'Chưa có hợp đồng',
            message: 'Hợp đồng kho của bạn sẽ hiển thị tại đây.',
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            itemCount: contracts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: AppSectionHeader(
                    title: 'Hành trình hợp đồng',
                    subtitle: 'Theo dõi ký kết, thanh toán và nhận kho',
                  ),
                );
              }
              final contract = contracts[index - 1];
              final facility = _map(contract['facility']);
              final unit = _map(contract['storageUnit']);
              final facilityName = _text(facility?['name']);
              final unitName =
                  _text(unit?['unitNumber']) ?? _text(unit?['code']);
              final code = _text(contract['contractCode']) ?? 'Hợp đồng kho';
              final status = _statusLabel(contract['status']);
              final next = _nextAction(contract);
              final rental = _text(contract['rentalPrice']);
              final billing = _text(contract['billingUnit']);
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openDetail(contract),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: AppTheme.primaryEmerald,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _StatusBadge(label: status),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          facilityName ?? 'Cơ sở lưu trữ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unitName == null
                              ? 'Chưa có thông tin kho'
                              : 'Kho $unitName',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_text(contract['startDate']) != null ||
                            _text(contract['endDate']) != null) ...[
                          const SizedBox(height: 12),
                          _DateRange(
                            start: contract['startDate'],
                            end: contract['endDate'],
                          ),
                        ],
                        if (rental != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tiền thuê: $rental${billing == null ? '' : ' / ${_billingLabel(billing)}'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.lightMint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: AppTheme.primaryEmerald,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  next,
                                  style: const TextStyle(
                                    color: AppTheme.primaryDarkGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _openDetail(contract),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Xem chi tiết'),
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

  Future<void> _openDetail(Map<String, dynamic> contract) async {
    final id = _text(contract['id']);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hợp đồng chưa có mã định danh hợp lệ.')),
      );
      return;
    }
    try {
      final detail = await _repo.detail(id);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ContractDetailScreen(
            contract: detail,
            repository: _repo,
            paymentRepository: _paymentRepo,
            onContractChanged: widget.onContractsChanged,
            onViewPayment: (Payment payment) async {
              await context.push(
                '/payments/${Uri.encodeComponent(payment.id)}/view?contractId=${Uri.encodeComponent(id)}',
              );
            },
          ),
        ),
      );
      if (mounted) {
        widget.onContractsChanged?.call();
        setState(() => _future = _repo.list());
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải chi tiết hợp đồng. Vui lòng thử lại.'),
        ),
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 130),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.lightMint,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppTheme.primaryEmerald,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DateRange extends StatelessWidget {
  const _DateRange({this.start, this.end});
  final Object? start;
  final Object? end;
  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.tryParse('$start');
    final endDate = DateTime.tryParse('$end');
    final localizations = MaterialLocalizations.of(context);
    final range = [
      if (startDate != null)
        localizations.formatMediumDate(startDate.toLocal()),
      if (endDate != null) localizations.formatMediumDate(endDate.toLocal()),
    ].join(' – ');
    return Row(
      children: [
        const Icon(
          Icons.calendar_month_outlined,
          size: 17,
          color: AppTheme.secondaryText,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(range, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;
String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

String _statusLabel(Object? value) => switch ('$value'.toLowerCase()) {
  'draft' => 'Bản nháp',
  'active' => 'Đang hoạt động',
  'overdue' => 'Quá hạn',
  'completed' => 'Đã hoàn tất',
  'cancelled' => 'Đã hủy',
  'terminated' => 'Đã chấm dứt',
  _ => 'Đang xử lý',
};
String _billingLabel(String value) => switch (value.toLowerCase()) {
  'month' || 'monthly' => 'tháng',
  'day' || 'daily' => 'ngày',
  'year' || 'yearly' => 'năm',
  _ => value,
};
String _nextAction(Map<String, dynamic> contract) {
  if (contract['status'] == 'active') {
    return 'Hợp đồng đang hoạt động';
  }
  if (contract['customerSigned'] == true && contract['staffSigned'] != true) {
    return 'Chờ nhân viên hoàn tất thủ tục nhận kho';
  }
  if (contract['customerSigned'] != true && contract['status'] == 'draft') {
    return 'Xem lại hợp đồng và xác nhận chữ ký';
  }
  if (contract['staffSigned'] == true && contract['customerSigned'] == true) {
    return 'Đang cập nhật trạng thái hợp đồng';
  }
  return 'Theo dõi cập nhật từ cơ sở';
}
