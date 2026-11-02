import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/models/payment.dart';
import '../data/repositories/payment_repository.dart';

final paymentHistoryRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(dioProvider)),
);

final paymentHistoryProvider =
    AsyncNotifierProvider.autoDispose<
      PaymentHistoryController,
      PaymentHistoryPage
    >(PaymentHistoryController.new);

class PaymentHistoryController extends AsyncNotifier<PaymentHistoryPage> {
  static const pageSize = 20;
  late PaymentRepository _repository;

  @override
  Future<PaymentHistoryPage> build() async {
    _repository = ref.watch(paymentHistoryRepositoryProvider);
    return _repository.getHistoryPage(limit: pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.getHistoryPage(limit: pageSize),
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasNextPage) return;
    try {
      final next = await _repository.getHistoryPage(
        page: current.page + 1,
        limit: pageSize,
      );
      final ids = current.items.map((payment) => payment.id).toSet();
      state = AsyncData(
        PaymentHistoryPage(
          items: [
            ...current.items,
            ...next.items.where((payment) => !ids.contains(payment.id)),
          ],
          page: next.page,
          limit: next.limit,
          totalItems: next.totalItems,
          totalPages: next.totalPages,
          hasNextPage: next.hasNextPage,
        ),
      );
    } catch (_) {
      // Keep current page visible; the screen offers an explicit retry.
      rethrow;
    }
  }
}
