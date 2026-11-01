import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../data/contract_repository.dart';

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
  const ContractsScreen({super.key, required this.dio});
  final Dio dio;
  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  late final ContractRepository _repo;
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _repo = ContractRepository(widget.dio);
    _future = _repo.list();
  }

  void _reload() => setState(() => _future = _repo.list());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My storages & contracts')),
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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = rows[i];
            return Card(
              child: ListTile(
                title: Text('${c['contractCode'] ?? 'Contract'}'),
                subtitle: Text(
                  '${c['status'] ?? ''} · Storage unit ${c['storageUnitId'] ?? ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _detail('${c['id']}'),
              ),
            );
          },
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
