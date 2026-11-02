import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../contracts/data/contract_repository.dart';
import '../../explore/application/facility_providers.dart';
import '../../explore/data/models/facility.dart';
import '../../reservations/data/models/reservation.dart';
import '../data/customer_inventory_summary.dart';
import '../data/customer_inventory_summary_repository.dart';
import '../data/active_rental_summary.dart';

final customerInventorySummaryRepositoryProvider =
    Provider<CustomerInventorySummaryRepository>(
      (ref) => CustomerInventorySummaryRepository(ref.watch(dioProvider)),
    );

final dashboardInventorySummaryProvider =
    FutureProvider.autoDispose<CustomerInventorySummary>(
      (ref) =>
          ref.watch(customerInventorySummaryRepositoryProvider).getSummary(),
    );

final dashboardContractsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ContractRepository(ref.watch(dioProvider)).listAll(),
    );

final dashboardActiveRentalsProvider =
    FutureProvider.autoDispose<ActiveRentalSummary>(
      (ref) async => ActiveRentalSummary.fromContracts(
        await ref.watch(dashboardContractsProvider.future),
      ),
    );

final dashboardReservationsProvider =
    FutureProvider.autoDispose<List<Reservation>>(
      (ref) => ref.watch(reservationPaymentProvider).reservations.list(),
    );

final dashboardFacilitiesProvider = FutureProvider.autoDispose<List<Facility>>(
  (ref) => ref.watch(facilityRepositoryProvider).search(),
);
