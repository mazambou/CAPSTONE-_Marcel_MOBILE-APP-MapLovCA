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

class LocationService {
  const LocationService._();
  static const instance = LocationService._();

  Future<Position> updateMyLocation() async {
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
    await MapLovRepository.instance.updateLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
    return position;
  }

  Future<bool> openRequiredSettings(MapLovLocationFailure failure) =>
      failure.reason == MapLovLocationFailureReason.serviceDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
