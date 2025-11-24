import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_destination.dart';

part 'login_controller.g.dart';

@riverpod
class LoginController extends _$LoginController {
  @override
  AsyncValue<AuthDestination?> build() => const AsyncData(null);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<AuthDestination?> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.signInWithGoogle);
    return state.valueOrNull;
  }

  Future<AuthDestination?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.loginWithEmail(email: email, password: password),
    );
    return state.valueOrNull;
  }

  Future<AuthDestination?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.registerWithEmail(email: email, password: password),
    );
    return state.valueOrNull;
  }

  Future<AuthDestination> refreshEmailVerification() async {
    state = const AsyncLoading();
    final result = await _repository.refreshEmailVerification();
    state = AsyncData(result);
    return result;
  }

  Future<void> resendVerificationEmail() async {
    state = const AsyncLoading();
    try {
      await _repository.resendVerificationEmail();
      state = const AsyncData(null);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}
