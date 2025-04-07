import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'map.dart';
import 'home_page/widgets/drawer_widget.dart';
import 'AddFavoriteLocationPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteLocationPage extends StatefulWidget {
  final AppConfig config;
  const FavoriteLocationPage({Key? key, required this.config})
      : super(key: key);

  @override
  _FavoriteLocationPageState createState() => _FavoriteLocationPageState();
}

class _FavoriteLocationPageState extends State<FavoriteLocationPage> {
  bool isDarkMode = true;
  List<FavoriteLocation> favoriteLocations = [];
  int? userId;

  @override
  void initState() {
    super.initState();
    _loadFavoriteLocations();
  }

  Future<void> _loadFavoriteLocations() async {
    // Instead of calling /api/favorite-locations, we call /api/favorite-paths
    // since your table (favorite_path) doesn’t have a favorite_id column.
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id");
    if (userId == null) return;
    final url =
        Uri.parse("${widget.config.ngrok}/api/favorite-paths?user_id=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() {
            favoriteLocations = (data["favorite_paths"] as List)
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
    final url = Uri.parse("${widget.config.ngrok}/api/nearest-station-aqi");
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(
              {"latitude": fav.lat, "longitude": fav.lon, "source": "All"}));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          return data["nearest_station"];
        }
      }
    } catch (e) {
      print("Error fetching AQI for location: $e");
    }
    return null;
  }

  Future<void> _deleteFavoriteLocation(int favId) async {
    if (userId == null) return;
    // Call the favorite paths DELETE endpoint since we're using that table.
    final url = Uri.parse("${widget.config.ngrok}/api/favorite-paths");
    try {
      final response = await http.delete(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"user_id": userId, "path_id": favId}));
      if (response.statusCode == 200) {
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
    final backgroundColor = isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF545978) : Colors.white;
    final iconColor = isDarkMode ? Colors.white : Colors.black;

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
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: iconColor),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
          )
        ],
      ),
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadFavoriteLocations,
        child: favoriteLocations.isEmpty
            ? Center(
                child: Text(
                  "No favorite locations added.",
                  style: TextStyle(
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
              )
            : ListView.builder(
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
                    child: Card(
                      color: cardColor,
                      margin: const EdgeInsets.all(8.0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    fav.locationName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Confirm Delete"),
                                        content: const Text(
                                            "Are you sure you want to delete this favorite location?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _deleteFavoriteLocation(fav.id);
                                            },
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Air Quality Index",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _fetchAQIForLocation(fav),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError || !snapshot.hasData) {
                                  return Text("AQI not available",
                                      style: TextStyle(color: textColor));
                                }
                                final aqiData = snapshot.data!;
                                final aqi = aqiData["aqi"] as int;
                                return Column(
                                  children: [
                                    Text(
                                      "$aqi",
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: _getAQIColor(aqi),
                                      ),
                                    ),
                                    Text(
                                      _getAQILabel(aqi),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _getAQIColor(aqi),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? const Color(0xFF444C63)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            "Station: ${aqiData["station_name"]}",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            _getAQIRecommendation(aqi),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFavoriteLocationPage(
                  config: widget.config, isDarkMode: isDarkMode),
            ),
          );
          if (result != null) {
            await _loadFavoriteLocations();
          }
        },
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
      return "Air quality is good. Perfect for outdoor activities!";
    } else if (aqi <= 100) {
      return "Air quality is acceptable. Sensitive individuals should limit prolonged outdoor exposure.";
    } else if (aqi <= 150) {
      return "Members of sensitive groups may experience health effects.";
    } else if (aqi <= 200) {
      return "Everyone may begin to experience health effects.";
    } else if (aqi <= 300) {
      return "Health alert: everyone may experience more serious health effects.";
    } else {
      return "Health warnings of emergency conditions. Entire population is likely to be affected.";
    }
  }
}

// Model for FavoriteLocation based on favorite_path table
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
    // Here we assume the server returns start_location and start_lat_lon for favorite paths.
    double lat = 0, lon = 0;
    if (json.containsKey("start_lat_lon") && json["start_lat_lon"] is String) {
      final parts = json["start_lat_lon"].split(",");
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0]) ?? 0;
        lon = double.tryParse(parts[1]) ?? 0;
      }
    }
    return FavoriteLocation(
      id: json["path_id"], // using path_id as the id
      locationName: json["start_location"],
      lat: json["lat"] ?? lat,
      lon: json["lon"] ?? lon,
      timestamp: json["timestamp"] ?? "",
      aqi: json["aqi"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "path_id": id,
        "location_name": locationName,
        "lat": lat,
        "lon": lon,
        "timestamp": timestamp,
        "aqi": aqi,
      };
}
