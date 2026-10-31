import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../core/widgets/app_ui.dart';
import '../data/contract_repository.dart';

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
  late final ContractRepository _repo;
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _repo = ContractRepository(widget.dio);
    _future = _repo.list();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My storages & contracts')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return AppErrorState(
            message: 'Contracts could not be loaded. Check your connection and retry.',
            onRetry: () => setState(() => _future = _repo.list()),
          );
        }
        final rows = s.data ?? const [];
        if (rows.isEmpty) {
          return const AppEmptyState(
            icon: Icons.description_outlined,
            title: 'No contracts yet',
            message: 'Your active storage contracts will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: rows.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppSectionHeader(
                  title: 'Your storage contracts',
                  subtitle: 'Review terms and active storage periods',
                ),
              );
            }
            final c = rows[i - 1];
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
    try {
      final c = await _repo.detail(id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c['contractCode']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Status: ${c['status']}'),
              Text('Period: ${c['startDate']} – ${c['endDate']}'),
              Text('Rental: ${c['rentalPrice']} ${c['billingUnit']}'),
              if (c['customerSigned'] != true)
                FilledButton(
                  onPressed: () async {
                    try {
                      await _repo.acceptTerms(id);
                      widget.onContractsChanged?.call();
                      if (context.mounted) Navigator.pop(context);
                      if (mounted) setState(() => _future = _repo.list());
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not accept contract terms: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Accept contract terms'),
                ),
              if (c['status'] == 'active')
                OutlinedButton.icon(
                  onPressed: () => _renew(context, id, c),
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Request renewal'),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load contract: $e')));
      }
    }
  }

  Future<void> _renew(
    BuildContext sheetContext,
    String id,
    Map<String, dynamic> contract,
  ) async {
    final endDate = DateTime.tryParse('${contract['endDate']}');
    if (endDate == null) return;
    final chosen = await showDatePicker(
      context: sheetContext,
      firstDate: endDate.add(const Duration(days: 1)),
      lastDate: DateTime(endDate.year + 5),
      initialDate: DateTime(endDate.year + 1, endDate.month, endDate.day),
    );
    if (chosen == null) return;
    try {
      await _repo.renew(id, chosen);
      widget.onContractsChanged?.call();
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted) setState(() => _future = _repo.list());
    } catch (error) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text('Renewal request failed: $error')),
        );
      }
    }
  }
}
