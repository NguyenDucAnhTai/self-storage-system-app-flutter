import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/models/auth_user.dart';
import '../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(apiClientProvider)),
);
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthUser?> {
  late AuthRepository _repository;
  @override
  Future<AuthUser?> build() async {
    _repository = ref.watch(authRepositoryProvider);
    return _repository.restore();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.login(email, password));
    state.requireValue;
  }

  Future<void> register({
    required String email,
    required String otp,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.register(
        email: email,
        otp: otp,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
      ),
    );
    state.requireValue;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }
}
