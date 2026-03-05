// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_feed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$postFeedControllerHash() =>
    r'c4e5d4849f48338fdaceb8eafb27c6bb5ae2650f';

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

abstract class _$PostFeedController
    extends BuildlessAutoDisposeNotifier<PostFeedState> {
  late final FeedType feedType;
  late final String filterValue;

  PostFeedState build(FeedType feedType, String filterValue);
}

/// See also [PostFeedController].
@ProviderFor(PostFeedController)
const postFeedControllerProvider = PostFeedControllerFamily();

/// See also [PostFeedController].
class PostFeedControllerFamily extends Family<PostFeedState> {
  /// See also [PostFeedController].
  const PostFeedControllerFamily();

  /// See also [PostFeedController].
  PostFeedControllerProvider call(FeedType feedType, String filterValue) {
    return PostFeedControllerProvider(feedType, filterValue);
  }

  @override
  PostFeedControllerProvider getProviderOverride(
    covariant PostFeedControllerProvider provider,
  ) {
    return call(provider.feedType, provider.filterValue);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'postFeedControllerProvider';
}

/// See also [PostFeedController].
class PostFeedControllerProvider
    extends AutoDisposeNotifierProviderImpl<PostFeedController, PostFeedState> {
  /// See also [PostFeedController].
  PostFeedControllerProvider(FeedType feedType, String filterValue)
    : this._internal(
        () =>
            PostFeedController()
              ..feedType = feedType
              ..filterValue = filterValue,
        from: postFeedControllerProvider,
        name: r'postFeedControllerProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$postFeedControllerHash,
        dependencies: PostFeedControllerFamily._dependencies,
        allTransitiveDependencies:
            PostFeedControllerFamily._allTransitiveDependencies,
        feedType: feedType,
        filterValue: filterValue,
      );

  PostFeedControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.feedType,
    required this.filterValue,
  }) : super.internal();

  final FeedType feedType;
  final String filterValue;

  @override
  PostFeedState runNotifierBuild(covariant PostFeedController notifier) {
    return notifier.build(feedType, filterValue);
  }

  @override
  Override overrideWith(PostFeedController Function() create) {
    return ProviderOverride(
      origin: this,
      override: PostFeedControllerProvider._internal(
        () =>
            create()
              ..feedType = feedType
              ..filterValue = filterValue,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        feedType: feedType,
        filterValue: filterValue,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<PostFeedController, PostFeedState>
  createElement() {
    return _PostFeedControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PostFeedControllerProvider &&
        other.feedType == feedType &&
        other.filterValue == filterValue;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, feedType.hashCode);
    hash = _SystemHash.combine(hash, filterValue.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PostFeedControllerRef on AutoDisposeNotifierProviderRef<PostFeedState> {
  /// The parameter `feedType` of this provider.
  FeedType get feedType;

  /// The parameter `filterValue` of this provider.
  String get filterValue;
}

class _PostFeedControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<PostFeedController, PostFeedState>
    with PostFeedControllerRef {
  _PostFeedControllerProviderElement(super.provider);

  @override
  FeedType get feedType => (origin as PostFeedControllerProvider).feedType;
  @override
  String get filterValue => (origin as PostFeedControllerProvider).filterValue;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
