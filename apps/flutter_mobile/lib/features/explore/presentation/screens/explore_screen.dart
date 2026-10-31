import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../data/models/facility.dart';
import '../../data/repositories/facility_repository.dart';
import '../../../notifications/presentation/notification_bell.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.repository,
    required this.onSelect,
  });
  final FacilityRepository repository;
  final ValueChanged<Facility> onSelect;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  late Future<List<Facility>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.search();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _load() {
    _searchDebounce?.cancel();
    setState(() => _future = widget.repository.search(search: _search.text));
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
        Expanded(
          child: FutureBuilder<List<Facility>>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const _FacilityLoadingList();
              }
              if (s.hasError) {
                return AppErrorState(
                  message: 'Không thể tải danh sách cơ sở. Vui lòng kiểm tra kết nối và thử lại.',
                  onRetry: _load,
                );
              }
              final items = s.data ?? const [];
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _load(),
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
                onRefresh: () async => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: items.length + 1,
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
