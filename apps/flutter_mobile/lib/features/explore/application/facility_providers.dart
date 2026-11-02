import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/repositories/facility_repository.dart';

final facilityRepositoryProvider = Provider<FacilityRepository>(
  (ref) => FacilityRepository(ref.watch(dioProvider)),
);
