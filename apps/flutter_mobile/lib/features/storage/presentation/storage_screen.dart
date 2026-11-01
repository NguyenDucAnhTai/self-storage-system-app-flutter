import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../data/storage_repository.dart';
import '../../contracts/data/contract_repository.dart';

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : {};
List<Map<String, dynamic>> _rows(dynamic value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
String _text(dynamic value, [String fallback = '—']) =>
    value == null || '$value'.isEmpty ? fallback : '$value';
String _nested(Map<String, dynamic> value, String key, String field) =>
    _text(_map(value[key])[field]);
String _error(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map) {
      return '${body['message'] ?? 'Request failed'}${body['messageCode'] == null ? '' : ' (${body['messageCode']})'}';
    }
    return error.message ?? 'Request failed';
  }
  return '$error';
}

class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key, required this.dio});
  final Dio dio;
  @override
  Widget build(BuildContext context) {
    final repo = StorageRepository(dio);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My storage'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Inventory'),
              Tab(text: 'Movements'),
              Tab(text: 'SKUs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Overview(repo: repo),
            _PagedList(repo: repo, kind: _Kind.inventory),
            _PagedList(repo: repo, kind: _Kind.movements),
            _PagedList(repo: repo, kind: _Kind.skus),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatefulWidget {
  const _Overview({required this.repo});
  final StorageRepository repo;
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.repo.get('/customer-inventories/summary');
  }

  void reload() =>
      setState(() => future = widget.repo.get('/customer-inventories/summary'));
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _Failure(error: snapshot.error!, retry: reload);
      }
      final d = snapshot.data!;
      final categories = _rows(d['categoryBreakdown']);
      final movements = _rows(d['recentMovements']);
      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in {
                  'SKUs': d['totalSkus'],
                  'Items': d['totalQuantity'],
                  'Active contracts': d['totalActiveContracts'],
                  'Storage units': d['totalStorageUnits'],
                }.entries)
                  SizedBox(
                    width: 160,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key),
                            Text(
                              _text(entry.value),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _StorageContracts(repo: widget.repo),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Storage contracts and layouts'),
            ),
            const SizedBox(height: 20),
            Text('Categories', style: Theme.of(context).textTheme.titleLarge),
            if (categories.isEmpty)
              const ListTile(title: Text('No inventory categories yet.')),
            for (final c in categories)
              ListTile(
                title: Text(_text(c['category'])),
                subtitle: Text(
                  '${_text(c['skuCount'])} SKUs · ${_text(c['totalQuantity'])} items',
                ),
              ),
            Text(
              'Recent movements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (movements.isEmpty)
              const ListTile(title: Text('No movements yet.')),
            for (final m in movements) _MovementTile(movement: m),
          ],
        ),
      );
    },
  );
}

class _StorageContracts extends StatefulWidget {
  const _StorageContracts({required this.repo});
  final StorageRepository repo;
  @override
  State<_StorageContracts> createState() => _StorageContractsState();
}

