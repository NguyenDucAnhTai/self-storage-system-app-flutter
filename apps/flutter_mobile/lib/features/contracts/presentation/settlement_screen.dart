import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/contract_repository.dart';

String _value(dynamic v) => v == null || '$v'.isEmpty ? '—' : '$v';
String _money(dynamic v) => v is num
    ? NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '₫',
        decimalDigits: 0,
      ).format(v)
    : '—';
String _error(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? e.message ?? 'Request failed';
      final code = data['messageCode'];
      return code == null ? '$message' : '$message ($code)';
    }
    return e.message ?? 'Request failed';
  }
  return '$e';
}

String _status(dynamic value) => switch (value) {
  'pending_approval' => 'Pending approval',
  'approved' => 'Approved · awaiting payout',
  'paid' => 'Payout recorded',
  'rejected' => 'Rejected',
  'cancelled' => 'Cancelled',
  _ => _value(value),
};
Widget _field(String name, dynamic value) =>
    ListTile(dense: true, title: Text(name), subtitle: Text(_value(value)));

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({
    super.key,
    required this.repo,
    required this.contractId,
  });
  final ContractRepository repo;
  final String contractId;
  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late Future<Map<String, dynamic>> contract;
  late Future<Map<String, dynamic>> refunds;
  bool busy = false;
  int page = 1;
  @override
  void initState() {
    super.initState();
    contract = widget.repo.detail(widget.contractId);
    refunds = widget.repo.refunds(widget.contractId);
  }

  void reloadContract() =>
      setState(() => contract = widget.repo.detail(widget.contractId));
  void reloadRefunds() => setState(
    () => refunds = widget.repo.refunds(widget.contractId, page: page),
  );
  Future<void> action(
    Future<Map<String, dynamic>> Function() operation,
    String message,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = await operation();
      if (!mounted) return;
      setState(() => contract = Future.value(data));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm settlement?'),
        content: const Text(
          'Confirm that you accept the settlement amounts shown.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await action(
        () => widget.repo.confirmSettlement(widget.contractId),
        'Settlement confirmed.',
      );
    }
  }

  Future<void> dispute() async {
    var input = '';
    String? validation;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Dispute settlement'),
          content: TextField(
            onChanged: (value) => input = value,
            maxLength: 1000,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason',
              errorText: validation,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                final text = input.trim();
                if (text.isEmpty) {
                  update(() => validation = 'Enter a reason');
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: const Text('Submit dispute'),
            ),
          ],
        ),
      ),
    );
    if (reason != null && mounted) {
      await action(
        () => widget.repo.disputeSettlement(widget.contractId, reason),
        'Dispute submitted.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settlement & refunds')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: contract,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: reloadContract,
              child: Text(
                '${_error(s.error!)}\nRetry',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final c = s.data!;
        final canAct =
            c['status'] == 'completed' && c['settlementConfirmedAt'] == null;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            Text(
              _value(c['contractCode']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Deposit settlement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _field('Deposit', _money(c['depositAmount'])),
            _field('Damage fee', _money(c['damageFee'])),
            _field('Overdue fee', _money(c['overdueFee'])),
            _field('Amount calculated for refund', _money(c['refundAmount'])),
            _field(
              'Additional payment required',
              _money(c['additionalPaymentRequired']),
            ),
            _field('Deposit calculation status', c['depositStatus']),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'The deposit status describes the settlement calculation. Check each refund request below for payout status.',
              ),
            ),
            if (c['settlementConfirmedAt'] != null)
              _field('Settlement confirmed at', c['settlementConfirmedAt']),
            if (c['disputedAt'] != null) _field('Disputed at', c['disputedAt']),
            if (c['disputeReason'] != null &&
                '${c['disputeReason']}'.isNotEmpty)
              _field('Dispute reason', c['disputeReason']),
            if (canAct)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : confirm,
                    child: const Text('Confirm settlement'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : dispute,
                    child: const Text('Dispute'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text(
              'Refund requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: refunds,
              builder: (context, r) {
                if (r.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (r.hasError) {
                  return TextButton(
                    onPressed: reloadRefunds,
                    child: Text(
                      'Could not load refunds: ${_error(r.error!)}. Retry',
                    ),
                  );
                }
                final list = (r.data!['items'] as List)
                    .whereType<Map<String, dynamic>>()
                    .toList();
                final pagination = r.data!['pagination'] as Map;
                return Column(
                  children: [
                    if (list.isEmpty)
                      const ListTile(
                        title: Text('No refund requests on this page.'),
                      ),
                    for (final item in list)
                      Card(
                        child: ListTile(
                          title: Text(_value(item['refundCode'])),
                          subtitle: Text(
                            'Reason: ${_value(item['reason'])}\n${_status(item['status'])} · ${_money(item['amount'])}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RefundDetailScreen(
                                  repo: widget.repo,
                                  id: '${item['id']}',
                                ),
                              ),
                            );
                            if (mounted) reloadRefunds();
                          },
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: page > 1
                              ? () {
                                  page--;
                                  reloadRefunds();
                                }
                              : null,
                          child: const Text('Previous'),
                        ),
                        Text('Page $page'),
                        TextButton(
                          onPressed: pagination['hasNextPage'] == true
                              ? () {
                                  page++;
                                  reloadRefunds();
                                }
                              : null,
                          child: const Text('Next'),
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
}

class RefundDetailScreen extends StatefulWidget {
  const RefundDetailScreen({super.key, required this.repo, required this.id});
  final ContractRepository repo;
  final String id;
  @override
  State<RefundDetailScreen> createState() => _RefundDetailState();
}

class _RefundDetailState extends State<RefundDetailScreen> {
  late Future<Map<String, dynamic>> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.repo.refundDetail(widget.id);
  }

  void reload() => setState(() => future = widget.repo.refundDetail(widget.id));
  Future<void> cancel() async {
    var input = '';
    String? validation;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Cancel refund request'),
          content: TextField(
            onChanged: (value) => input = value,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason (3–500 characters)',
              errorText: validation,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                final text = input.trim();
                if (text.length < 3) {
                  update(() => validation = 'Enter at least 3 characters');
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: const Text('Cancel request'),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      final data = await widget.repo.cancelRefund(widget.id, reason);
      if (mounted) setState(() => future = Future.value(data));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Refund details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: reload,
              child: Text(
                '${_error(s.error!)}\nRetry',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final d = s.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            Text(
              _value(d['refundCode']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _field('Reason', d['reason']),
            _field('Amount', _money(d['amount'])),
            _field('Payout status', _status(d['status'])),
            if (d['refundBankName'] != null &&
                '${d['refundBankName']}'.isNotEmpty)
              _field('Bank', d['refundBankName']),
            if (d['refundAccountNumberMasked'] != null &&
                '${d['refundAccountNumberMasked']}'.isNotEmpty)
              _field('Account', d['refundAccountNumberMasked']),
            if (d['refundAccountHolder'] != null &&
                '${d['refundAccountHolder']}'.isNotEmpty)
              _field('Account holder', d['refundAccountHolder']),
            if (d['referenceCode'] != null &&
                '${d['referenceCode']}'.isNotEmpty)
              _field('Payout reference', d['referenceCode']),
            if (d['rejectionReason'] != null &&
                '${d['rejectionReason']}'.isNotEmpty)
              _field('Rejection reason', d['rejectionReason']),
            if (d['cancellationReason'] != null &&
                '${d['cancellationReason']}'.isNotEmpty)
              _field('Cancellation reason', d['cancellationReason']),
            if (d['note'] != null && '${d['note']}'.isNotEmpty)
              _field('Note', d['note']),
            for (final entry in {
              'Requested at': d['requestedAt'],
              'Approved at': d['approvedAt'],
              'Paid at': d['paidAt'],
              'Rejected at': d['rejectedAt'],
              'Cancelled at': d['cancelledAt'],
            }.entries)
              if (entry.value != null) _field(entry.key, entry.value),
            if (d['proofImageUrl'] != null &&
                '${d['proofImageUrl']}'.isNotEmpty) ...[
              const Text('Payout proof'),
              Image.network(
                '${d['proofImageUrl']}',
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('Could not load proof image'),
              ),
            ],
            if (d['status'] == 'pending_approval')
              OutlinedButton(
                onPressed: busy ? null : cancel,
                child: const Text('Cancel refund request'),
              ),
          ],
        );
      },
    ),
  );
}
