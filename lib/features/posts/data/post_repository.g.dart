// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$postRepositoryHash() => r'04cd4e2d499986bbe36f193a400cb696536580cb';

/// See also [postRepository].
@ProviderFor(postRepository)
final postRepositoryProvider = Provider<PostRepository>.internal(
  postRepository,
  name: r'postRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$postRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PostRepositoryRef = ProviderRef<PostRepository>;
String _$globalPostsStreamHash() => r'2469e621541294a842abea38e50a1ef005527e46';

/// See also [globalPostsStream].
@ProviderFor(globalPostsStream)
final globalPostsStreamProvider = StreamProvider<List<Post>>.internal(
  globalPostsStream,
  name: r'globalPostsStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$globalPostsStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GlobalPostsStreamRef = StreamProviderRef<List<Post>>;
String _$facultyPostsStreamHash() =>
    r'198b5c63348aaf16495257300c24cef87792abf4';

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

/// See also [facultyPostsStream].
@ProviderFor(facultyPostsStream)
const facultyPostsStreamProvider = FacultyPostsStreamFamily();

/// See also [facultyPostsStream].
class FacultyPostsStreamFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [facultyPostsStream].
  const FacultyPostsStreamFamily();

  /// See also [facultyPostsStream].
  FacultyPostsStreamProvider call(String faculty) {
    return FacultyPostsStreamProvider(faculty);
  }

  @override
  FacultyPostsStreamProvider getProviderOverride(
    covariant FacultyPostsStreamProvider provider,
  ) {
    return call(provider.faculty);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'facultyPostsStreamProvider';
}

/// See also [facultyPostsStream].
class FacultyPostsStreamProvider extends StreamProvider<List<Post>> {
  /// See also [facultyPostsStream].
  FacultyPostsStreamProvider(String faculty)
    : this._internal(
        (ref) => facultyPostsStream(ref as FacultyPostsStreamRef, faculty),
        from: facultyPostsStreamProvider,
        name: r'facultyPostsStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$facultyPostsStreamHash,
        dependencies: FacultyPostsStreamFamily._dependencies,
        allTransitiveDependencies:
            FacultyPostsStreamFamily._allTransitiveDependencies,
        faculty: faculty,
      );

  FacultyPostsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.faculty,
  }) : super.internal();

  final String faculty;

  @override
  Override overrideWith(
    Stream<List<Post>> Function(FacultyPostsStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FacultyPostsStreamProvider._internal(
        (ref) => create(ref as FacultyPostsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        faculty: faculty,
      ),
    );
  }

  @override
  StreamProviderElement<List<Post>> createElement() {
    return _FacultyPostsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FacultyPostsStreamProvider && other.faculty == faculty;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, faculty.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FacultyPostsStreamRef on StreamProviderRef<List<Post>> {
  /// The parameter `faculty` of this provider.
  String get faculty;
}

class _FacultyPostsStreamProviderElement
    extends StreamProviderElement<List<Post>>
    with FacultyPostsStreamRef {
  _FacultyPostsStreamProviderElement(super.provider);

  @override
  String get faculty => (origin as FacultyPostsStreamProvider).faculty;
}

String _$departmentPostsStreamHash() =>
    r'cda0ec00313f6133ee345f677a762af6175414ca';

/// See also [departmentPostsStream].
@ProviderFor(departmentPostsStream)
const departmentPostsStreamProvider = DepartmentPostsStreamFamily();

/// See also [departmentPostsStream].
class DepartmentPostsStreamFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [departmentPostsStream].
  const DepartmentPostsStreamFamily();

  /// See also [departmentPostsStream].
  DepartmentPostsStreamProvider call(String department) {
    return DepartmentPostsStreamProvider(department);
  }

  @override
  DepartmentPostsStreamProvider getProviderOverride(
    covariant DepartmentPostsStreamProvider provider,
  ) {
    return call(provider.department);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'departmentPostsStreamProvider';
}

/// See also [departmentPostsStream].
class DepartmentPostsStreamProvider extends StreamProvider<List<Post>> {
  /// See also [departmentPostsStream].
  DepartmentPostsStreamProvider(String department)
    : this._internal(
        (ref) =>
            departmentPostsStream(ref as DepartmentPostsStreamRef, department),
        from: departmentPostsStreamProvider,
        name: r'departmentPostsStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$departmentPostsStreamHash,
        dependencies: DepartmentPostsStreamFamily._dependencies,
        allTransitiveDependencies:
            DepartmentPostsStreamFamily._allTransitiveDependencies,
        department: department,
      );

  DepartmentPostsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.department,
  }) : super.internal();

  final String department;

  @override
  Override overrideWith(
    Stream<List<Post>> Function(DepartmentPostsStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DepartmentPostsStreamProvider._internal(
        (ref) => create(ref as DepartmentPostsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        department: department,
      ),
    );
  }

  @override
  StreamProviderElement<List<Post>> createElement() {
    return _DepartmentPostsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DepartmentPostsStreamProvider &&
        other.department == department;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, department.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DepartmentPostsStreamRef on StreamProviderRef<List<Post>> {
  /// The parameter `department` of this provider.
  String get department;
}

class _DepartmentPostsStreamProviderElement
    extends StreamProviderElement<List<Post>>
    with DepartmentPostsStreamRef {
  _DepartmentPostsStreamProviderElement(super.provider);

  @override
  String get department => (origin as DepartmentPostsStreamProvider).department;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
