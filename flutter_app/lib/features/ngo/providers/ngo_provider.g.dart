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

/// See also [NearbyCases].
class NearbyCasesFamily extends Family<AsyncValue<List<dynamic>>> {
  const NearbyCasesFamily();

  NearbyCasesProvider call({
    required double lat,
    required double lng,
    required double radius,
  }) {
    return NearbyCasesProvider(
      lat: lat,
      lng: lng,
      radius: radius,
    );
  }

  @override
  NearbyCasesProvider getProviderOverride(covariant NearbyCasesProvider provider) {
    return call(
      lat: provider.lat,
      lng: provider.lng,
      radius: provider.radius,
    );
  }

  @override
  List<ProviderOrFamily>? get allTransitiveDependencies => null;

  @override
  List<ProviderOrFamily>? get dependencies => null;

  @override
  String? get name => r'nearbyCasesProvider';
}

final nearbyCasesProvider = NearbyCasesFamily();

class NearbyCasesProvider extends AutoDisposeAsyncNotifierProviderImpl<
    NearbyCases, List<dynamic>> {
  NearbyCasesProvider({
    required this.lat,
    required this.lng,
    required this.radius,
  }) : super.internal(
          () => NearbyCases()
            ..lat = lat
            ..lng = lng
            ..radius = radius,
          from: nearbyCasesProvider,
          name: r'nearbyCasesProvider',
          debugGetCreateSourceHash: null,
          dependencies: null,
          allTransitiveDependencies: null,
        );

  final double lat;
  final double lng;
  final double radius;

  @override
  bool operator ==(Object other) {
    return other is NearbyCasesProvider &&
        other.lat == lat &&
        other.lng == lng &&
        other.radius == radius;
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      lat,
      lng,
      radius,
    );
  }

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
      override: NearbyCasesProvider(
        lat: lat,
        lng: lng,
        radius: radius,
      ),
    );
  }
}

abstract class _$NearbyCases extends BuildlessAutoDisposeAsyncNotifier<List<dynamic>> {
  late final double lat;
  late final double lng;
  late final double radius;

  FutureOr<List<dynamic>> build({
    required double lat,
    required double lng,
    required double radius,
  });
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
