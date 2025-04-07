import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePreferences {
  static const String _startKey = 'route_start_location';
  static const String _endKey = 'route_end_location';
  static const String _startCoordsKey = 'route_start_coordinates';
  static const String _endCoordsKey = 'route_end_coordinates';
  static const String _travelModeKey = 'route_travel_mode';

  static Future<void> saveRouteData({
    required String startLocation,
    required String endLocation,
    String travelMode = 'driving',
    LatLng? startCoords,
    LatLng? endCoords,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_startKey, startLocation),
      prefs.setString(_endKey, endLocation),
      prefs.setString(_travelModeKey, travelMode),
      if (startCoords != null)
        prefs.setString(_startCoordsKey,
            '${startCoords.latitude},${startCoords.longitude}'),
      if (endCoords != null)
        prefs.setString(
            _endCoordsKey, '${endCoords.latitude},${endCoords.longitude}'),
    ]);
  }

  static Future<Map<String, dynamic>> getRouteData() async {
    final prefs = await SharedPreferences.getInstance();

    LatLng? startLatLng;
    LatLng? endLatLng;

    final startCoords = prefs.getString(_startCoordsKey);
    final endCoords = prefs.getString(_endCoordsKey);

    if (startCoords?.contains(',') ?? false) {
      final coords = startCoords!.split(',');
      if (coords.length == 2) {
        startLatLng = LatLng(double.tryParse(coords[0]) ?? 0.0,
            double.tryParse(coords[1]) ?? 0.0);
      }
    }

    if (endCoords?.contains(',') ?? false) {
      final coords = endCoords!.split(',');
      if (coords.length == 2) {
        endLatLng = LatLng(double.tryParse(coords[0]) ?? 0.0,
            double.tryParse(coords[1]) ?? 0.0);
      }
    }

    return {
      'startLocation': prefs.getString(_startKey) ?? '',
      'endLocation': prefs.getString(_endKey) ?? '',
      'travelMode': prefs.getString(_travelModeKey) ?? 'driving',
      'startCoords': startLatLng,
      'endCoords': endLatLng,
    };
  }

  static Future<void> clearRouteData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_startKey);
    await prefs.remove(_endKey);
    await prefs.remove(_startCoordsKey);
    await prefs.remove(_endCoordsKey);
    await prefs.remove(_travelModeKey);
  }
}
