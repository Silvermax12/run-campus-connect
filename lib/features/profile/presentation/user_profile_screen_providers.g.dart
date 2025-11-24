// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendStatusStreamHash() =>
    r'b54cc760c39609062daf601882954147514486dd';

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

/// See also [friendStatusStream].
@ProviderFor(friendStatusStream)
const friendStatusStreamProvider = FriendStatusStreamFamily();

/// See also [friendStatusStream].
class FriendStatusStreamFamily extends Family<AsyncValue<FriendStatus>> {
  /// See also [friendStatusStream].
  const FriendStatusStreamFamily();

  /// See also [friendStatusStream].
  FriendStatusStreamProvider call({
    required String myUid,
    required String targetUid,
  }) {
    return FriendStatusStreamProvider(myUid: myUid, targetUid: targetUid);
  }

  @override
  FriendStatusStreamProvider getProviderOverride(
    covariant FriendStatusStreamProvider provider,
  ) {
    return call(myUid: provider.myUid, targetUid: provider.targetUid);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'friendStatusStreamProvider';
}

/// See also [friendStatusStream].
class FriendStatusStreamProvider
    extends AutoDisposeStreamProvider<FriendStatus> {
  /// See also [friendStatusStream].
  FriendStatusStreamProvider({required String myUid, required String targetUid})
    : this._internal(
        (ref) => friendStatusStream(
          ref as FriendStatusStreamRef,
          myUid: myUid,
          targetUid: targetUid,
        ),
        from: friendStatusStreamProvider,
        name: r'friendStatusStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$friendStatusStreamHash,
        dependencies: FriendStatusStreamFamily._dependencies,
        allTransitiveDependencies:
            FriendStatusStreamFamily._allTransitiveDependencies,
        myUid: myUid,
        targetUid: targetUid,
      );

  FriendStatusStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.myUid,
    required this.targetUid,
  }) : super.internal();

  final String myUid;
  final String targetUid;

  @override
  Override overrideWith(
    Stream<FriendStatus> Function(FriendStatusStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FriendStatusStreamProvider._internal(
        (ref) => create(ref as FriendStatusStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        myUid: myUid,
        targetUid: targetUid,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<FriendStatus> createElement() {
    return _FriendStatusStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FriendStatusStreamProvider &&
        other.myUid == myUid &&
        other.targetUid == targetUid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, myUid.hashCode);
    hash = _SystemHash.combine(hash, targetUid.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FriendStatusStreamRef on AutoDisposeStreamProviderRef<FriendStatus> {
  /// The parameter `myUid` of this provider.
  String get myUid;

  /// The parameter `targetUid` of this provider.
  String get targetUid;
}

class _FriendStatusStreamProviderElement
    extends AutoDisposeStreamProviderElement<FriendStatus>
    with FriendStatusStreamRef {
  _FriendStatusStreamProviderElement(super.provider);

  @override
  String get myUid => (origin as FriendStatusStreamProvider).myUid;
  @override
  String get targetUid => (origin as FriendStatusStreamProvider).targetUid;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
