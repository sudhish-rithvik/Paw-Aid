// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myReportsHash() => r'016439a9eec6a269ed381b8153ad7da69e42b77e';

/// See also [MyReports].
@ProviderFor(MyReports)
final myReportsProvider =
    AutoDisposeAsyncNotifierProvider<MyReports, List<dynamic>>.internal(
  MyReports.new,
  name: r'myReportsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MyReports = AutoDisposeAsyncNotifier<List<dynamic>>;
String _$caseStatusNotifierHash() =>
    r'92fd00797cc0574cc0c43a1f0a366aaad2643f0d';

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

abstract class _$CaseStatusNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String caseId;

  FutureOr<Map<String, dynamic>> build(
    String caseId,
  );
}

/// See also [CaseStatusNotifier].
@ProviderFor(CaseStatusNotifier)
const caseStatusNotifierProvider = CaseStatusNotifierFamily();

/// See also [CaseStatusNotifier].
class CaseStatusNotifierFamily
    extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [CaseStatusNotifier].
  const CaseStatusNotifierFamily();

  /// See also [CaseStatusNotifier].
  CaseStatusNotifierProvider call(
    String caseId,
  ) {
    return CaseStatusNotifierProvider(
      caseId,
    );
  }

  @override
  CaseStatusNotifierProvider getProviderOverride(
    covariant CaseStatusNotifierProvider provider,
  ) {
    return call(
      provider.caseId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'caseStatusNotifierProvider';
}

/// See also [CaseStatusNotifier].
class CaseStatusNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    CaseStatusNotifier, Map<String, dynamic>> {
  /// See also [CaseStatusNotifier].
  CaseStatusNotifierProvider(
    String caseId,
  ) : this._internal(
          () => CaseStatusNotifier()..caseId = caseId,
          from: caseStatusNotifierProvider,
          name: r'caseStatusNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$caseStatusNotifierHash,
          dependencies: CaseStatusNotifierFamily._dependencies,
          allTransitiveDependencies:
              CaseStatusNotifierFamily._allTransitiveDependencies,
          caseId: caseId,
        );

  CaseStatusNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.caseId,
  }) : super.internal();

  final String caseId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant CaseStatusNotifier notifier,
  ) {
    return notifier.build(
      caseId,
    );
  }

  @override
  Override overrideWith(CaseStatusNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: CaseStatusNotifierProvider._internal(
        () => create()..caseId = caseId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        caseId: caseId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<CaseStatusNotifier,
      Map<String, dynamic>> createElement() {
    return _CaseStatusNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CaseStatusNotifierProvider && other.caseId == caseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, caseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CaseStatusNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `caseId` of this provider.
  String get caseId;
}

class _CaseStatusNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<CaseStatusNotifier,
        Map<String, dynamic>> with CaseStatusNotifierRef {
  _CaseStatusNotifierProviderElement(super.provider);

  @override
  String get caseId => (origin as CaseStatusNotifierProvider).caseId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
