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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
      _fetchAQIData(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _fetchAQIData(double lat, double lng) async {
    final url = Uri.https('api.waqi.info', '/map/bounds/', {
      'latlng': '${lat - 0.5},${lng - 0.5},${lat + 0.5},${lng + 0.5}',
      'token': _waqiApiKey,
    });

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
  Map<int, String> stationUpdateTimes = {};

  for (var station in stations) {
    final lat = station['lat'];
    final lng = station['lon'];
    final aqi = _parseAQI(station['aqi']);
    final markerIcon = await _createCustomMarker(aqi);

    stationUpdateTimes[station['uid']] = station['time'] != null && station['time']['s'] != null ? station['time']['s'] : 'Unknown';
    markers.add(
      Marker(
        markerId: MarkerId(station['station']['name']),
        position: LatLng(lat, lng),
        icon: markerIcon,
        onTap: () async {
          final stationData = await _fetchStationAQIData(station['uid']);
          setState(() {
            _selectedStation = {
              'uid': station['uid'],
              'name': stationData['name'],
              'aqi': stationData['aqi'],
              'time': stationData['time'],
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

Future<Map<String, dynamic>> _fetchStationAQIData(int stationId) async {
    if (_selectedStation != null && _selectedStation!['uid'] == stationId) {
      return {
        'name': _selectedStation!['name'],
        'aqi': _selectedStation!['aqi'],
        'time': _selectedStation!['time'],
      };
    }
  final url = Uri.https('api.waqi.info', '/feed/@$stationId/', {
    'token': _waqiApiKey,
  });

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return {
        'name': data['city']['name'],
        'aqi': data['aqi'],
        'time': data['time']['s'],
      };
    } else {
      throw Exception("Failed to load station data");
    }
  } catch (e) {
    print('Error fetching station data: $e');
    return {
      'name': 'Unknown',
      'aqi': 0,
      'time': 'Unknown',
    };
  }
}

  int _parseAQI(dynamic aqiValue) {
    return int.tryParse(aqiValue?.toString() ?? '0') ?? 0;
  }

  Future<BitmapDescriptor> _createCustomMarker(int aqi) async {
    final Color markerColor = _getAQIColor(aqi);
    final String aqiText = aqi.toString();

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = markerColor;

    const double radius = 20.0;
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: aqiText,
        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));

    final image = await pictureRecorder.endRecording().toImage((radius * 2).toInt(), (radius * 2).toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Color _getAQIColor(int aqi) {
    if (aqi == 0) return Colors.grey;
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map & AQI Stations')),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
    final lastUpdated = _selectedStation!['time'];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0, spreadRadius: 1.0)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _getAQIColor(aqi), borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Text(emoji, style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('$aqi - $aqiLevel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Last updated: $lastUpdated', style: TextStyle(fontSize: 10, color: Colors.black54)),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {},
                child: Text('See more details >>', style: TextStyle(color: Colors.blue, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAQIEmoji(int aqi) {
    if (aqi == 0) return '😶';
    if (aqi <= 50) return '😊';
    if (aqi <= 100) return '😐';
    if (aqi <= 150) return '😷';
    if (aqi <= 200) return '🤢';
    if (aqi <= 300) return '🤮';
    return '☠️';
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
