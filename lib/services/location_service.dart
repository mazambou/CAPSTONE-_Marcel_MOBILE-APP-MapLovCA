import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../config/supabase_config.dart';
import 'maplov_repository.dart';

enum MapLovLocationFailureReason { serviceDisabled, denied, deniedForever }

class MapLovLocationFailure implements Exception {
  const MapLovLocationFailure(this.reason);

  final MapLovLocationFailureReason reason;

  bool get requiresSettings => reason != MapLovLocationFailureReason.denied;

  @override
  String toString() => switch (reason) {
    MapLovLocationFailureReason.serviceDisabled =>
      'Location services are disabled.',
    MapLovLocationFailureReason.denied => 'Location permission was denied.',
    MapLovLocationFailureReason.deniedForever =>
      'Location permission is blocked in the device settings.',
  };
}

class DetectedResidence {
  const DetectedResidence({
    required this.position,
    required this.country,
    required this.countryCode,
    required this.region,
    required this.city,
  });

  final Position position;
  final String country;
  final String countryCode;
  final String region;
  final String city;
}

class ResidenceDetectionFailure implements Exception {
  const ResidenceDetectionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  const LocationService._();
  static const instance = LocationService._();

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const MapLovLocationFailure(
        MapLovLocationFailureReason.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const MapLovLocationFailure(
        MapLovLocationFailureReason.deniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const MapLovLocationFailure(MapLovLocationFailureReason.denied);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return position;
  }

  @visibleForTesting
  static ({String country, String countryCode, String region, String city})
  parseWebResidence(Object? value) {
    if (value is! Map) {
      throw const ResidenceDetectionFailure(
        'Unable to determine the residence from this location.',
      );
    }
    String field(String name) => value[name]?.toString().trim() ?? '';
    final country = field('country');
    final countryCode = field('countryCode').toUpperCase();
    final region = field('region');
    final city = field('city');
    if (country.isEmpty || countryCode.length != 2) {
      throw const ResidenceDetectionFailure(
        'Unable to determine the residence country.',
      );
    }
    return (
      country: country,
      countryCode: countryCode,
      region: region,
      city: city,
    );
  }

  static String residenceErrorMessage(Object error) => switch (error) {
    ResidenceDetectionFailure() => error.message,
    MapLovLocationFailure() => error.toString(),
    _ => 'Unable to verify your residence location. Please try again.',
  };

  Future<DetectedResidence> _reverseGeocodeWeb(Position position) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ResidenceDetectionFailure(
        'The Web residence verification service is unavailable.',
      );
    }
    try {
      final response = await client.functions.invoke(
        'reverse-geocode-location',
        body: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      if (response.status < 200 || response.status >= 300) {
        throw const ResidenceDetectionFailure(
          'Unable to determine the residence from this location.',
        );
      }
      final address = parseWebResidence(response.data);
      return DetectedResidence(
        position: position,
        country: address.country,
        countryCode: address.countryCode,
        region: address.region,
        city: address.city,
      );
    } on ResidenceDetectionFailure {
      rethrow;
    } catch (_) {
      throw const ResidenceDetectionFailure(
        'Unable to verify your residence location. Please try again.',
      );
    }
  }

  Future<DetectedResidence> _reverseGeocodeNative(Position position) async {
    final placemarks = await Geocoding(
      locale: const Locale('en'),
    ).placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isEmpty) {
      throw const ResidenceDetectionFailure(
        'Unable to determine the residence from this location.',
      );
    }
    final place = placemarks.first;
    final country = place.country?.trim() ?? '';
    final countryCode = place.isoCountryCode?.trim().toUpperCase() ?? '';
    if (country.isEmpty || countryCode.length != 2) {
      throw const ResidenceDetectionFailure(
        'Unable to determine the residence country.',
      );
    }
    return DetectedResidence(
      position: position,
      country: country,
      countryCode: countryCode,
      region: (place.administrativeArea ?? place.subAdministrativeArea ?? '')
          .trim(),
      city: (place.locality ?? place.subAdministrativeArea ?? place.name ?? '')
          .trim(),
    );
  }

  Future<DetectedResidence> _reverseGeocode(Position position) =>
      kIsWeb ? _reverseGeocodeWeb(position) : _reverseGeocodeNative(position);

  Future<DetectedResidence> detectResidence() async =>
      _reverseGeocode(await _currentPosition());

  Future<Position> updateMyLocation() async {
    final position = await _currentPosition();
    await MapLovRepository.instance.updateLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
    try {
      final residence = await _reverseGeocode(position);
      await MapLovRepository.instance.syncResidenceFromLocation(
        country: residence.country,
        countryCode: residence.countryCode,
        region: residence.region,
        city: residence.city,
      );
    } catch (_) {
      // Nearby distance remains usable if the native reverse-geocoder is
      // temporarily unavailable. Registration performs the strict check.
    }
    return position;
  }

  Future<bool> openRequiredSettings(MapLovLocationFailure failure) =>
      failure.reason == MapLovLocationFailureReason.serviceDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
