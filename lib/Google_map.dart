import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  LatLng? _selectedLocation;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _autocompleteResults = [];
  bool _isSearching = false;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(15.4134, 100.5899), // Thailand fallback position
    zoom: 6,
  );

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MySecureMap'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: _defaultPosition,
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => _fetchAutocompleteSuggestions(value),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Search for location',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    ),
                  ),
                ),
                if (_isSearching)
                  Container(
                    color: Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _autocompleteResults.length,
                      itemBuilder: (context, index) {
                        final result = _autocompleteResults[index];
                        return ListTile(
                          title: Text(result['description']),
                          onTap: () async {
                            await _selectLocation(result['place_id']);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _getUserLocation(),
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position: _currentLocation!,
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      );
    });

    _moveToCurrentLocation();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentLocation != null) {
      _moveToCurrentLocation();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (_currentLocation != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
    }
  }

  // This function fetches autocomplete suggestions from Google Place API
  Future<void> _fetchAutocompleteSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _autocompleteResults.clear();
        _isSearching = false;
      });
      return;
    }

    final String apiKey = dotenv.env['GOOGLE_API'] ?? 'API_KEY_NOT_SET';
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': query,
      'key': apiKey,
      'location': '${_currentLocation?.latitude},${_currentLocation?.longitude}',
      'radius': '50000', // 50 km search radius
    });

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _autocompleteResults = List<Map<String, dynamic>>.from(data['predictions']);
          _isSearching = true;
        });
      }
    } catch (e) {
      print('Error fetching autocomplete: $e');
      setState(() => _isSearching = false);
    }
  }

  // Select location and show a marker
  Future<void> _selectLocation(String placeId) async {
    setState(() => _isSearching = false);

    final String apiKey = dotenv.env['GOOGLE_API'] ?? 'API_KEY_NOT_SET';
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': apiKey,
    });

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['result'];
        final double lat = data['geometry']['location']['lat'];
        final double lng = data['geometry']['location']['lng'];
        final LatLng location = LatLng(lat, lng);

        setState(() {
          _selectedLocation = location;
          _markers.add(
            Marker(
              markerId: MarkerId('selectedLocation'),
              position: location,
              infoWindow: InfoWindow(title: data['name']),
            ),
          );
        });

        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(location, 14),
        );
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
  }
}
