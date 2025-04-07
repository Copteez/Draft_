// แบ่งส่วนการค้นหาเส้นทางออกเป็น StatefulWidget สำหรับการใช้งานในหน้า MapPage
// โดยมีการใช้งาน Google Places API ในการค้นหาสถานที่และดึงข้อมูลพิกัด
// และส่งข้อมูลที่ได้ไปให้ parent ผ่าน callback function
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/route_preferences.dart';

class RouteSearchSection extends StatefulWidget {
  /// ปรับ onSubmit ให้รับข้อมูลเพิ่มเติม (เช่นพิกัด) ได้ด้วย
  final Function(String start, String end, String travelMode,
      {LatLng? startCoordinates, LatLng? endCoordinates}) onSubmit;
  final VoidCallback onUseCurrentLocationForStart;
  final String googleApiKey;

  const RouteSearchSection({
    Key? key,
    required this.onSubmit,
    required this.onUseCurrentLocationForStart,
    required this.googleApiKey,
  }) : super(key: key);

  @override
  _RouteSearchSectionState createState() => _RouteSearchSectionState();
}

class _RouteSearchSectionState extends State<RouteSearchSection> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<Map<String, dynamic>> _startSuggestions = [];
  List<Map<String, dynamic>> _endSuggestions = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  bool _startIsCurrentLocation = false;

  String _selectedTravelMode = 'driving';
  final List<String> _travelModes = ['driving', 'walking', 'bicycling'];

  // เก็บพิกัดที่ได้จาก Place Details API
  LatLng? _startLatLng;
  LatLng? _endLatLng;

  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _loadSavedLocations(); // Load saved data when widget initializes
    setState(() {
      _isLoading = true; // Set loading state true initially
    });
  }

  Future<void> _loadSavedLocations() async {
    try {
      final routeData = await RoutePreferences.getRouteData();

      if (mounted) {
        setState(() {
          // Update controllers with saved values
          if (routeData['startLocation'].isNotEmpty) {
            _startController.text = routeData['startLocation'];
            _startLatLng = routeData['startCoords'];
          }
          if (routeData['endLocation'].isNotEmpty) {
            _endController.text = routeData['endLocation'];
            _endLatLng = routeData['endCoords'];
          }
          _selectedTravelMode = routeData['travelMode'];
          _isLoading = false; // Set loading state to false after data is loaded
        });
      }
    } catch (e) {
      print("Error loading saved locations: $e");
      if (mounted) {
        setState(() {
          _isLoading =
              false; // Set loading state to false even if there's an error
        });
      }
    }
  }

  void _saveRouteData() {
    RoutePreferences.saveRouteData(
      startLocation: _startController.text,
      endLocation: _endController.text,
      travelMode: _selectedTravelMode,
      startCoords: _startLatLng,
      endCoords: _endLatLng,
    );
  }

  @override
  void dispose() {
    _saveRouteData(); // Save data when widget is disposed
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  /// ดึง autocomplete suggestions สำหรับที่อยู่ (จำกัดให้ในไทย)
  Future<void> _fetchStartSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _startSuggestions = [];
        _isSearchingStart = false;
      });
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': widget.googleApiKey,
        'components': 'country:th', // จำกัดผลลัพธ์ให้เป็นประเทศไทย
        'types': 'geocode',
      },
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _startSuggestions =
              List<Map<String, dynamic>>.from(data['predictions']);
          _isSearchingStart = true;
        });
      }
    } catch (e) {
      print("Error fetching start suggestions: $e");
    }
  }

  Future<void> _fetchEndSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _endSuggestions = [];
        _isSearchingEnd = false;
      });
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': widget.googleApiKey,
        'components': 'country:th', // จำกัดผลลัพธ์ให้เป็นประเทศไทย
        'types': 'geocode',
      },
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _endSuggestions =
              List<Map<String, dynamic>>.from(data['predictions']);
          _isSearchingEnd = true;
        });
      }
    } catch (e) {
      print("Error fetching end suggestions: $e");
    }
  }

  /// เมื่อผู้ใช้เลือก suggestion ให้ใช้ Place Details API เพื่อดึงข้อมูลที่ละเอียดมากขึ้น
  Future<void> _selectStartSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.googleApiKey,
        'fields': 'formatted_address,geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        String formattedAddress = result['formatted_address'] ?? "";
        // ดึงพิกัดจาก geometry ด้วย
        final geometry = result['geometry'];
        final location = geometry != null ? geometry['location'] : null;
        if (location != null) {
          double lat = location['lat'];
          double lng = location['lng'];
          _startLatLng = LatLng(lat, lng);
        }
        setState(() {
          _startController.text = formattedAddress;
          _startSuggestions = [];
          _isSearchingStart = false;
          _startIsCurrentLocation = false;
        });
        _saveRouteData(); // Changed from _saveLocations()
      }
    } catch (e) {
      print("Error fetching place details for start: $e");
    }
  }

  Future<void> _selectEndSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.googleApiKey,
        'fields': 'formatted_address,geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        String formattedAddress = result['formatted_address'] ?? "";
        final geometry = result['geometry'];
        final location = geometry != null ? geometry['location'] : null;
        if (location != null) {
          double lat = location['lat'];
          double lng = location['lng'];
          _endLatLng = LatLng(lat, lng);
        }
        setState(() {
          _endController.text = formattedAddress;
          _endSuggestions = [];
          _isSearchingEnd = false;
        });
        _saveRouteData(); // Changed from _saveLocations()
      }
    } catch (e) {
      print("Error fetching place details for end: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Start location TextField with autocomplete and clear button
              TextField(
                controller: _startController,
                decoration: InputDecoration(
                  hintText: 'Start location',
                  filled: true,
                  fillColor:
                      isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_startController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear,
                              color: isDarkMode ? Colors.white : Colors.black),
                          onPressed: () {
                            setState(() {
                              _startController.clear();
                              _startLatLng = null;
                              _startSuggestions = [];
                              _isSearchingStart = false;
                              _startIsCurrentLocation = false;
                            });
                            _saveRouteData();
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.my_location,
                            color: isDarkMode ? Colors.white : Colors.black),
                        onPressed: () {
                          widget.onUseCurrentLocationForStart();
                          setState(() {
                            _startController.text = "Your location";
                            _startIsCurrentLocation = true;
                            _startSuggestions = [];
                            _isSearchingStart = false;
                          });
                          _saveRouteData();
                        },
                      ),
                    ],
                  ),
                ),
                onChanged: (value) =>
                    _fetchStartSuggestions(value), // Simplified
              ),
              if (_isSearchingStart && _startSuggestions.isNotEmpty)
                Container(
                  color: isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _startSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _startSuggestions[index];
                      return ListTile(
                        title: Text(
                          suggestion['description'] ?? "",
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        onTap: () => _selectStartSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              // End location TextField with clear button
              TextField(
                controller: _endController,
                decoration: InputDecoration(
                  hintText: 'End location',
                  filled: true,
                  fillColor:
                      isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _endController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: isDarkMode ? Colors.white : Colors.black),
                          onPressed: () {
                            setState(() {
                              _endController.clear();
                              _endLatLng = null;
                              _endSuggestions = [];
                              _isSearchingEnd = false;
                            });
                            _saveRouteData();
                          },
                        )
                      : null,
                ),
                onChanged: (value) => _fetchEndSuggestions(value), // Simplified
              ),
              if (_isSearchingEnd && _endSuggestions.isNotEmpty)
                Container(
                  color: isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _endSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _endSuggestions[index];
                      return ListTile(
                        title: Text(
                          suggestion['description'] ?? "",
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        onTap: () => _selectEndSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              // Row สำหรับ travel mode และ Submit
              Row(
                children: [
                  // Dropdown สำหรับเลือก travel mode อยู่ด้านซ้าย
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? const Color(0xFF2D3250) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTravelMode,
                          dropdownColor: isDarkMode
                              ? const Color(0xFF2D3250)
                              : Colors.white,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          items: _travelModes.map((mode) {
                            return DropdownMenuItem<String>(
                              value: mode,
                              child: Text(mode),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTravelMode = newValue;
                              });
                              _saveRouteData();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ปุ่ม Submit อยู่ด้านขวา
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        // เมื่อกด Submit ให้เรียก onSubmit พร้อมทั้งส่งพิกัด (ถ้ามี)
                        widget.onSubmit(
                          _startController.text,
                          _endController.text,
                          _selectedTravelMode,
                          startCoordinates: _startLatLng,
                          endCoordinates: _endLatLng,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text("Submit"),
                    ),
                  ),
                ],
              ),
            ],
          );
  }
}
