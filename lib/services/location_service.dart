import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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

  Future<DetectedResidence> _reverseGeocode(Position position) async {
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
