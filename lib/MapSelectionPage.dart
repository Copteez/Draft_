import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'map/map_theme.dart';

class MapSelectionPage extends StatefulWidget {
  final String title;
  final bool isDarkMode;
  final String googleApiKey;
  const MapSelectionPage({
    Key? key,
    required this.title,
    required this.isDarkMode,
    required this.googleApiKey,
  }) : super(key: key);

  @override
  _MapSelectionPageState createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage> {
  GoogleMapController? _mapController;
  // เริ่มต้นตำแหน่งที่กรุงเทพฯ
  LatLng _initialPosition = const LatLng(13.7563, 100.5018);
  LatLng? _selectedPosition;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  bool _isSearching = false;

  // ----------------------------------------------------------------------
  // ฟังก์ชันค้นหาสถานที่จาก Google Places Autocomplete API
  // ----------------------------------------------------------------------
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
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
          _isSearching = true;
        });
      }
    } catch (e) {
      print("Error searching places: $e");
    }
  }

  // ----------------------------------------------------------------------
  // ฟังก์ชันดึงรายละเอียดสถานที่โดยใช้ place_id จาก Google Places Details API
  // ----------------------------------------------------------------------
  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.googleApiKey,
        'fields': 'name,geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'];
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
    return null;
  }

  // ----------------------------------------------------------------------
  // ฟังก์ชัน reverse geocode: เปลี่ยนพิกัดเป็นชื่อสถานที่
  // ----------------------------------------------------------------------
  Future<String> _getPlaceNameFromCoordinates(LatLng position) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${position.latitude},${position.longitude}',
        'key': widget.googleApiKey,
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
        title: Text(
          widget.title,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        iconTheme: IconThemeData(
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: Stack(
        children: [
          // แผนที่ Google Map
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _initialPosition, zoom: 14),
            onMapCreated: (controller) {
              _mapController = controller;
              // Apply dark/light map theme based on theme setting
              _mapController!.setMapStyle(
                  widget.isDarkMode ? darkMapStyle : lightMapStyle);
            },
            onTap: (position) async {
              // Get location name before showing confirmation dialog
              final placeName = await _getPlaceNameFromCoordinates(position);

              // Show confirmation dialog with location name
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: widget.isDarkMode
                        ? const Color(0xFF3C4055)
                        : Colors.white,
                    title: Text(
                      "Confirm Location",
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      "Are you sure you want to select this location?\n\n📍 $placeName\n\nLatitude: ${position.latitude.toStringAsFixed(6)}\nLongitude: ${position.longitude.toStringAsFixed(6)}",
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Confirm"),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true) {
                // User confirmed, return with location data
                Navigator.pop(context, {
                  "name": placeName,
                  "lat": position.latitude,
                  "lng": position.longitude,
                });
              }
            },
            markers: _selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId("selected"),
                      position: _selectedPosition!,
                    )
                  }
                : {},
          ),
          // ส่วน overlay สำหรับแสดง search field และ suggestion list
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search location",
                      hintStyle: TextStyle(
                        color:
                            widget.isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(8),
                    ),
                    onChanged: _searchPlaces,
                  ),
                ),
                if (_isSearching && _suggestions.isNotEmpty)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color:
                          widget.isDarkMode ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion['description'] ?? "",
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          onTap: () async {
                            final details =
                                await _getPlaceDetails(suggestion['place_id']);
                            if (details != null) {
                              // Show confirmation dialog with location name
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: widget.isDarkMode
                                        ? const Color(0xFF3C4055)
                                        : Colors.white,
                                    title: Text(
                                      "Confirm Location",
                                      style: TextStyle(
                                        color: widget.isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      "Are you sure you want to select this location?\n\n📍 ${details['name']}\n\nLatitude: ${details['geometry']['location']['lat'].toStringAsFixed(6)}\nLongitude: ${details['geometry']['location']['lng'].toStringAsFixed(6)}",
                                      style: TextStyle(
                                        color: widget.isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(
                                          "Cancel",
                                          style: TextStyle(
                                            color: widget.isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text("Confirm"),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed == true) {
                                Navigator.pop(context, {
                                  "name": details['name'],
                                  "lat": details['geometry']['location']['lat'],
                                  "lng": details['geometry']['location']['lng'],
                                });
                              }
                            }
                          },
                        );
                      },
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
      // ปุ่ม floating action button สำหรับยืนยันเลือกสถานที่
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_selectedPosition != null) {
            // Get location name before showing confirmation dialog
            final placeName =
                await _getPlaceNameFromCoordinates(_selectedPosition!);

            // Show confirmation dialog with location name
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF3C4055)
                      : Colors.white,
                  title: Text(
                    "Confirm Location",
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    "Are you sure you want to confirm this location?\n\n📍 $placeName\n\nLatitude: ${_selectedPosition!.latitude.toStringAsFixed(6)}\nLongitude: ${_selectedPosition!.longitude.toStringAsFixed(6)}",
                    style: TextStyle(
                      color: widget.isDarkMode
                          ? Colors.grey[300]
                          : Colors.grey[700],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Confirm"),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true) {
              Navigator.pop(context, {
                "name": placeName,
                "lat": _selectedPosition!.latitude,
                "lng": _selectedPosition!.longitude,
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please select a location")),
            );
          }
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}
