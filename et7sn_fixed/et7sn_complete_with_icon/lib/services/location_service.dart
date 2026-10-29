import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    this.isFallback = false,
  });

  final double latitude;
  final double longitude;

  /// True when this is the default city rather than the device's real position.
  final bool isFallback;
}

enum LocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.issue);
  final LocationIssue issue;

  String message({required bool isArabic}) {
    switch (issue) {
      case LocationIssue.serviceDisabled:
        return isArabic ? 'خدمة الموقع (GPS) متوقفة' : 'Location services (GPS) are turned off.';
      case LocationIssue.permissionDenied:
        return isArabic ? 'لم يتم السماح بالوصول إلى الموقع' : 'Location permission was denied.';
      case LocationIssue.permissionDeniedForever:
        return isArabic
            ? 'تم رفض إذن الموقع نهائياً. فعّله من إعدادات التطبيق.'
            : 'Location permission is permanently denied. Enable it in app settings.';
      case LocationIssue.unavailable:
        return isArabic ? 'تعذر تحديد موقعك الآن' : 'Could not determine your location right now.';
    }
  }

  @override
  String toString() => 'LocationFailure($issue)';
}

/// Wraps `geolocator`: service check → permission → position, with a cached
/// last-known location so prayer times still work offline / with GPS off.
class LocationService {
  static const _latKey = 'last_lat';
  static const _lngKey = 'last_lng';

  /// Cairo — used only when the user chooses to skip GPS.
  static const cairoFallback = AppLocation(
    latitude: 30.0444,
    longitude: 31.2357,
    isFallback: true,
  );

  Future<AppLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(LocationIssue.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(LocationIssue.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationIssue.permissionDeniedForever);
    }

    Position? position;
    try {
      // City-level accuracy is plenty for prayer times and saves battery.
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw const LocationFailure(LocationIssue.unavailable);
    }

    final location = AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _cache(location);
    return location;
  }

  Future<AppLocation?> cachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return AppLocation(latitude: lat, longitude: lng);
  }

  Future<void> _cache(AppLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, location.latitude);
    await prefs.setDouble(_lngKey, location.longitude);
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
