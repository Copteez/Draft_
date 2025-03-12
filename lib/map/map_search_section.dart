import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:MySecureMap/map/map_source_dropdown.dart';

class CombinedSearchSection extends StatefulWidget {
  final Function(
    String start,
    String end,
    String travelMode, {
    LatLng? startCoordinates,
    LatLng? endCoordinates,
  }) onSubmit;
  final VoidCallback onUseCurrentLocationForStart;
  final String googleApiKey;
  final bool isDarkMode; // Added parameter

  // For Source and Parameter
  final String selectedSource;
  final List<String> sources;
  final Function(String?) onSourceChanged;
  final String selectedParameter;
  final List<String> parameters;
  final Function(String?) onParameterChanged;

  // New properties
  final bool isRouteLoading;
  final bool markersLoaded;
  final String? userId;
  final LatLng? currentLocation;

  const CombinedSearchSection({
    Key? key,
    required this.onSubmit,
    required this.onUseCurrentLocationForStart,
    required this.googleApiKey,
    required this.selectedSource,
    required this.sources,
    required this.onSourceChanged,
    required this.selectedParameter,
    required this.parameters,
    required this.onParameterChanged,
    required this.isRouteLoading,
    required this.markersLoaded,
    required this.isDarkMode, // Added here
    this.userId,
    this.currentLocation,
  }) : super(key: key);

  @override
  _CombinedSearchSectionState createState() => _CombinedSearchSectionState();
}

class _CombinedSearchSectionState extends State<CombinedSearchSection> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _startSuggestions = [];
  List<Map<String, dynamic>> _endSuggestions = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  bool _startIsCurrentLocation = false;

  String _selectedTravelMode = 'driving';
  final List<String> _travelModes = ['driving', 'walking', 'bicycling'];

  LatLng? _startLatLng;
  LatLng? _endLatLng;

  Future<void> _logSearchQuery(
      String start, String end, String travelMode) async {
    if (widget.userId == null) return;
    final url = Uri.parse(
        'https://3e24-2001-fb1-178-76e-402b-db55-4cab-efc.ngrok-free.app/api/history-search');
    double startLat = _startLatLng?.latitude ??
        ((start.trim().toLowerCase() == "your location" &&
                widget.currentLocation != null)
            ? widget.currentLocation!.latitude
            : 0);
    double startLon = _startLatLng?.longitude ??
        ((start.trim().toLowerCase() == "your location" &&
                widget.currentLocation != null)
            ? widget.currentLocation!.longitude
            : 0);
    double endLat = _endLatLng?.latitude ?? 0;
    double endLon = _endLatLng?.longitude ?? 0;

    try {
      await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": widget.userId,
            "start_location": start,
            "start_lat": startLat,
            "start_lon": startLon,
            "end_location": end,
            "end_lat": endLat,
            "end_lon": endLon,
          }));
    } catch (e) {
      print("Error logging search query: $e");
    }
  }

  void _clearStartInput() {
    setState(() {
      _startController.clear();
      _startLatLng = null;
      _startSuggestions = [];
      _isSearchingStart = false;
    });
  }

  void _clearEndInput() {
    setState(() {
      _endController.clear();
      _endSuggestions = [];
      _isSearchingEnd = false;
      _endLatLng = null;
    });
  }

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
        'components': 'country:th',
        'types': 'establishment',
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
        _scrollToBottom();
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
        'components': 'country:th',
        'types': 'establishment',
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
        _scrollToBottom();
      }
    } catch (e) {
      print("Error fetching end suggestions: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<String> _getPlaceName(String placeId) async {
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': widget.googleApiKey,
        'fields': 'name,formatted_address,geometry'
      },
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        return result['name'] ?? result['formatted_address'] ?? "";
      }
    } catch (e) {
      print("Error fetching place name: $e");
    }
    return "";
  }

  Future<void> _selectStartSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    String placeName = await _getPlaceName(placeId);
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': widget.googleApiKey, 'fields': 'geometry'},
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final location = data['result']['geometry']['location'];
        setState(() {
          _startLatLng = LatLng(location['lat'], location['lng']);
          _startController.text = placeName;
          _startSuggestions = [];
          _isSearchingStart = false;
        });
      }
    } catch (e) {
      print("Error fetching place details for start: $e");
    }
  }

  Future<void> _selectEndSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    String placeName = await _getPlaceName(placeId);
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': widget.googleApiKey, 'fields': 'geometry'},
    );
    try {
      final response = await http.get(detailsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final location = data['result']['geometry']['location'];
        setState(() {
          _endLatLng = LatLng(location['lat'], location['lng']);
          _endController.text = placeName;
          _endSuggestions = [];
          _isSearchingEnd = false;
        });
      }
    } catch (e) {
      print("Error fetching place details for end: $e");
    }
  }

  Future<void> _handleSubmit() async {
    await _logSearchQuery(
        _startController.text, _endController.text, _selectedTravelMode);
    widget.onSubmit(
      _startController.text,
      _endController.text,
      _selectedTravelMode,
      startCoordinates: _startLatLng,
      endCoordinates: _endLatLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the explicit isDarkMode from widget instead of reading from Theme.of(context)
    final bool isDark = widget.isDarkMode;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          color: isDark ? Colors.grey[900] : Colors.white,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Search",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search input fields (moved to top)
                TextField(
                  controller: _startController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Start Location',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.clear,
                              color: isDark ? Colors.white : Colors.black),
                          onPressed: _clearStartInput,
                        ),
                        IconButton(
                          icon: Icon(Icons.my_location,
                              color: isDark ? Colors.white : Colors.black),
                          onPressed: () {
                            widget.onUseCurrentLocationForStart();
                            setState(() {
                              _startController.text = "Your location";
                              _startIsCurrentLocation = true;
                              _startSuggestions = [];
                              _isSearchingStart = false;
                              _startLatLng = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  onChanged: (value) {
                    _fetchStartSuggestions(value);
                  },
                ),
                if (_isSearchingStart && _startSuggestions.isNotEmpty)
                  Container(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _startSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _startSuggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion['description'] ?? "",
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                          ),
                          onTap: () => _selectStartSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _endController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'End Location',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: _clearEndInput,
                    ),
                  ),
                  onChanged: (value) {
                    _fetchEndSuggestions(value);
                  },
                ),
                if (_isSearchingEnd && _endSuggestions.isNotEmpty)
                  Container(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _endSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _endSuggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion['description'] ?? "",
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                          ),
                          onTap: () => _selectEndSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                // Moved Travel type dropdown under End Location field
                Text(
                  "Travel type:",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTravelMode,
                      dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
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
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.isRouteLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff9a72b),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Submit"),
                ),
                const SizedBox(height: 24),
                // Filter Section below search inputs
                Text(
                  "Filter",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sources:",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                MapSourceDropdown(
                  selectedSource: widget.selectedSource,
                  sources: widget.sources,
                  onChanged:
                      widget.markersLoaded ? widget.onSourceChanged : null,
                ),
                const SizedBox(height: 8),
                Text(
                  "Parameter:",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xfff9a72b),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.selectedParameter,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white),
                      dropdownColor: const Color(0xfff9a72b),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: widget.parameters.map((param) {
                        return DropdownMenuItem<String>(
                          value: param,
                          child: Text("Parameter: $param"),
                        );
                      }).toList(),
                      onChanged: widget.markersLoaded
                          ? widget.onParameterChanged
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Note below Filter section
                Text(
                  "Note: Filter settings do not affect path search results.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
