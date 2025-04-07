import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'map_route_models.dart';
import 'map_route_utils.dart';
import 'map_polyline_utils.dart';

Future<List<LatLng>> getRoutePoints(
    LatLng origin, LatLng destination, String travelMode, String apiKey) async {
  final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${destination.latitude},${destination.longitude}',
    'mode': travelMode,
    'alternatives': 'true',
    'key': apiKey,
  });

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final routes = data['routes'];
    if (routes != null && routes.isNotEmpty) {
      final overview = routes[0]['overview_polyline']['points'];
      List<LatLng> rawPoints = await decodePolyAsync(overview);
      return smoothPolyline(rawPoints, numPointsPerSegment: 10);
    }
  }
  throw Exception('Failed to load route');
}

double calculateRouteSafetyScore(
    List<LatLng> route, List<Map<String, dynamic>> stations) {
  double totalScore = 0;
  int samplePoints = 0;

  // Sample points along the route
  for (int i = 0; i < route.length - 1; i++) {
    LatLng start = route[i];
    LatLng end = route[i + 1];

    // Find nearby stations
    List<Map<String, dynamic>> nearbyStations = stations.where((station) {
      double? lat = double.tryParse(station["lat"]?.toString() ?? "");
      double? lon = double.tryParse(station["lon"]?.toString() ?? "");
      if (lat == null || lon == null) return false;

      double distance = distanceToSegment(lat, lon, start.latitude,
          start.longitude, end.latitude, end.longitude);
      return distance <= 0.5; // Within 500m
    }).toList();

    if (nearbyStations.isEmpty) continue;

    // Calculate weighted average AQI for this segment
    double segmentScore = 0;
    double totalWeight = 0;

    for (var station in nearbyStations) {
      int aqi = int.tryParse(station["aqi"]?.toString() ?? "0") ?? 0;
      double? lat = double.tryParse(station["lat"]?.toString() ?? "");
      double? lon = double.tryParse(station["lon"]?.toString() ?? "");
      if (lat == null || lon == null) continue;

      double distance = distanceToSegment(lat, lon, start.latitude,
          start.longitude, end.latitude, end.longitude);

      double weight = 1 / (distance + 0.1);
      segmentScore += aqi * weight;
      totalWeight += weight;
    }

    if (totalWeight > 0) {
      totalScore += segmentScore / totalWeight;
      samplePoints++;
    }
  }

  return samplePoints > 0 ? totalScore / samplePoints : double.infinity;
}

Future<Polyline> createRoutePolyline(
    RouteSegment segment, String id, double opacity) async {
  return Polyline(
    polylineId: PolylineId(id),
    points: segment.points,
    color: getAQIColor(segment.aqi.round()).withOpacity(opacity),
    width: 5,
  );
}

LatLngBounds getRouteBounds(LatLng origin, LatLng destination) {
  return LatLngBounds(
    southwest: LatLng(
      math.min(origin.latitude, destination.latitude),
      math.min(origin.longitude, destination.longitude),
    ),
    northeast: LatLng(
      math.max(origin.latitude, destination.latitude),
      math.max(origin.longitude, destination.longitude),
    ),
  );
}
