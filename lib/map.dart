import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  Set<Marker> markers = {};
  Position? _currentPosition; // Make this nullable

  final String googleApiKey = "AIzaSyD9uJEBY4FZ1T2wBCj3oVTsIW5dDbWv0G0";

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // Get current location
  Future<void> _getUserLocation() async {
    Position position = await _determinePosition();
    setState(() {
      _currentPosition = position;
    });
    _loadAQIStations();
  }

  // Get AQI data for nearby stations
// Get AQI data for nearby stations
Future<void> _loadAQIStations() async {
  if (_currentPosition == null) return;

  double latitude = _currentPosition!.latitude;
  double longitude = _currentPosition!.longitude;

  var apiKey = "58619aef51181265b04347c2df10bd62a56995ef";
  var bounds = "[[$latitude, $longitude], [${latitude + 1}, ${longitude + 1}]]";
  var url = "https://api.waqi.info/map/bounds/?token=$apiKey&latlng=$bounds";
  var response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    var jsonData = jsonDecode(response.body);
    List stations = jsonData['data'];

    setState(() {
      for (var station in stations) {
        double lat = station['lat'];
        double lon = station['lon'];
        int aqi = station['aqi'];
        String stationName = station['station']['name'];

        // Add marker
        markers.add(Marker(
          markerId: MarkerId(stationName),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(title: stationName, snippet: "AQI: $aqi"),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getAQIColorHue(aqi)),
        ));
      }
    });
  } else {
    throw Exception("Failed to load AQI data");
  }
}


  // AQI color
  double _getAQIColorHue(int aqi) {
    if (aqi <= 50) {
      return BitmapDescriptor.hueGreen; // Good
    } else if (aqi <= 100) {
      return BitmapDescriptor.hueYellow; // Moderate
    } else if (aqi <= 150) {
      return BitmapDescriptor.hueOrange; // Unhealthy for sensitive groups
    } else if (aqi <= 200) {
      return BitmapDescriptor.hueRed; // Unhealthy
    } else if (aqi <= 300) {
      return BitmapDescriptor.hueViolet; // Very Unhealthy
    } else {
      return BitmapDescriptor.hueRose; // Hazardous
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AQI Map"),
        centerTitle: true,
      ),
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 10,
              ),
              markers: markers,
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions),
            label: 'Path Finder',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: 1,
        selectedItemColor: Color(0xFF77A1C9),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            // Home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 1) {
            // Map
          } else if (index == 2) {
            // Path Finder
          } else if (index == 3) {
            // Settings
          }
        },
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }
}
