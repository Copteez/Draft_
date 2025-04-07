import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteSegment {
  final List<LatLng> points;
  final double aqi;
  final List<Map<String, dynamic>> nearbyStations;

  RouteSegment(
      {required this.points,
      required this.aqi,
      this.nearbyStations = const []});
}

class WeightedStation {
  final int aqi;
  final double weight;
  final String stationName;
  final double distance;

  WeightedStation(
      {required this.aqi,
      required this.weight,
      required this.stationName,
      required this.distance});
}

class StationAccumulator {
  double startDistance;
  double endDistance;
  double sumAqi;
  int count;

  StationAccumulator({
    required this.startDistance,
    required this.endDistance,
    required this.sumAqi,
    required this.count,
  });
}

class RouteCalculation {
  final String stationName;
  final double startDistance;
  final double endDistance;
  final int aqi;

  RouteCalculation({
    required this.stationName,
    required this.startDistance,
    required this.endDistance,
    required this.aqi,
  });
}

class RouteOption {
  final int routeIndex;
  final double avgAqi;
  final List<RouteCalculation> calculations;
  final bool isSafest;
  final int displayIndex;

  RouteOption({
    required this.routeIndex,
    required this.avgAqi,
    required this.calculations,
    this.isSafest = false,
    required this.displayIndex,
  });
}
