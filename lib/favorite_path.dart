import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'network_service.dart';
import 'AddFavoritePathPage.dart';
import 'map.dart';
import 'theme_provider.dart';
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

  // Cache AQI data to prevent refetching on theme changes
  final Map<String, List<int?>> _aqiCache = {};

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

    // Clear AQI cache when fetching new paths
    _aqiCache.clear();

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
      return "Air quality improves significantly during the journey.";
    } else if (endAqi - startAqi >= 20) {
      return "Air quality worsens significantly during the journey.";
    } else {
      return "Air quality remains relatively stable along the route.";
    }
  }

  // ดึงค่า AQI ทั้ง start และ end พร้อมกัน (with caching)
  Future<List<int?>> _fetchBothAQI(
      double startLat, double startLon, double endLat, double endLon) async {
    final cacheKey = "$startLat,$startLon-$endLat,$endLon";

    // Return cached data if available
    if (_aqiCache.containsKey(cacheKey)) {
      return _aqiCache[cacheKey]!;
    }

    // Fetch new data
    final start = await fetchCurrentAQI(startLat, startLon);
    final end = await fetchCurrentAQI(endLat, endLon);
    final result = [start ?? 0, end ?? 0];

    // Cache the result
    _aqiCache[cacheKey] = result;

    return result;
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
        // Clear AQI cache when deleting path
        _aqiCache.clear();
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final bool isDarkMode = themeProvider.isDarkMode;

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
            backgroundColor:
                isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
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
          // ใช้ RefreshIndicator เพื่อรองรับการลากหน้าจอลง refresh
          body: RefreshIndicator(
            onRefresh: () async {
              // Clear cache on manual refresh
              _aqiCache.clear();
              if (userId != null) {
                await fetchFavoritePaths(userId!);
              }
            },
            child: _buildBody(isDarkMode),
          ),
          floatingActionButton: favoritePaths.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddFavoritePathPage(config: widget.config),
                      ),
                    );
                  },
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text(
                    "Add Route",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    if (favoritePaths.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.route,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                "No Favorite Routes Yet",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                "Save your frequently traveled routes to quickly check air quality along your journey.",
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Call to action button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddFavoritePathPage(config: widget.config),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add Your First Route",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: Colors.orange.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: favoritePaths.length,
      itemBuilder: (context, index) {
        final fav = favoritePaths[index];
        return _buildFavoritePathCard(fav, isDarkMode);
      },
    );
  }

  Widget _buildFavoritePathCard(FavoritePath fav, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _navigateToRoute(fav),
      child: FutureBuilder<List<int?>>(
        future:
            _fetchBothAQI(fav.startLat, fav.startLon, fav.endLat, fav.endLon),
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
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 24,
                      ),
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
                        ? [
                            const Color(0xFF545978),
                            const Color(0xFF444C63),
                          ]
                        : [
                            Colors.white,
                            Colors.grey.shade50,
                          ],
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
                          // Route icon badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.route,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Route title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Favorite Route",
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
                                        Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            fav.startLocation,
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
                                        Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            fav.endLocation,
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
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        const SizedBox(width: 8),
                                        const Text("Delete Route"),
                                      ],
                                    ),
                                    content: const Text(
                                      "Are you sure you want to remove this favorite route?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(
                                          "Cancel",
                                          style: TextStyle(
                                              color: Colors.grey[600]),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteFavoritePath(fav.pathId);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
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
                                    Text('Delete Route'),
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
                                            width: 3,
                                          ),
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
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.orange,
                                    size: 24,
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
                                            width: 3,
                                          ),
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Recommendation
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recommendation,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? Colors.orange[200]
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tap hint
                      Text(
                        "Tap to navigate this route",
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
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
