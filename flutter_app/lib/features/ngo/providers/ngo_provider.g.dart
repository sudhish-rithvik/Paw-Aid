// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ngo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentNGOHash() => r'9fca9af435211def63278cfe56489bec74f3a370';

/// See also [currentNGO].
@ProviderFor(currentNGO)
final currentNGOProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>?>.internal(
  currentNGO,
  name: r'currentNGOProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentNGOHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentNGORef = AutoDisposeFutureProviderRef<Map<String, dynamic>?>;
String _$rescueQueueHash() => r'de5a05b5e0df5bb8fb979b5a1314518f6d6e1cad';

/// See also [RescueQueue].
@ProviderFor(RescueQueue)
final rescueQueueProvider =
    AutoDisposeAsyncNotifierProvider<RescueQueue, List<dynamic>>.internal(
  RescueQueue.new,
  name: r'rescueQueueProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$rescueQueueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RescueQueue = AutoDisposeAsyncNotifier<List<dynamic>>;
String _$nGOAnalyticsDataHash() => r'ef57d57ba6c7a09bfd0716eb0b07ebc72f176b52';

/// See also [NGOAnalyticsData].
@ProviderFor(NGOAnalyticsData)
final nGOAnalyticsDataProvider = AutoDisposeAsyncNotifierProvider<
    NGOAnalyticsData, Map<String, dynamic>>.internal(
  NGOAnalyticsData.new,
  name: r'nGOAnalyticsDataProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nGOAnalyticsDataHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NGOAnalyticsData = AutoDisposeAsyncNotifier<Map<String, dynamic>>;
String _$nearbyCasesHash() => r'f0616ef109943e95be9b2e603c6cd3d05000ea8d';

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

abstract class _$NearbyCases
    extends BuildlessAutoDisposeAsyncNotifier<List<dynamic>> {
  late final double lat;
  late final double lng;
  late final double radius;

  FutureOr<List<dynamic>> build({
    required double lat,
    required double lng,
    double radius = 25.0,
  });
}

/// See also [NearbyCases].
@ProviderFor(NearbyCases)
const nearbyCasesProvider = NearbyCasesFamily();

/// See also [NearbyCases].
class NearbyCasesFamily extends Family<AsyncValue<List<dynamic>>> {
  /// See also [NearbyCases].
  const NearbyCasesFamily();

  /// See also [NearbyCases].
  NearbyCasesProvider call({
    required double lat,
    required double lng,
    double radius = 25.0,
  }) {
    return NearbyCasesProvider(
      lat: lat,
      lng: lng,
      radius: radius,
    );
  }

  @override
  NearbyCasesProvider getProviderOverride(
    covariant NearbyCasesProvider provider,
  ) {
    return call(
      lat: provider.lat,
      lng: provider.lng,
      radius: provider.radius,
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
  String? get name => r'nearbyCasesProvider';
}

/// See also [NearbyCases].
class NearbyCasesProvider
    extends AutoDisposeAsyncNotifierProviderImpl<NearbyCases, List<dynamic>> {
  /// See also [NearbyCases].
  NearbyCasesProvider({
    required double lat,
    required double lng,
    double radius = 25.0,
  }) : this._internal(
          () => NearbyCases()
            ..lat = lat
            ..lng = lng
            ..radius = radius,
          from: nearbyCasesProvider,
          name: r'nearbyCasesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$nearbyCasesHash,
          dependencies: NearbyCasesFamily._dependencies,
          allTransitiveDependencies:
              NearbyCasesFamily._allTransitiveDependencies,
          lat: lat,
          lng: lng,
          radius: radius,
        );

  NearbyCasesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.lat,
    required this.lng,
    required this.radius,
  }) : super.internal();

  final double lat;
  final double lng;
  final double radius;

  @override
  FutureOr<List<dynamic>> runNotifierBuild(
    covariant NearbyCases notifier,
  ) {
    return notifier.build(
      lat: lat,
      lng: lng,
      radius: radius,
    );
  }

  @override
  Override overrideWith(NearbyCases Function() create) {
    return ProviderOverride(
      origin: this,
      override: NearbyCasesProvider._internal(
        () => create()
          ..lat = lat
          ..lng = lng
          ..radius = radius,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        lat: lat,
        lng: lng,
        radius: radius,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<NearbyCases, List<dynamic>>
      createElement() {
    return _NearbyCasesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NearbyCasesProvider &&
        other.lat == lat &&
        other.lng == lng &&
        other.radius == radius;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, lat.hashCode);
    hash = _SystemHash.combine(hash, lng.hashCode);
    hash = _SystemHash.combine(hash, radius.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin NearbyCasesRef on AutoDisposeAsyncNotifierProviderRef<List<dynamic>> {
  /// The parameter `lat` of this provider.
  double get lat;

  /// The parameter `lng` of this provider.
  double get lng;

  /// The parameter `radius` of this provider.
  double get radius;
}

class _NearbyCasesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<NearbyCases, List<dynamic>>
    with NearbyCasesRef {
  _NearbyCasesProviderElement(super.provider);

  @override
  double get lat => (origin as NearbyCasesProvider).lat;
  @override
  double get lng => (origin as NearbyCasesProvider).lng;
  @override
  double get radius => (origin as NearbyCasesProvider).radius;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
