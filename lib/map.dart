import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:MySecureMap/config.dart';
import 'package:MySecureMap/home_page/widgets/drawer_widget.dart';
import 'package:MySecureMap/map/map_source_dropdown.dart';
import 'package:MySecureMap/map/map_theme.dart';
import 'package:MySecureMap/map/map_search_section.dart'; // widget ที่รวมฟีเจอร์ search ทั้งหมด

class MapPage extends StatefulWidget {
  final AppConfig config;
  const MapPage({Key? key, required this.config}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  String _selectedSource = "All";
  List<String> _sources = ["All"];
  List<Map<String, dynamic>> _allStations = [];
  Set<Marker> _markers = {};
  List<LatLng> polylineCoordinates = [];
  Map<PolylineId, Polyline> polylines = {};
  String _searchQuery = "";
  bool _isDarkMode = false;
  String _selectedParameter = "AQI";
  final List<String> _parameters = ["AQI", "PM2.5", "PM10", "O3", "SO2"];
  String _startAddress = "";

  // Manual base URL
  final String baseUrl =
      "https://3e24-2001-fb1-178-76e-402b-db55-4cab-efc.ngrok-free.app";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchSources();
    _fetchAllAQIStations();
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    // ถ้า input เป็น "Your location" ให้คืนค่าตำแหน่งปัจจุบัน
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

  // ฟังก์ชันใหม่สำหรับดึงค่า AQI สำหรับแต่ละจุดในเส้นทาง
  Future<List<int>> _getBatchAQI(List<LatLng> points) async {
    final url = Uri.parse('$baseUrl/api/batch-nearest-station-aqi');
    try {
      final coordinates = points.map((point) {
        return {"latitude": point.latitude, "longitude": point.longitude};
      }).toList();

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"coordinates": coordinates, "source": "All"}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<dynamic> results = data['results'];
          print("✅ AQI Results: $results"); // Debug ค่า AQI ที่ได้รับ
          return results.map<int>((result) => result['aqi'] as int).toList();
        } else {
          throw Exception('Failed to get AQI: ${data['error']}');
        }
      } else {
        throw Exception("Failed to fetch data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching AQI batch data: $e");
      return List.filled(points.length, 0);
    }
  }

  // ฟังก์ชันใหม่สำหรับเพิ่ม polyline โดยแบ่ง segment ตามค่า AQI
  Future<void> _addPolyline(List<LatLng> points, {int routeIndex = 0}) async {
    try {
      final aqiValues = await _getBatchAQI(points);
      for (int i = 1; i < points.length; i++) {
        // สร้าง PolylineId โดยรวม routeIndex เข้าไปด้วย
        PolylineId id = PolylineId(
            "polyline_route_${routeIndex}_${DateTime.now().millisecondsSinceEpoch}_$i");
        // เลือกค่า AQI สำหรับ segment นี้ (สามารถปรับให้ใช้จุดตรงกลางหรือใกล้ที่สุดได้ตามต้องการ)
        int aqi = aqiValues[i];
        Color aqiColor = _getAQIColor(aqi);

        Polyline polyline = Polyline(
          polylineId: id,
          width: 5,
          color: aqiColor,
          points: [points[i - 1], points[i]],
        );

        setState(() {
          polylines[id] = polyline;
        });
      }
    } catch (e) {
      print("Error adding polylines: $e");
    }
  }

