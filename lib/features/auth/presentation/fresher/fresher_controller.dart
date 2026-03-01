import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_destination.dart';

part 'fresher_controller.g.dart';

@riverpod
class FresherController extends _$FresherController {
  @override
  AsyncValue<AuthDestination?> build() => const AsyncData(null);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<AuthDestination?> signUpFresher({
    required String fullName,
    required String jambNumber,
    required String department,
    required String password,
    required String cloudinaryUrl1,
    required String cloudinaryUrl2,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.signUpFresher(
        fullName: fullName,
        jambNumber: jambNumber,
        department: department,
        password: password,
        cloudinaryUrl1: cloudinaryUrl1,
        cloudinaryUrl2: cloudinaryUrl2,
      ),
    );
    return state.valueOrNull;
  }

  Future<AuthDestination?> signInFresher({
    required String jambNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.signInFresher(
        jambNumber: jambNumber,
        password: password,
      ),
    );
    return state.valueOrNull;
  }

  void reset() {
    state = const AsyncData(null);
  }
}
