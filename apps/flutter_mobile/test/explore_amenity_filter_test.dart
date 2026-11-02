import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/amenities/amenity_repository.dart';
import 'package:flutter_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_mobile/features/auth/data/models/auth_user.dart';
import 'package:flutter_mobile/features/explore/data/models/facility.dart';
import 'package:flutter_mobile/features/explore/data/repositories/facility_repository.dart';
import 'package:flutter_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:flutter_mobile/features/notifications/application/notification_providers.dart';

void main() {
  testWidgets('Apply, match-any and Clear use selected amenity IDs', (
    tester,
  ) async {
    final repository = _SearchRepository((request) async {
      if (request.amenityIds.isEmpty) {
        return _page([_unfiltered], page: request.page);
      }
      return _page([_matchAny], page: request.page);
    });
    await _pumpExplore(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Cơ sở chưa lọc'), findsOneWidget);

    await _openAndSelect(tester, ['Kho lạnh', 'Lưu kho'], matchAll: false);
    expect(find.text('Tiện ích (2)'), findsOneWidget);
    expect(find.text('Kho lạnh'), findsOneWidget);
    expect(find.text('Lưu kho'), findsOneWidget);
    expect(find.text('Cơ sở lọc được'), findsOneWidget);
    final filteredRequest = repository.calls.last;
    expect(filteredRequest.amenityIds, [_coldStorageId, _storageId]);
    expect(filteredRequest.matchAllAmenities, isFalse);
    expect(filteredRequest.page, 1);

    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Tiện ích (2)'), findsNothing);
    expect(find.text('Cơ sở chưa lọc'), findsOneWidget);
    expect(repository.calls.last.amenityIds, isEmpty);
  });

  testWidgets(
    'match-all pagination preserves active amenity and search filters',
    (tester) async {
      final repository = _SearchRepository((request) async {
        if (request.page == 1 && request.amenityIds.isNotEmpty) {
          return _page([_matchAny], page: 1, hasNextPage: true);
        }
        if (request.page == 2 && request.amenityIds.isNotEmpty) {
          return _page([_secondMatch], page: 2);
        }
        return _page([_unfiltered], page: request.page);
      });
      await _pumpExplore(tester, repository);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kho A');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await _openAndSelect(tester, ['Kho lạnh', 'Lưu kho'], matchAll: true);
      expect(repository.calls.last.search, 'Kho A');
      expect(repository.calls.last.matchAllAmenities, isTrue);
      expect(repository.calls.last.page, 1);
      expect(find.text('Cơ sở lọc được'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tải thêm cơ sở'));
      await tester.pumpAndSettle();
      expect(repository.calls.last.page, 2);
      expect(repository.calls.last.search, 'Kho A');
      expect(repository.calls.last.amenityIds, [_coldStorageId, _storageId]);
      expect(repository.calls.last.matchAllAmenities, isTrue);
      await tester.scrollUntilVisible(
        find.text('Cơ sở trang hai'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Cơ sở trang hai'), findsOneWidget);
    },
  );

  testWidgets(
    'a late unfiltered response cannot replace a newer filtered result',
    (tester) async {
      final initial = Completer<FacilitySearchPage>();
      final repository = _SearchRepository((request) {
        if (request.amenityIds.isEmpty) return initial.future;
        return Future.value(_page([_matchAny], page: 1));
      });
      await _pumpExplore(tester, repository);
      await tester.pump();
      await _openAndSelect(tester, ['Kho lạnh']);
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở lọc được'), findsOneWidget);

      initial.complete(_page([_unfiltered], page: 1));
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở lọc được'), findsOneWidget);
      expect(find.text('Cơ sở chưa lọc'), findsNothing);
    },
  );

  testWidgets('backing out of the filter sheet discards draft selection', (
    tester,
  ) async {
    final repository = _SearchRepository(
      (request) async => _page([_matchAny], page: request.page),
    );
    await _pumpExplore(tester, repository);
    await tester.pumpAndSettle();
    await _openAndSelect(tester, ['Kho lạnh']);
    final appliedRequestCount = repository.calls.length;
    expect(find.text('Tiện ích (1)'), findsOneWidget);

    await tester.tap(find.textContaining('Tiện ích').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu kho').first);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Tiện ích (1)'), findsOneWidget);
    expect(find.text('Kho lạnh'), findsOneWidget);
    expect(find.text('Lưu kho'), findsNothing);
    expect(repository.calls, hasLength(appliedRequestCount));
  });

  testWidgets('empty filtered results and request errors are distinct', (
    tester,
  ) async {
    final failedRequest = Completer<FacilitySearchPage>();
    final repository = _SearchRepository((request) async {
      if (request.amenityIds.isNotEmpty) {
        if (request.amenityIds.contains(_coldStorageId) &&
            !request.amenityIds.contains(_storageId)) {
          return _page(const [], page: request.page);
        }
        if (request.amenityIds.contains(_storageId)) {
          return failedRequest.future;
        }
      }
      return _page([_unfiltered], page: request.page);
    });
    await _pumpExplore(tester, repository);
    await tester.pumpAndSettle();
    await _openAndSelect(tester, ['Kho lạnh']);
    expect(find.text('Không tìm thấy cơ sở'), findsOneWidget);

    await _openAndSelect(tester, ['Lưu kho']);
    failedRequest.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Không thể tải danh sách cơ sở. Vui lòng kiểm tra kết nối và thử lại.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('long amenity labels fit the filter sheet on a 320dp screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final amenityRepository = _AmenityRepository([
      Amenity(
        id: _coldStorageId,
        name: 'Dịch vụ lưu kho lạnh có tên dài để kiểm tra hiển thị trên điện thoại',
        status: 'active',
        description: 'Mô tả dài về điều kiện bảo quản và dịch vụ đi kèm. ' * 4,
      ),
    ]);
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 720);
      await _pumpExplore(
        tester,
        _SearchRepository((request) async => _page([_unfiltered], page: 1)),
        amenityRepository: amenityRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiện ích'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width: $width');
      expect(find.textContaining('Dịch vụ lưu kho lạnh'), findsOneWidget);
      expect(
        tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)),
        hasLength(1),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _pumpExplore(
  WidgetTester tester,
  _SearchRepository repository, {
  _AmenityRepository? amenityRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedOutAuthController.new),
        notificationUnreadCountProvider.overrideWith((ref) async => 0),
      ],
      child: MaterialApp(
        home: ExploreScreen(
          repository: repository,
          amenityRepository:
              amenityRepository ?? _AmenityRepository(_amenities),
          onSelect: (_) {},
        ),
      ),
    ),
  );
}

Future<void> _openAndSelect(
  WidgetTester tester,
  List<String> labels, {
  bool? matchAll,
}) async {
  await tester.tap(find.textContaining('Tiện ích').first);
  await tester.pumpAndSettle();
  if (matchAll == false) {
    await tester.tap(find.text('Cơ sở có tất cả tiện ích đã chọn'));
    await tester.pumpAndSettle();
  }
  for (final label in labels) {
    await tester.tap(find.text(label).first);
    await tester.pump();
  }
  await tester.tap(find.text('Áp dụng'));
  await tester.pumpAndSettle();
}

class _SearchCall {
  const _SearchCall({
    required this.search,
    required this.city,
    required this.page,
    required this.amenityIds,
    required this.matchAllAmenities,
  });
  final String? search;
  final String? city;
  final int page;
  final List<String> amenityIds;
  final bool matchAllAmenities;
}

class _SearchRepository extends FacilityRepository {
  _SearchRepository(this.respond) : super(Dio());
  final Future<FacilitySearchPage> Function(_SearchCall request) respond;
  final calls = <_SearchCall>[];

  @override
  Future<FacilitySearchPage> searchPage({
    String? search,
    String? city,
    int page = 1,
    List<String> amenityIds = const [],
    bool matchAllAmenities = true,
  }) {
    final request = _SearchCall(
      search: search,
      city: city,
      page: page,
      amenityIds: List.of(amenityIds),
      matchAllAmenities: matchAllAmenities,
    );
    calls.add(request);
    return respond(request);
  }
}

class _AmenityRepository extends AmenityRepository {
  _AmenityRepository(this.amenities) : super(Dio());
  final List<Amenity> amenities;
  @override
  Future<List<Amenity>> listActive({int page = 1}) async => amenities;
}

class _SignedOutAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => null;
}

const _coldStorageId = '0123456789abcdef01234567';
const _storageId = '1123456789abcdef01234567';
const _amenities = [
  Amenity(id: _coldStorageId, name: 'Kho lạnh', status: 'active'),
  Amenity(id: _storageId, name: 'Lưu kho', status: 'active'),
];

FacilitySearchPage _page(
  List<Facility> items, {
  required int page,
  bool hasNextPage = false,
}) => FacilitySearchPage(items: items, page: page, hasNextPage: hasNextPage);

const _unfiltered = Facility(
  id: 'unfiltered',
  name: 'Cơ sở chưa lọc',
  address: 'Địa chỉ A',
  city: 'Hà Nội',
  status: 'active',
);

const _matchAny = Facility(
  id: 'match-any',
  name: 'Cơ sở lọc được',
  address: 'Địa chỉ B',
  city: 'Hà Nội',
  status: 'active',
);

const _secondMatch = Facility(
  id: 'match-page-2',
  name: 'Cơ sở trang hai',
  address: 'Địa chỉ C',
  city: 'Hà Nội',
  status: 'active',
);
