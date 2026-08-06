import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

@immutable
class GeographyCountry {
  const GeographyCountry({
    required this.id,
    required this.name,
    required this.iso2,
    this.iso3,
  });

  factory GeographyCountry.fromJson(Map<String, dynamic> json) =>
      GeographyCountry(
        id: json['id'] as String,
        name: json['name'] as String,
        iso2: json['iso2'] as String,
        iso3: json['iso3'] as String?,
      );

  final String id;
  final String name;
  final String iso2;
  final String? iso3;
}

@immutable
class GeographyRegion {
  const GeographyRegion({
    required this.id,
    required this.countryId,
    required this.name,
    this.code,
  });

  factory GeographyRegion.fromJson(Map<String, dynamic> json) =>
      GeographyRegion(
        id: json['id'] as String,
        countryId: json['country_id'] as String,
        name: json['name'] as String,
        code: json['code'] as String?,
      );

  final String id;
  final String countryId;
  final String name;
  final String? code;
}

@immutable
class GeographyCity {
  const GeographyCity({
    required this.id,
    required this.regionId,
    required this.countryId,
    required this.name,
  });

  factory GeographyCity.fromJson(Map<String, dynamic> json) => GeographyCity(
    id: json['id'] as String,
    regionId: json['region_id'] as String,
    countryId: json['country_id'] as String,
    name: json['name'] as String,
  );

  final String id;
  final String regionId;
  final String countryId;
  final String name;
}

typedef GeographyCountriesLoader = Future<List<GeographyCountry>> Function();
typedef GeographyRegionsLoader =
    Future<List<GeographyRegion>> Function(String countryId);
typedef GeographyCitiesLoader =
    Future<List<GeographyCity>> Function(String regionId);

class GeographyRepository {
  GeographyRepository._({
    SupabaseClient? Function()? clientProvider,
    this._countriesLoader,
    this._regionsLoader,
    this._citiesLoader,
  }) : _clientProvider = clientProvider ?? (() => SupabaseConfig.client);

  factory GeographyRepository.forTesting({
    required GeographyCountriesLoader countriesLoader,
    required GeographyRegionsLoader regionsLoader,
    required GeographyCitiesLoader citiesLoader,
  }) => GeographyRepository._(
    clientProvider: () => null,
    countriesLoader: countriesLoader,
    regionsLoader: regionsLoader,
    citiesLoader: citiesLoader,
  );

  static final GeographyRepository _production = GeographyRepository._();
  static GeographyRepository? _testing;

  static GeographyRepository get instance => _testing ?? _production;

  @visibleForTesting
  static void useForTesting(GeographyRepository? repository) {
    _testing = repository;
  }

  final SupabaseClient? Function() _clientProvider;
  final GeographyCountriesLoader? _countriesLoader;
  final GeographyRegionsLoader? _regionsLoader;
  final GeographyCitiesLoader? _citiesLoader;

  List<GeographyCountry>? _countries;
  final Map<String, List<GeographyRegion>> _regions = {};
  final Map<String, List<GeographyCity>> _cities = {};
  Future<List<GeographyCountry>>? _countriesRequest;
  final Map<String, Future<List<GeographyRegion>>> _regionRequests = {};
  final Map<String, Future<List<GeographyCity>>> _cityRequests = {};

  List<GeographyCountry> get cachedCountries => _countries ?? const [];
  List<GeographyRegion> cachedRegions(String countryId) =>
      _regions[countryId] ?? const [];
  List<GeographyCity> cachedCities(String regionId) =>
      _cities[regionId] ?? const [];

  GeographyCountry? countryById(String? id) => id == null
      ? null
      : cachedCountries.where((value) => value.id == id).firstOrNull;
  GeographyCountry? countryByName(String? name) => name == null
      ? null
      : cachedCountries
            .where(
              (value) =>
                  value.name.trim().toLowerCase() == name.trim().toLowerCase(),
            )
            .firstOrNull;
  GeographyRegion? regionById(String? id) => id == null
      ? null
      : _regions.values
            .expand((values) => values)
            .where((value) => value.id == id)
            .firstOrNull;
  GeographyRegion? regionByName(String countryId, String? name) => name == null
      ? null
      : cachedRegions(countryId)
            .where(
              (value) =>
                  value.name.trim().toLowerCase() == name.trim().toLowerCase(),
            )
            .firstOrNull;
  GeographyCity? cityById(String? id) => id == null
      ? null
      : _cities.values
            .expand((values) => values)
            .where((value) => value.id == id)
            .firstOrNull;
  GeographyCity? cityByName(String regionId, String? name) => name == null
      ? null
      : cachedCities(regionId)
            .where(
              (value) =>
                  value.name.trim().toLowerCase() == name.trim().toLowerCase(),
            )
            .firstOrNull;

