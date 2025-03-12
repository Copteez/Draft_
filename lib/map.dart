import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:MySecureMap/config.dart';
import 'package:MySecureMap/home_page/widgets/drawer_widget.dart';
import 'package:MySecureMap/map/map_source_dropdown.dart';
import 'package:MySecureMap/map/map_theme.dart';
import 'package:MySecureMap/map/map_search_section.dart';
import 'package:MySecureMap/details_page.dart';

/// Decodes a polyline into a list of coordinate pairs.
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

/// Asynchronously decodes a polyline into a list of LatLng.
Future<List<LatLng>> decodePolyAsync(String poly) async {
  final List<List<double>> list = await compute(decodePoly, poly);
  return list.map((e) => LatLng(e[0], e[1])).toList();
}

/// Smooths a polyline using Catmull-Rom spline interpolation.
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

/// Computes cumulative distance along a polyline from its start to a given point (in km).
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

/// Haversine formula: returns distance in km between two coordinates.
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

class MapPage extends StatefulWidget {
  final AppConfig config;
  final double? initialLat;
  final double? initialLon;
  final String? locationName;
  const MapPage({
    Key? key,
    required this.config,
    this.initialLat,
    this.initialLon,
    this.locationName,
  }) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  String _selectedSource = "All";
  List<String> _sources = ["All"];
  List<Map<String, dynamic>> _allStations = [];
  Set<Marker> _markers = {};
  Map<PolylineId, Polyline> polylines = {};
  bool _isDarkMode = true;
  String _selectedParameter = "AQI";
  final List<String> _parameters = ["AQI", "PM2.5", "PM10", "O3", "SO2"];
  bool _hasHandledRouteArguments = false;
  bool _isRouteLoading = false;
  bool _markersLoaded = false;

  // For custom info window
  Map<String, dynamic>? _selectedStationDetail;
  LatLng? _selectedMarkerLatLng;
  Offset? _infoWindowOffset;

  // For route selection:
  Map<int, List<LatLng>> _routePolylines = {};
  int _selectedRouteIndex = 0;

  // User ID (dummy for now)
  String? _userId;
  final String baseUrl =
      "https://3e24-2001-fb1-178-76e-402b-db55-4cab-efc.ngrok-free.app";

  // Add new state variables
  Map<int, double> _routeSafetyScores = {};
  int? _safestRouteIndex;

  // Add new state variable to store all route polylines
  final Map<String, Polyline> _allPolylines = {};

  // Add new state variable for route loading
  bool _isRoutePlotting = false;

  // Add cache for route colors
  Map<String, Color> _segmentColors = {};

  // Add new constants for segmentation
  static const double SEGMENT_LENGTH = 0.2; // 200 meters per segment
  static const double MERGE_THRESHOLD =
      10; // AQI difference threshold for merging

