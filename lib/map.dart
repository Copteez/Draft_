import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:MySecureMap/config.dart';
import 'package:MySecureMap/home_page/widgets/drawer_widget.dart';
import 'package:MySecureMap/details_page.dart';
import 'package:MySecureMap/map/map_search_section.dart' as search;
import 'package:MySecureMap/map/map_floating_option.dart';
import 'map/map_polyline_utils.dart';
import 'map/map_route_models.dart';
import 'map/map_marker_utils.dart';
import 'map/map_route_utils.dart';
import 'map/map_theme.dart';
import 'map/map_location_service.dart';
import 'map/map_ui_components.dart';
import 'map/map_route_service.dart';
import 'map/map_route_progress.dart';
// ignore_for_file: unused_field, unused_element
import 'map/map_android_notification.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'network_service.dart';

// Primary Map screen widget
class MapPage extends StatefulWidget {
  final AppConfig config;
  final double? initialLat;
  final double? initialLon;
  final String? locationName;

  const MapPage(
      {Key? key,
      required this.config,
      this.initialLat,
      this.initialLon,
      this.locationName})
      : super(key: key);

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
  String _selectedParameter = "AQI";
  final List<String> _parameters = ["AQI", "PM2.5", "PM10", "O3", "SO2"];
  bool _hasHandledRouteArguments = false;
  bool _isRouteLoading = false;
  bool _markersLoaded = false;

  Map<String, dynamic>? _selectedStationDetail;
  LatLng? _selectedMarkerLatLng;
  Offset? _infoWindowOffset;
  // Track selected station favorite status
  bool _selectedStationIsFavorite = false;
  int? _selectedStationFavoriteId;
  String? _selectedFavoriteSource; // 'location' or 'path'

  Map<int, List<LatLng>> _routePolylines = {};
  int _selectedRouteIndex = 0;

  String? _userId;
  late String baseUrl;

  Map<int, double> _routeSafetyScores = {};
  int? _safestRouteIndex;

  final Map<String, Polyline> _allPolylines = {};

  bool _isRoutePlotting = false;

  Map<String, Color> _segmentColors = {};

  static const double SEGMENT_LENGTH = 0.2;
  static const double MERGE_THRESHOLD = 10;

  static final Map<int, BitmapDescriptor> _markerIconCache = {};
  Timer? _markersUpdateTimer;

  List<RouteOption> _routeOptions = [];

  int _userSelectedRouteIndex = 0;

  Set<String> _activeStationIds = {};

  StreamSubscription<Position>? _positionStreamSubscription;
  BitmapDescriptor? _userLocationIcon;

  bool _isLoadingMarkers = false;

  String? _nearestStationName;
  Timer? _stationCheckTimer;

  bool _showRouteProgress = false;

  // Add notification flag
  bool _showNotification = false;

  // Add this field for AQI predictions
  List<Map<String, dynamic>> _predictions = [];

  // Add this field to the _MapPageState class
  int _routeProgress = 0; // Store the current route progress percentage

