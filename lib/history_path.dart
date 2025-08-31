import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'network_service.dart';
import 'theme_provider.dart';
import 'package:MySecureMap/home_page/widgets/drawer_widget.dart';
import 'aqi_card.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class HistoryPathPage extends StatefulWidget {
  final AppConfig config;
  const HistoryPathPage({Key? key, required this.config}) : super(key: key);

  @override
  _HistoryPathPageState createState() => _HistoryPathPageState();
}

class _HistoryPathPageState extends State<HistoryPathPage> {
  bool isLoading = true;
  List<HistoryPath> historyPaths = [];
  int? userId;
  late final NetworkService networkService;

  // Cache AQI data to prevent refetching on theme changes
  final Map<String, List<int?>> _aqiCache = {};

  // ฟังก์ชันดึงค่า AQI ปัจจุบันจาก API สำหรับพิกัดที่กำหนด
  Future<int?> fetchCurrentAQI(double lat, double lon) async {
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = Uri.parse("$effectiveBaseUrl/api/nearest-station-aqi");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "latitude": lat,
        "longitude": lon,
        "source": "All",
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["nearest_station"]["aqi"];
    }
    return null;
  }

  // ฟังก์ชันแปลงค่า AQI เป็นสี
  Color getAQIColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return const Color(0xFFF8D461); // Match map yellow color
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  // ฟังก์ชันแปลงค่า AQI เป็น label
  String getAQILabel(int aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive Groups";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }

  // ฟังก์ชัน recommendation แนะนำข้อความตามค่า AQI ทั้งสอง
  String getRecommendation(int startAqi, int endAqi) {
    if (startAqi - endAqi >= 20) {
      return "Air quality improved during the journey.";
    } else if (endAqi - startAqi >= 20) {
      return "Air quality worsened during the journey.";
    } else {
      return "Air quality was relatively stable along the route.";
    }
  }

  // ดึงค่า AQI ทั้ง start และ end พร้อมกัน (with caching)
  Future<List<int?>> _fetchBothAQI(
      double startLat, double startLon, double endLat, double endLon) async {
    String cacheKey = "${startLat}_${startLon}_${endLat}_${endLon}";
    if (_aqiCache.containsKey(cacheKey)) {
      return _aqiCache[cacheKey]!;
    }

    List<int?> result = await Future.wait([
      fetchCurrentAQI(startLat, startLon),
      fetchCurrentAQI(endLat, endLon),
    ]);
    _aqiCache[cacheKey] = result;
    return result;
  }

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    _loadUserIdAndFetchData();
  }

  Future<void> _loadUserIdAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id");
    if (userId != null) {
      fetchHistoryPaths(userId!);
    } else {
      setState(() {
        historyPaths = [];
        isLoading = false;
      });
    }
  }

  // Fetch history paths from the server (assuming a GET endpoint exists)
  Future<void> fetchHistoryPaths(int userId) async {
    setState(() {
      isLoading = true;
    });
    final baseUrl =
        await NetworkService(config: widget.config).getEffectiveBaseUrl();
    final url = Uri.parse("$baseUrl/api/history-paths?user_id=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data["success"] == true && data["history_paths"] != null) {
          List<HistoryPath> fetchedPaths = (data["history_paths"] as List)
              .map((item) => HistoryPath.fromJson(item))
              .toList();
          setState(() {
            historyPaths = fetchedPaths;
            isLoading = false;
          });
          return;
        }
      }
      setState(() {
        historyPaths = [];
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching history paths: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Delete a history path record
  Future<void> _deleteHistoryPath(int historyPathId) async {
    final baseUrl =
        await NetworkService(config: widget.config).getEffectiveBaseUrl();
    final url = Uri.parse("$baseUrl/api/history-paths");
    try {
      final response = await http.delete(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "path_id": historyPathId}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Deleted successfully")));
        if (userId != null) {
          fetchHistoryPaths(userId!);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Format the timestamp into a readable format.
  String formatTimestamp(String timestamp) {
    try {
      // Attempt to parse the HTTP-date string.
      DateTime dt = HttpDate.parse(timestamp).toLocal();
      return DateFormat("dd/MM/yyyy HH:mm", "th").format(dt);
    } catch (e) {
      print("Timestamp parsing error: $e");
      // Fallback: Remove "GMT" and return the rest of the string.
      String cleaned = timestamp.replaceAll("GMT", "").trim();
      // Optionally, you can do additional formatting here.
      return cleaned;
    }
  }

  Widget _buildHistoryPathCard(HistoryPath hist, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        // Navigate to map with auto-route using the history path
        Navigator.pushReplacementNamed(context, '/map', arguments: {
          "origin": {"lat": hist.startLat, "lon": hist.startLon},
          "destination": {"lat": hist.endLat, "lon": hist.endLon}
        });
      },
      child: FutureBuilder<List<int?>>(
        future: _fetchBothAQI(
            hist.startLat, hist.startLon, hist.endLat, hist.endLon),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Card(
                color: isDarkMode ? const Color(0xFF545978) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Card(
                color: isDarkMode ? const Color(0xFF545978) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        "Unable to load AQI data",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final aqiList = snapshot.data!;
          final startAqi = aqiList[0] ?? 0;
          final endAqi = aqiList[1] ?? 0;
          final recommendation = getRecommendation(startAqi, endAqi);

          // Modern gradient card design
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Card(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [const Color(0xFF545978), const Color(0xFF444C63)]
                        : [Colors.white, Colors.grey.shade50],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with route icon and menu
                      Row(
                        children: [
                          // History icon badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.history,
                                color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          // Route title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Search History",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Split the route into separate lines for better readability
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 12, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            hist.startLocation,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 12, color: Colors.red),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            hist.endLocation,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Menu button
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: isDarkMode
                                  ? Colors.grey[300]
                                  : Colors.grey[600],
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    title: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        const SizedBox(width: 8),
                                        const Text("Delete History"),
                                      ],
                                    ),
                                    content: const Text(
                                      "Are you sure you want to remove this search history?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text("Cancel",
                                            style: TextStyle(
                                                color: Colors.grey[600])),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteHistoryPath(hist.pathId);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete History'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AQI comparison section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Start and End AQI
                            Row(
                              children: [
                                // Start AQI
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        "Start",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: getAQIColor(startAqi),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                              color: getAQIColor(startAqi),
                                              width: 3),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "$startAqi",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: getAQIColor(startAqi)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          getAQILabel(startAqi),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: getAQIColor(startAqi),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Arrow
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black54,
                                    size: 20,
                                  ),
                                ),

                                // End AQI
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        "End",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: getAQIColor(endAqi),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                              color: getAQIColor(endAqi),
                                              width: 3),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "$endAqi",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: getAQIColor(endAqi)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          getAQILabel(endAqi),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: getAQIColor(endAqi),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Recommendation text
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      recommendation,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.blue[300]
                                            : Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Timestamp
                            Text(
                              "Searched at: ${formatTimestamp(hist.timestamp)}",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme from provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      drawer: buildDrawer(context: context, isDarkMode: isDarkMode),
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        title: Text(
          "History Paths",
          style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        actions: [
          Row(
            children: [
              Icon(
                isDarkMode
                    ? CupertinoIcons.moon_fill
                    : CupertinoIcons.sun_max_fill,
                color: isDarkMode ? Colors.white : Colors.black,
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
      backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          if (userId != null) {
            await fetchHistoryPaths(userId!);
          }
        },
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ))
            : historyPaths.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 80,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No Search History",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your route search history will appear here",
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: historyPaths.length,
                    itemBuilder: (context, index) {
                      final hist = historyPaths[index];
                      return _buildHistoryPathCard(hist, isDarkMode);
                    },
                  ),
      ),
    );
  }
}

// Model class for HistoryPath
class HistoryPath {
  final int pathId;
  final String startLocation;
  final String endLocation;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String timestamp; // timestamp when history was recorded

  HistoryPath({
    required this.pathId,
    required this.startLocation,
    required this.endLocation,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.timestamp,
  });

  factory HistoryPath.fromJson(Map<String, dynamic> json) {
    // Parse start_lat_lon and end_lat_lon strings into doubles.
    String startLatLon = json["start_lat_lon"] ?? "0,0";
    List<String> startParts = startLatLon.split(",");
    double sLat = double.tryParse(startParts[0]) ?? 0.0;
    double sLon =
        startParts.length > 1 ? double.tryParse(startParts[1]) ?? 0.0 : 0.0;

    String endLatLon = json["end_lat_lon"] ?? "0,0";
    List<String> endParts = endLatLon.split(",");
    double eLat = double.tryParse(endParts[0]) ?? 0.0;
    double eLon =
        endParts.length > 1 ? double.tryParse(endParts[1]) ?? 0.0 : 0.0;

    return HistoryPath(
      pathId: json["path_id"],
      startLocation: json["start_location"],
      endLocation: json["end_location"],
      startLat: sLat,
      startLon: sLon,
      endLat: eLat,
      endLon: eLon,
      timestamp: json["timestamp"] ?? "",
    );
  }
}
