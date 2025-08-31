import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'network_service.dart';
import 'theme_provider.dart';
import 'map.dart';
import 'dart:io';
import 'home_page/widgets/drawer_widget.dart';

class HistoryLocationPage extends StatefulWidget {
  final AppConfig config;

  const HistoryLocationPage({Key? key, required this.config}) : super(key: key);

  @override
  State<HistoryLocationPage> createState() => _HistoryLocationPageState();
}

class _HistoryLocationPageState extends State<HistoryLocationPage> {
  List<dynamic> historyLocations = [];
  bool isLoading = true;
  late final NetworkService networkService;

  // Cache AQI data to prevent refetching
  final Map<String, int?> _aqiCache = {};

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    fetchHistoryLocations();
  }

  // ฟังก์ชันดึงค่า AQI ปัจจุบันจาก API สำหรับพิกัดที่กำหนด
  Future<int?> fetchCurrentAQI(double lat, double lon) async {
    final cacheKey = "${lat}_${lon}";
    if (_aqiCache.containsKey(cacheKey)) {
      return _aqiCache[cacheKey];
    }

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

    int? aqi;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      aqi = data["nearest_station"]["aqi"];
    }

    _aqiCache[cacheKey] = aqi;
    return aqi;
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

  Future<void> fetchHistoryLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final baseUrl = await networkService.getEffectiveBaseUrl();

    try {
      final response = await Dio().get(
        '$baseUrl/api/history-locations',
        queryParameters: {'user_id': userId},
      );

      if (response.data['success'] == true) {
        setState(() {
          historyLocations = response.data['history_locations'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching history locations: $e");
      setState(() => isLoading = false);
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      // Attempt to parse the HTTP-date string.
      DateTime dt = HttpDate.parse(timestamp).toLocal();
      return DateFormat("dd/MM/yyyy HH:mm", "th").format(dt);
    } catch (e) {
      print("Timestamp parsing error: $e");
      // Fallback: Remove "GMT" and return the rest of the string.
      String cleaned = timestamp.replaceAll("GMT", "").trim();
      return cleaned;
    }
  }

  void goToMap(double lat, double lon, String locationName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(
          config: widget.config,
          initialLat: lat,
          initialLon: lon,
          locationName: locationName,
        ),
      ),
    );
  }

  Widget _buildHistoryLocationCard(
      dynamic location, double lat, double lon, bool isDarkMode) {
    return GestureDetector(
      onTap: () => goToMap(lat, lon, location['location_name']),
      child: FutureBuilder<int?>(
        future: fetchCurrentAQI(lat, lon),
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

          final aqi = snapshot.data ?? 0;

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
                      // Header with location icon and info
                      Row(
                        children: [
                          // History icon badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.location_history,
                                color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          // Location title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Search history",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  location['location_name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // AQI Badge
                          if (aqi > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: getAQIColor(aqi),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "$aqi",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AQI Details section
                      if (aqi > 0)
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
                          child: Row(
                            children: [
                              // AQI Circle
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: getAQIColor(aqi),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: getAQIColor(aqi), width: 3),
                                ),
                                child: Center(
                                  child: Text(
                                    "$aqi",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // AQI Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Current Air Quality",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            getAQIColor(aqi).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        getAQILabel(aqi),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: getAQIColor(aqi),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (aqi > 0) const SizedBox(height: 12),

                      // Timestamp
                      Container(
                        width: double.infinity,
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
                              Icons.access_time,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Searched at: ${formatTimestamp(location['timestamp'])}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                                fontWeight: FontWeight.w500,
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

    // Define colors based on theme mode.
    final backgroundColor = isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
    final appBarColor = isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      drawer: buildDrawer(context: context, isDarkMode: isDarkMode),
      appBar: AppBar(
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "History Locations",
          style: TextStyle(color: textColor),
        ),
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ))
          : historyLocations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_history,
                        size: 80,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No Location History",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Your visited locations will appear here",
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: historyLocations.length,
                  itemBuilder: (context, index) {
                    final location = historyLocations[index];
                    final latLon = location['lat_lon'].split(',');
                    final lat = double.parse(latLon[0]);
                    final lon = double.parse(latLon[1]);

                    return _buildHistoryLocationCard(
                        location, lat, lon, isDarkMode);
                  },
                ),
    );
  }
}
