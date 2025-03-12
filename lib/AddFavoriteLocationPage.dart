import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'config.dart';
import 'MapSelectionPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddFavoriteLocationPage extends StatefulWidget {
  final AppConfig config;
  final bool isDarkMode;
  const AddFavoriteLocationPage(
      {Key? key, required this.config, required this.isDarkMode})
      : super(key: key);

  @override
  _AddFavoriteLocationPageState createState() =>
      _AddFavoriteLocationPageState();
}

class _AddFavoriteLocationPageState extends State<AddFavoriteLocationPage> {
  final TextEditingController locationController = TextEditingController();
  List<dynamic> _suggestions = [];
  bool _isSearching = false;
  LatLng? _selectedLatLng;

  Future<void> _fetchSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': widget.config.googleApiKey,
        'components': 'country:th',
      },
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestions = data['predictions'] ?? [];
          _isSearching = true;
        });
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    }
  }

  Future<void> _selectSuggestion(dynamic suggestion) async {
    final placeId = suggestion['place_id'];
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.config.googleApiKey,
        'fields': 'name,geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        String name = result['name'] ?? "";
        final location = result['geometry']['location'];
        LatLng latLng = LatLng(location['lat'], location['lng']);
        setState(() {
          locationController.text = name;
          _selectedLatLng = latLng;
          _suggestions = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      print("Error selecting suggestion: $e");
    }
  }

  Future<void> _saveFavoriteLocation() async {
    if (_selectedLatLng == null || locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please select a location and enter a location name.")),
      );
      return;
    }
    // Get user_id from SharedPreferences (assumes user is logged in)
    // You may have already stored it; here we simply fetch it.
    // For a production app, consider using a dedicated auth service.
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("User not found. Please log in again.")));
      return;
    }

    // Prepare POST request to your server endpoint /api/favorite-locations.
    final url = Uri.parse("${widget.config.ngrok}/api/favorite-locations");
    final body = jsonEncode({
      "user_id": userId,
      "location_name": locationController.text,
      "latitude": _selectedLatLng!.latitude,
      "longitude": _selectedLatLng!.longitude,
    });
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"}, body: body);
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          // Assuming the server returns a favorite_id and other details.
          int favId =
              data["favorite_id"] ?? DateTime.now().millisecondsSinceEpoch;
          final newFav = FavoriteLocation(
            id: favId,
            locationName: locationController.text,
            lat: _selectedLatLng!.latitude,
            lon: _selectedLatLng!.longitude,
            timestamp: DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now()),
            aqi: 0, // aqi will be fetched later in the list page.
          );
          Navigator.pop(context, newFav);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(data["error"] ?? "Error saving favorite location.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${response.statusCode}")));
      }
    } catch (e) {
      print("Error saving favorite location: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(
        title:
            Text("Add Favorite Location", style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field with live suggestions
            TextField(
              controller: locationController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Search Location",
                labelStyle: TextStyle(color: textColor),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: widget.isDarkMode
                    ? const Color(0xFF545978)
                    : Colors.grey[200],
              ),
              onChanged: (value) {
                _fetchSuggestions(value);
              },
            ),
            if (_suggestions.isNotEmpty)
              Container(
                color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      title: Text(
                        suggestion['description'] ?? "",
                        style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors.black),
                      ),
                      onTap: () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            // Fallback option: choose location from map
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapSelectionPage(
                      title: "Select Favorite Location",
                      isDarkMode: widget.isDarkMode,
                      googleApiKey: widget.config.googleApiKey,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    locationController.text = result["name"];
                    _selectedLatLng = LatLng(result["lat"], result["lng"]);
                  });
                }
              },
              child: const Text("Select Location from Map"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveFavoriteLocation,
              child: const Text("Save Favorite Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model for FavoriteLocation
class FavoriteLocation {
  final int id;
  final String locationName;
  final double lat;
  final double lon;
  final String timestamp;
  final int aqi;

  FavoriteLocation({
    required this.id,
    required this.locationName,
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.aqi,
  });

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) {
    // Assume the server returns a field "lat_lon" which we'll split
    double lat = 0, lon = 0;
    if (json.containsKey("lat_lon") && json["lat_lon"] is String) {
      final parts = json["lat_lon"].split(",");
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0]) ?? 0;
        lon = double.tryParse(parts[1]) ?? 0;
      }
    }
    return FavoriteLocation(
      id: json["favorite_id"] ?? json["id"],
      locationName: json["location_name"] ?? json["locationName"],
      lat: json["lat"] ?? lat,
      lon: json["lon"] ?? lon,
      timestamp: json["timestamp"] ?? "",
      aqi: json["aqi"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "favorite_id": id,
        "location_name": locationName,
        "lat": lat,
        "lon": lon,
        "timestamp": timestamp,
        "aqi": aqi,
      };
}
