import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteCalculation {
  final String stationName;
  final double startDistance;
  final double endDistance;
  final int aqi;

  RouteCalculation({
    required this.stationName,
    required this.startDistance,
    required this.endDistance,
    required this.aqi,
  });
}

class RouteOption {
  final int routeIndex;
  final double avgAqi;
  final List<RouteCalculation> calculations;
  final bool isSafest;
  final int displayIndex; // Add this field

  RouteOption({
    required this.routeIndex,
    required this.avgAqi,
    required this.calculations,
    this.isSafest = false,
    required this.displayIndex,
  });
}

class MapSearchSection extends StatefulWidget {
  final Function(
    String start,
    String end,
    String travelMode, {
    LatLng? startCoordinates,
    LatLng? endCoordinates,
  }) onSubmit;
  final Function(int) onRouteSelected;
  final List<RouteOption> routeOptions;
  final bool isDarkMode;
  final String googleApiKey;
  final LatLng? currentLocation;
  final bool isRouteLoading;
  final Color backgroundColor; // Add this property
  final int selectedRouteIndex; // Add this line

  const MapSearchSection({
    Key? key,
    required this.onSubmit,
    required this.onRouteSelected,
    required this.routeOptions,
    required this.isDarkMode,
    required this.googleApiKey,
    this.currentLocation,
    required this.isRouteLoading,
    this.backgroundColor = const Color(0xFF2D3250), // Set default color
    required this.selectedRouteIndex, // Add this line
  }) : super(key: key);

  @override
  _MapSearchSectionState createState() => _MapSearchSectionState();
}

