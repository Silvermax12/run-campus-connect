// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$likeServiceHash() => r'85225a15b87bd58e87cf0f12bc7097167bc3862b';

/// See also [likeService].
@ProviderFor(likeService)
final likeServiceProvider = Provider<LikeService>.internal(
  likeService,
  name: r'likeServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$likeServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LikeServiceRef = ProviderRef<LikeService>;
String _$checkPostLikedHash() => r'55fc0274c330170b011de4c685085f35bd893cd9';

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

/// See also [checkPostLiked].
@ProviderFor(checkPostLiked)
const checkPostLikedProvider = CheckPostLikedFamily();

/// See also [checkPostLiked].
class CheckPostLikedFamily extends Family<AsyncValue<bool>> {
  /// See also [checkPostLiked].
  const CheckPostLikedFamily();

  /// See also [checkPostLiked].
  CheckPostLikedProvider call({required String postId}) {
    return CheckPostLikedProvider(postId: postId);
  }

  @override
  CheckPostLikedProvider getProviderOverride(
    covariant CheckPostLikedProvider provider,
  ) {
    return call(postId: provider.postId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'checkPostLikedProvider';
}

/// See also [checkPostLiked].
class CheckPostLikedProvider extends AutoDisposeStreamProvider<bool> {
  /// See also [checkPostLiked].
  CheckPostLikedProvider({required String postId})
    : this._internal(
        (ref) => checkPostLiked(ref as CheckPostLikedRef, postId: postId),
        from: checkPostLikedProvider,
        name: r'checkPostLikedProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$checkPostLikedHash,
        dependencies: CheckPostLikedFamily._dependencies,
        allTransitiveDependencies:
            CheckPostLikedFamily._allTransitiveDependencies,
        postId: postId,
      );

  CheckPostLikedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.postId,
  }) : super.internal();

  final String postId;

  @override
  Override overrideWith(
    Stream<bool> Function(CheckPostLikedRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CheckPostLikedProvider._internal(
        (ref) => create(ref as CheckPostLikedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        postId: postId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<bool> createElement() {
    return _CheckPostLikedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CheckPostLikedProvider && other.postId == postId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, postId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CheckPostLikedRef on AutoDisposeStreamProviderRef<bool> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _CheckPostLikedProviderElement
    extends AutoDisposeStreamProviderElement<bool>
    with CheckPostLikedRef {
  _CheckPostLikedProviderElement(super.provider);

  @override
  String get postId => (origin as CheckPostLikedProvider).postId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
