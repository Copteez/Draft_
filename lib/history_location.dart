import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'network_service.dart';
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
  bool isDarkMode = true; // Default dark mode

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    fetchHistoryLocations();
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

  @override
  Widget build(BuildContext context) {
    // Define colors based on theme mode.
    final backgroundColor = isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
    final appBarColor = isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF545978) : Colors.white;
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
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: iconColor),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyLocations.isEmpty
              ? Center(
                  child: Text(
                    "No history locations found.",
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                )
              : ListView.builder(
                  itemCount: historyLocations.length,
                  itemBuilder: (context, index) {
                    final location = historyLocations[index];
                    final latLon = location['lat_lon'].split(',');
                    final lat = double.parse(latLon[0]);
                    final lon = double.parse(latLon[1]);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      elevation: 4,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.location_on, color: iconColor),
                        title: Text(
                          location['location_name'],
                          style: TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          "Visited: ${formatTimestamp(location['timestamp'])}",
                          style: TextStyle(color: textColor.withOpacity(0.8)),
                        ),
                        onTap: () =>
                            goToMap(lat, lon, location['location_name']),
                      ),
                    );
                  },
                ),
    );
  }
}