class _MapSearchSectionState extends State<MapSearchSection> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final List<String> _travelModes = ['driving', 'walking', 'bicycling'];
  String _selectedTravelMode = 'driving';

  List<Map<String, dynamic>> _startSuggestions = [];
  List<Map<String, dynamic>> _endSuggestions = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  Map<int, bool> _expandedStates = {};

  LatLng? _startLatLng;
  LatLng? _endLatLng;

  Future<void> _fetchPlaceSuggestions(String query, bool isStart) async {
    if (query.isEmpty) {
      setState(() {
        if (isStart) {
          _startSuggestions = [];
          _isSearchingStart = false;
        } else {
          _endSuggestions = [];
          _isSearchingEnd = false;
        }
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
        'types': 'establishment',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (isStart) {
            _startSuggestions =
                List<Map<String, dynamic>>.from(data['predictions']);
            _isSearchingStart = true;
          } else {
            _endSuggestions =
                List<Map<String, dynamic>>.from(data['predictions']);
            _isSearchingEnd = true;
          }
        });
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    }
  }

  Future<LatLng?> _getPlaceLatLng(String placeId) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': widget.googleApiKey, 'fields': 'geometry'},
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final location = data['result']['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
    return null;
  }

  String _getAqiLevel(double aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive Groups";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }

  Color _getAqiColor(double aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  Widget _buildRouteOptionCard(RouteOption option) {
    final isSelected =
        option.routeIndex == widget.selectedRouteIndex; // Add this line

    return Card(
      color: widget.isDarkMode ? widget.backgroundColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Add border to highlight selected route
        side: BorderSide(
          color: isSelected
              ? const Color(0xfff9a72b)
              : Colors.transparent, // Update this line
          width: 2,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "Route ${option.displayIndex + 1}",
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (option.isSafest)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          "👍",
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _expandedStates[option.routeIndex] == true
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _expandedStates[option.routeIndex] =
                          !(_expandedStates[option.routeIndex] ?? false);
                    });
                  },
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Average AQI: ${option.avgAqi.toStringAsFixed(1)}",
                  style: TextStyle(
                    color: _getAqiColor(option.avgAqi),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getAqiLevel(option.avgAqi),
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  "Total Distance: ${option.calculations.isNotEmpty ? option.calculations.last.endDistance.toStringAsFixed(1) : '0'} km",
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton(
                    onPressed: () => widget.onRouteSelected(option.routeIndex),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected // Update this line
                          ? const Color(0xfff9a72b)
                          : Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Select This Route",
                      style: TextStyle(
                        color:
                            Colors.white, // Ensure text is white in all modes
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_expandedStates[option.routeIndex] == true)
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.black12 : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      "Route Details:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: option.calculations.length,
                    itemBuilder: (context, index) {
                      final calc = option.calculations[index];

                      // Check if user is within this segment's distance range
                      bool isUserInSegment = false;
                      if (widget.currentLocation != null) {
                        // Get the nearest point on the route to user's location
                        double distanceAlongRoute =
                            0; // Calculate distance along route
                        // You would need to implement logic to calculate actual distance along route
                        // For now, we'll use a simple check
                        isUserInSegment =
                            distanceAlongRoute >= calc.startDistance &&
                                distanceAlongRoute <= calc.endDistance;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          border: index < option.calculations.length - 1
                              ? Border(
                                  bottom: BorderSide(
                                    color: widget.isDarkMode
                                        ? Colors.grey[800]!
                                        : Colors.grey[300]!,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Remove the Row with triangle pointer and replace with direct Text
                            Text(
                              calc.stationName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${calc.startDistance.toStringAsFixed(1)} - ${calc.endDistance.toStringAsFixed(1)} km",
                                  style: TextStyle(
                                    color: widget.isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getAqiColor(calc.aqi.toDouble())
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "AQI: ${calc.aqi}",
                                    style: TextStyle(
                                      color: _getAqiColor(calc.aqi.toDouble()),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final borderColor = widget.isDarkMode ? Colors.grey[600] : Colors.grey[300];
    final hintTextColor =
        widget.isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Material(
      color: Colors.transparent,
      child: Container(
        color: widget.isDarkMode ? widget.backgroundColor : Colors.white,
        child: SafeArea(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            color: widget.isDarkMode ? widget.backgroundColor : Colors.white,
            child: Column(
              children: [
                AppBar(
                  backgroundColor:
                      widget.isDarkMode ? widget.backgroundColor : Colors.white,
                  elevation: 0,
                  title: Text(
                    "Route Search",
                    style: TextStyle(color: textColor),
                  ),
                  automaticallyImplyLeading:
                      false, // Add this to remove default back button
                  actions: [
                    IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _startController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Start Location',
                          hintStyle: TextStyle(color: hintTextColor),
                          labelStyle: TextStyle(color: textColor),
                          filled: true,
                          fillColor: widget.isDarkMode
                              ? widget.backgroundColor
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: widget.isDarkMode
                                    ? Colors.orange
                                    : Colors.blue),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_startController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.clear,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                  onPressed: () {
                                    setState(() {
                                      _startController.clear();
                                      _startLatLng = null;
                                      _startSuggestions = [];
                                      _isSearchingStart = false;
                                    });
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.my_location,
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black),
                                onPressed: () {
                                  if (widget.currentLocation != null) {
                                    setState(() {
                                      _startController.text = "Your Location";
                                      _startLatLng = widget.currentLocation;
                                      _startSuggestions = [];
                                      _isSearchingStart = false;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) =>
                            _fetchPlaceSuggestions(value, true),
                      ),
                      if (_isSearchingStart) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _startSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _startSuggestions[index];
                              return ListTile(
                                title: Text(
                                  suggestion['description'],
                                  style: TextStyle(
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                onTap: () async {
                                  final latLng = await _getPlaceLatLng(
                                      suggestion['place_id']);
                                  if (latLng != null) {
                                    setState(() {
                                      _startController.text =
                                          suggestion['description'];
                                      _startLatLng = latLng;
                                      _startSuggestions = [];
                                      _isSearchingStart = false;
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _endController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'End Location',
                          hintStyle: TextStyle(color: hintTextColor),
                          labelStyle: TextStyle(color: textColor),
                          filled: true,
                          fillColor: widget.isDarkMode
                              ? widget.backgroundColor
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: widget.isDarkMode
                                    ? Colors.orange
                                    : Colors.blue),
                          ),
                          suffixIcon: _endController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                  onPressed: () {
                                    setState(() {
                                      _endController.clear();
                                      _endLatLng = null;
                                      _endSuggestions = [];
                                      _isSearchingEnd = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) =>
                            _fetchPlaceSuggestions(value, false),
                      ),
                      if (_isSearchingEnd) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _endSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _endSuggestions[index];
                              return ListTile(
                                title: Text(
                                  suggestion['description'],
                                  style: TextStyle(
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                onTap: () async {
                                  final latLng = await _getPlaceLatLng(
                                      suggestion['place_id']);
                                  if (latLng != null) {
                                    setState(() {
                                      _endController.text =
                                          suggestion['description'];
                                      _endLatLng = latLng;
                                      _endSuggestions = [];
                                      _isSearchingEnd = false;
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? widget.backgroundColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTravelMode,
                            isExpanded: true,
                            dropdownColor: widget.isDarkMode
                                ? widget.backgroundColor
                                : Colors.white,
                            style: TextStyle(color: textColor),
                            items: _travelModes.map((mode) {
                              return DropdownMenuItem(
                                value: mode,
                                child: Text(mode),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedTravelMode = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: widget.isRouteLoading
                            ? null
                            : () {
                                // Include location names when submitting the route query
                                String startLocationName =
                                    _startController.text;
                                String endLocationName = _endController.text;

                                widget.onSubmit(
                                  startLocationName,
                                  endLocationName,
                                  _selectedTravelMode,
                                  startCoordinates: _startLatLng,
                                  endCoordinates: _endLatLng,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xfff9a72b),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: widget.isRouteLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                "Search Route",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white, // Ensure text is white
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.routeOptions.isNotEmpty) ...[
                        Text(
                          "Available Routes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                widget.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // No need to sort here as routes are already sorted
                        ...widget.routeOptions
                            .map((option) => _buildRouteOptionCard(option)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Update TrianglePointer to point right instead of left
class TrianglePointer extends CustomPainter {
  final Color color;

  TrianglePointer({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height / 2)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