  // Add marker cache
  static final Map<int, BitmapDescriptor> _markerIconCache = {};
  Timer? _markersUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Add user ID loading
    _loadUserId();
    Future.wait([
      _initializeUserAndLocation(),
      _fetchSources(),
    ]).then((_) {
      _fetchAllAQIStations();
      if (_mapController != null && _currentLocation != null) {
        _mapController!
            .animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
      }
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id')?.toString();
    });
  }

  Future<void> _initializeUserAndLocation() async {
    if (widget.initialLat != null && widget.initialLon != null) {
      setState(() {
        _currentLocation = LatLng(widget.initialLat!, widget.initialLon!);
      });
    } else {
      await _getCurrentLocation();
    }
    // TODO: Load user id if needed.
  }

  void _handleRouteArguments() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null &&
        args.containsKey("origin") &&
        args.containsKey("destination")) {
      final originMap = args["origin"] as Map<String, dynamic>;
      final destinationMap = args["destination"] as Map<String, dynamic>;
      final origin = LatLng(originMap["lat"], originMap["lon"]);
      final destination = LatLng(destinationMap["lat"], destinationMap["lon"]);
      if (_mapController == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_mapController != null) {
            _loadRoute(origin, destination, "driving");
            _updateCameraPositionForRoute(origin, destination);
          }
        });
      } else {
        _loadRoute(origin, destination, "driving");
        _updateCameraPositionForRoute(origin, destination);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleRouteArguments();
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    if (address.trim().toLowerCase() == "your location") {
      return _currentLocation;
    }
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations[0].latitude, locations[0].longitude);
      }
    } catch (e) {
      print("Error in geocoding: $e");
    }
    return null;
  }

  /// Load route from Directions API and store only segmented polyline.
  Future<void> _loadRoute(
      LatLng origin, LatLng destination, String travelMode) async {
    setState(() {
      _routePolylines.clear();
      _allPolylines.clear();
      _selectedRouteIndex = -1; // or null if you prefer
      _isRoutePlotting = true; // Set loading state
    });
    _populateAllMarkers();
    final String apiKey = widget.config.googleApiKey;
    final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': travelMode,
      'alternatives': 'true',
      'key': apiKey,
    });
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'];
        if (routes != null && routes.isNotEmpty) {
          int routeCount = routes.length >= 3 ? 3 : routes.length;
          _routeSafetyScores.clear();

          for (int r = 0; r < routeCount; r++) {
            final overview = routes[r]['overview_polyline']['points'];
            List<LatLng> rawPoints = await decodePolyAsync(overview);
            List<LatLng> points =
                smoothPolyline(rawPoints, numPointsPerSegment: 10);
            _routePolylines[r] = points;

            // Calculate safety score for this route
            _routeSafetyScores[r] = _calculateRouteSafetyScore(points);
          }

          // Find safest route
          _safestRouteIndex = _routeSafetyScores.entries
              .reduce((a, b) => a.value < b.value ? a : b)
              .key;

          // Create all route polylines at once
          for (int r = 0; r < routeCount; r++) {
            await _createRoutePolylines(_routePolylines[r]!,
                routeIndex: r, opacity: r == _safestRouteIndex ? 1.0 : 0.3);
          }

          setState(() {
            _selectedRouteIndex = _safestRouteIndex!;
            polylines = Map.from(_allPolylines);
            _isRoutePlotting = false;
          });
        } else {
          print("No routes found");
        }
      } else {
        print("Error fetching directions: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching polyline: $e");
    } finally {
      setState(() {
        _isRouteLoading = false;
        _isRoutePlotting = false;
      });
      await _fetchAllAQIStations();
    }
  }

  /// New method to create route polylines
  Future<void> _createRoutePolylines(List<LatLng> points,
      {required int routeIndex, required double opacity}) async {
    final segments = await compute(_createSegmentsInIsolate, {
      'points': points,
      'stations': _allStations,
      'segmentLength': SEGMENT_LENGTH,
    });

    for (int i = 0; i < segments.length; i++) {
      RouteSegment segment = segments[i];
      String polylineId = "seg_${routeIndex}_$i";

      // Get color based on nearest station AQI
      Color segColor = segment.nearbyStations.isNotEmpty
          ? _getAQIColor(segment.nearbyStations.first['aqi'])
          : Colors.grey;

      _allPolylines[polylineId] = Polyline(
        polylineId: PolylineId(polylineId),
        points: segment.points,
        color: segColor.withOpacity(opacity),
        width: 5,
        onTap: () => _showSegmentInfo(segment),
      );
    }
  }

  /// Improved route segmentation
  Future<List<RouteSegment>> _createSegments(List<LatLng> points) async {
    const double SEGMENT_LENGTH = 0.2; // 200m segments

    List<RouteSegment> segments = [];
    List<LatLng> currentSegment = [points.first];
    double currentDistance = 0;

    for (int i = 1; i < points.length; i++) {
      LatLng prev = points[i - 1];
      LatLng curr = points[i];

      double segmentDistance = haversine(
          prev.latitude, prev.longitude, curr.latitude, curr.longitude);

      currentDistance += segmentDistance;
      currentSegment.add(curr);

      if (currentDistance >= SEGMENT_LENGTH || i == points.length - 1) {
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

        for (var station in _allStations) {
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

  /// Calculate average AQI for a route segment based on nearby stations
  Color _getSegmentColor(
      LatLng start, LatLng end, List<Map<String, dynamic>> stations) {
    double totalAQI = 0;
    int count = 0;

    // Calculate midpoint of segment
    LatLng midpoint = LatLng((start.latitude + end.latitude) / 2,
        (start.longitude + end.longitude) / 2);

    // Find stations within 500m of segment midpoint
    for (var station in stations) {
      double? lat = double.tryParse(station["lat"]?.toString() ?? "");
      double? lon = double.tryParse(station["lon"]?.toString() ?? "");
      int? aqi = int.tryParse(station["aqi"]?.toString() ?? "");

      if (lat != null && lon != null && aqi != null) {
        double distance =
            haversine(midpoint.latitude, midpoint.longitude, lat, lon);

        // Only consider stations within 500m
        if (distance <= 0.5) {
          // Weight by inverse distance
          double weight =
              1 / (distance + 0.1); // Add 0.1 to avoid division by zero
          totalAQI += aqi * weight;
          count += 1;
        }
      }
    }

    if (count > 0) {
      int avgAQI = (totalAQI / count).round();
      return _getAQIColor(avgAQI);
    }

    // Default color if no stations nearby
    return Colors.grey;
  }

  /// Calculate safety score for a route (lower is safer)
  double _calculateRouteSafetyScore(List<LatLng> route) {
    double totalScore = 0;
    int samplePoints = 0;

    // Sample points along the route
    for (int i = 0; i < route.length - 1; i++) {
      LatLng start = route[i];
      LatLng end = route[i + 1];

      // Find nearby stations
      List<Map<String, dynamic>> nearbyStations = _allStations.where((station) {
        double? lat = double.tryParse(station["lat"]?.toString() ?? "");
        double? lon = double.tryParse(station["lon"]?.toString() ?? "");
        if (lat == null || lon == null) return false;

        double distance = _distanceToSegment(lat, lon, start.latitude,
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

        double distance = _distanceToSegment(lat, lon, start.latitude,
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

  /// Update camera bounds to include both origin and destination.
  void _updateCameraPositionForRoute(LatLng origin, LatLng destination) {
    if (_mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(math.min(origin.latitude, destination.latitude),
            math.min(origin.longitude, destination.longitude)),
        northeast: LatLng(math.max(origin.latitude, destination.latitude),
            math.max(origin.longitude, destination.longitude)),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else {
      print("Warning: _mapController is null, cannot update camera position.");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      if (_mapController != null && _currentLocation != null) {
        _mapController!
            .animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
      }
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Future<void> _fetchSources() async {
    final url = "$baseUrl/api/sources";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          List<dynamic> src = data["sources"];
          setState(() {
            _sources = ["All"] + src.map((e) => e.toString()).toList();
          });
        } else {
          setState(() {
            _sources = ["All"];
          });
        }
      } else {
        setState(() {
          _sources = ["All"];
        });
      }
    } catch (e) {
      setState(() {
        _sources = ["All"];
      });
    }
  }

  Future<void> _fetchAllAQIStations() async {
    String url = "$baseUrl/api/stations-aqi";
    if (_selectedSource != "All") {
      url += "?source=$_selectedSource";
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() {
            _allStations = List<Map<String, dynamic>>.from(data["stations"]);
          });
          _populateAllMarkers();
        } else {
          print("API error: ${data['error']}");
        }
      } else {
        print("Failed to fetch stations: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching all AQI stations: $e");
    }
  }

  /// Populate markers with proper caching
  Future<void> _populateAllMarkers({List<LatLng>? selectedRoute}) async {
    _markersUpdateTimer?.cancel();
    _markersUpdateTimer = Timer(const Duration(milliseconds: 100), () async {
      // Pre-generate marker icons for all AQI values
      for (var station in _allStations) {
        int aqi = int.tryParse(station["aqi"]?.toString() ?? "0") ?? 0;
        if (aqi > 0 && !_markerIconCache.containsKey(aqi)) {
          _markerIconCache[aqi] = await _createCustomMarker(aqi);
        }
      }

      final markers = await compute(_createMarkersInIsolate, {
        'stations': _allStations,
        'currentLocation': _currentLocation,
        'selectedParameter': _selectedParameter,
        'markerCache': _markerIconCache,
      });

      if (mounted) {
        setState(() {
          _markers = markers;
          _markersLoaded = true;
        });
      }
    });
  }

  // Add this helper method to calculate the distance from a point to a line segment
  double _distanceToSegment(
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

  /// Create a custom marker.
  Future<BitmapDescriptor> _createCustomMarker(int aqi) async {
    if (_markerIconCache.containsKey(aqi)) {
      return _markerIconCache[aqi]!;
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = _getAQIColor(aqi);
    const double radius = 60.0;

    canvas.drawCircle(const Offset(radius, radius), radius, paint);

    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: aqi.toString(),
        style: const TextStyle(
            fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
            radius - textPainter.width / 2, radius - textPainter.height / 2));

    final img = await pictureRecorder
        .endRecording()
        .toImage((radius * 2).toInt(), (radius * 2).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    final icon = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
    _markerIconCache[aqi] = icon;
    return icon;
  }

  Color _getAQIColor(int aqi) {
    if (aqi <= 0) return Colors.grey;
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return const Color.fromARGB(255, 223, 205, 43);
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  Future<void> _updateInfoWindowPosition() async {
    if (_selectedMarkerLatLng != null && _mapController != null) {
      final ScreenCoordinate screenCoordinate =
          await _mapController!.getScreenCoordinate(_selectedMarkerLatLng!);
      setState(() {
        _infoWindowOffset = Offset(
            screenCoordinate.x.toDouble(), screenCoordinate.y.toDouble());
      });
    }
  }

  Widget _buildCustomInfoWindow(Map<String, dynamic> station) {
    String updatedText = "N/A";
    if (station.containsKey("timestamp") && station["timestamp"] != null) {
      try {
        DateTime updatedTime = DateTime.parse(station["timestamp"]);
        final hoursAgo = DateTime.now().difference(updatedTime).inHours;
        updatedText = "$hoursAgo hour(s) ago";
      } catch (e) {
        updatedText = "N/A";
      }
    }
    int aqi = int.tryParse(station["aqi"]?.toString() ?? "0") ?? 0;
    String emoji;
    String level;
    if (aqi <= 50) {
      emoji = "😊";
      level = "Good";
    } else if (aqi <= 100) {
      emoji = "😐";
      level = "Moderate";
    } else if (aqi <= 150) {
      emoji = "😷";
      level = "Unhealthy for Sensitive Groups";
    } else if (aqi <= 200) {
      emoji = "😫";
      level = "Unhealthy";
    } else if (aqi <= 300) {
      emoji = "🤒";
      level = "Very Unhealthy";
    } else {
      emoji = "💀";
      level = "Hazardous";
    }
    return Card(
      color: _isDarkMode ? const Color(0xFF2D3250) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    station["station_name"] ?? "Station",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStationDetail = null;
                      _selectedMarkerLatLng = null;
                      _infoWindowOffset = null;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    color: _isDarkMode ? Colors.white : Colors.black,
                    size: 20,
                  ),
                )
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "$aqi - $level",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: _isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                "Latest updated $updatedText",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DetailsPage(
                              config: widget.config,
                              station: _selectedStationDetail!)));
                },
                child: Text(
                  "See more details",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.orange[200] : Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSelector() {
    if (_routePolylines.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: (_selectedStationDetail != null) ? 120 : 20,
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        color: _isDarkMode ? Colors.black.withOpacity(0.5) : Colors.white70,
        child: _isRoutePlotting
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _isDarkMode ? Colors.white : Colors.black),
                ),
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _routePolylines.keys.length,
                itemBuilder: (context, index) {
                  bool selected = index == _selectedRouteIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRouteIndex = index;
                        _updateRouteVisibility(index);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.orange : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Route ${index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (index == _safestRouteIndex)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified,
                                  color: Colors.white, size: 16),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(_isDarkMode ? darkMapStyle : lightMapStyle);

    // Center on user location when map is ready
    if (_currentLocation != null) {
      _mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
    }

    // Handle route arguments after map is ready
    if (!_hasHandledRouteArguments) {
      _handleRouteArguments();
    }
  }

  void _onUseCurrentLocationForStart() {
    if (_currentLocation != null) {
      print("Using current location as start point");
    }
  }

  Future<void> _logSearchQuery(String start, String end, String travelMode,
      LatLng? startCoordinates, LatLng? endCoordinates) async {
    if (_userId == null) {
      print("Cannot log search: User ID is null");
      return;
    }

    final url = Uri.parse('$baseUrl/api/search-history');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "userId": _userId,
          "startLocation": {
            "name": start,
            "latitude": startCoordinates?.latitude,
            "longitude": startCoordinates?.longitude,
          },
          "endLocation": {
            "name": end,
            "latitude": endCoordinates?.latitude,
            "longitude": endCoordinates?.longitude,
          },
          "travelMode": travelMode,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        print("Failed to log search history: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error logging search history: $e");
    }
  }

  /// Process route segments with color caching
  Future<void> _processRouteSegments(
      List<LatLng> points, int routeIndex) async {
    _routeSafetyScores[routeIndex] = _calculateRouteSafetyScore(points);

    final segments = await _getRouteSegments(points);
    if (segments == null) return;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final segStart = LatLng(seg["start"]["lat"], seg["start"]["lon"]);
      final segEnd = LatLng(seg["end"]["lat"], seg["end"]["lon"]);

      final segmentId =
          "${segStart.latitude},${segStart.longitude}-${segEnd.latitude},${segEnd.longitude}";

      // Use cached color if available
      Color segColor = _segmentColors[segmentId] ?? _colorFromHex(seg["color"]);
      _segmentColors[segmentId] = segColor;

      String polylineId = "seg_${routeIndex}_$i";
      _allPolylines[polylineId] = Polyline(
        polylineId: PolylineId(polylineId),
        points: [segStart, segEnd],
        color:
            segColor.withOpacity(routeIndex == _selectedRouteIndex ? 1.0 : 0.3),
        width: 5,
      );
    }
  }

  /// Fetch route segments from the server
  Future<List<dynamic>?> _getRouteSegments(List<LatLng> points) async {
    final url = Uri.parse("$baseUrl/api/route-segmentation");
    final routePayload = {
      "route": points.map((point) {
        return {"lat": point.latitude, "lon": point.longitude};
      }).toList()
    };
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(routePayload));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return data["segments"];
        } else {
          print("Segmentation API error: ${data['error']}");
        }
      } else {
        print("Error fetching segmentation: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception in _getRouteSegments: $e");
    }
    return null;
  }

  /// Update route visibility when switching routes
  void _updateRouteVisibility(int selectedIndex) {
    polylines = Map.fromEntries(_allPolylines.entries.map((entry) {
      final routeIndex = int.tryParse(entry.key.split('_')[1]) ?? -1;
      return MapEntry(
          PolylineId(entry.key),
          entry.value.copyWith(
              colorParam: entry.value.color
                  .withOpacity(routeIndex == selectedIndex ? 1.0 : 0.3)));
    }));

    // Update markers for selected route
    _updateMarkers();
  }

  /// Update markers opacity based on selected route
  void _updateMarkers() {
    if (!_routePolylines.containsKey(_selectedRouteIndex)) return;

    final selectedRoute = _routePolylines[_selectedRouteIndex]!;
    _populateAllMarkers(selectedRoute: selectedRoute);
  }

  void _showSegmentInfo(RouteSegment segment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Segment Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AQI: ${segment.aqi.toStringAsFixed(2)}'),
              if (segment.nearbyStations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nearest Station:'),
                ListTile(
                  title: Text(segment.nearbyStations[0]['name']),
                  subtitle: Text(
                    'Distance: ${segment.nearbyStations[0]['distance'].toStringAsFixed(2)} km',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu,
                color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ),
        actions: [
          Row(
            children: [
              Icon(_isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                  color: _isDarkMode ? Colors.white : Colors.black),
              Switch(
                value: _isDarkMode,
                onChanged: (bool value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  if (_mapController != null) {
                    _mapController!.setMapStyle(
                        _isDarkMode ? darkMapStyle : lightMapStyle);
                  }
                },
                activeColor: Colors.orange,
                inactiveThumbColor: Colors.grey,
                activeTrackColor: Colors.orange.withOpacity(0.5),
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
        ],
      ),
      drawer: buildDrawer(context: context, isDarkMode: _isDarkMode),
      endDrawer: CombinedSearchSection(
        isDarkMode: _isDarkMode,
        onSubmit: (String start, String end, String travelMode,
            {LatLng? startCoordinates, LatLng? endCoordinates}) async {
          LatLng? origin = startCoordinates ??
              await _getLatLngFromAddress(start) ??
              _currentLocation;
          LatLng? destination =
              endCoordinates ?? await _getLatLngFromAddress(end);
          if (origin != null && destination != null) {
            await _logSearchQuery(start, end, travelMode, origin, destination);
            await _loadRoute(origin, destination, travelMode);
          } else {
            print("Failed to get origin or destination coordinates.");
          }
        },
        onUseCurrentLocationForStart: _onUseCurrentLocationForStart,
        googleApiKey: widget.config.googleApiKey,
        selectedSource: _selectedSource,
        sources: _sources,
        onSourceChanged: (String? newSource) {
          if (newSource != null) {
            setState(() {
              _selectedSource = newSource;
            });
            _fetchAllAQIStations();
          }
        },
        selectedParameter: _selectedParameter,
        parameters: _parameters,
        onParameterChanged: (String? newParam) {
          if (newParam != null) {
            setState(() {
              _selectedParameter = newParam;
            });
            _fetchAllAQIStations();
          }
        },
        isRouteLoading: _isRouteLoading,
        markersLoaded: _markersLoaded,
        userId: _userId,
        currentLocation: _currentLocation,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(13.7563, 100.5018),
              zoom: 14,
            ),
            myLocationEnabled: true,
            markers: _markers,
            polylines: Set<Polyline>.of(polylines.values),
            onCameraMove: (position) {},
          ),
          _buildRouteSelector(),
          if (_selectedStationDetail != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DetailsPage(
                              config: widget.config,
                              station: _selectedStationDetail!)));
                },
                child: Container(
                  color: _isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: _buildCustomInfoWindow(_selectedStationDetail!),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                    backgroundColor:
                        _isDarkMode ? Colors.grey[800] : Colors.white,
                    child: Icon(Icons.settings,
                        color: _isDarkMode ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    mini: true,
                    onPressed: () async {
                      setState(() {
                        // Clear markers
                        _markers.clear();

                        // Clear route data
                        polylines.clear();
                        _routePolylines.clear();
                        _allPolylines.clear();
                        _routeSafetyScores.clear();
                        _selectedRouteIndex = 0;
                        _safestRouteIndex = null;
                        _isRoutePlotting = false;

                        // Clear selected station data
                        _selectedStationDetail = null;
                        _selectedMarkerLatLng = null;

                        // Clear cached data
                        _segmentColors.clear();
                      });
                      await _fetchAllAQIStations();
                    },
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper classes
class RouteSegment {
  final List<LatLng> points;
  final double aqi;
  final List<Map<String, dynamic>> nearbyStations; // Add nearby stations info

  RouteSegment(
      {required this.points,
      required this.aqi,
      this.nearbyStations = const []});
}

class WeightedStation {
  final int aqi;
  final double weight;
  final String stationName; // Add station name
  final double distance; // Add distance from segment

  WeightedStation(
      {required this.aqi,
      required this.weight,
      required this.stationName,
      required this.distance});
}

// Add isolate computation functions
List<RouteSegment> _createSegmentsInIsolate(Map<String, dynamic> params) {
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

Set<Marker> _createMarkersInIsolate(Map<String, dynamic> params) {
  final stations = params['stations'] as List<Map<String, dynamic>>;
  final currentLocation = params['currentLocation'] as LatLng?;
  final selectedParameter = params['selectedParameter'] as String;
  final markerCache = params['markerCache'] as Map<int, BitmapDescriptor>;

  Set<Marker> markers = {};
  if (currentLocation != null) {
    markers.add(
      Marker(
        markerId: const MarkerId('user'),
        position: currentLocation,
        infoWindow: const InfoWindow(title: "Your Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  for (var station in stations) {
    double? lat = double.tryParse(station["lat"]?.toString() ?? "");
    double? lon = double.tryParse(station["lon"]?.toString() ?? "");
    int aqi = int.tryParse(station["aqi"]?.toString() ?? "") ?? 0;

    if (aqi <= 0 || lat == null || lon == null) continue;

    // Use cached marker icon
    final markerIcon = markerCache[aqi] ?? BitmapDescriptor.defaultMarker;

    markers.add(
      Marker(
        markerId: MarkerId(station["station_id"].toString()),
        position: LatLng(lat, lon),
        icon: markerIcon,
        // Don't set infoWindow since we're using custom info window
      ),
    );
  }

  return markers;
}
