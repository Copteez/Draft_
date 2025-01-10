import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  late GoogleMapController mapController;
  Set<Marker> _markers = {};
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  List<Map<String, dynamic>> _autocompleteResults = [];
  bool _isSearching = false;

  LatLng? _selectedLocation;
  LatLng? _currentLocation;

  final String _waqiApiKey = dotenv.env['WAQIAPIKEY'] ?? 'default_value';
  Map<String, dynamic>? _selectedStation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedMode = 'driving';

  // Initial position (default location until we get the user's location)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(15.41340027175844, 100.58989014756472),  // ThaiLand
    zoom: 2, // Low zoom until the user's location is fetched
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map & AQI Stations')),
      body: Column(
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
                onPressed: () {
                  _searchController.clear();
                },
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
                      _updateEndLocation(_searchController.text);
                      _updateCameraPosition();
                      _markers.add(
                          Marker(
                            markerId: MarkerId('Destination_Location'),
                            position: _selectedLocation!,
                            infoWindow: InfoWindow(title: 'END_Location'),
                            icon: BitmapDescriptor.defaultMarker,
                          ));
                      _getPolyline();
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _selectedMode,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedMode = newValue;
                    // _getRoute(); // Fetch the route again when the mode changes
                  });
                }
              },
              items: ['driving', 'walking', 'bicycling'].map((String mode) {
                return DropdownMenuItem<String>(
                  value: mode,
                  child: Text(mode),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: _defaultPosition,
              markers: _markers,
              polylines: Set<Polyline>.of(polylines.values),
              onTap: (LatLng tappedPosition) {
                _setMyLocation(tappedPosition);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setMyLocation(LatLng newLocation) {
    setState(() {
      // Update the current location and add a marker
      _currentLocation = newLocation;

      _markers.removeWhere((marker) => marker.markerId.value == 'currentLocation');
      _markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position: newLocation,
          infoWindow: InfoWindow(title: 'Your Selected Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );

      // Update the camera position to focus on the new location
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(newLocation, 14),
      );

      // Optionally fetch AQI data for the new location
      _fetchAQIData(newLocation.latitude, newLocation.longitude);
    });
  }

  // Function to get current location of the user
  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _fetchAQIData(position.latitude, position.longitude);
    });

    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation!, 14),
    );
  }

  // Map creation callback
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Optional: You can move the camera to the user's location once the map is created, in case the location is already available.
    if (_currentLocation != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading AQI data.")));
      }
    }
  }

  Future<int> _getAQI(double lat, double lng) async {
    final url = Uri.https('api.waqi.info',
      '/feed/geo:$lat;$lng/',
      {'token': _waqiApiKey},
    );
    print("LAT: $lat, LNG: $lng");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Accessing 'data' and then the 'aqi' value
        if (data['status'] == 'ok' && data['data'] != null) {
          final aqi = data['data']['aqi']; //
          return aqi;
        } else {
          throw Exception('Failed to retrieve AQI data or invalid data format');
        }
      } else {
        throw Exception("Failed to load AQI data: ${response.statusCode}");
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading AQI data.")));
      }
    }
    return -1; // Return -1 on error
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
          onTap: () async {
            final stationData = await _fetchStationAQIData(station['uid']);
            if (mounted) {
              setState(() {
                _selectedStation = {
                  'uid': station['uid'],
                  'name': stationData['name'],
                  'aqi': stationData['aqi'],
                  'time': stationData['time'],
                };
              });
            }
          },
        ),
      );
    }
    setState(() {
      _markers = markers;
      _markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position: _currentLocation!,
          infoWindow: InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
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

    const double radius = 50.0;
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: aqiText,
        style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
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

  Future<void> _updateEndLocation(String query) async {
    try {
      final List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        setState(() {
          _selectedLocation = LatLng(locations[0].latitude, locations[0].longitude);
        });
        // _getRoute();
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  // Decode polyline points from the API response
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
      int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
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
      int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng((lat / 1E5), (lng / 1E5)));
    }
    return points;
  }


// Function to add polyline to the map
  Future<void> _addPolyline(List<LatLng> points) async {
    final tenPercentofRoute = getTenPercent(points.length);
    for (int i = tenPercentofRoute;i<points.length;i = i + tenPercentofRoute){
      PolylineId id = PolylineId("polyline_${DateTime.now().millisecondsSinceEpoch}");
      Color aqiColor = _getAQIColor(await _getAQI(points[i].latitude,points[i].longitude));
      // print("Point lenght: ${points.length}");
      Polyline polyline = Polyline(
        polylineId: id,
        width: 5,
        color: aqiColor,
        points: [points[i-tenPercentofRoute], points[i]],
      );

      setState(() {
        polylines[id] = polyline;
      });

    }
  }

  int getTenPercent(int number) {
    return (number * 10) ~/ 100;
  }


  _getPolyline() async {
    final String apiKey = dotenv.env['GOOGLE_API'] ?? 'API key not found';
    final origin = _currentLocation!;
    final destination = _selectedLocation!;

    // Prepare the URL to fetch the directions from Google Maps API with multiple alternatives
    final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': _selectedMode,  // Driving, walking, or bicycling
      'alternatives': 'true',  // Request multiple routes
      'key': apiKey,
    });

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'];

        // Clear any existing polylines before adding new ones
        setState(() {
          polylines.clear();
          polylineCoordinates.clear();
        });

        // Add each alternative route as a polyline
        for (var route in routes) {
          List<LatLng> points = [];
          for (var leg in route['legs']) {
            for (var step in leg['steps']) {
              final polyline = step['polyline']['points'];
              points.addAll(_decodePoly(polyline));
            }
          }

          // Create a new polyline for this route
          await _addPolyline(points);
        }
      } else {
        throw Exception("Failed to fetch routes");
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading routes.")));
    }
  }

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
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
  }

  void _updateCameraPosition() {
    if (_currentLocation != null && _selectedLocation != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentLocation!.latitude < _selectedLocation!.latitude
              ? _currentLocation!.latitude
              : _selectedLocation!.latitude,
          _currentLocation!.longitude < _selectedLocation!.longitude
              ? _currentLocation!.longitude
              : _selectedLocation!.longitude,
        ),
        northeast: LatLng(
          _currentLocation!.latitude > _selectedLocation!.latitude
              ? _currentLocation!.latitude
              : _selectedLocation!.latitude,
          _currentLocation!.longitude > _selectedLocation!.longitude
              ? _currentLocation!.longitude
              : _selectedLocation!.longitude,
        ),
      );

      // Set the camera to fit the bounds with some padding
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50)); // Adjust padding as needed
    }
  }
}
