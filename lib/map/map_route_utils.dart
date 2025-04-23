import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'map_route_models.dart';
import 'map_polyline_utils.dart';
import 'package:flutter/material.dart';

List<RouteSegment> createSegmentsInIsolate(Map<String, dynamic> params) {
  final points = params['points'] as List<LatLng>;
  final stations = params['stations'] as List<Map<String, dynamic>>;
  final segmentLength = params['segmentLength'] as double;

  List<RouteSegment> segments = [];
  List<LatLng> currentSegment = [points.first];
  double currentDistance = 0;

  for (int i = 1; i < points.length; i++) {
    LatLng prev = points[i - 1];
    LatLng curr = points[i];

    double segmentDistance =
        haversine(prev.latitude, prev.longitude, curr.latitude, curr.longitude);

    currentDistance += segmentDistance;
    currentSegment.add(curr);

    if (currentDistance >= segmentLength || i == points.length - 1) {
      // Calculate segment center
      double centerLat = 0, centerLon = 0;
      for (var point in currentSegment) {
        centerLat += point.latitude;
        centerLon += point.longitude;
      }
      centerLat /= currentSegment.length;
      centerLon /= currentSegment.length;

      // Find nearest station regardless of distance
      WeightedStation? nearestStation;
      double minDistance = double.infinity;

      for (var station in stations) {
        double? lat = double.tryParse(station["lat"]?.toString() ?? "");
        double? lon = double.tryParse(station["lon"]?.toString() ?? "");
        int? aqi = int.tryParse(station["aqi"]?.toString() ?? "");

        if (lat == null || lon == null || aqi == null || aqi <= 0) continue;

        double distance = haversine(centerLat, centerLon, lat, lon);
        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = WeightedStation(
            aqi: aqi,
            weight: 1 / (distance + 0.1),
            stationName: station["station_name"] ?? "Unknown",
            distance: distance,
          );
        }
      }

      double finalAqi = nearestStation?.aqi.toDouble() ?? 0;
      List<Map<String, dynamic>> stationInfo = nearestStation != null
          ? [
              {
                'name': nearestStation.stationName,
                'aqi': nearestStation.aqi,
                'distance': nearestStation.distance,
              }
            ]
          : [];

      segments.add(RouteSegment(
        points: List.from(currentSegment),
        aqi: finalAqi,
        nearbyStations: stationInfo,
      ));

      // Start new segment
      currentSegment = [curr];
      currentDistance = 0;
    }
  }

  return segments;
}

double calculateSegmentProgress(LatLng point, LatLng start, LatLng end) {
  double dx = end.longitude - start.longitude;
  double dy = end.latitude - start.latitude;
  double segmentLength = math.sqrt(dx * dx + dy * dy);

  if (segmentLength == 0) return 0;

  double px = point.longitude - start.longitude;
  double py = point.latitude - start.latitude;

  double dot = (px * dx + py * dy) / (segmentLength * segmentLength);
  return dot.clamp(0, 1);
}

double distanceToSegment(
  double px,
  double py,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  double A = px - x1;
  double B = py - y1;
  double C = x2 - x1;
  double D = y2 - y1;

  double dot = A * C + B * D;
  double len_sq = C * C + D * D;
  double param = dot / len_sq;

  double xx, yy;

  if (param < 0) {
    xx = x1;
    yy = y1;
  } else if (param > 1) {
    xx = x2;
    yy = y2;
  } else {
    xx = x1 + param * C;
    yy = y1 + param * D;
  }

  return haversine(px, py, xx, yy);
}

double findDistanceAlongRoute(Map<String, dynamic> params) {
  final userLocation = params['userLocation'] as LatLng;
  final routePoints = params['routePoints'] as List<LatLng>;

  if (routePoints.isEmpty) return 0;

  double bestPerpDistance = double.infinity;
  double bestCumulativeDistance = 0.0;
  double cumulativeDistance = 0.0;
  double totalRouteDistance = 0.0;

  // First calculate total route distance
  for (int i = 0; i < routePoints.length - 1; i++) {
    LatLng a = routePoints[i];
    LatLng b = routePoints[i + 1];
    totalRouteDistance +=
        haversine(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  // Then find where the user is along this route
  for (int i = 0; i < routePoints.length - 1; i++) {
    LatLng a = routePoints[i];
    LatLng b = routePoints[i + 1];
    double segmentLength =
        haversine(a.latitude, a.longitude, b.latitude, b.longitude);

    double perpDistance = distanceToSegment(
      userLocation.latitude,
      userLocation.longitude,
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    if (perpDistance < bestPerpDistance) {
      bestPerpDistance = perpDistance;

      // Calculate how far along this segment the user is
      double proj = calculateSegmentProgress(userLocation, a, b);
      double projectedDistance = segmentLength * proj;

      bestCumulativeDistance = cumulativeDistance + projectedDistance;
    }

    cumulativeDistance += segmentLength;
  }

  // Ensure we don't return a value greater than the total route distance
  return math.min(bestCumulativeDistance, totalRouteDistance);
}

Color getAQIColor(int aqi) {
  if (aqi <= 0) return Colors.grey;
  if (aqi <= 50) return Colors.green;
  if (aqi <= 100) return const Color.fromARGB(255, 223, 205, 43);
  if (aqi <= 150) return Colors.orange;
  if (aqi <= 200) return Colors.red;
  if (aqi <= 300) return Colors.purple;
  return Colors.brown;
}

Set<Marker> createMarkersInIsolate(Map<String, dynamic> params) {
  // Implementation for creating markers
  return {};
}