class _StorageContractsState extends State<_StorageContracts> {
  int page = 1;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = ContractRepository(widget.repo.dio).list(page: page);
  }

  void reload() => setState(
    () => future = ContractRepository(widget.repo.dio).list(page: page),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Storage contracts')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Failure(error: snapshot.error!, retry: reload);
        }
        final all = snapshot.data!;
        final eligible = all
            .where((c) => c['status'] == 'active' || c['status'] == 'overdue')
            .toList();
        return Column(
          children: [
            Expanded(
              child: eligible.isEmpty
                  ? const Center(
                      child: Text(
                        'No active or overdue contracts on this page.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: eligible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final c = eligible[index];
                        final id = c['storageUnitId']?.toString();
                        return Card(
                          child: ListTile(
                            title: Text(_text(c['contractCode'])),
                            subtitle: Text(
                              '${_text(c['status'])} · ${_nested(c, 'storageUnit', 'unitNumber')}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: id == null || id.isEmpty
                                ? null
                                : () => _showData(
                                    context,
                                    widget.repo,
                                    '/customer-inventories/unit/${Uri.encodeComponent(id)}/tree',
                                    'Storage layout',
                                    tree: true,
                                  ),
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
                  onPressed: all.length == 20
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
  );
}

enum _Kind { inventory, movements, skus }

class _PagedList extends StatefulWidget {
  const _PagedList({required this.repo, required this.kind});
  final StorageRepository repo;
  final _Kind kind;
  @override
  State<_PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<_PagedList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final search = TextEditingController();
  String query = '';
  String? status;
  int page = 1;
  late Future<StoragePage> future;
  String get path => switch (widget.kind) {
    _Kind.inventory => '/customer-inventories',
    _Kind.movements => '/customer-inventories/movements',
    _Kind.skus => '/customer-skus',
  };
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

  Future<StoragePage> load() => widget.repo.list(
    path,
    page: page,
    filters: {
      if (query.isNotEmpty) 'search': query,
      if (status != null)
        widget.kind == _Kind.movements ? 'type' : 'status': status,
    },
  );
  void reload({bool first = false}) => setState(() {
    if (first) page = 1;
    future = load();
  });
  Future<void> openSku([Map<String, dynamic>? sku]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SkuDetail(
          repo: widget.repo,
          sku: sku,
          onRestored: () {
            if (mounted) reload(first: true);
          },
        ),
      ),
    );
    if (mounted) reload(first: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final options = switch (widget.kind) {
      _Kind.inventory => ['normal', 'temporary_holding', 'damaged', 'disputed'],
      _Kind.movements => ['in', 'out', 'move', 'adjust'],
      _Kind.skus => ['active', 'inactive'],
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    query = v.trim();
                    reload(first: true);
                  },
                  decoration: InputDecoration(
                    labelText: 'Search',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        query = search.text.trim();
                        reload(first: true);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Filter',
                onSelected: (v) {
                  status = v == 'all' ? null : v;
                  reload(first: true);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('All statuses'),
                  ),
                  for (final o in options)
                    PopupMenuItem(value: o, child: Text(o)),
                ],
                icon: Icon(
                  status == null ? Icons.filter_list : Icons.filter_alt,
                ),
              ),
            ],
          ),
        ),
        if (widget.kind == _Kind.skus)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _barcodeLookup(context, widget.repo),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Find barcode'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => openSku(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add SKU'),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<StoragePage>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Failure(error: snapshot.error!, retry: reload);
              }
              final data = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: data.items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('No results found.'),
                                TextButton(
                                  onPressed: reload,
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => reload(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: data.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = data.items[index];
                                if (widget.kind == _Kind.movements) {
                                  return Card(
                                    child: _MovementTile(movement: item),
                                  );
                                }
                                if (widget.kind == _Kind.skus) {
                                  return Card(
                                    child: ListTile(
                                      title: Text(_text(item['name'])),
                                      subtitle: Text(
                                        '${_text(item['skuCode'])} · ${_text(item['status'])}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => openSku(item),
                                    ),
                                  );
                                }
                                return Card(
                                  child: ListTile(
                                    title: Text(_nested(item, 'sku', 'name')),
                                    subtitle: Text(
                                      '${_nested(item, 'facility', 'name')} · ${_nested(item, 'storageUnit', 'unitNumber')}\nAvailable ${_text(item['availableQuantity'])} / ${_text(item['quantity'])} · ${_text(item['status'])}',
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _InventoryDetail(
                                          repo: widget.repo,
                                          id: '${item['id']}',
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
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
                        onPressed: data.hasNextPage
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
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error(error), textAlign: TextAlign.center),
          TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final Map<String, dynamic> movement;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(
      '${_text(movement['type'])} · ${_nested(movement, 'sku', 'name')}',
    ),
    subtitle: Text(
      '${_text(movement['movementCode'])} · ${_text(movement['createdAt'])}',
    ),
    trailing: Text(_text(movement['quantity'])),
  );
}

class _InventoryDetail extends StatefulWidget {
  const _InventoryDetail({required this.repo, required this.id});
  final StorageRepository repo;
  final String id;
  @override
  State<_InventoryDetail> createState() => _InventoryDetailState();
}

class _InventoryDetailState extends State<_InventoryDetail> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.repo.get(
      '/customer-inventories/${Uri.encodeComponent(widget.id)}',
    );
  }

  void reload() => setState(
    () => future = widget.repo.get(
      '/customer-inventories/${Uri.encodeComponent(widget.id)}',
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventory details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return _Failure(error: s.error!, retry: reload);
        final d = s.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _nested(d, 'sku', 'name'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            _field('SKU', _nested(d, 'sku', 'skuCode')),
            _field('Facility', _nested(d, 'facility', 'name')),
            _field('Contract', _nested(d, 'contract', 'contractCode')),
            _field('Storage unit', _nested(d, 'storageUnit', 'unitNumber')),
            _field('Rack', _nested(d, 'storageRack', 'rackCode')),
            _field('Tier', _nested(d, 'rackTier', 'tierCode')),
            _field('Quantity', d['quantity']),
            _field('Pending outbound', d['pendingOutboundQuantity']),
            _field('Available', d['availableQuantity']),
            _field('Status', d['status']),
            if (d['holdingReason'] != null)
              _field('Holding reason', d['holdingReason']),
            if (d['relatedIncidentId'] != null)
              _field('Related incident', d['relatedIncidentId']),
            if (d['storageUnitId'] != null)
              OutlinedButton.icon(
                onPressed: () => _showData(
                  context,
                  widget.repo,
                  '/customer-inventories/unit/${Uri.encodeComponent('${d['storageUnitId']}')}/tree',
                  'Storage layout',
                  tree: true,
                ),
                icon: const Icon(Icons.view_module_outlined),
                label: const Text('View storage layout'),
              ),
            if (d['skuId'] != null)
              OutlinedButton.icon(
                onPressed: () => _showData(
                  context,
                  widget.repo,
                  '/customer-inventories/sku/${Uri.encodeComponent('${d['skuId']}')}/locations',
                  'SKU locations',
                ),
                icon: const Icon(Icons.place_outlined),
                label: const Text('All locations for this SKU'),
              ),
          ],
        );
      },
    ),
  );
}

Widget _field(String label, dynamic value) =>
    ListTile(dense: true, title: Text(label), subtitle: Text(_text(value)));

void _showData(
  BuildContext context,
  StorageRepository repo,
  String path,
  String title, {
  bool tree = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          _DataScreen(repo: repo, path: path, title: title, tree: tree),
    ),
  );
}

