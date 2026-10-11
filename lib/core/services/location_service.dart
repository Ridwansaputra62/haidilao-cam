import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationInfo {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final bool isAccurate;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    this.isAccurate = true,
  });

  String get fullLocationString {
    if (address.isNotEmpty) {
      return '$address ($latitude, $longitude)';
    }
    return '$latitude, $longitude';
  }
}

class LocationService {
  static Future<LocationInfo> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _getFallbackLocation('GPS Nonaktif');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _getFallbackLocation('Izin Lokasi Ditolak');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _getFallbackLocation('Izin Lokasi Permanen Ditolak');
      }

      Position? position;
      // 1. Ambil last known position secara instan (0 detik) agar tidak loading lama
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 2. Jika belum ada last known, fetch dengan timeout pendek (3 detik)
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (_) {}
      }

      if (position == null) {
        return _getFallbackLocation('Haidilao Store Area');
      }

      String address = '';
      String city = '';

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 4));

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          List<String> parts = [];
          if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
          if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
          if (place.locality != null && place.locality!.isNotEmpty) {
            parts.add(place.locality!);
            city = place.locality!;
          }
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty && city.isEmpty) {
            city = place.subAdministrativeArea!;
          }
          address = parts.join(', ');
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }

      if (address.isEmpty) {
        address = 'Lat: ${position.latitude.toStringAsFixed(4)}, Long: ${position.longitude.toStringAsFixed(4)}';
      }

      return LocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        city: city.isNotEmpty ? city : 'Jakarta',
        isAccurate: true,
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return _getFallbackLocation('Haidilao Store Area');
    }
  }

  static LocationInfo _getFallbackLocation(String note) {
    return LocationInfo(
      latitude: -6.1938,
      longitude: 106.8226,
      address: 'Jl. M.H. Thamrin No.1, Menteng, Jakarta Pusat ($note)',
      city: 'Jakarta Pusat',
      isAccurate: false,
    );
  }
}
