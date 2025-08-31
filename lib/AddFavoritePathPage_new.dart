import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'config.dart';
import 'MapSelectionPage.dart';
import 'theme_provider.dart';
import 'network_service.dart';

class AddFavoritePathPage extends StatefulWidget {
  final Config config;

  const AddFavoritePathPage({Key? key, required this.config}) : super(key: key);

  @override
  _AddFavoritePathPageState createState() => _AddFavoritePathPageState();
}

class _AddFavoritePathPageState extends State<AddFavoritePathPage> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;

  @override
  void dispose() {
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // ฟังก์ชันสำหรับบันทึก Favorite Path เรียกใช้ API
  // ----------------------------------------------------------------------
  Future<void> _saveFavoritePath() async {
    if (startController.text.isEmpty || endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter both start and end locations")),
      );
      return;
    }

    if (_startLatLng == null || _endLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select or search for valid locations")),
      );
      return;
    }

    try {
      const String apiUrl = "http://192.168.1.104:5000/api/favorite-paths";
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 1, // Default user ID - you can make this dynamic later
          'start_location': startController.text,
          'end_location': endController.text,
          'start_lat': _startLatLng!.latitude,
          'start_lon': _startLatLng!.longitude,
          'end_lat': _endLatLng!.latitude,
          'end_lon': _endLatLng!.longitude,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Favorite path saved successfully")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save favorite path")),
        );
      }
    } catch (e) {
      print("Error saving favorite path: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving favorite path")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Favorite Path",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          Row(
            children: [
              Icon(
                isDarkMode
                    ? CupertinoIcons.sun_max_fill
                    : CupertinoIcons.moon_fill,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              Switch(
                value: isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeColor: Colors.orange,
                inactiveThumbColor: Colors.grey,
                activeTrackColor: Colors.orange.withOpacity(0.5),
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Text(
              "Create New Route",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Set up your favorite route for quick air quality monitoring",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Start Location Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [const Color(0xFF545978), const Color(0xFF444C63)]
                      : [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Start location header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Start Location",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Start location input
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.2)
                            : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: startController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter start location or search...",
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        onChanged: (value) {
                          _fetchStartSuggestions(value);
                        },
                      ),
                    ),

                    // Start suggestions
                    if (_startSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF3C4055)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _startSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _startSuggestions[index];
                            return ListTile(
                              leading: Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 20,
                              ),
                              title: Text(
                                suggestion['description'] ?? "",
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () => _selectStartSuggestion(suggestion),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Start location action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapSelectionPage(
                                    title: "Select Start Location",
                                    isDarkMode: isDarkMode,
                                    googleApiKey: widget.config.googleApiKey,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  startController.text = result["name"];
                                  _startLatLng =
                                      LatLng(result["lat"], result["lng"]);
                                });
                              }
                            },
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text(
                              "From Map",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _setCurrentLocation(true),
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const Text(
                              "Current",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // End Location Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [const Color(0xFF545978), const Color(0xFF444C63)]
                      : [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // End location header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "End Location",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // End location input
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.2)
                            : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: endController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter end location or search...",
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        onChanged: (value) {
                          _fetchEndSuggestions(value);
                        },
                      ),
                    ),

                    // End suggestions
                    if (_endSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF3C4055)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _endSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _endSuggestions[index];
                            return ListTile(
                              leading: Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 20,
                              ),
                              title: Text(
                                suggestion['description'] ?? "",
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () => _selectEndSuggestion(suggestion),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // End location action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapSelectionPage(
                                    title: "Select End Location",
                                    isDarkMode: isDarkMode,
                                    googleApiKey: widget.config.googleApiKey,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  endController.text = result["name"];
                                  _endLatLng =
                                      LatLng(result["lat"], result["lng"]);
                                });
                              }
                            },
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text(
                              "From Map",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _setCurrentLocation(false),
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const Text(
                              "Current",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _saveFavoritePath();
                },
                icon: const Icon(Icons.favorite, size: 24),
                label: const Text(
                  "Save Favorite Route",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 6,
                  shadowColor: Colors.orange.withOpacity(0.3),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  Future<void> _fetchStartSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _startSuggestions = [];
      });
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': widget.config.googleApiKey,
        'components': 'country:th',
      },
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _startSuggestions = data['predictions'] ?? [];
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
      });
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': widget.config.googleApiKey,
        'components': 'country:th',
      },
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _endSuggestions = data['predictions'] ?? [];
          _isSearchingEnd = true;
        });
      }
    } catch (e) {
      print("Error fetching end suggestions: $e");
    }
  }

  Future<String> _getPlaceName(String placeId) async {
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.config.googleApiKey,
        'fields': 'name'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['name'] ?? "";
      }
    } catch (e) {
      print("Error fetching place name: $e");
    }
    return "";
  }

  Future<void> _selectStartSuggestion(dynamic suggestion) async {
    final placeId = suggestion['place_id'];
    String name = await _getPlaceName(placeId);
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.config.googleApiKey,
        'fields': 'geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loc = data['result']['geometry']['location'];
        setState(() {
          startController.text = name;
          _startLatLng = LatLng(loc['lat'], loc['lng']);
          _startSuggestions = [];
          _isSearchingStart = false;
        });
      }
    } catch (e) {
      print("Error fetching start place details: $e");
    }
  }

  Future<void> _selectEndSuggestion(dynamic suggestion) async {
    final placeId = suggestion['place_id'];
    String name = await _getPlaceName(placeId);
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.config.googleApiKey,
        'fields': 'geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loc = data['result']['geometry']['location'];
        setState(() {
          endController.text = name;
          _endLatLng = LatLng(loc['lat'], loc['lng']);
          _endSuggestions = [];
          _isSearchingEnd = false;
        });
      }
    } catch (e) {
      print("Error fetching end place details: $e");
    }
  }

  // ----------------------------------------------------------------------
  // ฟังก์ชันสำหรับใช้ตำแหน่งปัจจุบัน (Current Location)
  // ----------------------------------------------------------------------
  Future<void> _setCurrentLocation(bool isStart) async {
    bool serviceEnabled;
    LocationPermission permission;

    // ตรวจสอบว่าเปิด Location Service แล้วหรือไม่
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location services are disabled.")),
      );
      return;
    }
    // ตรวจสอบ Permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are denied.")),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Location permissions are permanently denied.")),
      );
      return;
    }
    // ดึงตำแหน่งปัจจุบัน
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    String placeName = await _getPlaceNameFromCoordinates(
        LatLng(position.latitude, position.longitude));
    setState(() {
      if (isStart) {
        startController.text = placeName;
        _startLatLng = LatLng(position.latitude, position.longitude);
      } else {
        endController.text = placeName;
        _endLatLng = LatLng(position.latitude, position.longitude);
      }
    });
  }

  // ----------------------------------------------------------------------
  // ฟังก์ชัน reverse geocoding: เปลี่ยนพิกัดเป็นชื่อสถานที่
  // ----------------------------------------------------------------------
  Future<String> _getPlaceNameFromCoordinates(LatLng position) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${position.latitude},${position.longitude}',
        'key': widget.config.googleApiKey,
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] ?? "Unknown location";
        }
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
    }
    return "Unknown location";
  }
}
