import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/services/geography_repository.dart';

void main() {
  const canada = GeographyCountry(id: 'ca', name: 'Canada', iso2: 'CA');
  const france = GeographyCountry(id: 'fr', name: 'France', iso2: 'FR');
  const ontario = GeographyRegion(
    id: 'ca-on',
    countryId: 'ca',
    name: 'Ontario',
  );
  const quebec = GeographyRegion(id: 'ca-qc', countryId: 'ca', name: 'Quebec');
  const parisRegion = GeographyRegion(
    id: 'fr-idf',
    countryId: 'fr',
    name: 'Île-de-France',
  );
  const toronto = GeographyCity(
    id: 'ca-on-toronto',
    regionId: 'ca-on',
    countryId: 'ca',
    name: 'Toronto',
  );

  test('loads countries, then only requested regions and cities', () async {
    var countryCalls = 0;
    final regionCalls = <String>[];
    final cityCalls = <String>[];
    final repository = GeographyRepository.forTesting(
      countriesLoader: () async {
        countryCalls++;
        return const [canada, france];
      },
      regionsLoader: (countryId) async {
        regionCalls.add(countryId);
        return countryId == canada.id
            ? const [ontario, quebec]
            : const [parisRegion];
      },
      citiesLoader: (regionId) async {
        cityCalls.add(regionId);
        return regionId == ontario.id ? const [toronto] : const [];
      },
    );

    expect(await repository.getCountries(), const [canada, france]);
    expect(countryCalls, 1);
    expect(regionCalls, isEmpty);
    expect(cityCalls, isEmpty);

    expect(await repository.getRegionsByCountry(canada.id), [ontario, quebec]);
    expect(regionCalls, [canada.id]);
    expect(cityCalls, isEmpty);

    expect(await repository.getCitiesByRegion(ontario.id), [toronto]);
    expect(cityCalls, [ontario.id]);
  });

  test(
    'caches completed requests and deduplicates concurrent requests',
    () async {
      var calls = 0;
      final completer = Completer<List<GeographyRegion>>();
      final repository = GeographyRepository.forTesting(
        countriesLoader: () async => const [canada],
        regionsLoader: (_) {
          calls++;
          return completer.future;
        },
        citiesLoader: (_) async => const [],
      );

      final first = repository.getRegionsByCountry(canada.id);
      final second = repository.getRegionsByCountry(canada.id);
      expect(calls, 1);
      completer.complete(const [ontario]);
      expect(await first, const [ontario]);
      expect(await second, const [ontario]);
      expect(await repository.getRegionsByCountry(canada.id), const [ontario]);
      expect(calls, 1);
    },
  );

  test('keeps caches scoped to their parent identifiers', () async {
    final repository = GeographyRepository.forTesting(
      countriesLoader: () async => const [canada, france],
      regionsLoader: (id) async =>
          id == canada.id ? const [ontario] : const [parisRegion],
      citiesLoader: (id) async => id == ontario.id ? const [toronto] : const [],
    );

    await repository.getCountries();
    await repository.getRegionsByCountry(canada.id);
    expect(repository.cachedRegions(france.id), isEmpty);
    await repository.getCitiesByRegion(ontario.id);
    expect(repository.cachedCities(parisRegion.id), isEmpty);
  });

  test('sorts countries, regions and cities alphabetically', () async {
    const ottawa = GeographyCity(
      id: 'ca-on-ottawa',
      regionId: 'ca-on',
      countryId: 'ca',
      name: 'Ottawa',
    );
    const hamilton = GeographyCity(
      id: 'ca-on-hamilton',
      regionId: 'ca-on',
      countryId: 'ca',
      name: 'Hamilton',
    );
    final repository = GeographyRepository.forTesting(
      countriesLoader: () async => const [france, canada],
      regionsLoader: (_) async => const [quebec, ontario],
      citiesLoader: (_) async => const [toronto, ottawa, hamilton],
    );

    expect((await repository.getCountries()).map((value) => value.name), [
      'Canada',
      'France',
    ]);
    expect(
      (await repository.getRegionsByCountry(
        canada.id,
      )).map((value) => value.name),
      ['Ontario', 'Quebec'],
    );
    expect(
      (await repository.getCitiesByRegion(
        ontario.id,
      )).map((value) => value.name),
      ['Hamilton', 'Ottawa', 'Toronto'],
    );
  });
}
