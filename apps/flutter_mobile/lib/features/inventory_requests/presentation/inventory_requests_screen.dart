import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../storage/data/storage_repository.dart';
import '../data/inventory_requests_repository.dart';

String label(dynamic v, [String fallback = '—']) =>
    v == null || '$v'.isEmpty ? fallback : '$v';
Map<String, dynamic> asMap(dynamic v) => v is Map<String, dynamic> ? v : {};
List<Map<String, dynamic>> asRows(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : [];
String failure(Object e) {
  if (e is DioException) {
    final b = e.response?.data;
    if (b is Map) {
      return '${b['message'] ?? e.message ?? 'Request failed'}${b['messageCode'] == null ? '' : ' (${b['messageCode']})'}';
    }
    return e.message ?? 'Request failed';
  }
  return '$e';
}

class InventoryRequestsScreen extends StatefulWidget {
  const InventoryRequestsScreen({super.key, required this.dio});
  final Dio dio;
  @override
  State<InventoryRequestsScreen> createState() =>
      _InventoryRequestsScreenState();
}

class _InventoryRequestsScreenState extends State<InventoryRequestsScreen> {
  late final InventoryRequestsRepository repo = InventoryRequestsRepository(
    widget.dio,
  );
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  String? type, status;
  Map<String, dynamic>? contractFilter;
  DateTimeRange? dateRange;
  int page = 1;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> load() => repo.list(
    page: page,
    filters: {
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (contractFilter != null) 'contractId': contractFilter!['id'],
      if (dateRange != null)
        'startDate': dateRange!.start.toUtc().toIso8601String(),
      if (dateRange != null)
        'endDate': dateRange!.end
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1))
            .toUtc()
            .toIso8601String(),
      if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
    },
  );
  void reload({bool first = false}) => setState(() {
    if (first) page = 1;
    future = load();
  });
  Future<void> openDetail(String id, {Map<String, dynamic>? initial}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RequestDetailScreen(repo: repo, id: id, initial: initial),
      ),
    );
    if (mounted) reload();
  }

  Future<void> create(String kind) async {
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateRequest(dio: widget.dio, type: kind),
      ),
    );
    if (created != null && mounted) {
      reload(first: true);
      await openDetail('${created['id']}', initial: created);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventory requests')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      onSubmitted: (_) => reload(first: true),
                      decoration: InputDecoration(
                        labelText: 'Search requests',
                        suffixIcon: IconButton(
                          onPressed: () => reload(first: true),
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Type',
                    onSelected: (v) {
                      type = v == 'all' ? null : v;
                      reload(first: true);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All types'),
                      ),
                      for (final v in ['inbound', 'outbound'])
                        PopupMenuItem(value: v, child: Text(v)),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Status',
                    onSelected: (v) {
                      status = v == 'all' ? null : v;
                      reload(first: true);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All statuses'),
                      ),
                      for (final v in [
                        'pending',
                        'pending_confirmation',
                        'processing',
                        'ready_to_putaway',
                        'completed',
                        'disputed',
                        'cancelled',
                        'expired',
                      ])
                        PopupMenuItem(value: v, child: Text(v)),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _Picker(
                            dio: widget.dio,
                            path: '/contracts',
                            filters: const {},
                          ),
                        ),
                      );
                      if (result != null && mounted) {
                        contractFilter = result;
                        reload(first: true);
                      }
                    },
                    child: Text(
                      contractFilter == null
                          ? 'Contract'
                          : label(contractFilter!['contractCode']),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final result = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (result != null && mounted) {
                        dateRange = result;
                        reload(first: true);
                      }
                    },
                    child: Text(
                      dateRange == null
                          ? 'Dates'
                          : '${MaterialLocalizations.of(context).formatShortDate(dateRange!.start)} – ${MaterialLocalizations.of(context).formatShortDate(dateRange!.end)}',
                    ),
                  ),
                  if (contractFilter != null || dateRange != null)
                    TextButton(
                      onPressed: () {
                        contractFilter = null;
                        dateRange = null;
                        reload(first: true);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => create('inbound'),
                      child: const Text('New inbound'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => create('outbound'),
                      child: const Text('New outbound'),
                    ),
                  ),
                ],
              ),
              if (type != null || status != null)
                Text(
                  'Filters: ${type ?? 'all types'} · ${status ?? 'all statuses'}',
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
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
                      '${failure(s.error!)}\nRetry',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final rows = asRows(s.data?['items']);
              final next = asMap(s.data?['pagination'])['hasNextPage'] == true;
              return Column(
                children: [
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: TextButton(
                              onPressed: reload,
                              child: const Text('No requests. Refresh'),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              return Card(
                                child: ListTile(
                                  title: Text(label(r['requestCode'])),
                                  subtitle: Text(
                                    '${label(r['type'])} · ${label(r['status'])}\n${label(r['facilityName'])} · ${label(r['createdAt'])}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => openDetail('${r['id']}'),
                                ),
                              );
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
                                reload();
                              }
                            : null,
                        child: const Text('Previous'),
                      ),
                      Text('Page $page'),
                      TextButton(
                        onPressed: next
                            ? () {
                                page++;
                                reload();
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
        ),
      ],
    ),
  );
}

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.repo,
    required this.id,
    this.initial,
  });
  final InventoryRequestsRepository repo;
  final String id;
  final Map<String, dynamic>? initial;
  @override
  State<RequestDetailScreen> createState() => _RequestDetailState();
}