class _DataScreen extends StatefulWidget {
  const _DataScreen({
    required this.repo,
    required this.path,
    required this.title,
    this.tree = false,
  });
  final StorageRepository repo;
  final String path;
  final String title;
  final bool tree;
  @override
  State<_DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<_DataScreen> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.repo.get(widget.path);
  }

  void reload() => setState(() => future = widget.repo.get(widget.path));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return _Failure(error: s.error!, retry: reload);
        final d = s.data!;
        if (!widget.tree) {
          final sku = _map(d['sku']);
          final locations = _rows(d['locations']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${_text(sku['name'])} · ${_text(sku['skuCode'])}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              _field('Total quantity', sku['totalQuantity']),
              if (locations.isEmpty)
                const ListTile(title: Text('No locations found.')),
              for (final l in locations)
                Card(
                  child: ListTile(
                    title: Text(
                      '${_nested(l, 'facility', 'name')} · ${_nested(l, 'storageUnit', 'unitNumber')}',
                    ),
                    subtitle: Text(
                      'Rack ${_nested(l, 'storageRack', 'rackCode')} · Tier ${_nested(l, 'rackTier', 'tierCode')}',
                    ),
                    trailing: Text(_text(l['quantity'])),
                  ),
                ),
            ],
          );
        }
        final racks = _rows(d['racks']);
        final loose = _rows(d['unrackedItems']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Unit ${_nested(d, 'storageUnit', 'unitNumber')} · ${_nested(d, 'facility', 'name')}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (racks.isEmpty) const ListTile(title: Text('No racks.')),
            for (final rack in racks)
              Card(
                child: ExpansionTile(
                  title: Text('Rack ${_text(rack['rackCode'])}'),
                  subtitle: rack['isMine'] == false
                      ? const Text('Shared rack')
                      : null,
                  children: [
                    for (final tier in _rows(rack['tiers']))
                      ExpansionTile(
                        title: Text('Tier ${_text(tier['tierCode'])}'),
                        subtitle: Text(_text(tier['status'])),
                        children: [
                          if (_rows(tier['items']).isEmpty)
                            const ListTile(title: Text('No visible items.')),
                          for (final item in _rows(tier['items']))
                            _treeItem(item),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Items without rack',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (loose.isEmpty) const ListTile(title: Text('No items.')),
            for (final item in loose) _treeItem(item),
          ],
        );
      },
    ),
  );
  Widget _treeItem(Map<String, dynamic> item) => ListTile(
    title: Text(_nested(item, 'sku', 'name')),
    subtitle: Text(
      '${_nested(item, 'sku', 'skuCode')} · ${_text(item['status'])}',
    ),
    trailing: Text(_text(item['quantity'])),
  );
}

