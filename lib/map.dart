import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  Set<Marker> _markers = {};
  Position? _currentPosition;
  final String _waqiApiKey = "58619aef51181265b04347c2df10bd62a56995ef";
  Map<String, dynamic>? _selectedStation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      _fetchAQIData(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _fetchAQIData(double lat, double lng) async {
    final url = Uri.https(
      'api.waqi.info',
      '/map/bounds/',
      {
        'latlng': '${lat - 0.5},${lng - 0.5},${lat + 0.5},${lng + 0.5}',
        'token': _waqiApiKey,
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _populateMarkers(data['data']);
      } else {
        throw Exception("Failed to load AQI data");
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading AQI data.")),
      );
    }
  }

  void _populateMarkers(List<dynamic> stations) async {
    Set<Marker> markers = {};
    for (var station in stations) {
      final lat = station['lat'];
      final lng = station['lon'];
      final aqi = _parseAQI(station['aqi']);
      final markerIcon = await _createCustomMarker(aqi);

      markers.add(
        Marker(
          markerId: MarkerId(station['station']['name']),
          position: LatLng(lat, lng),
          icon: markerIcon,
          onTap: () {
            setState(() {
              _selectedStation = {
                'name': station['station']['name'],
                'aqi': aqi,
              };
            });
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  int _parseAQI(dynamic aqiValue) {
    if (aqiValue == null || aqiValue == '-' || aqiValue == '') {
      return 0;
    }
    try {
      return int.parse(aqiValue.toString());
    } catch (e) {
      print('Error parsing AQI: $e');
      return 0;
    }
  }

// AQI marker 
Future<BitmapDescriptor> _createCustomMarker(int aqi) async {
  final Color markerColor = _getAQIColor(aqi);
  final String aqiText = aqi.toString();

  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()..color = markerColor;

  const double radius = 20.0; // radius aqi
  canvas.drawCircle(
    Offset(radius, radius),
    radius,
    paint,
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: aqiText,
      style: TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      radius - textPainter.width / 2,
      radius - textPainter.height / 2,
    ),
  );

  final image = await pictureRecorder.endRecording().toImage(
    (radius * 2).toInt(),
    (radius * 2).toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

  Color _getAQIColor(int aqi) {
    if (aqi == 0) {
      return Colors.grey; // Use gray for AQI = 0
    } else if (aqi <= 50) {
      return Colors.green; // Good
    } else if (aqi <= 100) {
      return Colors.yellow; // Moderate
    } else if (aqi <= 150) {
      return Colors.orange; // Unhealthy for Sensitive Groups
    } else if (aqi <= 200) {
      return Colors.red; // Unhealthy
    } else if (aqi <= 300) {
      return Colors.purple; // Very Unhealthy
    } else {
      return Colors.brown; // Hazardous
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & AQI Stations'),
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: (controller) {
                    mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 12,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
          if (_selectedStation != null) _buildInfoWindow(),
        ],
      ),
    );
  }

Widget _buildInfoWindow() {
  final name = _selectedStation!['name'];
  final aqi = _selectedStation!['aqi'];
  final aqiLevel = _getAQILevel(aqi);
  final emoji = _getAQIEmoji(aqi);

  return Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _getAQIColor(aqi),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  emoji,
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  '$aqi - $aqiLevel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Last updated 
          Text(
            'Last updated: 1 hour ago',
            style: TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // See more details
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: () {},
              child: Text(
                'See more details >>',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// emoji for AQI value
String _getAQIEmoji(int aqi) {
  if (aqi == 0) return '😶';
  if (aqi <= 50) return '😊'; // Good
  if (aqi <= 100) return '😐'; // Moderate
  if (aqi <= 150) return '😷'; // Unhealthy for Sensitive Groups
  if (aqi <= 200) return '🤢'; // Unhealthy
  if (aqi <= 300) return '🤮'; // Very Unhealthy
  return '☠️'; // Hazardous
}


  String _getAQILevel(int aqi) {
    if (aqi == 0) return 'No Data';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }
}
