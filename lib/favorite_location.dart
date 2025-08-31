import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'config.dart';
import 'map.dart';
import 'home_page/widgets/drawer_widget.dart';
// Hide FavoriteLocation class from the Add page to avoid name collision
import 'AddFavoriteLocationPage.dart' hide FavoriteLocation;
import 'package:shared_preferences/shared_preferences.dart';
import 'network_service.dart';
import 'theme_provider.dart';

class FavoriteLocationPage extends StatefulWidget {
  final AppConfig config;
  const FavoriteLocationPage({Key? key, required this.config})
      : super(key: key);

  @override
  _FavoriteLocationPageState createState() => _FavoriteLocationPageState();
}

class _FavoriteLocationPageState extends State<FavoriteLocationPage> {
  List<FavoriteLocation> favoriteLocations = [];
  int? userId;
  String? _baseUrl;

  // Cache AQI data to prevent refetching on theme changes
  final Map<String, Map<String, dynamic>?> _aqiCache = {};

  @override
  void initState() {
    super.initState();
    _initBaseUrlAndLoad();
  }

  Future<void> _initBaseUrlAndLoad() async {
    final service = NetworkService(config: widget.config);
    final url = await service.getEffectiveBaseUrl();
    setState(() => _baseUrl = url);
    await _loadFavoriteLocations();
  }