Future<void> _barcodeLookup(
  BuildContext context,
  StorageRepository repo,
) async {
  final controller = TextEditingController();
  final barcode = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Find by barcode'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Barcode'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Find'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (!context.mounted || barcode == null || barcode.isEmpty) return;
  _showData(
    context,
    repo,
    '/customer-inventories/barcode/${Uri.encodeComponent(barcode)}/locations',
    'Barcode locations',
  );
}

class _SkuDetail extends StatefulWidget {
  const _SkuDetail({required this.repo, required this.onRestored, this.sku});
  final StorageRepository repo;
  final Map<String, dynamic>? sku;
  final VoidCallback onRestored;
  @override
  State<_SkuDetail> createState() => _SkuDetailState();
}

class _SkuDetailState extends State<_SkuDetail> {
  late Future<Map<String, dynamic>>? future;
  @override
  void initState() {
    super.initState();
    future = widget.sku == null
        ? null
        : widget.repo.get(
            '/customer-skus/${Uri.encodeComponent('${widget.sku!['id']}')}',
          );
  }

  void reload() => setState(
    () => future = widget.repo.get(
      '/customer-skus/${Uri.encodeComponent('${widget.sku!['id']}')}',
    ),
  );
  Future<void> edit([Map<String, dynamic>? sku]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SkuForm(repo: widget.repo, sku: sku),
      ),
    );
    if (saved != true || !mounted) return;
    if (sku == null) {
      Navigator.pop(context, true);
    } else {
      reload();
    }
  }

  Future<void> remove(Map<String, dynamic> sku) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete SKU?'),
        content: Text(
          'Delete ${_text(sku['name'])}? SKUs with active inventory cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final id = '${sku['id']}';
    final repo = widget.repo;
    final onRestored = widget.onRestored;
    try {
      await repo.deleteSku(id);
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('SKU deleted.'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await repo.restoreSku(id);
                onRestored();
                messenger.showSnackBar(
                  const SnackBar(content: Text('SKU restored.')),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(_error(e))));
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sku == null) return _SkuForm(repo: widget.repo);
    return Scaffold(
      appBar: AppBar(title: const Text('SKU details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return _Failure(error: s.error!, retry: reload);
          final d = s.data!;
          final dimensions = _map(d['dimensions']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _text(d['name']),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              _field('SKU code', d['skuCode']),
              _field('Barcode', d['barcode']),
              _field('Category', d['category']),
              _field('Description', d['description']),
              _field('Unit', d['uom']),
              _field('Status', d['status']),
              _field('Weight (kg)', d['weightKg']),
              if (dimensions.isNotEmpty)
                _field(
                  'Dimensions (cm)',
                  '${_text(dimensions['length'])} × ${_text(dimensions['width'])} × ${_text(dimensions['height'])}',
                ),
              _field('Image URL', d['imageUrl']),
              OutlinedButton.icon(
                onPressed: () => _showData(
                  context,
                  widget.repo,
                  '/customer-inventories/sku/${Uri.encodeComponent('${d['id']}')}/locations',
                  'SKU locations',
                ),
                icon: const Icon(Icons.place_outlined),
                label: const Text('View locations'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => edit(d),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit SKU'),
              ),
              TextButton.icon(
                onPressed: () => remove(d),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete SKU'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SkuForm extends StatefulWidget {
  const _SkuForm({required this.repo, this.sku});
  final StorageRepository repo;
  final Map<String, dynamic>? sku;
  @override
  State<_SkuForm> createState() => _SkuFormState();
}

class _SkuFormState extends State<_SkuForm> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool saving = false;
  String status = 'active';
  @override
  void initState() {
    super.initState();
    final sku = widget.sku ?? {};
    final dims = _map(sku['dimensions']);
    for (final key in [
      'skuCode',
      'name',
      'description',
      'category',
      'barcode',
      'uom',
      'weightKg',
      'imageUrl',
      'length',
      'width',
      'height',
    ]) {
      fields[key] = TextEditingController(
        text:
            '${(['length', 'width', 'height'].contains(key) ? dims[key] : sku[key]) ?? ''}',
      );
    }
    status = sku['status'] == 'inactive' ? 'inactive' : 'active';
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (fields['skuCode']!.text.trim().isEmpty ||
        fields['name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SKU code and name are required.')),
      );
      return;
    }
    final weightText = fields['weightKg']!.text.trim();
    if (widget.sku?['weightKg'] != null && weightText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The API does not support removing an existing weight.',
          ),
        ),
      );
      return;
    }
    final weightValue = double.tryParse(weightText);
    if (weightText.isNotEmpty &&
        (weightValue == null || !weightValue.isFinite || weightValue < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-negative weight.')),
      );
      return;
    }
    final dimensionValues = [
      for (final k in ['length', 'width', 'height']) fields[k]!.text.trim(),
    ];
    if (_map(widget.sku?['dimensions']).isNotEmpty &&
        dimensionValues.every((v) => v.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The API does not support removing existing dimensions.',
          ),
        ),
      );
      return;
    }
    if (dimensionValues.any((v) => v.isNotEmpty) &&
        dimensionValues.any((v) {
          final value = double.tryParse(v);
          return value == null || !value.isFinite || value < 0.1;
        })) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter all three dimensions, each at least 0.1 cm.'),
        ),
      );
      return;
    }
    final imageText = fields['imageUrl']!.text.trim();
    final imageUri = Uri.tryParse(imageText);
    if (imageText.isNotEmpty &&
        (imageUri == null || !imageUri.hasScheme || !imageUri.hasAuthority)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid image URL.')));
      return;
    }
    if (!form.currentState!.validate()) return;
    final payload = <String, dynamic>{};
    for (final key in [
      'skuCode',
      'name',
      'description',
      'category',
      'barcode',
      'uom',
      'imageUrl',
    ]) {
      final value = fields[key]!.text.trim();
      if (value.isNotEmpty || (widget.sku != null && key != 'uom')) {
        payload[key] = value;
      }
    }
    final weight = fields['weightKg']!.text.trim();
    if (weight.isNotEmpty) payload['weightKg'] = double.parse(weight);
    if (fields['length']!.text.trim().isNotEmpty) {
      payload['dimensions'] = {
        for (final k in ['length', 'width', 'height'])
          k: double.parse(fields[k]!.text.trim()),
      };
    }
    if (widget.sku != null) payload['status'] = status;
    setState(() => saving = true);
    try {
      await widget.repo.saveSku(payload, id: widget.sku?['id']?.toString());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget input(
    String key,
    String label, {
    bool required = false,
    int? maxLength,
    bool number = false,
    bool dimension = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: fields[key],
      maxLength: maxLength,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (raw) {
        final v = raw?.trim() ?? '';
        if (required && v.isEmpty) return 'Required';
        if (dimension &&
            [
              'length',
              'width',
              'height',
            ].any((k) => fields[k]!.text.trim().isNotEmpty) &&
            v.isEmpty) {
          return 'Enter all three dimensions';
        }
        if (number && v.isNotEmpty) {
          final n = double.tryParse(v);
          if (n == null || !n.isFinite || n < (dimension ? 0.1 : 0)) {
            return dimension
                ? 'Enter a number of at least 0.1'
                : 'Enter a non-negative number';
          }
        }
        if (key == 'imageUrl' && v.isNotEmpty) {
          final uri = Uri.tryParse(v);
          if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
            return 'Enter a valid URL';
          }
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.sku == null ? 'Add SKU' : 'Edit SKU')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          input('skuCode', 'SKU code', required: true, maxLength: 50),
          input('name', 'Name', required: true, maxLength: 100),
          input('description', 'Description', maxLength: 1000),
          input('category', 'Category', maxLength: 50),
          input('barcode', 'Barcode', maxLength: 50),
          input('uom', 'Unit of measure', maxLength: 30),
          input('weightKg', 'Weight (kg)', number: true),
          Text(
            'Dimensions (cm)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          input('length', 'Length', number: true, dimension: true),
          input('width', 'Width', number: true, dimension: true),
          input('height', 'Height', number: true, dimension: true),
          input('imageUrl', 'Image URL'),
          if (widget.sku != null)
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => status = v ?? status),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
