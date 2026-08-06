part of '../app.dart';

GeographyRepository get _geography => GeographyRepository.instance;

List<String> get _worldCountries => _geography.cachedCountries
    .map((country) => country.name)
    .toList(growable: false);

Map<String, List<String>> get _regionsByCountry => {
  for (final country in _geography.cachedCountries)
    country.name: _geography
        .cachedRegions(country.id)
        .map((region) => region.name)
        .toList(growable: false),
};

List<String> _regionOptions(String country) => [
  'Any region',
  ...(_regionsByCountry[country] ?? const <String>[]),
];

List<String> _citiesForCountryRegion(String country, String region) {
  final countryValue = _geography.countryByName(country);
  if (countryValue == null) return const [];
  final regionValue = _geography.regionByName(countryValue.id, region);
  if (regionValue == null) return const [];
  return _geography
      .cachedCities(regionValue.id)
      .map((city) => city.name)
      .toList(growable: false);
}

String _firstRegionForCountry(String country, {bool allowAny = false}) {
  if (allowAny) return 'Any region';
  return _regionsByCountry[country]?.firstOrNull ?? 'Other region';
}

String _firstCityForCountryRegion(
  String country,
  String region, {
  bool allowAny = false,
}) {
  if (allowAny) return 'Any city';
  return _citiesForCountryRegion(country, region).firstOrNull ?? 'Other city';
}

bool _cityBelongsToSelection(String country, String region, String city) =>
    _citiesForCountryRegion(country, region).contains(city);

String? _regionForKnownCity(String country, String city) {
  final countryValue = _geography.countryByName(country);
  if (countryValue == null) return null;
  for (final region in _geography.cachedRegions(countryValue.id)) {
    if (_geography.cachedCities(region.id).any((value) => value.name == city)) {
      return region.name;
    }
  }
  return null;
}

String? _countryId(String? name) => _geography.countryByName(name)?.id;

String? _regionId(String? countryName, String? regionName) {
  final country = _geography.countryByName(countryName);
  return country == null
      ? null
      : _geography.regionByName(country.id, regionName)?.id;
}

String? _cityId(String? countryName, String? regionName, String? cityName) {
  final region = _regionId(countryName, regionName);
  return region == null ? null : _geography.cityByName(region, cityName)?.id;
}

Future<List<GeographyCountry>> _loadCountries() => _geography.getCountries();

Future<List<GeographyRegion>> _loadRegions(String countryName) async {
  final country = _geography.countryByName(countryName);
  if (country == null) return const [];
  return _geography.getRegionsByCountry(country.id);
}

Future<List<GeographyCity>> _loadCities(
  String countryName,
  String regionName,
) async {
  final country = _geography.countryByName(countryName);
  if (country == null) return const [];
  final region = _geography.regionByName(country.id, regionName);
  if (region == null) return const [];
  return _geography.getCitiesByRegion(region.id);
}