  Future<void> _loadFavoriteLocations() async {
    // Clear AQI cache when loading new locations
    _aqiCache.clear();

    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id");
    if (userId == null || _baseUrl == null) return;
    final url = Uri.parse("$_baseUrl/api/favorite-locations?user_id=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["favorite_locations"] is List) {
          setState(() {
            favoriteLocations = (data["favorite_locations"] as List)
                .map((json) => FavoriteLocation.fromJson(json))
                .toList();
          });
        }
      }
    } catch (e) {
      print("Error loading favorite locations: $e");
    }
  }

  Future<Map<String, dynamic>?> _fetchAQIForLocation(
      FavoriteLocation fav) async {
    final cacheKey = "${fav.lat},${fav.lon}";

    // Return cached data if available
    if (_aqiCache.containsKey(cacheKey)) {
      return _aqiCache[cacheKey];
    }

    final base = _baseUrl ?? widget.config.ngrok;
    final url = Uri.parse("$base/api/nearest-station-aqi");
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(
              {"latitude": fav.lat, "longitude": fav.lon, "source": "All"}));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          final result = data["nearest_station"];
          // Cache the result
          _aqiCache[cacheKey] = result;
          return result;
        }
      }
    } catch (e) {
      print("Error fetching AQI for location: $e");
    }

    // Cache null result to prevent repeated failed requests
    _aqiCache[cacheKey] = null;
    return null;
  }

  Future<void> _deleteFavoriteLocation(int favId) async {
    if (userId == null) return;
    if (_baseUrl == null) return;
    final url = Uri.parse("$_baseUrl/api/favorite-locations");
    try {
      final response = await http.delete(url,
          headers: {"Content-Type": "application/json"},
          // Server expects 'location_id' (not 'favorite_id')
          body: jsonEncode({"user_id": userId, "location_id": favId}));
      if (response.statusCode == 200) {
        // Clear AQI cache when deleting location
        _aqiCache.clear();
        await _loadFavoriteLocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: ${response.body}")));
      }
    } catch (e) {
      print("Error deleting favorite location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final bool isDarkMode = themeProvider.isDarkMode;

        final backgroundColor =
            isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final iconColor = isDarkMode ? Colors.white : Colors.black;

        return _buildScaffold(
            isDarkMode, backgroundColor, textColor, iconColor);
      },
    );
  }

  Widget _buildScaffold(bool isDarkMode, Color backgroundColor, Color textColor,
      Color iconColor) {
    return Scaffold(
      drawer: buildDrawer(context: context, isDarkMode: isDarkMode),
      appBar: AppBar(
        title: Text("Favorite Locations",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Row(
            children: [
              Icon(
                isDarkMode
                    ? CupertinoIcons.moon_fill
                    : CupertinoIcons.sun_max_fill,
                color: iconColor,
                size: 24,
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) => Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .toggleTheme(value);
                  },
                  activeColor: Colors.orange,
                  inactiveThumbColor: Colors.grey,
                  activeTrackColor: Colors.orange.withOpacity(0.5),
                  inactiveTrackColor: Colors.grey.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadFavoriteLocations,
        child: favoriteLocations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: Colors.orange.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "No Favorite Locations",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Start by adding your first favorite location\nto quickly check air quality",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddFavoriteLocationPage(config: widget.config),
                          ),
                        );
                        if (result != null) {
                          await _loadFavoriteLocations();
                        }
                      },
                      icon: const Icon(Icons.add_location, color: Colors.white),
                      label: const Text(
                        "Add Location",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: favoriteLocations.length,
                itemBuilder: (context, index) {
                  final fav = favoriteLocations[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapPage(
                            config: widget.config,
                            initialLat: fav.lat,
                            initialLon: fav.lon,
                            locationName: fav.locationName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDarkMode
                              ? [
                                  const Color(0xFF545978),
                                  const Color(0xFF3E4961)
                                ]
                              : [Colors.white, const Color(0xFFF8F9FA)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with location name and menu
                              Row(
                                children: [
                                  // Location icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Location name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fav.locationName,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Tap to view on map",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete button
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: isDarkMode
                                                ? const Color(0xFF2C2C47)
                                                : Colors.white,
                                            title: Text(
                                              "Remove Location",
                                              style:
                                                  TextStyle(color: textColor),
                                            ),
                                            content: Text(
                                              "Are you sure you want to remove this favorite location?",
                                              style:
                                                  TextStyle(color: textColor),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: Text(
                                                  "Cancel",
                                                  style: TextStyle(
                                                      color: Colors.grey[600]),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteFavoriteLocation(
                                                      fav.id);
                                                },
                                                child: const Text(
                                                  "Remove",
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline,
                                                color: Colors.red, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Remove',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // AQI Information Section
                              FutureBuilder<Map<String, dynamic>?>(
                                future: _fetchAQIForLocation(fav),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      height: 80,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? const Color(0xFF444C63)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "AQI data unavailable",
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final aqiData = snapshot.data!;
                                  final aqi = aqiData["aqi"] as int;
                                  final aqiColor = _getAQIColor(aqi);

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? const Color(0xFF444C63)
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: aqiColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // AQI Circle Badge
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: aqiColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: aqiColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "$aqi",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: aqiColor,
                                                ),
                                              ),
                                              Text(
                                                "AQI",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: aqiColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 16),

                                        // AQI Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: aqiColor
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      _getAQILabel(aqi),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: aqiColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Station: ${aqiData["station_name"]}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDarkMode
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _getAQIRecommendation(aqi),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: textColor,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddFavoriteLocationPage(config: widget.config),
              ),
            );
            if (result != null) {
              await _loadFavoriteLocations();
            }
          },
          icon: const Icon(Icons.add_location),
          label: const Text(
            "Add Location",
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Color _getAQIColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  String _getAQILabel(int aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive Groups";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }

  String _getAQIRecommendation(int aqi) {
    if (aqi <= 50) {
      return "Perfect for outdoor activities!";
    } else if (aqi <= 100) {
      return "Acceptable for most people";
    } else if (aqi <= 150) {
      return "Sensitive groups should be cautious";
    } else if (aqi <= 200) {
      return "Consider limiting outdoor time";
    } else if (aqi <= 300) {
      return "Avoid prolonged outdoor exposure";
    } else {
      return "Stay indoors if possible";
    }
  }
}

// Model for FavoriteLocation based on favorite_locations endpoint
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
    // Expect fields: favorite_id, location_name, lat_lon ("lat,lon")
    double lat = (json["lat"] is num) ? (json["lat"] as num).toDouble() : 0;
    double lon = (json["lon"] is num) ? (json["lon"] as num).toDouble() : 0;
    if ((lat == 0 || lon == 0) &&
        json.containsKey("lat_lon") &&
        json["lat_lon"] is String) {
      final parts = (json["lat_lon"] as String).split(",");
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0]) ?? lat;
        lon = double.tryParse(parts[1]) ?? lon;
      }
    }
    return FavoriteLocation(
      id: json["location_id"] ?? json["favorite_id"] ?? json["id"] ?? 0,
      locationName: json["location_name"] ?? json["locationName"] ?? "",
      lat: lat,
      lon: lon,
      timestamp: json["timestamp"]?.toString() ?? "",
      aqi: (json["aqi"] is num) ? (json["aqi"] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "location_id": id,
        "location_name": locationName,
        "lat": lat,
        "lon": lon,
        "timestamp": timestamp,
        "aqi": aqi,
      };
}