  Future<List<GeographyCountry>> getCountries({bool refresh = false}) {
    if (!refresh && _countries != null) {
      return SynchronousFuture(_countries!);
    }
    if (!refresh && _countriesRequest != null) return _countriesRequest!;
    final request = _loadCountries();
    _countriesRequest = request;
    return request.whenComplete(() {
      if (identical(_countriesRequest, request)) _countriesRequest = null;
    });
  }

  Future<List<GeographyRegion>> getRegionsByCountry(
    String countryId, {
    bool refresh = false,
  }) {
    if (countryId.isEmpty) return SynchronousFuture(const []);
    if (!refresh && _regions.containsKey(countryId)) {
      return SynchronousFuture(_regions[countryId]!);
    }
    final pending = _regionRequests[countryId];
    if (!refresh && pending != null) return pending;
    final request = _loadRegions(countryId);
    _regionRequests[countryId] = request;
    return request.whenComplete(() {
      if (identical(_regionRequests[countryId], request)) {
        _regionRequests.remove(countryId);
      }
    });
  }

  Future<List<GeographyCity>> getCitiesByRegion(
    String regionId, {
    bool refresh = false,
  }) {
    if (regionId.isEmpty) return SynchronousFuture(const []);
    if (!refresh && _cities.containsKey(regionId)) {
      return SynchronousFuture(_cities[regionId]!);
    }
    final pending = _cityRequests[regionId];
    if (!refresh && pending != null) return pending;
    final request = _loadCities(regionId);
    _cityRequests[regionId] = request;
    return request.whenComplete(() {
      if (identical(_cityRequests[regionId], request)) {
        _cityRequests.remove(regionId);
      }
    });
  }

  Future<List<GeographyCountry>> _loadCountries() async {
    final custom = _countriesLoader;
    final values = custom != null
        ? await custom()
        : await _countriesFromSupabase();
    _countries = List.unmodifiable(
      [...values]..sort((left, right) => _compareNames(left.name, right.name)),
    );
    return _countries!;
  }

  Future<List<GeographyRegion>> _loadRegions(String countryId) async {
    final custom = _regionsLoader;
    final values = custom != null
        ? await custom(countryId)
        : await _regionsFromSupabase(countryId);
    _regions[countryId] = List.unmodifiable(
      [...values]..sort((left, right) => _compareNames(left.name, right.name)),
    );
    return _regions[countryId]!;
  }

  Future<List<GeographyCity>> _loadCities(String regionId) async {
    final custom = _citiesLoader;
    final values = custom != null
        ? await custom(regionId)
        : await _citiesFromSupabase(regionId);
    _cities[regionId] = List.unmodifiable(
      [...values]..sort((left, right) => _compareNames(left.name, right.name)),
    );
    return _cities[regionId]!;
  }

  Future<List<GeographyCountry>> _countriesFromSupabase() async {
    final client = _clientProvider();
    if (client == null) return const [];
    final rows = await client
        .from('countries')
        .select('id, name, iso2, iso3')
        .eq('is_active', true)
        .order('name', ascending: true);
    return rows
        .cast<Map<String, dynamic>>()
        .map(GeographyCountry.fromJson)
        .toList(growable: false);
  }

  Future<List<GeographyRegion>> _regionsFromSupabase(String countryId) async {
    final client = _clientProvider();
    if (client == null) return const [];
    final rows = await client
        .from('regions')
        .select('id, country_id, name, code')
        .eq('country_id', countryId)
        .eq('is_active', true)
        .order('name', ascending: true);
    return rows
        .cast<Map<String, dynamic>>()
        .map(GeographyRegion.fromJson)
        .toList(growable: false);
  }

  Future<List<GeographyCity>> _citiesFromSupabase(String regionId) async {
    final client = _clientProvider();
    if (client == null) return const [];
    final rows = await client
        .from('cities')
        .select('id, region_id, country_id, name')
        .eq('region_id', regionId)
        .eq('is_active', true)
        .order('name', ascending: true);
    return rows
        .cast<Map<String, dynamic>>()
        .map(GeographyCity.fromJson)
        .toList(growable: false);
  }

  @visibleForTesting
  void clearCache() {
    _countries = null;
    _regions.clear();
    _cities.clear();
    _countriesRequest = null;
    _regionRequests.clear();
    _cityRequests.clear();
  }

  static int _compareNames(String left, String right) =>
      left.toLowerCase().compareTo(right.toLowerCase());
}
