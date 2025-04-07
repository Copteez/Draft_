import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

List<List<double>> decodePoly(String poly) {
  var list = poly.codeUnits;
  List<List<double>> points = [];
  int index = 0;
  int len = poly.length;
  int lat = 0;
  int lng = 0;
  while (index < len) {
    int shift = 0;
    int result = 0;
    while (true) {
      int byte = list[index] - 63;
      index++;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }
    int dLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dLat;
    shift = 0;
    result = 0;
    while (true) {
      int byte = list[index] - 63;
      index++;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }
    int dLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dLng;
    points.add([lat / 1e5, lng / 1e5]);
  }
  return points;
}

Future<List<LatLng>> decodePolyAsync(String poly) async {
  final List<List<double>> list = await compute(decodePoly, poly);
  return list.map((e) => LatLng(e[0], e[1])).toList();
}

List<LatLng> smoothPolyline(List<LatLng> points,
    {int numPointsPerSegment = 10}) {
  if (points.length < 4) return points;
  List<LatLng> smoothedPoints = [];
  for (int i = 0; i < points.length - 1; i++) {
    LatLng p0 = i == 0 ? points[i] : points[i - 1];
    LatLng p1 = points[i];
    LatLng p2 = points[i + 1];
    LatLng p3 = (i + 2 < points.length) ? points[i + 2] : points[i + 1];
    for (int j = 0; j < numPointsPerSegment; j++) {
      double t = j / numPointsPerSegment;
      double t2 = t * t;
      double t3 = t2 * t;
      double lat = 0.5 *
          (2 * p1.latitude +
              (-p0.latitude + p2.latitude) * t +
              (2 * p0.latitude -
                      5 * p1.latitude +
                      4 * p2.latitude -
                      p3.latitude) *
                  t2 +
              (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) *
                  t3);
      double lng = 0.5 *
          (2 * p1.longitude +
              (-p0.longitude + p2.longitude) * t +
              (2 * p0.longitude -
                      5 * p1.longitude +
                      4 * p2.longitude -
                      p3.longitude) *
                  t2 +
              (-p0.longitude +
                      3 * p1.longitude -
                      3 * p2.longitude +
                      p3.longitude) *
                  t3);
      smoothedPoints.add(LatLng(lat, lng));
    }
  }
  smoothedPoints.add(points.last);
  return smoothedPoints;
}

double computeCumulativeDistance(LatLng point, List<LatLng> polyline) {
  double total = 0.0;
  for (int i = 1; i < polyline.length; i++) {
    total += haversine(
      polyline[i - 1].latitude,
      polyline[i - 1].longitude,
      polyline[i].latitude,
      polyline[i].longitude,
    );
    if ((polyline[i].latitude - point.latitude).abs() < 0.0001 &&
        (polyline[i].longitude - point.longitude).abs() < 0.0001) {
      break;
    }
  }
  return total;
}

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371;
  final phi1 = math.pi * lat1 / 180;
  final phi2 = math.pi * lat2 / 180;
  final deltaPhi = math.pi * (lat2 - lat1) / 180;
  final deltaLambda = math.pi * (lon2 - lon1) / 180;

  final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLambda / 2) *
          math.sin(deltaLambda / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}