  @override
  void initState() {
    super.initState();
    // Remove call to _initializeUserLocationIcon() as we don't need it anymore
    _loadUserId();
    _loadFavoriteRoutes();

    // Only initialize Android notifications safely
    try {
      if (Platform.isAndroid) {
        // Safely request permissions first
        _requestNotificationPermission();

        // Then initialize the notification service
        AndroidNotificationService.initialize();
      }
    } catch (e) {
      print("Error initializing notifications: $e");
    }

    _initializeBaseUrl().then((_) {
      return Future.wait([
        _initializeUserAndLocation(),
        _fetchSources(),
      ]);
    }).then((_) {
      _fetchAllAQIStations();
      if (_mapController != null && _currentLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 14),
        );
      }
    });

    _stationCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateNearestStation(),
    );
  }

  Future<void> _initializeBaseUrl() async {
    try {
      final network = NetworkService(config: widget.config);
      baseUrl = await network.getEffectiveBaseUrl();
    } catch (_) {
      // As a last resort, use zerotier or ngrok from config without calling
      baseUrl = widget.config.ngrok.isNotEmpty
          ? widget.config.ngrok
          : widget.config.zerotier;
    }
  }

  @override
  void dispose() {
    // Clean up only if on Android
    if (Platform.isAndroid) {
      AndroidNotificationService.hideRouteProgressNotification();
    }
    _stationCheckTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeUserLocationIcon() async {
    _userLocationIcon = await createUserLocationIcon();
    if (mounted) setState(() {});
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
      try {
        final position = await getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      } catch (e) {
        print("Error getting current location: $e");
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API level 33+), explicitly request notification permission
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
        print("Requested notification permission");
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wait for stations to be loaded first
    _handleRouteArgumentsAfterStationsLoad();
  }

  void _handleRouteArgumentsAfterStationsLoad() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null &&
        args.containsKey("origin") &&
        args.containsKey("destination")) {
      // If we need to load a route, make sure stations are loaded first
      if (_allStations.isEmpty) {
        // If stations aren't loaded yet, fetch them first, then handle route
        _fetchAllAQIStations().then((_) {
          _processRouteArguments(args);
        });
      } else {
        // Stations already loaded, handle the route directly
        _processRouteArguments(args);
      }
    }
  }

  void _processRouteArguments(Map<String, dynamic> args) {
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode
            ? darkMapStyle
            : lightMapStyle);

    if (_currentLocation != null) {
      _mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
    }

    if (!_hasHandledRouteArguments) {
      // Update this line to call the new method instead of the old one
      _handleRouteArgumentsAfterStationsLoad();
      _hasHandledRouteArguments = true;
    }
  }

  void _updateCameraPositionForRoute(LatLng origin, LatLng destination) {
    if (_mapController != null) {
      final bounds = getRouteBounds(origin, destination);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else {
      print("Warning: _mapController is null, cannot update camera position.");
    }
  }

  Future<void> _fetchSources() async {
    final url = "$baseUrl/api/sources";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["sources"] is List) {
          final src = List<dynamic>.from(data["sources"]);
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
    setState(() {
      _isLoadingMarkers = true;
    });

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
            if (_selectedParameter != "AQI") {
              _allStations = _allStations.where((station) {
                var value = station[_selectedParameter.toLowerCase()];
                return value != null && value > 0;
              }).toList();
            }
          });
          await _populateAllMarkers();
        } else {
          print("API error: ${data['error']}");
        }
      } else {
        print("Failed to fetch stations: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching all AQI stations: $e");
    } finally {
      setState(() {
        _isLoadingMarkers = false;
      });
    }
  }

  Future<void> _populateAllMarkers({List<LatLng>? selectedRoute}) async {
    _markersUpdateTimer?.cancel();
    _markersUpdateTimer = Timer(const Duration(milliseconds: 100), () async {
      Set<Marker> newMarkers = {};

      // Remove the custom user marker - we'll use the built-in Google Maps location marker
      // The built-in marker is enabled with myLocationEnabled: true

      // Keep adding station markers as before
      List<Map<String, dynamic>> visibleStations = _allStations;
      if (_activeStationIds.isNotEmpty) {
        visibleStations = _allStations
            .where((station) =>
                _activeStationIds.contains(station["station_name"]))
            .toList();
      }

      for (var station in visibleStations) {
        double? lat = double.tryParse(station["lat"]?.toString() ?? "");
        double? lon = double.tryParse(station["lon"]?.toString() ?? "");
        int aqi = int.tryParse(station["aqi"]?.toString() ?? "") ?? 0;

        if (aqi <= 0 || lat == null || lon == null) continue;

        BitmapDescriptor markerIcon;
        if (!_markerIconCache.containsKey(aqi)) {
          markerIcon = await createCustomMarker(aqi);
          _markerIconCache[aqi] = markerIcon;
        } else {
          markerIcon = _markerIconCache[aqi]!;
        }

        newMarkers.add(
          Marker(
            markerId: MarkerId(station["station_id"].toString()),
            position: LatLng(lat, lon),
            icon: markerIcon,
            onTap: () async {
              setState(() {
                _selectedStationDetail = station;
                _selectedMarkerLatLng = LatLng(lat, lon);
                _selectedStationIsFavorite = false;
                _selectedStationFavoriteId = null;
                _selectedFavoriteSource = null;
              });
              await _refreshSelectedStationFavoriteState();
            },
          ),
        );
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
          _markersLoaded = true;
        });
      }
    });
  }

  Future<void> _refreshSelectedStationFavoriteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null || _selectedStationDetail == null) return;

      final lat =
          double.tryParse(_selectedStationDetail!['lat']?.toString() ?? '');
      final lon =
          double.tryParse(_selectedStationDetail!['lon']?.toString() ?? '');
      if (lat == null || lon == null) return;

      // Try favorite-locations first
      bool matched = false;
      int? favId;
      String? favSrc;
      try {
        final res = await http.get(
          Uri.parse("$baseUrl/api/favorite-locations?user_id=$userId"),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          List favs;
          if (data is Map && data['favorite_locations'] is List) {
            favs = List.from(data['favorite_locations']);
          } else if (data is List) {
            favs = data;
          } else {
            favs = [];
          }
          const double threshold = 0.0009; // ~100m
          for (final f in favs) {
            double? fLat = double.tryParse(
                f['latitude']?.toString() ?? f['lat']?.toString() ?? '');
            double? fLon = double.tryParse(
                f['longitude']?.toString() ?? f['lon']?.toString() ?? '');
            if ((fLat == null || fLon == null) && f['lat_lon'] != null) {
              final parts = f['lat_lon'].toString().split(',');
              if (parts.length >= 2) {
                fLat = double.tryParse(parts[0].trim());
                fLon = double.tryParse(parts[1].trim());
              }
            }
            if (fLat == null || fLon == null) continue;
            if ((fLat - lat).abs() < threshold &&
                (fLon - lon).abs() < threshold) {
              matched = true;
              favId = (f['location_id'] ?? f['id']) is int
                  ? (f['location_id'] ?? f['id'])
                  : int.tryParse(
                      (f['location_id'] ?? f['id'])?.toString() ?? '');
              favSrc = 'location';
              break;
            }
          }
        }
      } catch (_) {
        // ignore
      }

      if (!matched) {
        // Fallback: check favorite-paths (match start_lat_lon or start_lat/start_lon)
        try {
          final res = await http.get(
            Uri.parse("$baseUrl/api/favorite-paths?user_id=$userId"),
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final paths = (data is Map && data['favorite_paths'] is List)
                ? List.from(data['favorite_paths'])
                : <dynamic>[];
            const double threshold = 0.0009; // ~100m
            for (final p in paths) {
              double? pLat = double.tryParse(p['start_lat']?.toString() ?? '');
              double? pLon = double.tryParse(p['start_lon']?.toString() ?? '');
              if ((pLat == null || pLon == null) &&
                  p['start_lat_lon'] != null) {
                final parts = p['start_lat_lon'].toString().split(',');
                if (parts.length >= 2) {
                  pLat = double.tryParse(parts[0].trim());
                  pLon = double.tryParse(parts[1].trim());
                }
              }
              if (pLat == null || pLon == null) continue;
              if ((pLat - lat).abs() < threshold &&
                  (pLon - lon).abs() < threshold) {
                matched = true;
                favId = (p['path_id'] is int)
                    ? p['path_id']
                    : int.tryParse(p['path_id']?.toString() ?? '');
                favSrc = 'path';
                break;
              }
            }
          }
        } catch (_) {
          // ignore
        }
      }

      setState(() {
        _selectedStationIsFavorite = matched;
        _selectedStationFavoriteId = favId;
        _selectedFavoriteSource = favSrc;
      });
    } catch (e) {
      // ignore transient errors
    }
  }

  Future<void> _loadRoute(
      LatLng origin, LatLng destination, String travelMode) async {
    setState(() {
      _routePolylines.clear();
      _allPolylines.clear();
      _selectedRouteIndex = -1;
      _isRoutePlotting = true;
      _routeOptions = [];
    });
    _populateAllMarkers();

    // Save this route to history on server
    _saveRouteToHistory(origin, destination);

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
            // 1) Simplify to reduce point count, then 2) smooth with lower density
            final simplified =
                simplifyByDistance(rawPoints, minDistanceMeters: 40);
            List<LatLng> points =
                smoothPolyline(simplified, numPointsPerSegment: 4);
            _routePolylines[r] = points;

            // Draw a temporary polyline immediately for quick feedback
            final tempId = "temp_${r}";
            _allPolylines[tempId] = Polyline(
              polylineId: PolylineId(tempId),
              points: points,
              color: Colors.blue.withOpacity(r == 0 ? 0.9 : 0.4),
              width: 5,
            );
            if (mounted) {
              setState(() {
                polylines = Map.fromEntries(_allPolylines.entries
                    .map((e) => MapEntry(PolylineId(e.key), e.value)));
              });
            }

            _routeSafetyScores[r] =
                calculateRouteSafetyScore(points, _allStations);
          }

          _safestRouteIndex = _routeSafetyScores.entries
              .reduce((a, b) => a.value < b.value ? a : b)
              .key;

          for (int r = 0; r < routeCount; r++) {
            await _createRoutePolylines(_routePolylines[r]!,
                routeIndex: r, opacity: r == _safestRouteIndex ? 1.0 : 0.3);
          }

          _routeOptions = [];
          for (int r = 0; r < routeCount; r++) {
            await _processRouteSegments(_routePolylines[r]!, r);
          }

          _routeOptions.sort((a, b) => a.avgAqi.compareTo(b.avgAqi));
          final bestRouteIndex = _routeOptions[0].routeIndex;

          for (int i = 0; i < _routeOptions.length; i++) {
            _routeOptions[i] = RouteOption(
              routeIndex: _routeOptions[i].routeIndex,
              avgAqi: _routeOptions[i].avgAqi,
              calculations: _routeOptions[i].calculations,
              isSafest: i == 0,
              displayIndex: i,
            );
          }

          _activeStationIds.clear();
          final bestRoute = _routeOptions[0];
          for (var calc in bestRoute.calculations) {
            _activeStationIds.add(calc.stationName);
          }

          // Remove temporary polylines now that segmented ones are ready
          _allPolylines.removeWhere((k, v) => k.startsWith('temp_'));

          setState(() {
            _selectedRouteIndex = bestRouteIndex;
            _userSelectedRouteIndex = bestRouteIndex;
            polylines = Map.fromEntries(_allPolylines.entries.map((entry) {
              final routeIndex = int.tryParse(entry.key.split('_')[1]) ?? -1;
              return MapEntry(
                  PolylineId(entry.key),
                  entry.value.copyWith(
                      colorParam: entry.value.color.withOpacity(
                          routeIndex == bestRouteIndex ? 1.0 : 0.3)));
            }));
            _isRoutePlotting = false;
            // Show route details panel immediately
            _showRouteProgress = true;
          });

          _updateMarkers();

          if (_mapController != null) {
            final bounds = getRouteBounds(origin, destination);
            _mapController!
                .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Small delay to ensure the drawer animation is smooth
            Future.delayed(const Duration(milliseconds: 120), () {
              if (mounted) {
                _scaffoldKey.currentState?.openEndDrawer();
              }
            });
          });

          // After route is loaded successfully, fetch predictions for destination
          await _fetchDestinationPredictions(destination);
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
      // Avoid redundant station fetch here; stations were loaded before routing
    }
  }

  // Update the method to save route history to server
  Future<void> _saveRouteToHistory(LatLng origin, LatLng destination) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) return;

      final network = NetworkService(config: widget.config);
      final base = await network.getEffectiveBaseUrl();
      final url = Uri.parse("$base/api/history-search");

      final body = jsonEncode({
        "user_id": userId,
        "start_location": "Start",
        "start_lat": origin.latitude,
        "start_lon": origin.longitude,
        "end_location": "End",
        "end_lat": destination.latitude,
        "end_lon": destination.longitude,
      });

      await http.post(url,
          headers: {"Content-Type": "application/json"}, body: body);
    } catch (err) {
      // ignore errors for history saving
    }
  }

  Future<void> _createRoutePolylines(List<LatLng> points,
      {required int routeIndex, required double opacity}) async {
    final segments = await compute(createSegmentsInIsolate, {
      'points': points,
      'stations': _allStations,
      'segmentLength': SEGMENT_LENGTH,
    });

    // Merge consecutive segments with same color to reduce polyline count
    List<LatLng> currentPoints = [];
    Color? currentColor;
    int mergedIndex = 0;
    for (final segment in segments) {
      final color = segment.nearbyStations.isNotEmpty
          ? getAQIColor(segment.nearbyStations.first['aqi'])
          : const Color(0xFF2D3250);
      if (currentColor == null) {
        currentColor = color;
        currentPoints = List.from(segment.points);
      } else if (color.value == currentColor.value) {
        // Append but avoid duplicating the join point
        currentPoints.addAll(segment.points.skip(1));
      } else {
        final polylineId = "seg_${routeIndex}_${mergedIndex++}";
        _allPolylines[polylineId] = Polyline(
          polylineId: PolylineId(polylineId),
          points: currentPoints,
          color: currentColor.withOpacity(opacity),
          width: 5,
          // Tap opens info for the last segment in this merged run
          onTap: () => showSegmentInfo(context, segment),
        );
        currentColor = color;
        currentPoints = List.from(segment.points);
      }
    }
    if (currentPoints.isNotEmpty && currentColor != null) {
      final polylineId = "seg_${routeIndex}_${mergedIndex++}";
      _allPolylines[polylineId] = Polyline(
        polylineId: PolylineId(polylineId),
        points: currentPoints,
        color: currentColor.withOpacity(opacity),
        width: 5,
      );
    }
  }

  Future<void> _processRouteSegments(
      List<LatLng> points, int routeIndex) async {
    List<RouteCalculation> calculations = [];
    double totalAqi = 0;
    double totalDistance = 0;

    final segments = await compute(createSegmentsInIsolate, {
      'points': points,
      'stations': _allStations,
      'segmentLength': SEGMENT_LENGTH,
    });

    Map<String, StationAccumulator> stationAccumulators = {};

    for (var segment in segments) {
      if (segment.nearbyStations.isNotEmpty) {
        String stationName = segment.nearbyStations[0]['name'];
        double segmentDistance = haversine(
            segment.points.first.latitude,
            segment.points.first.longitude,
            segment.points.last.latitude,
            segment.points.last.longitude);
        totalDistance += segmentDistance;

        stationAccumulators.putIfAbsent(
          stationName,
          () => StationAccumulator(
            startDistance: totalDistance - segmentDistance,
            endDistance: totalDistance,
            sumAqi: 0,
            count: 0,
          ),
        );

        var accumulator = stationAccumulators[stationName]!;
        accumulator.sumAqi += segment.aqi;
        accumulator.count++;
        accumulator.endDistance = totalDistance;
      }
    }

    var sortedStations = stationAccumulators.entries.toList()
      ..sort((a, b) => a.value.startDistance.compareTo(b.value.startDistance));

    for (var entry in sortedStations) {
      calculations.add(RouteCalculation(
        stationName: entry.key,
        startDistance: entry.value.startDistance,
        endDistance: entry.value.endDistance,
        aqi: (entry.value.sumAqi / entry.value.count).round(),
      ));

      double segmentLength =
          entry.value.endDistance - entry.value.startDistance;
      totalAqi += (entry.value.sumAqi / entry.value.count) * segmentLength;
    }

    double avgAqi = totalDistance > 0 ? totalAqi / totalDistance : 0;

    if (mounted) {
      setState(() {
        _routeOptions.add(RouteOption(
          routeIndex: routeIndex,
          avgAqi: avgAqi,
          calculations: calculations,
          isSafest: routeIndex == _safestRouteIndex,
          displayIndex: routeIndex,
        ));
      });
    }
  }

  void _updateRouteVisibility(int selectedIndex) {
    setState(() {
      _userSelectedRouteIndex = selectedIndex;
      _activeStationIds.clear();
      final selectedOption = _routeOptions.firstWhere(
        (option) => option.routeIndex == selectedIndex,
        orElse: () => _routeOptions[0],
      );
      for (var calc in selectedOption.calculations) {
        _activeStationIds.add(calc.stationName);
      }

      polylines = Map.fromEntries(_allPolylines.entries.map((entry) {
        final routeIndex = int.tryParse(entry.key.split('_')[1]) ?? -1;
        return MapEntry(
            PolylineId(entry.key),
            entry.value.copyWith(
                colorParam: entry.value.color
                    .withOpacity(routeIndex == selectedIndex ? 1.0 : 0.3)));
      }));
    });

    _updateMarkers();
    _startLocationUpdates();
    _checkIfCurrentRouteIsFavorite();
  }

  // Close the route progress view, disable notifications, and clear the current route overlays/state
  void _closeRouteAndClear() async {
    setState(() {
      _showRouteProgress = false;
      // Disable alerts/notification
      if (_showNotification) {
        _showNotification = false;
        if (Platform.isAndroid) {
          AndroidNotificationService.hideRouteProgressNotification();
        }
      }
      // Clear current route related state
      polylines.clear();
      _routePolylines.clear();
      _allPolylines.clear();
      _routeSafetyScores.clear();
      _selectedRouteIndex = -1;
      _userSelectedRouteIndex = -1;
      _safestRouteIndex = null;
      _isRoutePlotting = false;
      _activeStationIds.clear();
      _routeOptions = [];
    });
    // Reload all stations/markers without route filters
    await _fetchAllAQIStations();
  }

  void _updateMarkers() {
    if (!_routePolylines.containsKey(_selectedRouteIndex)) return;

    final selectedRoute = _routePolylines[_selectedRouteIndex]!;
    _populateAllMarkers(selectedRoute: selectedRoute);
  }

  void _startLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_routeOptions.isNotEmpty && !_showRouteProgress) {
          _showRouteProgress = true;
        }
      });
      _updateNearestStation();
    });
  }

  void _updateNearestStation() {
    if (_currentLocation == null || _routeOptions.isEmpty) return;

    double minDistance = double.infinity;
    String? nearestStation;
    int nearestStationAqi = 0;

    final selectedRoute = _routeOptions.firstWhere(
      (option) => option.routeIndex == _userSelectedRouteIndex,
      orElse: () => _routeOptions[0],
    );

    RouteCalculation? nearestCalculation;

    for (var calc in selectedRoute.calculations) {
      for (var station in _allStations) {
        if (station["station_name"] == calc.stationName) {
          double? lat = double.tryParse(station["lat"]?.toString() ?? "");
          double? lon = double.tryParse(station["lon"]?.toString() ?? "");

          if (lat != null && lon != null) {
            double distance = haversine(
              _currentLocation!.latitude,
              _currentLocation!.longitude,
              lat,
              lon,
            );

            if (distance < minDistance) {
              minDistance = distance;
              nearestStation = calc.stationName;
              nearestStationAqi = calc.aqi;
              nearestCalculation = calc;
            }
          }
        }
      }
    }

    // Find the highest AQI zone in the route
    RouteCalculation? worstZone;
    int highestAqi = 0;

    for (var calc in selectedRoute.calculations) {
      if (calc.aqi > highestAqi) {
        highestAqi = calc.aqi;
        worstZone = calc;
      }
    }

    // Calculate time and distance to worst zone if found
    String? timeToWorstZone;
    String? distanceToWorstZone;

    if (worstZone != null && nearestCalculation != null) {
      // Only calculate if worst zone is ahead of current position
      if (worstZone.startDistance > nearestCalculation.endDistance) {
        // Calculate distance in km
        double distanceKm =
            worstZone.startDistance - nearestCalculation.endDistance;
        distanceToWorstZone = distanceKm < 1.0
            ? "${(distanceKm * 1000).toInt()}m"
            : "${distanceKm.toStringAsFixed(1)}km";

        // Estimate time based on average walking/driving speed
        // Assuming average speed of 30 km/h
        double timeHours = distanceKm / 30.0;
        if (timeHours < 1.0 / 60.0) {
          // Less than a minute
          timeToWorstZone = "< 1 min";
        } else if (timeHours < 1.0) {
          // Less than an hour
          timeToWorstZone = "${(timeHours * 60).toInt()} min";
        } else {
          timeToWorstZone = "${timeHours.toStringAsFixed(1)} hours";
        }
      }
    }

    // Calculate user's progress along the route more accurately
    double progressDistance = 0.0;

    // If we have route points for the selected route, calculate the user's position along it
    if (_routePolylines.containsKey(_userSelectedRouteIndex)) {
      progressDistance = findDistanceAlongRoute({
        'userLocation': _currentLocation!,
        'routePoints': _routePolylines[_userSelectedRouteIndex]!,
      });
    } else if (nearestCalculation != null) {
      // Fallback if route points aren't available
      progressDistance = nearestCalculation.startDistance;
    }

    final totalRouteDistance = _getTotalRouteDistance();

    // Calculate percentage and ensure it's between 0 and 100
    int progressPercent = 0;
    if (totalRouteDistance > 0) {
      progressPercent = ((progressDistance / totalRouteDistance) * 100).round();
      // Clamp value between 0 and 100
      progressPercent = progressPercent.clamp(0, 100);
    }

    if (mounted) {
      setState(() {
        _nearestStationName = nearestStation;
        // Update the class field to store progress
        _routeProgress = progressPercent;
      });

      // Show notifications only on Android if enabled
      if (_showNotification && nearestStation != null) {
        if (Platform.isAndroid) {
          AndroidNotificationService.showRouteProgressNotification(
            nearestStationName: nearestStation,
            progressPercent: progressPercent,
            aqi: nearestStationAqi,
            timeToWorstZone: timeToWorstZone,
            distanceToWorstZone: distanceToWorstZone,
          );
        }
      }
    }
  }

  String? _findNearestStationInRoute(LatLng userLocation, RouteOption route) {
    if (route.calculations.isEmpty) return null;

    String? nearestStation;
    double minDistance = double.infinity;

    for (var station in _allStations) {
      if (!route.calculations
          .any((calc) => calc.stationName == station['station_name'])) {
        continue;
      }

      double? lat = double.tryParse(station["lat"]?.toString() ?? "");
      double? lon = double.tryParse(station["lon"]?.toString() ?? "");

      if (lat != null && lon != null) {
        double distance =
            haversine(userLocation.latitude, userLocation.longitude, lat, lon);

        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station['station_name'];
        }
      }
    }
    return nearestStation;
  }

  void _showFilterDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SafeArea(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: Material(
                  color: Provider.of<ThemeProvider>(context, listen: false)
                          .isDarkMode
                      ? const Color(0xFF2D3250)
                      : Colors.white,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return Column(
                        children: [
                          AppBar(
                            backgroundColor: Provider.of<ThemeProvider>(context,
                                        listen: false)
                                    .isDarkMode
                                ? const Color(0xFF2D3250)
                                : Colors.white,
                            elevation: 0,
                            title: Text(
                              'Filter Stations',
                              style: TextStyle(
                                color: Provider.of<ThemeProvider>(context,
                                            listen: false)
                                        .isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            leading: Container(),
                            actions: [
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Provider.of<ThemeProvider>(context,
                                              listen: false)
                                          .isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Parameter',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Provider.of<ThemeProvider>(context,
                                                  listen: false)
                                              .isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Provider.of<ThemeProvider>(context,
                                                  listen: false)
                                              .isDarkMode
                                          ? Colors.black
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Provider.of<ThemeProvider>(
                                                    context,
                                                    listen: false)
                                                .isDarkMode
                                            ? Colors.grey[800]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _selectedParameter,
                                        dropdownColor:
                                            Provider.of<ThemeProvider>(context,
                                                        listen: false)
                                                    .isDarkMode
                                                ? const Color(0xFF2D3250)
                                                : Colors.white,
                                        style: TextStyle(
                                          color: Provider.of<ThemeProvider>(
                                                      context,
                                                      listen: false)
                                                  .isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        items: _parameters.map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (String? value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedParameter = value;
                                            });
                                            _fetchAllAQIStations();
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Source',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Provider.of<ThemeProvider>(context,
                                                  listen: false)
                                              .isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Provider.of<ThemeProvider>(context,
                                                  listen: false)
                                              .isDarkMode
                                          ? Colors.black
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Provider.of<ThemeProvider>(
                                                    context,
                                                    listen: false)
                                                .isDarkMode
                                            ? Colors.grey[800]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _selectedSource,
                                        dropdownColor:
                                            Provider.of<ThemeProvider>(context,
                                                        listen: false)
                                                    .isDarkMode
                                                ? const Color(0xFF2D3250)
                                                : Colors.white,
                                        style: TextStyle(
                                          color: Provider.of<ThemeProvider>(
                                                      context,
                                                      listen: false)
                                                  .isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        items: _sources.map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (String? value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedSource = value;
                                            });
                                            _fetchAllAQIStations();
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  double _getTotalRouteDistance() {
    if (_routeOptions.isEmpty || _userSelectedRouteIndex < 0) {
      return 0.0;
    }

    final route = _routeOptions.firstWhere(
      (option) => option.routeIndex == _userSelectedRouteIndex,
      orElse: () => _routeOptions[0],
    );

    if (route.calculations.isEmpty) {
      return 0.0;
    }

    return route.calculations.last.endDistance;
  }

  // Add a method to estimate arrival time based on average speed
  DateTime _calculateEstimatedArrivalTime() {
    // If no route is selected or no distance is available, return current time
    if (_routeOptions.isEmpty || _getTotalRouteDistance() <= 0) {
      return DateTime.now();
    }

    // Calculate remaining distance in km
    double totalDistance = _getTotalRouteDistance();
    double remainingDistance = totalDistance;

    // If user is already on the route, calculate remaining distance
    if (_nearestStationName != null && _currentLocation != null) {
      final route = _routeOptions.firstWhere(
        (option) => option.routeIndex == _userSelectedRouteIndex,
        orElse: () => _routeOptions[0],
      );

      final nearestCalculation = route.calculations.firstWhere(
        (calc) => calc.stationName == _nearestStationName,
        orElse: () => route.calculations.first,
      );

      // Estimate remaining distance
      remainingDistance = totalDistance - nearestCalculation.endDistance;
      if (remainingDistance < 0) remainingDistance = totalDistance;
    }

    // Assume average speed of 30 km/h (urban environment)
    const double averageSpeedKmh = 30.0;
    // Calculate time in hours
    double timeHours = remainingDistance / averageSpeedKmh;

    // Calculate arrival time
    return DateTime.now().add(Duration(minutes: (timeHours * 60).round()));
  }

  // Predict AQI at destination at arrival time
  int _predictDestinationAQI() {
    // If no routes or no predictions, return 0
    if (_routeOptions.isEmpty) {
      return 0;
    }

    // Get arrival time and calculate prediction index based on travel hours
    final DateTime arrivalTime = _calculateEstimatedArrivalTime();
    final DateTime now = DateTime.now();
    final Duration difference = arrivalTime.difference(now);
    int hoursFromNow = difference.inMinutes ~/ 60; // Integer division for hours

    // Apply rounding based on remaining minutes
    int remainingMinutes = difference.inMinutes % 60;
    if (remainingMinutes > 30) {
      hoursFromNow += 1; // Round up if more than 30 minutes
    }

    // If we don't have predictions or the hoursFromNow is out of range, use fallback
    if (_predictions.isEmpty ||
        hoursFromNow >= _predictions.length ||
        hoursFromNow < 0) {
      return _getFallbackAQIValue();
    }

    // Return the predicted AQI at the calculated hour
    return _predictions[hoursFromNow]['aqi'];
  }

  // Helper method to get fallback AQI value from route calculations
  int _getFallbackAQIValue() {
    // Use last station in route (destination) as fallback
    if (_routeOptions.isNotEmpty) {
      final routeOption = _routeOptions.firstWhere(
        (option) => option.routeIndex == _userSelectedRouteIndex,
        orElse: () => _routeOptions[0],
      );

      if (routeOption.calculations.isNotEmpty) {
        return routeOption.calculations.last.aqi;
      }
    }

    // Default value if no options available
    return 0;
  }

  // Add a method to fetch AQI predictions for the destination
  Future<void> _fetchDestinationPredictions(LatLng destination) async {
    try {
      // Find the nearest station to the destination point
      double minDistance = double.infinity;
      Map<String, dynamic>? nearestStation;

      for (var station in _allStations) {
        double? lat = double.tryParse(station["lat"]?.toString() ?? "");
        double? lon = double.tryParse(station["lon"]?.toString() ?? "");

        if (lat != null && lon != null) {
          double distance =
              haversine(destination.latitude, destination.longitude, lat, lon);

          if (distance < minDistance) {
            minDistance = distance;
            nearestStation = station;
          }
        }
      }

      // Create a request body with either station_id or coordinates
      final Map<String, dynamic> requestBody = {
        "latitude": destination.latitude,
        "longitude": destination.longitude,
      };

      // Add station_id if we found a nearby station
      if (nearestStation != null && nearestStation.containsKey('station_id')) {
        requestBody['station_id'] = nearestStation['station_id'].toString();
      }

      final url = "$baseUrl/api/aqi-prediction";
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data.containsKey("predictions")) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(data["predictions"]);
          });
        } else {
          // Fallback to generate prediction data
          _generateFallbackPredictions();
        }
      } else {
        // Fallback to generate prediction data
        _generateFallbackPredictions();
      }
    } catch (e) {
      print("Error fetching destination predictions: $e");
      // Fallback to generate prediction data
      _generateFallbackPredictions();
    }
  }

  // Add a fallback method to generate prediction data when API fails
  void _generateFallbackPredictions() {
    // Get the destination AQI (if we're in route mode)
    int destinationAqi = 0;

    if (_routeOptions.isNotEmpty) {
      // Use the last station in the route (destination area)
      final route = _routeOptions.firstWhere(
        (option) => option.routeIndex == _userSelectedRouteIndex,
        orElse: () => _routeOptions[0],
      );

      if (route.calculations.isNotEmpty) {
        destinationAqi = route.calculations.last.aqi;
      }
    } else if (_allStations.isNotEmpty) {
      // If no route, use average AQI
      destinationAqi = _allStations.fold(0, (sum, station) {
            int aqi = int.tryParse(station['aqi']?.toString() ?? '0') ?? 0;
            return sum + aqi;
          }) ~/
          _allStations.length;
    } else {
      // Default modest AQI if no data
      destinationAqi = 0;
    }

    // Create predictions for next 24 hours with slight variations
    _predictions = [];
    final random = math.Random();
    final now = DateTime.now();

    // Base the predictions on destination AQI with reasonable fluctuations
    for (int i = 0; i < 24; i++) {
      // Add random fluctuation of +/- 15%
      final fluctuation = (random.nextDouble() * 0.3) - 0.15;
      final predictedAqi = (destinationAqi * (1 + fluctuation)).round();

      // Create a prediction entry
      _predictions.add({
        'timestamp': now.add(Duration(hours: i)).toIso8601String(),
        'aqi': predictedAqi.clamp(20, 300), // Keep in reasonable range
      });
    }
  }

  // Add variables to store favorite routes
  List<Map<String, dynamic>> _favoriteRoutes = [];
  bool _isCurrentRouteFavorite = false;

  // Load favorite routes from SharedPreferences
  Future<void> _loadFavoriteRoutes() async {
    // First load from SharedPreferences as a fallback/cache
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString('favorite_routes');

    if (favoritesJson != null) {
      setState(() {
        _favoriteRoutes =
            List<Map<String, dynamic>>.from(jsonDecode(favoritesJson) as List);
      });
    }

    // Only proceed with server fetch if user is logged in
    if (_userId == null) return;

    try {
      // Retrieve favorite paths from server
      final response = await http.get(
        Uri.parse("$baseUrl/api/favorite-paths?user_id=$_userId"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data.containsKey("favorite_paths")) {
          // Transform server data format to our local format
          List<Map<String, dynamic>> serverFavorites = [];

          for (var path in data["favorite_paths"]) {
            // Extract lat/lon from start_lat_lon and end_lat_lon strings
            List<String> startLatLon =
                path["start_lat_lon"].toString().split(",");
            List<String> endLatLon = path["end_lat_lon"].toString().split(",");

            if (startLatLon.length == 2 && endLatLon.length == 2) {
              double startLat = double.tryParse(startLatLon[0].trim()) ?? 0;
              double startLon = double.tryParse(startLatLon[1].trim()) ?? 0;
              double endLat = double.tryParse(endLatLon[0].trim()) ?? 0;
              double endLon = double.tryParse(endLatLon[1].trim()) ?? 0;

              serverFavorites.add({
                'id': "${startLat},${startLon}-${endLat},${endLon}",
                'name': 'Route to ${path["end_location"]}',
                'origin': {'lat': startLat, 'lon': startLon},
                'destination': {'lat': endLat, 'lon': endLon},
                'date': DateTime.now().toIso8601String(),
                'path_id':
                    path["path_id"], // Keep server's path_id for deletion
              });
            }
          }

          // Update state with server data
          if (mounted) {
            setState(() {
              _favoriteRoutes = serverFavorites;
            });

            // Save back to SharedPreferences
            await prefs.setString(
                'favorite_routes', jsonEncode(serverFavorites));
          }
        }
      } else {
        print("Failed to fetch favorite routes: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching favorite routes: $e");
    }

    // Check if current route is a favorite
    _checkIfCurrentRouteIsFavorite();
  }

  // Save favorite routes to SharedPreferences
  Future<void> _saveFavoriteRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_routes', jsonEncode(_favoriteRoutes));
  }

  // Fix the _toggleFavoriteRoute method to correctly handle favorite routes and preserve location names
  Future<void> _toggleFavoriteRoute() async {
    // First check if we have route options and valid user ID
    if (_routeOptions.isEmpty || _userSelectedRouteIndex < 0) {
      print("Cannot save favorite: No active route");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save favorites")),
      );
      return;
    }

    final selectedRoute = _routeOptions.firstWhere(
      (option) => option.routeIndex == _userSelectedRouteIndex,
      orElse: () => _routeOptions[0],
    );

    // Get origin and destination data
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location not available")),
      );
      return;
    }

    // For destination, use the last point in the route polyline
    LatLng? destinationLocation;
    if (_routePolylines.containsKey(_userSelectedRouteIndex)) {
      final points = _routePolylines[_userSelectedRouteIndex]!;
      if (points.isNotEmpty) {
        destinationLocation = points.last;
      }
    }

    if (destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Destination location not available")),
      );
      return;
    }

    // Get location names - preserve names from search if available
    String startLocationName = "Your Location";
    String endLocationName = "Destination";

    try {
      // First check if we have names from calculations for the destination
      if (selectedRoute.calculations.isNotEmpty) {
        endLocationName = selectedRoute.calculations.last.stationName;
      }

      // Get more detailed start location name from geocoding
      if (_currentLocation != null) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
              _currentLocation!.latitude, _currentLocation!.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;

            // Create a more descriptive address from the placemark components
            List<String> addressParts = [];

            if (place.thoroughfare?.isNotEmpty ?? false) {
              addressParts.add(place.thoroughfare!);
            }

            if (place.subLocality?.isNotEmpty ?? false) {
              addressParts.add(place.subLocality!);
            } else if (place.locality?.isNotEmpty ?? false) {
              addressParts.add(place.locality!);
            }

            if (place.administrativeArea?.isNotEmpty ?? false) {
              addressParts.add(place.administrativeArea!);
            }

            if (addressParts.isNotEmpty) {
              startLocationName = addressParts.join(", ");
            } else if (place.name?.isNotEmpty ?? false) {
              startLocationName = place.name!;
            }
          }
        } catch (e) {
          print("Error getting start location name: $e");
        }
      }

      // Try to get a more descriptive destination name if it's still generic
      if (endLocationName == "Destination") {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
              destinationLocation.latitude, destinationLocation.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;

            // Create a detailed address for destination
            List<String> addressParts = [];

            if (place.thoroughfare?.isNotEmpty ?? false) {
              addressParts.add(place.thoroughfare!);
            }

            if (place.subLocality?.isNotEmpty ?? false) {
              addressParts.add(place.subLocality!);
            } else if (place.locality?.isNotEmpty ?? false) {
              addressParts.add(place.locality!);
            }

            if (place.administrativeArea?.isNotEmpty ?? false) {
              addressParts.add(place.administrativeArea!);
            }

            if (addressParts.isNotEmpty) {
              endLocationName = addressParts.join(", ");
            } else if (place.name?.isNotEmpty ?? false) {
              endLocationName = place.name!;
            }
          }
        } catch (e) {
          print("Error getting destination location name: $e");
        }
      }
    } catch (e) {
      print("Error preparing location names: $e");
    }

    try {
      // Check if we're adding or removing from favorites
      final existingPathId = await _checkIfCurrentRouteIsFavoriteAndGetPathId();
      final isCurrentlyFavorite = existingPathId != null;

      if (isCurrentlyFavorite) {
        // Delete existing favorite
        final response = await http.delete(
          Uri.parse("$baseUrl/api/favorite-paths"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": userId,
            "path_id": existingPathId,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["success"] == true) {
            setState(() {
              _isCurrentRouteFavorite = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Removed from favorites")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(data["error"] ?? "Failed to remove from favorites")),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Network error removing favorite")),
          );
        }
      } else {
        // Add as new favorite
        final response = await http.post(
          Uri.parse("$baseUrl/api/favorite-paths"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": userId,
            "start_location": startLocationName,
            "start_lat": _currentLocation!.latitude,
            "start_lon": _currentLocation!.longitude,
            "end_location": endLocationName,
            "end_lat": destinationLocation.latitude,
            "end_lon": destinationLocation.longitude,
          }),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data["success"] == true) {
            setState(() {
              _isCurrentRouteFavorite = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Added to favorites")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data["error"] ?? "Failed to add to favorites")),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Network error adding favorite")),
          );
        }
      }

      // Refresh favorite routes list
      await _loadFavoriteRoutes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // Add helper method to check if current route is favorite and return path_id
  Future<int?> _checkIfCurrentRouteIsFavoriteAndGetPathId() async {
    if (_currentLocation == null || _routeOptions.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return null;

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/favorite-paths?user_id=$userId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["favorite_paths"] != null) {
          // Get destination coordinates from current route
          LatLng? destination;
          if (_routePolylines.containsKey(_userSelectedRouteIndex)) {
            final points = _routePolylines[_userSelectedRouteIndex]!;
            if (points.isNotEmpty) {
              destination = points.last;
            }
          }

          if (destination == null) return null;

          // Check each favorite path for a match
          for (var path in data["favorite_paths"]) {
            // Extract coordinates
            String startLatLon = path["start_lat_lon"] ?? "0,0";
            List<String> startParts = startLatLon.split(",");
            double startLat = double.tryParse(startParts[0]) ?? 0;
            double startLon =
                startParts.length > 1 ? double.tryParse(startParts[1]) ?? 0 : 0;

            String endLatLon = path["end_lat_lon"] ?? "0,0";
            List<String> endParts = endLatLon.split(",");
            double endLat = double.tryParse(endParts[0]) ?? 0;
            double endLon =
                endParts.length > 1 ? double.tryParse(endParts[1]) ?? 0 : 0;

            // Check if coordinates are close enough (within ~100m)
            const double threshold = 0.001; // Approximately 100m
            if ((startLat - _currentLocation!.latitude).abs() < threshold &&
                (startLon - _currentLocation!.longitude).abs() < threshold &&
                (endLat - destination.latitude).abs() < threshold &&
                (endLon - destination.longitude).abs() < threshold) {
              setState(() {
                _isCurrentRouteFavorite = true;
              });

              return path["path_id"];
            }
          }
        }
      }
    } catch (e) {
      print("Error checking if route is favorite: $e");
    }

    setState(() {
      _isCurrentRouteFavorite = false;
    });

    return null;
  }

  // Update _checkIfCurrentRouteIsFavorite to use the new helper method
  void _checkIfCurrentRouteIsFavorite() async {
    final pathId = await _checkIfCurrentRouteIsFavoriteAndGetPathId();
    setState(() {
      _isCurrentRouteFavorite = pathId != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme from provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu,
                color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ),
        actions: [
          Row(
            children: [
              Icon(
                isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              Switch(
                value: isDarkMode,
                onChanged: (bool value) {
                  // Update the theme using the provider
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme(value);

                  if (_mapController != null) {
                    _mapController!
                        .setMapStyle(isDarkMode ? darkMapStyle : lightMapStyle);
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
      drawer: buildDrawer(context: context, isDarkMode: isDarkMode),
      endDrawer: Container(
        color: const Color(0xFF2D3250),
        child: search.MapSearchSection(
          isDarkMode: isDarkMode,
          onSubmit: (String start, String end, String travelMode,
              {LatLng? startCoordinates, LatLng? endCoordinates}) async {
            LatLng? origin = startCoordinates ??
                await getLatLngFromAddress(start, _currentLocation) ??
                _currentLocation;
            LatLng? destination = endCoordinates ??
                await getLatLngFromAddress(end, _currentLocation);

            if (origin != null && destination != null) {
              setState(() {
                _routeOptions = [];
                _isRouteLoading = true;
              });
              await _loadRoute(origin, destination, travelMode);
            }
          },
          selectedRouteIndex: _userSelectedRouteIndex,
          onRouteSelected: (int index) {
            setState(() {
              _selectedRouteIndex = index;
              _updateRouteVisibility(index);
            });
            Navigator.pop(context);
          },
          routeOptions: _routeOptions
              .map((ro) => search.RouteOption(
                    routeIndex: ro.routeIndex,
                    avgAqi: ro.avgAqi,
                    calculations: ro.calculations
                        .map((calc) => search.RouteCalculation(
                              stationName: calc.stationName,
                              startDistance: calc.startDistance,
                              endDistance: calc.endDistance,
                              aqi: calc.aqi,
                            ))
                        .toList(),
                    isSafest: ro.isSafest,
                    displayIndex: ro.displayIndex,
                  ))
              .toList(),
          googleApiKey: widget.config.googleApiKey,
          currentLocation: _currentLocation,
          isRouteLoading: _isRouteLoading,
          backgroundColor: const Color(0xFF2D3250),
        ),
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
            onCameraMove: (_) {},
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FloatingOptions(
                onPathFinder: () {
                  _scaffoldKey.currentState?.openEndDrawer();
                },
                onFilter: _showFilterDialog,
                onReset: () async {
                  setState(() {
                    _markers.clear();
                    polylines.clear();
                    _routePolylines.clear();
                    _allPolylines.clear();
                    _routeSafetyScores.clear();
                    _selectedRouteIndex = 0;
                    _safestRouteIndex = null;
                    _isRoutePlotting = false;
                    _selectedStationDetail = null;
                    _selectedMarkerLatLng = null;
                    _segmentColors.clear();
                    _activeStationIds.clear();
                    _routeOptions = [];
                  });
                  await _fetchAllAQIStations();
                },
                onToggleProgress: () {
                  setState(() {
                    _showRouteProgress = !_showRouteProgress;
                  });
                },
                onToggleAlerts: () {
                  setState(() {
                    _showNotification = !_showNotification;
                    if (_showNotification) {
                      _updateNearestStation();
                    } else if (Platform.isAndroid) {
                      AndroidNotificationService
                          .hideRouteProgressNotification();
                    }
                  });
                },
                isProgressVisible: _showRouteProgress,
                alertsEnabled: _showNotification,
                hasActiveRoute:
                    _routeOptions.isNotEmpty && _userSelectedRouteIndex >= 0,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _showRouteProgress &&
                    _routeOptions.isNotEmpty &&
                    _userSelectedRouteIndex >= 0
                ? (MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : 16)
                : -200,
            child: _routeOptions.isNotEmpty && _userSelectedRouteIndex >= 0
                ? RouteProgressDisplay(
                    stations: _routeOptions
                        .firstWhere(
                          (option) =>
                              option.routeIndex == _userSelectedRouteIndex,
                          orElse: () => _routeOptions[0],
                        )
                        .calculations,
                    nearestStationName: _nearestStationName,
                    totalRouteDistance: _getTotalRouteDistance(),
                    isDarkMode: isDarkMode,
                    onClose: _closeRouteAndClear,
                    // Add estimated arrival time
                    estimatedArrivalTime: _calculateEstimatedArrivalTime(),
                    // Add predicted AQI
                    predictedDestinationAqi: _predictDestinationAQI(),
                    // Add the current progress percentage
                    currentProgress: _routeProgress,
                    // Add these new properties
                    isFavorite: _isCurrentRouteFavorite,
                    onToggleFavorite: _toggleFavoriteRoute,
                  )
                : const SizedBox.shrink(),
          ),
          // Moving this below the UI elements and modifying the styling
          if (_selectedStationDetail != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: buildCustomInfoWindow(
                    _selectedStationDetail!,
                    isDarkMode,
                    onClose: () {
                      setState(() {
                        _selectedStationDetail = null;
                      });
                    },
                    onSaveFavorite: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final userId = prefs.getInt('user_id');
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please log in to save favorites')),
                        );
                        return;
                      }

                      try {
                        final station = _selectedStationDetail!;
                        final lat =
                            double.tryParse(station['lat']?.toString() ?? '');
                        final lon =
                            double.tryParse(station['lon']?.toString() ?? '');
                        if (lat == null || lon == null) return;

                        if (_selectedStationIsFavorite &&
                            _selectedStationFavoriteId != null) {
                          // Remove favorite
                          bool removed = false;
                          // Prefer deleting from the source we stored
                          if (_selectedFavoriteSource == 'path') {
                            try {
                              final del = await http.delete(
                                Uri.parse("$baseUrl/api/favorite-paths"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({
                                  "user_id": userId,
                                  "path_id": _selectedStationFavoriteId,
                                }),
                              );
                              removed = del.statusCode == 200;
                            } catch (_) {}
                          } else {
                            // default to location
                            try {
                              final res = await http.delete(
                                Uri.parse("$baseUrl/api/favorite-locations"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({
                                  "user_id": userId,
                                  // Server expects 'location_id'
                                  "location_id": _selectedStationFavoriteId,
                                }),
                              );
                              removed = res.statusCode == 200;
                            } catch (_) {}
                          }

                          if (!removed) {
                            // Fallback: try the other type based on coordinate matching
                            try {
                              // Find matching path_id
                              int? pathId;
                              final res = await http.get(
                                Uri.parse(
                                    "$baseUrl/api/favorite-paths?user_id=$userId"),
                              );
                              if (res.statusCode == 200) {
                                final data = jsonDecode(res.body);
                                final paths = (data is Map &&
                                        data['favorite_paths'] is List)
                                    ? List.from(data['favorite_paths'])
                                    : <dynamic>[];
                                const double threshold = 0.0009;
                                for (final p in paths) {
                                  double? pLat = double.tryParse(
                                      p['start_lat']?.toString() ?? '');
                                  double? pLon = double.tryParse(
                                      p['start_lon']?.toString() ?? '');
                                  if ((pLat == null || pLon == null) &&
                                      p['start_lat_lon'] != null) {
                                    final parts = p['start_lat_lon']
                                        .toString()
                                        .split(',');
                                    if (parts.length >= 2) {
                                      pLat = double.tryParse(parts[0].trim());
                                      pLon = double.tryParse(parts[1].trim());
                                    }
                                  }
                                  if (pLat == null || pLon == null) continue;
                                  if ((pLat - lat).abs() < threshold &&
                                      (pLon - lon).abs() < threshold) {
                                    pathId = p['path_id'];
                                    break;
                                  }
                                }
                              }
                              if (pathId != null) {
                                final del = await http.delete(
                                  Uri.parse("$baseUrl/api/favorite-paths"),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode(
                                      {"user_id": userId, "path_id": pathId}),
                                );
                                removed = del.statusCode == 200;
                              }
                            } catch (_) {}
                          }

                          if (removed) {
                            setState(() {
                              _selectedStationIsFavorite = false;
                              _selectedStationFavoriteId = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Removed from favorites')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Remove failed')),
                            );
                          }
                        } else {
                          // Add favorite
                          bool added = false;
                          int? newFavId;
                          // Try favorite-locations first
                          try {
                            final res = await http.post(
                              Uri.parse("$baseUrl/api/favorite-locations"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "user_id": userId,
                                "location_name": station['station_name'] ??
                                    'Favorite Station',
                                "latitude": lat,
                                "longitude": lon,
                              }),
                            );
                            if (res.statusCode == 201) {
                              added = true;
                              try {
                                final body = jsonDecode(res.body);
                                newFavId = body['location_id'] ??
                                    body['favorite_id'] ??
                                    body['id'];
                              } catch (_) {}
                              _selectedFavoriteSource = 'location';
                            } else if (res.statusCode == 400) {
                              // Possibly already exists; treat as success after refresh
                              await _refreshSelectedStationFavoriteState();
                              if (_selectedStationIsFavorite) {
                                added = true;
                                _selectedFavoriteSource ??= 'location';
                              }
                            }
                          } catch (_) {}

                          if (!added) {
                            // Fallback: add as favorite path (start=end)
                            try {
                              final res = await http.post(
                                Uri.parse("$baseUrl/api/favorite-paths"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({
                                  "user_id": userId,
                                  "start_location": station['station_name'] ??
                                      'Favorite Station',
                                  "start_lat": lat,
                                  "start_lon": lon,
                                  "end_location": station['station_name'] ??
                                      'Favorite Station',
                                  "end_lat": lat,
                                  "end_lon": lon,
                                }),
                              );
                              if (res.statusCode == 201 ||
                                  res.statusCode == 200) {
                                added = true;
                                try {
                                  final body = jsonDecode(res.body);
                                  newFavId = body['path_id'] ?? body['id'];
                                } catch (_) {}
                                _selectedFavoriteSource = 'path';
                              } else if (res.statusCode == 400) {
                                // Possibly duplicate; treat as success after refresh
                                await _refreshSelectedStationFavoriteState();
                                if (_selectedStationIsFavorite) {
                                  added = true;
                                  _selectedFavoriteSource ??= 'path';
                                }
                              }
                            } catch (_) {}
                          }

                          if (added) {
                            setState(() {
                              _selectedStationIsFavorite = true;
                              _selectedStationFavoriteId = newFavId;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Saved to favorites')),
                            );
                            await _refreshSelectedStationFavoriteState();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Save failed')),
                            );
                          }
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    onViewDetails: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(
                            config: widget.config,
                            station: _selectedStationDetail!,
                          ),
                        ),
                      );
                    },
                    isFavorite: _selectedStationIsFavorite,
                  ),
                ),
              ),
            ),
          if (_isLoadingMarkers)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
