import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'network_service.dart';
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
  bool isDarkMode = true; // default dark mode

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

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
          )
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
            ? const Center(child: CircularProgressIndicator())
            : historyPaths.isEmpty
                ? Center(
                    child: Text(
                      "No History Paths in your account.",
                      style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: historyPaths.length,
                    itemBuilder: (context, index) {
                      final hist = historyPaths[index];
                      return GestureDetector(
                        onTap: () {
                          // Navigate to map with auto-route using the history path
                          Navigator.pushReplacementNamed(context, '/map',
                              arguments: {
                                "origin": {
                                  "lat": hist.startLat,
                                  "lon": hist.startLon
                                },
                                "destination": {
                                  "lat": hist.endLat,
                                  "lon": hist.endLon
                                }
                              });
                        },
                        child: Card(
                          color: isDarkMode
                              ? const Color(0xFF545978)
                              : Colors.white,
                          margin: const EdgeInsets.all(8.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with route and delete button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${hist.startLocation} → ${hist.endLocation}",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Confirm Delete"),
                                            content: const Text(
                                                "Are you sure you want to delete this history path?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteHistoryPath(
                                                      hist.pathId);
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
                                // Display the timestamp
                                Text(
                                  "Logged at: ${formatTimestamp(hist.timestamp)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
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
