// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userPostsHash() => r'7158b85e96111a9b5f7ca9035e2bb962f70a1394';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [userPosts].
@ProviderFor(userPosts)
const userPostsProvider = UserPostsFamily();

/// See also [userPosts].
class UserPostsFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [userPosts].
  const UserPostsFamily();

  /// See also [userPosts].
  UserPostsProvider call({required String userId}) {
    return UserPostsProvider(userId: userId);
  }

  @override
  UserPostsProvider getProviderOverride(covariant UserPostsProvider provider) {
    return call(userId: provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userPostsProvider';
}

/// See also [userPosts].
class UserPostsProvider extends AutoDisposeFutureProvider<List<Post>> {
  /// See also [userPosts].
  UserPostsProvider({required String userId})
    : this._internal(
        (ref) => userPosts(ref as UserPostsRef, userId: userId),
        from: userPostsProvider,
        name: r'userPostsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userPostsHash,
        dependencies: UserPostsFamily._dependencies,
        allTransitiveDependencies: UserPostsFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserPostsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<Post>> Function(UserPostsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserPostsProvider._internal(
        (ref) => create(ref as UserPostsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Post>> createElement() {
    return _UserPostsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserPostsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserPostsRef on AutoDisposeFutureProviderRef<List<Post>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserPostsProviderElement
    extends AutoDisposeFutureProviderElement<List<Post>>
    with UserPostsRef {
  _UserPostsProviderElement(super.provider);

  @override
  String get userId => (origin as UserPostsProvider).userId;
}

String _$profileControllerHash() => r'2faafaf704f3912d9b73846fb060ba91fbf216c4';

/// See also [ProfileController].
@ProviderFor(ProfileController)
final profileControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProfileController, void>.internal(
      ProfileController.new,
      name: r'profileControllerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$profileControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
