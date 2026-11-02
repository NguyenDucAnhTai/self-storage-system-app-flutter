import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../data/models/facility.dart';
import '../../data/repositories/facility_repository.dart';
import '../../../notifications/presentation/notification_bell.dart';
import '../../../amenities/amenity_repository.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.repository,
    required this.onSelect,
    this.amenityRepository,
  });
  final FacilityRepository repository;
  final ValueChanged<Facility> onSelect;
  final AmenityRepository? amenityRepository;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  late Future<FacilitySearchPage> _future;
  Future<List<Amenity>>? _amenitiesFuture;
  List<Amenity> _amenities = const [];
  final Set<String> _selectedAmenityIds = {};
  bool _matchAllAmenities = true;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  int _requestGeneration = 0;
  @override
  void initState() {
    super.initState();
    _future = _requestPage();
    _amenitiesFuture = widget.amenityRepository?.listActive();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _requestGeneration++;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<FacilitySearchPage> _requestPage({int page = 1}) =>
      widget.repository.searchPage(
        search: _search.text,
        amenityIds: List.of(_selectedAmenityIds),
        matchAllAmenities: _matchAllAmenities,
        page: page,
      );

  void _load() {
    _searchDebounce?.cancel();
    _requestGeneration++;
    final future = _requestPage();
    setState(() {
      _future = future;
      _loadingMore = false;
      _loadMoreFailed = false;
    });
  }

  Future<void> _refresh() async {
    _load();
    try {
      await _future;
    } catch (_) {
      // FutureBuilder renders the request error state.
    }
  }

  Future<void> _loadMore(FacilitySearchPage current) async {
    if (_loadingMore || !current.hasNextPage) return;
    final request = ++_requestGeneration;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final next = await _requestPage(page: current.page + 1);
      if (!mounted || request != _requestGeneration) return;
      setState(() => _future = Future.value(current.append(next)));
    } catch (_) {
      if (mounted && request == _requestGeneration) {
        setState(() => _loadMoreFailed = true);
      }
    } finally {
      if (mounted && request == _requestGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _openAmenityFilter() async {
    final future = _amenitiesFuture;
    if (future == null) return;
    late final List<Amenity> amenities;
    try {
      amenities = await future;
    } catch (_) {
      if (!mounted) return;
      setState(() => _amenitiesFuture = widget.amenityRepository?.listActive());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tải được tiện ích. Vui lòng thử lại.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _amenities = amenities);
    if (amenities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có danh sách tiện ích để lọc.')),
      );
      return;
    }
    final draftIds = Set<String>.from(_selectedAmenityIds);
    var draftMatchAll = _matchAllAmenities;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lọc theo tiện ích',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draftMatchAll,
                    title: const Text('Cơ sở có tất cả tiện ích đã chọn'),
                    subtitle: const Text(
                      'Tắt để tìm cơ sở có ít nhất một tiện ích.',
                    ),
                    onChanged: (value) =>
                        setSheetState(() => draftMatchAll = value),
                  ),
                  Expanded(
                    child: ListView(
                      children: amenities
                          .map(
                            (amenity) => CheckboxListTile(
                              value: draftIds.contains(amenity.id),
                              title: Text(amenity.name),
                              subtitle: amenity.description == null
                                  ? null
                                  : Text(
                                      amenity.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onChanged: (selected) => setSheetState(() {
                                if (selected == true) {
                                  draftIds.add(amenity.id);
                                } else {
                                  draftIds.remove(amenity.id);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => setSheetState(draftIds.clear),
                        child: const Text('Xóa bộ lọc'),
                      ),
                      FilledButton(
                        onPressed: () {
                          _selectedAmenityIds
                            ..clear()
                            ..addAll(draftIds);
                          _matchAllAmenities = draftMatchAll;
                          Navigator.of(sheetContext).pop();
                          _load();
                        },
                        child: const Text('Áp dụng'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Khám phá'),
      actions: [
        const NotificationBell(),
        IconButton(
          tooltip: 'Cá nhân',
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tìm kho phù hợp',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tìm kiếm cơ sở lưu trữ và các loại kho đang được cung cấp.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            elevation: 1,
            shadowColor: const Color(0x16003327),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Tìm cơ sở lưu trữ',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_search.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Xóa nội dung tìm kiếm',
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    IconButton(
                      tooltip: 'Tìm kiếm',
                      onPressed: _load,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.amenityRepository != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _openAmenityFilter,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    _selectedAmenityIds.isEmpty
                        ? 'Tiện ích'
                        : 'Tiện ích (${_selectedAmenityIds.length})',
                  ),
                ),
                if (_selectedAmenityIds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _selectedAmenityIds.clear();
                      _load();
                    },
                    child: const Text('Xóa'),
                  ),
                ],
              ],
            ),
          ),
        if (_selectedAmenityIds.isNotEmpty && _amenities.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: _amenities
                        .where(
                          (amenity) => _selectedAmenityIds.contains(amenity.id),
                        )
                        .map(
                          (amenity) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(
                                amenity.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _matchAllAmenities
                      ? 'Cơ sở có tất cả tiện ích đã chọn'
                      : 'Cơ sở có ít nhất một tiện ích đã chọn',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        Expanded(
          child: FutureBuilder<FacilitySearchPage>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const _FacilityLoadingList();
              }
              if (s.hasError) {
                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: AppErrorState(
                        message: 'Không thể tải danh sách cơ sở. Vui lòng kiểm tra kết nối và thử lại.',
                        onRetry: _load,
                      ),
                    ),
                  ),
                );
              }
              final result = s.data!;
              final items = result.items;
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 360,
                        child: AppEmptyState(
                          icon: Icons.search_off_outlined,
                          title: 'Không tìm thấy cơ sở',
                          message: 'Hãy thử tên cơ sở hoặc địa điểm khác.',
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount:
                      items.length +
                      1 +
                      ((result.hasNextPage || _loadMoreFailed) ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${items.length} cơ sở lưu trữ',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (i == items.length + 1) {
                      return Column(
                        children: [
                          if (_loadMoreFailed)
                            const Text(
                              'Không tải thêm được. Vui lòng thử lại.',
                            ),
                          OutlinedButton(
                            onPressed: _loadingMore
                                ? null
                                : () => _loadMore(result),
                            child: _loadingMore
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _loadMoreFailed
                                        ? 'Thử tải thêm lại'
                                        : 'Tải thêm cơ sở',
                                  ),
                          ),
                        ],
                      );
                    }
                    final f = items[i - 1];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.onSelect(f),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: FacilityImage(
                                    url: f.images.isEmpty
                                        ? null
                                        : f.images.first,
                                    height: 208,
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 14,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: .94,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 7,
                                      ),
                                      child: Text(
                                        '${_facilityStatus(f.status)} · ${f.city}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                16,
                                18,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          '${f.city} · ${f.address}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => widget.onSelect(f),
                                      icon: const Icon(
                                        Icons.arrow_forward_rounded,
                                      ),
                                      label: const Text('Xem chi tiết cơ sở'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  String _facilityStatus(String status) => switch (status.toLowerCase()) {
    'active' => 'Đang hoạt động',
    'inactive' => 'Tạm ngừng',
    'available' => 'Đang nhận khách',
    'unavailable' => 'Chưa khả dụng',
    _ => status,
  };
}

class _FacilityLoadingList extends StatelessWidget {
  const _FacilityLoadingList();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FacilityImage(url: null, height: 176),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 180,
                  height: 16,
                  color: const Color(0xFFE7F4EF),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 240,
                  height: 12,
                  color: const Color(0xFFE7F4EF),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