// Map cache สำหรับเก็บเส้นทางที่ค้นหาแล้ว
  Map<String, List<LatLng>> _routeCache = {};
  Future<void> _getSegmentedRoute(List<LatLng> points,
      {int routeIndex = 0}) async {
    final url = Uri.parse("$baseUrl/api/route-segmentation");

    final routePayload = {
      "route": points.map((point) {
        return {"lat": point.latitude, "lon": point.longitude};
      }).toList()
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(routePayload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Segmentation API response for route $routeIndex: $data");
        if (data["success"] == true) {
          List segments = data["segments"];
          for (int i = 0; i < segments.length; i++) {
            final seg = segments[i];
            final start = LatLng(seg["start"]["lat"], seg["start"]["lon"]);
            final end = LatLng(seg["end"]["lat"], seg["end"]["lon"]);
            Color segColor = _colorFromHex(seg["color"]);

            PolylineId id = PolylineId("seg_${routeIndex}_$i");
            Polyline polyline = Polyline(
              polylineId: id,
              color: segColor,
              width: 5,
              points: [start, end],
            );
            setState(() {
              polylines[id] = polyline;
            });
          }
        } else {
          print("Segmentation API error: ${data['error']}");
        }
      } else {
        print("Error fetching segmentation: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception in _getSegmentedRoute: $e");
    }
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    Color color = Color(int.parse(hexColor, radix: 16));
    return (color == Colors.black) ? Colors.grey : color; // เปลี่ยนจากดำเป็นเทา
  }

  Future<void> _getPolyline(
      LatLng origin, LatLng destination, String travelMode) async {
    final String apiKey = widget.config.googleApiKey;
    String cacheKey =
        "${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}_$travelMode";

    // Clear polyline เพียงครั้งเดียวก่อนเริ่มวน alternatives
    setState(() {
      polylines.clear();
      polylineCoordinates.clear();
    });

    final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': travelMode,
      'alternatives': 'true', // ขอเส้นทางมากกว่า 1 เส้น
      'key': apiKey,
    });

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'];
        if (routes != null && routes.isNotEmpty) {
          // เราจะวนลูป alternatives โดยไม่ล้าง polylinesในแต่ละรอบ
          int routeCount = routes.length >= 3 ? 3 : routes.length;
          for (int r = 0; r < routeCount; r++) {
            // ใช้ detailed polyline ถ้าเป็นไปได้ (หรือ overview_polyline ถ้า detailed ไม่พร้อม)
            final overview = routes[r]['overview_polyline']['points'];
            List<LatLng> points = _decodePoly(overview);
            _routeCache["$cacheKey-$r"] = points;
            await _getSegmentedRoute(points, routeIndex: r);
          }
          _updateCameraPositionForRoute(origin, destination);
        } else {
          print("No routes found");
        }
      } else {
        print("Error fetching directions: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching polyline: $e");
    }
  }

  List<LatLng> _decodePoly(String poly) {
    var list = poly.codeUnits;
    List<LatLng> points = [];
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

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _updateCameraPositionForRoute(LatLng origin, LatLng destination) {
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        math.min(origin.latitude, destination.latitude),
        math.min(origin.longitude, destination.longitude),
      ),
      northeast: LatLng(
        math.max(origin.latitude, destination.latitude),
        math.max(origin.longitude, destination.longitude),
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      if (_mapController != null && _currentLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 14),
        );
      }
    } catch (e) {
      print("Error getting current location: $e");
    }
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

  Future<void> _populateAllMarkers() async {
    Set<Marker> markers = {};

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: "Your Location"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    for (var station in _allStations) {
      double? lat;
      double? lon;

      if (station.containsKey("lat") && station.containsKey("lon")) {
        lat = double.tryParse(station["lat"].toString());
        lon = double.tryParse(station["lon"].toString());
      } else if (station.containsKey("lat_lon")) {
        List<String> parts = station["lat_lon"].toString().split(",");
        if (parts.length == 2) {
          lat = double.tryParse(parts[0]);
          lon = double.tryParse(parts[1]);
        }
      }

      int value = 0;
      switch (_selectedParameter) {
        case "AQI":
          value = int.tryParse(station["aqi"]?.toString() ?? "") ?? 0;
          break;
        case "PM2.5":
          value = int.tryParse(station["pm25"]?.toString() ?? "") ?? 0;
          break;
        case "PM10":
          value = int.tryParse(station["pm10"]?.toString() ?? "") ?? 0;
          break;
        case "O3":
          value = int.tryParse(station["o3"]?.toString() ?? "") ?? 0;
          break;
        case "SO2":
          value = int.tryParse(station["so2"]?.toString() ?? "") ?? 0;
          break;
        default:
          value = int.tryParse(station["aqi"]?.toString() ?? "") ?? 0;
      }

      if (value == -1) continue;

      if (lat != null && lon != null) {
        BitmapDescriptor markerIcon = await _createCustomMarker(value);
        markers.add(
          Marker(
            markerId: MarkerId(station["station_id"].toString()),
            position: LatLng(lat, lon),
            infoWindow: InfoWindow(
              title: station["station_name"],
              snippet: "$_selectedParameter: $value",
            ),
            icon: markerIcon,
          ),
        );
      }
    }
    setState(() {
      _markers = markers;
    });
  }

  Future<BitmapDescriptor> _createCustomMarker(int aqi) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();
    Color markerColor = _getAQIColor(aqi);
    paint.color = markerColor;
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
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(_isDarkMode ? darkMapStyle : lightMapStyle);
  }

  void _onUseCurrentLocationForStart() {
    if (_currentLocation != null) {
      print("Using current location as start point");
      // สามารถจัดการอัปเดตตำแหน่งเริ่มต้นใน parent ได้ที่นี่
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Row(
            children: [
              Icon(
                _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
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
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? const LatLng(13.7563, 100.5018),
                zoom: 14,
              ),
              myLocationEnabled: true,
              markers: _markers,
              polylines: Set<Polyline>.of(polylines.values),
            ),
          ),
          CombinedSearchSection(
            onSubmit: (String start, String end, String travelMode,
                {LatLng? startCoordinates, LatLng? endCoordinates}) async {
              print(
                  "onSubmit called with start: $start, end: $end, travelMode: $travelMode");
              // ถ้าผู้ใช้เลือกตำแหน่งจาก autocomplete จะได้ค่า startCoordinates กับ endCoordinates
              LatLng? origin = startCoordinates ??
                  await _getLatLngFromAddress(start) ??
                  _currentLocation;
              LatLng? destination =
                  endCoordinates ?? await _getLatLngFromAddress(end);
              if (origin != null && destination != null) {
                print("Origin: $origin, Destination: $destination");
                await _getPolyline(origin, destination, travelMode);
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
                _populateAllMarkers();
              }
            },
          ),
        ],
      ),
    );
  }
}
