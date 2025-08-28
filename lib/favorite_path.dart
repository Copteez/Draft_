import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'network_service.dart';
import 'AddFavoritePathPage.dart';
import 'map.dart';
import 'package:MySecureMap/home_page/widgets/drawer_widget.dart';

class FavoritePathPage extends StatefulWidget {
  final AppConfig config;
  const FavoritePathPage({Key? key, required this.config}) : super(key: key);

  @override
  _FavoritePathPageState createState() => _FavoritePathPageState();
}

class _FavoritePathPageState extends State<FavoritePathPage> {
  bool isLoading = true;
  List<FavoritePath> favoritePaths = [];
  int? userId;
  late final NetworkService networkService;
  bool isDarkMode = true; // dark mode default

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    _loadUserIdAndFetchData();
  }

  // โหลด user_id จาก SharedPreferences แล้วดึงข้อมูล Favorite Paths
  Future<void> _loadUserIdAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id");
    if (userId != null) {
      fetchFavoritePaths(userId!);
    } else {
      setState(() {
        favoritePaths = [];
        isLoading = false;
      });
    }
  }

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

  // ดึงข้อมูล Favorite Paths จาก server
  Future<void> fetchFavoritePaths(int userId) async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt("user_id");
    if (storedUserId == null) return;

    final baseUrl =
        await NetworkService(config: widget.config).getEffectiveBaseUrl();
    final url = Uri.parse("$baseUrl/api/favorite-paths?user_id=$storedUserId");

    try {
      final response = await http.get(url);
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data["success"] == true && data["favorite_paths"] != null) {
          List<FavoritePath> fetchedPaths = (data["favorite_paths"] as List)
              .map((item) => FavoritePath.fromJson(item))
              .toList();
          setState(() {
            favoritePaths = fetchedPaths;
            isLoading = false;
          });
          return;
        }
      }
      setState(() {
        favoritePaths = [];
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching favorite paths: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // ฟังก์ชันแปลงค่า AQI เป็นสี
  Color getAQIColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
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
      return "Air quality improves significantly during the journey.";
    } else if (endAqi - startAqi >= 20) {
      return "Air quality worsens significantly during the journey.";
    } else {
      return "Air quality remains relatively stable along the route.";
    }
  }

  // ดึงค่า AQI ทั้ง start และ end พร้อมกัน
  Future<List<int?>> _fetchBothAQI(
      double startLat, double startLon, double endLat, double endLon) async {
    final start = await fetchCurrentAQI(startLat, startLon);
    final end = await fetchCurrentAQI(endLat, endLon);
    return [start ?? 0, end ?? 0];
  }

  // ฟังก์ชันเรียก API เพื่อลบ favorite path
  Future<void> _deleteFavoritePath(int pathId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt("user_id");
    if (storedUserId == null) return;
    final effectiveBaseUrl =
        await NetworkService(config: widget.config).getEffectiveBaseUrl();
    final url = Uri.parse("$effectiveBaseUrl/api/favorite-paths");

    try {
      final response = await http.delete(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": storedUserId, "path_id": pathId}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Deleted successfully")));
        fetchFavoritePaths(storedUserId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // เมื่อกดที่การ์ด จะนำไปสู่หน้า Map โดย auto route
  void _navigateToRoute(FavoritePath fav) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(config: widget.config),
        settings: RouteSettings(arguments: {
          "origin": {"lat": fav.startLat, "lon": fav.startLon},
          "destination": {"lat": fav.endLat, "lon": fav.endLon}
        }),
      ),
    );
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
          "Favorite Paths",
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
      // ใช้ RefreshIndicator เพื่อรองรับการลากหน้าจอลง refresh
      body: RefreshIndicator(
        onRefresh: () async {
          if (userId != null) {
            await fetchFavoritePaths(userId!);
          }
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : favoritePaths.isEmpty
                ? Center(
                    child: Text(
                      "No Favorite Paths in your account.",
                      style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: favoritePaths.length,
                    itemBuilder: (context, index) {
                      final fav = favoritePaths[index];
                      // ใช้ GestureDetector เพื่อให้กดที่การ์ดแล้ว auto route ไปหน้า Map
                      return GestureDetector(
                        onTap: () => _navigateToRoute(fav),
                        child: FutureBuilder<List<int?>>(
                          future: _fetchBothAQI(fav.startLat, fav.startLon,
                              fav.endLat, fav.endLon),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Card(
                                margin: EdgeInsets.all(8.0),
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text("Loading AQI..."),
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return const Card(
                                margin: EdgeInsets.all(8.0),
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text("AQI not found"),
                                ),
                              );
                            }
                            final aqiList = snapshot.data!;
                            final startAqi = aqiList[0] ?? 0;
                            final endAqi = aqiList[1] ?? 0;
                            final recommendation =
                                getRecommendation(startAqi, endAqi);

                            // สร้างการ์ดเดียวสำหรับ favorite path
                            return Card(
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
                                    // หัวข้อเส้นทาง + ปุ่มลบ
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "${fav.startLocation} → ${fav.endLocation}",
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
                                                title: const Text(
                                                    "Confirm Delete"),
                                                content: const Text(
                                                    "Are you sure you want to delete this favorite path?"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text("Cancel"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      _deleteFavoritePath(
                                                          fav.pathId);
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
                                    // Subtitle
                                    Text(
                                      "Air Quality Index Transition",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // แสดงค่า AQI ของ start/end
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              "$startAqi",
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: getAQIColor(startAqi),
                                              ),
                                            ),
                                            Text(
                                              getAQILabel(startAqi),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: getAQIColor(startAqi),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Icon(
                                          Icons.arrow_forward,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              "$endAqi",
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: getAQIColor(endAqi),
                                              ),
                                            ),
                                            Text(
                                              getAQILabel(endAqi),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: getAQIColor(endAqi),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Summary recommendation (แบบ AQICard style)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? const Color(0xFF444C63)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        recommendation,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFavoritePathPage(
                  config: widget.config, isDarkMode: isDarkMode),
            ),
          );
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Model class สำหรับ Favorite Path
class FavoritePath {
  final int pathId;
  final String startLocation;
  final String endLocation;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;

  FavoritePath({
    required this.pathId,
    required this.startLocation,
    required this.endLocation,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
  });

  factory FavoritePath.fromJson(Map<String, dynamic> json) {
    // ดึงค่า start_lat_lon และ end_lat_lon แล้วแยกออกเป็น double
    String startLatLon = (json["start_lat_lon"] ?? "0,0").toString();
    List<String> startParts = startLatLon.split(",");
    double sLat = double.tryParse(startParts[0].trim()) ?? 0.0;
    double sLon = startParts.length > 1
        ? double.tryParse(startParts[1].trim()) ?? 0.0
        : 0.0;

    String endLatLon = (json["end_lat_lon"] ?? "0,0").toString();
    List<String> endParts = endLatLon.split(",");
    double eLat = double.tryParse(endParts[0].trim()) ?? 0.0;
    double eLon =
        endParts.length > 1 ? double.tryParse(endParts[1].trim()) ?? 0.0 : 0.0;

    return FavoritePath(
      pathId: json["path_id"],
      startLocation: json["start_location"],
      endLocation: json["end_location"],
      startLat: sLat,
      startLon: sLon,
      endLat: eLat,
      endLon: eLon,
    );
  }
}
