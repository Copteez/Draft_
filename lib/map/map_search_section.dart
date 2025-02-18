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

  // สำหรับ Source และ Parameter
  final String selectedSource;
  final List<String> sources;
  final Function(String?) onSourceChanged;
  final String selectedParameter;
  final List<String> parameters;
  final Function(String?) onParameterChanged;

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
  }) : super(key: key);

  @override
  _CombinedSearchSectionState createState() => _CombinedSearchSectionState();
}

class _CombinedSearchSectionState extends State<CombinedSearchSection> {
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

  // ควบคุมการแสดง/ซ่อน UI Search
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  /// ดึง autocomplete suggestions สำหรับ Start location (จำกัดให้ในไทย)
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
        // ใช้ 'establishment' เพื่อให้ผลลัพธ์มีรายละเอียดมากขึ้น
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
      }
    } catch (e) {
      print("Error fetching end suggestions: $e");
    }
  }

  /// เมื่อเลือก suggestion สำหรับ Start
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
      }
    } catch (e) {
      print("Error fetching place details for start: $e");
    }
  }

  /// เมื่อเลือก suggestion สำหรับ End
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
      }
    } catch (e) {
      print("Error fetching place details for end: $e");
    }
  }

  void _handleSubmit() {
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ปุ่ม Show/Hide Search
        Align(
          alignment: Alignment.center,
          child: ElevatedButton(
            onPressed: _toggleExpanded,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xfff9a72b),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isExpanded ? "Hide Search" : "Show Search",
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          // Row สำหรับ Source และ Parameter Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              MapSourceDropdown(
                selectedSource: widget.selectedSource,
                sources: widget.sources,
                onChanged: widget.onSourceChanged,
              ),
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
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
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
                    onChanged: widget.onParameterChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ส่วนของ TextField สำหรับ Start location พร้อม autocomplete
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _startController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start location',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.my_location,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
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
                  ),
                  onChanged: (value) {
                    _fetchStartSuggestions(value);
                  },
                ),
                if (_isSearchingStart && _startSuggestions.isNotEmpty)
                  Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _startSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _startSuggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion['description'] ?? "",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          onTap: () => _selectStartSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                // TextField สำหรับ End location พร้อม autocomplete
                TextField(
                  controller: _endController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'End location',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    _fetchEndSuggestions(value);
                  },
                ),
                if (_isSearchingEnd && _endSuggestions.isNotEmpty)
                  Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _endSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _endSuggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion['description'] ?? "",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          onTap: () => _selectEndSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row สำหรับ travel mode และ Submit
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTravelMode,
                        dropdownColor:
                            isDarkMode ? Colors.grey[800] : Colors.white,
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
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff9a72b),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Submit"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
