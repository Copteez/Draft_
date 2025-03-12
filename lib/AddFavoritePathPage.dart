import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'config.dart';
import 'MapSelectionPage.dart';
import 'network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddFavoritePathPage extends StatefulWidget {
  final AppConfig config;
  final bool isDarkMode;
  const AddFavoritePathPage(
      {Key? key, required this.config, required this.isDarkMode})
      : super(key: key);

  @override
  _AddFavoritePathPageState createState() => _AddFavoritePathPageState();
}

class _AddFavoritePathPageState extends State<AddFavoritePathPage> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  LatLng? _startLatLng;
  LatLng? _endLatLng;

  // ----------------------------------------------------------------------
  // API call เพื่อบันทึก Favorite Path โดยใช้ POST ไปที่ /api/favorite-paths
  // ----------------------------------------------------------------------
  Future<void> _saveFavoritePath() async {
    if (_startLatLng == null || _endLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("กรุณาเลือกทั้งตำแหน่งเริ่มต้นและปลายทางครับ")),
      );
      return;
    }

    // ดึง user_id จาก SharedPreferences ที่เซฟตอน login
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่ครับ")),
      );
      return;
    }

    final startLocation = startController.text;
    final endLocation = endController.text;

    final body = jsonEncode({
      "user_id": userId, // ใช้ user_id จาก SharedPreferences
      "start_location": startLocation,
      "start_lat": _startLatLng!.latitude,
      "start_lon": _startLatLng!.longitude,
      "end_location": endLocation,
      "end_lat": _endLatLng!.latitude,
      "end_lon": _endLatLng!.longitude,
    });

    final baseUrl =
        await NetworkService(config: widget.config).getEffectiveBaseUrl();
    final url = Uri.parse("$baseUrl/api/favorite-paths");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เพิ่ม Favorite Path สำเร็จ 🎉")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data["error"] ??
                  "เกิดข้อผิดพลาดในการเพิ่ม Favorite Path 😅")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ----------------------------------------------------------------------
  // ฟังก์ชันสำหรับค้นหาและแสดงคำแนะนำ (Autocomplete) จาก Google Places API
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
        if (data['results'] != null && data['results'].length > 0) {
          return data['results'][0]['formatted_address'] ?? "Unknown Location";
        }
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
    }
    return "Unknown Location";
  }

  // ----------------------------------------------------------------------
  // UI Build Method
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Favorite Path"),
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        iconTheme: IconThemeData(
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
        titleTextStyle: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Start location TextField with inline suggestions
              TextField(
                controller: startController,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: "Start Location",
                  labelStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.isDarkMode
                      ? const Color(0xFF545978)
                      : Colors.grey[200],
                ),
                onChanged: (value) {
                  _fetchStartSuggestions(value);
                },
              ),
              if (_startSuggestions.isNotEmpty)
                Container(
                  color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _startSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _startSuggestions[index];
                      return ListTile(
                        title: Text(
                          suggestion['description'] ?? "",
                          style: TextStyle(
                            color:
                                widget.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        onTap: () => _selectStartSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              // Button to select start location from map
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapSelectionPage(
                          title: "Select Start Location",
                          isDarkMode: widget.isDarkMode,
                          googleApiKey: widget.config.googleApiKey,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        startController.text = result["name"];
                        _startLatLng = LatLng(result["lat"], result["lng"]);
                      });
                    }
                  },
                  child: const Text("Select Start from Map"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Button to use current location for start
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _setCurrentLocation(true),
                  child: const Text("Use Current Start Location"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // End location TextField with inline suggestions
              TextField(
                controller: endController,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: "End Location",
                  labelStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: widget.isDarkMode
                      ? const Color(0xFF545978)
                      : Colors.grey[200],
                ),
                onChanged: (value) {
                  _fetchEndSuggestions(value);
                },
              ),
              if (_endSuggestions.isNotEmpty)
                Container(
                  color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _endSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _endSuggestions[index];
                      return ListTile(
                        title: Text(
                          suggestion['description'] ?? "",
                          style: TextStyle(
                            color:
                                widget.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        onTap: () => _selectEndSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              // Button to select end location from map
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapSelectionPage(
                          title: "Select End Location",
                          isDarkMode: widget.isDarkMode,
                          googleApiKey: widget.config.googleApiKey,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        endController.text = result["name"];
                        _endLatLng = LatLng(result["lat"], result["lng"]);
                      });
                    }
                  },
                  child: const Text("Select End from Map"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Button to use current location for end
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _setCurrentLocation(false),
                  child: const Text("Use Current End Location"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ปุ่ม Save Favorite Path เรียกใช้ API
              ElevatedButton(
                onPressed: _saveFavoritePath,
                child: const Text("Save Favorite Path"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