class _RequestDetailState extends State<RequestDetailScreen> {
  late Future<Map<String, dynamic>> future;
  String? oneTimeOtp;
  bool busy = false;
  Timer? expiryTimer;
  DateTime? scheduledExpiry;
  bool expiredByTimer = false;

  @override
  void dispose() {
    expiryTimer?.cancel();
    super.dispose();
  }

  void scheduleExpiry(DateTime? expiry) {
    if (expiry == scheduledExpiry) return;
    expiryTimer?.cancel();
    scheduledExpiry = expiry;
    expiredByTimer = false;
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      expiryTimer = Timer(expiry.difference(DateTime.now()), () {
        if (mounted) {
          setState(() {
            oneTimeOtp = null;
            expiredByTimer = true;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    oneTimeOtp = initial?['rawOtpCode']?.toString();
    future = initial == null
        ? widget.repo.detail(widget.id)
        : Future.value(initial);
  }

  void reload() => setState(() => future = widget.repo.detail(widget.id));
  Future<void> action(
    Future<Map<String, dynamic>> Function() call, {
    bool otp = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await call();
      if (!mounted) return;
      if (otp) {
        final raw = result['rawOtpCode']?.toString();
        setState(() => oneTimeOtp = raw);
        await widget.repo.detail(widget.id).then((v) {
          if (mounted) setState(() => future = Future.value(v));
        });
      } else {
        setState(() {
          oneTimeOtp = null;
          future = Future.value(result);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> prompt(String title, {int min = 0, int max = 500}) async {
    final c = TextEditingController();
    String? validation;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: c,
            maxLength: max,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: min > 0 ? 'Reason required' : 'Reason (optional)',
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
                final v = c.text.trim();
                if (v.length < min) {
                  setDialog(
                    () => validation = 'At least $min characters required',
                  );
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Request details'),
      actions: [
        IconButton(
          onPressed: busy ? null : reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
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
                '${failure(s.error!)}\nRetry',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final r = s.data!;
        final type = '${r['type']}';
        final status = '${r['status']}';
        final expiry = DateTime.tryParse('${r['expiresAt'] ?? ''}');
        scheduleExpiry(expiry);
        final valid =
            !expiredByTimer &&
            (expiry == null || expiry.isAfter(DateTime.now()));
        final qr = r['pickupQrPayload']?.toString();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            Text(
              label(r['requestCode']),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            _field('Type', type),
            _field('Status', status),
            _field('Facility', r['facilityName']),
            _field('Storage unit', r['unitNumber']),
            _field('Expires', r['expiresAt']),
            if (r['isAutoConfirmed'] == true)
              const ListTile(title: Text('Automatically confirmed')),
            if (status == 'pending' && valid && qr != null && qr.isNotEmpty)
              Center(
                child: QrImageView(
                  data: qr,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            if (oneTimeOtp != null && status == 'pending' && valid)
              Card(
                child: ListTile(
                  title: const Text('One-time OTP'),
                  subtitle: Text(oneTimeOtp!),
                  trailing: const Icon(Icons.lock_outline),
                ),
              ),
            if (oneTimeOtp != null && status == 'pending' && valid)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Show this OTP now. It cannot be retrieved again; regenerate it if needed.'),
              ),
            if (status == 'pending' && !valid)
              const ListTile(
                title: Text(
                  'This request has passed its expiry time. Refresh for its current status.',
                ),
              ),
            Text('Items', style: Theme.of(context).textTheme.titleLarge),
            for (final item in asRows(r['items']))
              Card(
                child: ListTile(
                  title: Text(
                    '${label(item['name'])} · ${label(item['skuCode'])}',
                  ),
                  subtitle: Text(
                    'Requested ${label(item['quantity'])} · Actual ${label(item['actualQuantity'])} · Difference ${label(item['discrepancyQuantity'])}\nRack ${label(item['rackCode'])} · Tier ${label(item['tierNumber'])}',
                  ),
                  isThreeLine: true,
                ),
              ),
            if (asMap(r['transporterInfo']).isNotEmpty)
              _field(
                'Transporter',
                '${label(asMap(r['transporterInfo'])['name'])} · ${label(asMap(r['transporterInfo'])['phoneNumber'])}',
              ),
            if (r['staffNotes'] != null) _field('Staff notes', r['staffNotes']),
            if (r['discrepancyReason'] != null)
              _field('Discrepancy', r['discrepancyReason']),
            if (r['customerFeedbackNotes'] != null)
              _field('Customer feedback', r['customerFeedbackNotes']),
            for (final key in ['evidenceImages', 'discrepancyImages'])
              if (r[key] is List && (r[key] as List).isNotEmpty) ...[
                Text(
                  key == 'evidenceImages' ? 'Evidence' : 'Discrepancy images',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final url in r[key] as List)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Image.network(
                      '$url',
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Text('Could not load image'),
                    ),
                  ),
              ],
            if (r['signatureUrl'] != null) ...[
              const Text('Signature'),
              Image.network(
                '${r['signatureUrl']}',
                height: 120,
                errorBuilder: (_, _, _) =>
                    const Text('Could not load signature'),
              ),
            ],
            if (status == 'pending' && valid)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => action(
                        () => widget.repo.regenerate(widget.id),
                        otp: true,
                      ),
                child: const Text('Regenerate OTP'),
              ),
            if (status == 'pending')
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final reason = await prompt('Cancel request');
                        if (reason != null) {
                          await action(
                            () => widget.repo.cancel(widget.id, type, reason),
                          );
                        }
                      },
                child: const Text('Cancel request'),
              ),
            if (type == 'inbound' && status == 'pending_confirmation') ...[
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Confirm receipt?'),
                            content: const Text(
                              'Confirm the received items and evidence.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Back'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await action(() => widget.repo.confirm(widget.id));
                        }
                      },
                child: const Text('Confirm receipt'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final reason = await prompt(
                          'Dispute receipt',
                          min: 5,
                          max: 1000,
                        );
                        if (reason != null) {
                          await action(
                            () => widget.repo.dispute(widget.id, reason),
                          );
                        }
                      },
                child: const Text('Dispute'),
              ),
            ],
          ],
        );
      },
    ),
  );
  Widget _field(String title, dynamic value) =>
      ListTile(dense: true, title: Text(title), subtitle: Text(label(value)));
}

class _CreateRequest extends StatefulWidget {
  const _CreateRequest({required this.dio, required this.type});
  final Dio dio;
  final String type;
  @override
  State<_CreateRequest> createState() => _CreateRequestState();
}

class _CreateRequestState extends State<_CreateRequest> {
  late final repo = InventoryRequestsRepository(widget.dio);
  Map<String, dynamic>? contract;
  final items = <Map<String, dynamic>>[];
  bool busy = false;
  final name = TextEditingController(),
      phone = TextEditingController(),
      plate = TextEditingController(),
      company = TextEditingController(),
      notes = TextEditingController();
  @override
  void dispose() {
    for (final c in [name, phone, plate, company, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>?> pick(
    String path, {
    Map<String, dynamic> filters = const {},
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _Picker(dio: widget.dio, path: path, filters: filters),
    ),
  );
  Future<void> addItem() async {
    if (contract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an active contract first.')),
      );
      return;
    }
    final outbound = widget.type == 'outbound';
    final selected = await pick(
      outbound ? '/customer-inventories' : '/customer-skus',
      filters: outbound
          ? {
              'contractId': contract!['id'],
              'status': 'normal',
              'minQuantity': 1,
            }
          : {},
    );
    if (selected == null || !mounted) return;
    final sku = outbound ? asMap(selected['sku']) : selected;
    final skuId = outbound ? selected['skuId'] : selected['id'];
    final rack = selected['storageRackId'], tier = selected['rackTierId'];
    if (outbound &&
        (rack == null ||
            tier == null ||
            (selected['availableQuantity'] as num? ?? 0) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select available normal stock with a rack and tier.'),
        ),
      );
      return;
    }
    if (items.any(
      (i) =>
          i['skuId'] == skuId &&
          i['storageRackId'] == rack &&
          i['rackTierId'] == tier,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is already selected.')),
      );
      return;
    }
    final c = TextEditingController();
    String? error;
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Quantity · ${label(sku['name'])}'),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: outbound
                  ? 'Available: ${selected['availableQuantity']}'
                  : 'Quantity',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(c.text);
                if (n == null ||
                    n <= 0 ||
                    (outbound && n > (selected['availableQuantity'] as num))) {
                  setDialog(() => error = 'Enter a valid available quantity');
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (qty == null || !mounted) return;
    setState(
      () => items.add({
        'skuId': skuId,
        'quantity': qty,
        if (outbound) 'storageRackId': rack,
        if (outbound) 'rackTierId': tier,
        '_name': label(sku['name']),
        '_location': outbound
            ? '${label(asMap(selected['storageRack'])['rackCode'])} / ${label(asMap(selected['rackTier'])['tierCode'])}'
            : '',
      }),
    );
  }

  Future<void> chooseLocation(Map<String, dynamic> item) async {
    final unitId = contract?['storageUnitId']?.toString();
    if (unitId == null || unitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage unit is unavailable.')),
      );
      return;
    }
    final future = StorageRepository(widget.dio)
        .get('/customer-inventories/unit/${Uri.encodeComponent(unitId)}/tree');
    final selection = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preferred location'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return Text(failure(snapshot.error!));
              final racks = asRows(snapshot.data?['racks'])
                  .where((r) => r['isMine'] != false)
                  .toList();
              return ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('No preference'),
                    onTap: () => Navigator.pop(ctx, <String, dynamic>{}),
                  ),
                  for (final rack in racks)
                    for (final tier in asRows(rack['tiers']))
                      if (rack['id'] != null && tier['id'] != null)
                        ListTile(
                          title: Text(
                            '${label(rack['rackCode'])} / ${label(tier['tierCode'])}',
                          ),
                          subtitle: Text(label(tier['status'])),
                          onTap: () => Navigator.pop(ctx, {
                            'storageRackId': rack['id'],
                            'rackTierId': tier['id'],
                            '_location':
                                '${label(rack['rackCode'])} / ${label(tier['tierCode'])}',
                          }),
                        ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (selection == null || !mounted) return;
    if (items.any(
      (other) =>
          !identical(other, item) &&
          other['skuId'] == item['skuId'] &&
          other['rackTierId'] == selection['rackTierId'],
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This SKU and location are already selected.'),
        ),
      );
      return;
    }
    setState(() {
      item.remove('storageRackId');
      item.remove('rackTierId');
      item['_location'] = '';
      item.addAll(selection);
    });
  }

  Future<void> submit() async {
    if (contract == null || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a contract and at least one item.'),
        ),
      );
      return;
    }
    final hasTransport = [
      name,
      phone,
      plate,
      company,
    ].any((c) => c.text.trim().isNotEmpty);
    if (hasTransport &&
        (name.text.trim().isEmpty ||
            phone.text.trim().length < 8 ||
            phone.text.trim().length > 20)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Transporter name and a phone number of 8–20 characters are required.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit request?'),
        content: Text('Create this ${widget.type} request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final body = <String, dynamic>{
      'contractId': contract!['id'],
      'items': [
        for (final i in items)
          {
            for (final entry in i.entries)
              if (!entry.key.startsWith('_')) entry.key: entry.value,
          },
      ],
      if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      if (hasTransport)
        'transporterInfo': {
          'name': name.text.trim(),
          'phoneNumber': phone.text.trim(),
          if (plate.text.trim().isNotEmpty) 'vehiclePlate': plate.text.trim(),
          if (company.text.trim().isNotEmpty)
            'deliveryCompany': company.text.trim(),
        },
    };
    setState(() => busy = true);
    try {
      final result = await repo.create(widget.type, body);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('New ${widget.type} request')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Active contract'),
          subtitle: Text(label(contract?['contractCode'], 'Select contract')),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy
              ? null
              : () async {
                  final c = await pick(
                    '/contracts',
                    filters: {'status': 'active'},
                  );
                  if (c != null && mounted) {
                    setState(() {
                      contract = c;
                      items.clear();
                    });
                  }
                },
        ),
        for (final i in items)
          Card(
            child: ListTile(
              title: Text('${i['_name']} · ${i['quantity']}'),
              subtitle: Text(
                i['_location'] == ''
                    ? 'No preferred location'
                    : '${i['_location']}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.type == 'inbound')
                    IconButton(
                      onPressed: busy ? null : () => chooseLocation(i),
                      icon: const Icon(Icons.place_outlined),
                      tooltip: 'Preferred location',
                    ),
                  IconButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => items.remove(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : addItem,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
        const SizedBox(height: 16),
        Text(
          'Transporter (optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final spec in [
          (name, 'Name', 100),
          (phone, 'Phone', 20),
          (plate, 'Vehicle plate', 30),
          (company, 'Delivery company', 100),
          (notes, 'Notes', 500),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: spec.$1,
              maxLength: spec.$3,
              decoration: InputDecoration(labelText: spec.$2),
            ),
          ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Submitting…' : 'Submit request'),
        ),
      ],
    ),
  );
}

class _Picker extends StatefulWidget {
  const _Picker({required this.dio, required this.path, required this.filters});
  final Dio dio;
  final String path;
  final Map<String, dynamic> filters;
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final repo = StorageRepository(widget.dio);
  late Future<StoragePage> future;
  int page = 1;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<StoragePage> load() => repo.list(
    widget.path,
    page: page,
    filters: {
      ...widget.filters,
      if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
    },
  );
  void reload() => setState(() => future = load());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Select')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            onSubmitted: (_) {
              page = 1;
              reload();
            },
            decoration: InputDecoration(
              labelText: 'Search',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  page = 1;
                  reload();
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<StoragePage>(
            future: future,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: reload,
                    child: Text('${failure(s.error!)}\nRetry'),
                  ),
                );
              }
              final d = s.data!;
              return Column(
                children: [
                  Expanded(
                    child: d.items.isEmpty
                        ? const Center(child: Text('No results.'))
                        : ListView.builder(
                            itemCount: d.items.length,
                            itemBuilder: (context, index) {
                              final i = d.items[index];
                              final stock =
                                  widget.path == '/customer-inventories';
                              final sku = stock ? asMap(i['sku']) : i;
                              final title = widget.path == '/contracts'
                                  ? label(i['contractCode'])
                                  : label(sku['name']);
                              return ListTile(
                                title: Text(title),
                                subtitle: Text(
                                  stock
                                      ? 'Available ${label(i['availableQuantity'])} · ${label(asMap(i['storageRack'])['rackCode'])} / ${label(asMap(i['rackTier'])['tierCode'])}'
                                      : label(i['skuCode'] ?? i['status']),
                                ),
                                onTap: () => Navigator.pop(context, i),
                              );
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
                                reload();
                              }
                            : null,
                        child: const Text('Previous'),
                      ),
                      Text('Page $page'),
                      TextButton(
                        onPressed: d.hasNextPage
                            ? () {
                                page++;
                                reload();
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
        ),
      ],
    ),
  );
}
