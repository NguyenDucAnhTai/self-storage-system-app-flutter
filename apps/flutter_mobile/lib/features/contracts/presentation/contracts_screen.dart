import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/contract_repository.dart';
import '../../payments/data/models/payment.dart';
import '../../payments/data/repositories/payment_repository.dart';
import 'contract_detail_screen.dart';
import 'settlement_screen.dart';

String _errorText(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map) {
      final message = body['message'] ?? error.message ?? 'Request failed';
      final code = body['messageCode'];
      return code == null ? '$message' : '$message ($code)';
    }
    return error.message ?? 'Request failed';
  }
  return '$error';
}

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

  void _reload() => setState(() => _future = _repo.list());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hợp đồng của tôi')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('Could not load contracts. Retry'),
            ),
          );
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const Center(child: Text('No storage contracts yet.'));
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

  Future<void> _detail(String id) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContractDetail(repo: _repo, id: id),
    );
    if (mounted) _reload();
  }
}

class _ContractDetail extends StatefulWidget {
  const _ContractDetail({required this.repo, required this.id});
  final ContractRepository repo;
  final String id;
  @override
  State<_ContractDetail> createState() => _ContractDetailState();
}

class _ContractDetailState extends State<_ContractDetail> {
  late Future<Map<String, dynamic>> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.repo.detail(widget.id);
  }

  void reload() => setState(() => future = widget.repo.detail(widget.id));

  Future<void> runAction(
    Future<Map<String, dynamic>> Function() action,
    String message,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => future = Future.value(updated));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestRenewal(Map<String, dynamic> contract) async {
    final end = DateTime.tryParse('${contract['endDate'] ?? ''}');
    if (end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract end date is unavailable.')),
      );
      return;
    }
    final localEnd = end.toLocal();
    final first = DateTime(localEnd.year, localEnd.month, localEnd.day + 1);
    final last = DateTime(first.year + 100, first.month, first.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last,
    );
    if (selected == null || !mounted) return;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request renewal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Requested end date: ${MaterialLocalizations.of(ctx).formatMediumDate(selected)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 1000,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (result != true || !mounted) return;
    await runAction(
      () => widget.repo.renew(widget.id, selected.toUtc(), note: note),
      'Renewal request submitted. Awaiting approval.',
    );
  }

  Future<void> sign(Map<String, dynamic> addendum) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign renewal?'),
        content: const Text(
          'Confirm that you accept this renewal request. The renewal takes effect after the facility signs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm and sign'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runAction(
      () => widget.repo.signAddendum(widget.id, '${addendum['id']}'),
      'Signed. Awaiting facility signature.',
    );
  }

  Future<void> cancel(Map<String, dynamic> addendum) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel renewal'),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (required)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await runAction(
      () => widget.repo.cancelAddendum(widget.id, '${addendum['id']}', reason),
      'Renewal request cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.9,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Contract details'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: reload,
                child: Text(
                  'Could not load contract: ${_errorText(snapshot.error!)}. Retry',
                ),
              ),
            );
          }
          final c = snapshot.data!;
          final status = '${c['status'] ?? ''}';
          final addendums =
              (c['addendums'] is List ? c['addendums'] as List : const [])
                  .whereType<Map<String, dynamic>>()
                  .where((a) => a['type'] == 'renew')
                  .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              Text(
                '${c['contractCode'] ?? 'Contract'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Status: $status'),
              Text('Period: ${c['startDate'] ?? '—'} – ${c['endDate'] ?? '—'}'),
              Text(
                'Rental: ${c['rentalPrice'] ?? '—'} ${c['billingUnit'] ?? ''}',
              ),
              if (c['customerSigned'] != true)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            await widget.repo.acceptTerms(widget.id);
                            if (mounted) reload();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_errorText(e))),
                              );
                            }
                          }
                        },
                  child: const Text('Accept contract terms'),
                ),
              if (status == 'active' || status == 'overdue')
                OutlinedButton.icon(
                  onPressed: busy ? null : () => requestRenewal(c),
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Request renewal'),
                ),
              if (status == 'completed')
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SettlementScreen(
                                repo: widget.repo,
                                contractId: widget.id,
                              ),
                            ),
                          );
                          if (mounted) reload();
                        },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Settlement & refunds'),
                ),
              const SizedBox(height: 20),
              Text(
                'Renewal addendums',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (addendums.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No renewal requests yet.'),
                ),
              for (final a in addendums)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a['addendumCode'] ?? 'Renewal'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Status: ${a['status'] ?? '—'}'),
                        Text('Previous end: ${a['previousEndDate'] ?? '—'}'),
                        Text('Requested end: ${a['newEndDate'] ?? '—'}'),
                        Text(
                          'Customer signed: ${a['customerSigned'] == true ? 'Yes' : 'No'}',
                        ),
                        Text(
                          'Facility signed: ${a['staffSigned'] == true ? 'Yes' : 'No'}',
                        ),
                        if (a['notes'] != null && '${a['notes']}'.isNotEmpty)
                          Text('Notes: ${a['notes']}'),
                        if (a['rejectionReason'] != null &&
                            '${a['rejectionReason']}'.isNotEmpty)
                          Text('Rejection reason: ${a['rejectionReason']}'),
                        if (a['cancellationReason'] != null &&
                            '${a['cancellationReason']}'.isNotEmpty)
                          Text(
                            'Cancellation reason: ${a['cancellationReason']}',
                          ),
                        if (a['status'] == 'draft' &&
                            a['customerSigned'] != true &&
                            (status == 'active' || status == 'overdue'))
                          FilledButton(
                            onPressed: busy ? null : () => sign(a),
                            child: const Text('Confirm and sign'),
                          ),
                        if (a['status'] == 'draft' ||
                            a['status'] == 'pending_approval')
                          TextButton(
                            onPressed: busy ? null : () => cancel(a),
                            child: const Text('Cancel renewal'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
