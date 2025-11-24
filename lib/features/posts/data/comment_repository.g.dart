// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$commentRepositoryHash() => r'391485d3abac2905c20d8a9a34956d7de00fc1e8';

/// See also [commentRepository].
@ProviderFor(commentRepository)
final commentRepositoryProvider = Provider<CommentRepository>.internal(
  commentRepository,
  name: r'commentRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$commentRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommentRepositoryRef = ProviderRef<CommentRepository>;
String _$postCommentsStreamHash() =>
    r'45ea89d8fb0abf7a20051538447914d817d19ed4';

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

/// See also [postCommentsStream].
@ProviderFor(postCommentsStream)
const postCommentsStreamProvider = PostCommentsStreamFamily();

/// See also [postCommentsStream].
class PostCommentsStreamFamily extends Family<AsyncValue<List<Comment>>> {
  /// See also [postCommentsStream].
  const PostCommentsStreamFamily();

  /// See also [postCommentsStream].
  PostCommentsStreamProvider call(String postId) {
    return PostCommentsStreamProvider(postId);
  }

  @override
  PostCommentsStreamProvider getProviderOverride(
    covariant PostCommentsStreamProvider provider,
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
  String? get name => r'postCommentsStreamProvider';
}

/// See also [postCommentsStream].
class PostCommentsStreamProvider extends StreamProvider<List<Comment>> {
  /// See also [postCommentsStream].
  PostCommentsStreamProvider(String postId)
    : this._internal(
        (ref) => postCommentsStream(ref as PostCommentsStreamRef, postId),
        from: postCommentsStreamProvider,
        name: r'postCommentsStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$postCommentsStreamHash,
        dependencies: PostCommentsStreamFamily._dependencies,
        allTransitiveDependencies:
            PostCommentsStreamFamily._allTransitiveDependencies,
        postId: postId,
      );

  PostCommentsStreamProvider._internal(
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
    Stream<List<Comment>> Function(PostCommentsStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PostCommentsStreamProvider._internal(
        (ref) => create(ref as PostCommentsStreamRef),
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
  StreamProviderElement<List<Comment>> createElement() {
    return _PostCommentsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PostCommentsStreamProvider && other.postId == postId;
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
mixin PostCommentsStreamRef on StreamProviderRef<List<Comment>> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _PostCommentsStreamProviderElement
    extends StreamProviderElement<List<Comment>>
    with PostCommentsStreamRef {
  _PostCommentsStreamProviderElement(super.provider);

  @override
  String get postId => (origin as PostCommentsStreamProvider).postId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
