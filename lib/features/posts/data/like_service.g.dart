// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$likeServiceHash() => r'95387783aa9495aa6307cd7a81b38a250d743fe8';

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
String _$isPostLikedHash() => r'48617217a55bf6f8ac16065a3d0e2ae56eedf91a';

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

/// See also [isPostLiked].
@ProviderFor(isPostLiked)
const isPostLikedProvider = IsPostLikedFamily();

/// See also [isPostLiked].
class IsPostLikedFamily extends Family<AsyncValue<bool>> {
  /// See also [isPostLiked].
  const IsPostLikedFamily();

  /// See also [isPostLiked].
  IsPostLikedProvider call(String postId) {
    return IsPostLikedProvider(postId);
  }

  @override
  IsPostLikedProvider getProviderOverride(
    covariant IsPostLikedProvider provider,
  ) {
    return call(provider.postId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isPostLikedProvider';
}

/// See also [isPostLiked].
class IsPostLikedProvider extends StreamProvider<bool> {
  /// See also [isPostLiked].
  IsPostLikedProvider(String postId)
    : this._internal(
        (ref) => isPostLiked(ref as IsPostLikedRef, postId),
        from: isPostLikedProvider,
        name: r'isPostLikedProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$isPostLikedHash,
        dependencies: IsPostLikedFamily._dependencies,
        allTransitiveDependencies: IsPostLikedFamily._allTransitiveDependencies,
        postId: postId,
      );

  IsPostLikedProvider._internal(
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
  Override overrideWith(Stream<bool> Function(IsPostLikedRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: IsPostLikedProvider._internal(
        (ref) => create(ref as IsPostLikedRef),
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
  StreamProviderElement<bool> createElement() {
    return _IsPostLikedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsPostLikedProvider && other.postId == postId;
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
mixin IsPostLikedRef on StreamProviderRef<bool> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _IsPostLikedProviderElement extends StreamProviderElement<bool>
    with IsPostLikedRef {
  _IsPostLikedProviderElement(super.provider);

  @override
  String get postId => (origin as IsPostLikedProvider).postId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
