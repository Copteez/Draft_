import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'MapSelectionPage.dart';
import 'theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

class AddFavoriteLocationPage extends StatefulWidget {
  final String googleApiKey;
  const AddFavoriteLocationPage({Key? key, required this.googleApiKey})
      : super(key: key);

  @override
  _AddFavoriteLocationPageState createState() =>
      _AddFavoriteLocationPageState();
}

class _AddFavoriteLocationPageState extends State<AddFavoriteLocationPage> {
  final TextEditingController locationController = TextEditingController();
  List<dynamic> _suggestions = [];
  LatLng? _selectedLatLng;

  @override
  void dispose() {
    locationController.dispose();
    super.dispose();
  }

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
        'key': widget.googleApiKey,
        'components': 'country:th',
      },
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestions = data['predictions'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching suggestions: \$e");
    }
  }

  Future<void> _getLocationFromPlaceId(
      String placeId, String description) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': widget.googleApiKey, 'fields': 'geometry'},
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loc = data['result']['geometry']['location'];
        setState(() {
          _selectedLatLng = LatLng(loc['lat'], loc['lng']);
          locationController.text = description;
          _suggestions = [];
        });
      }
    } catch (e) {
      print("Error fetching place details: \$e");
    }
  }

  Future<void> _saveFavoriteLocation() async {
    if (locationController.text.isEmpty || _selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location")),
      );
      return;
    }

    // Simplified save - just return the location
    final newFav = FavoriteLocation(
      id: DateTime.now().millisecondsSinceEpoch,
      locationName: locationController.text,
      lat: _selectedLatLng!.latitude,
      lon: _selectedLatLng!.longitude,
      timestamp: DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now()),
      aqi: 0,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Favorite location saved successfully")),
    );
    Navigator.pop(context, newFav);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Favorite Location",
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
                  themeProvider.toggleTheme(value);
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
              "Add New Location",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Save your favorite places for quick air quality monitoring",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Location Card
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
                    // Location header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Location Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location input
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
                        controller: locationController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter location name or search...",
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
                          _fetchSuggestions(value);
                        },
                      ),
                    ),

                    // Location suggestions
                    if (_suggestions.isNotEmpty) ...[
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
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: Icon(
                                Icons.location_on,
                                color: Colors.orange,
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
                              onTap: () {
                                _getLocationFromPlaceId(
                                  suggestion['place_id'],
                                  suggestion['description'],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Location action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapSelectionPage(
                                title: "Select Location",
                                isDarkMode: isDarkMode,
                                googleApiKey: widget.googleApiKey,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              locationController.text = result["name"];
                              _selectedLatLng =
                                  LatLng(result["lat"], result["lng"]);
                            });
                          }
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text(
                          "Select from Map",
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

                    // Location preview
                    if (_selectedLatLng != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Location selected: ${_selectedLatLng!.latitude.toStringAsFixed(4)}, ${_selectedLatLng!.longitude.toStringAsFixed(4)}",
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  await _saveFavoriteLocation();
                },
                icon: const Icon(Icons.favorite, size: 24),
                label: const Text(
                  "Save Favorite Location",
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
}
