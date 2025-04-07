import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Add this import
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'config.dart';
import 'theme_provider.dart'; // Add this import
import 'home_page/widgets/app_bar.dart';
import 'home_page/widgets/drawer_widget.dart';
import 'home_page/widgets/aqi_card.dart';
import 'home_page/widgets/aqi_graph.dart';
import 'home_page/widgets/aqi_labels.dart';
import 'home_page/widgets/key_pollutant_widget.dart';
import 'home_page/services/network_service.dart';
import 'home_page/services/location_service.dart';
import 'home_page/widgets/aqi_station_map_widget.dart';
import 'home_page/utils/data_generation.dart';
import 'home_page/utils/aqi_utils.dart';

class HomePage extends StatefulWidget {
  final AppConfig config;
  const HomePage({Key? key, required this.config}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Remove this line since theme is now managed by ThemeProvider
  // bool _isDarkMode = true;
  bool _isHistoryMode = false;
  String _selectedHistoryView = "day";
  bool _isLoading = false;
  String? _error;

  // สำหรับ dropdown ของ sources
  String _selectedSource = "All";
  List<String> _sources = ["All"];

  Position? _currentPosition;
  Map<String, dynamic>? _nearestStation;
  String _lastUpdated = "Loading...";
  List<FlSpot> _aqiData = [];
  List<FlSpot> _historyData = [];
  List<String> _historyLabels = [];
  String _forecastText = "Loading...";
  double _highestAQI = 0.0;

  // Add these new properties for prediction data
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoadingPredictions = false;
  String? _predictionError;

  late final NetworkService networkService;

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    _initializeData();
    _fetchSources();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _isLoadingPredictions = true;
    });

    await determinePosition(
      onSuccess: (Position position) async {
        _currentPosition = position;
        // First fetch the nearest station
        await _fetchNearestStation(position);
        // Only after station is fetched, we call _loadAQIData
        // We'll remove this call since _fetchNearestStation will now call _loadAQIData
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _isLoadingPredictions = false;
        });
        _showError(error);
      },
    );

    // Remove this call, as we'll only load AQI data after we have the station info
    // _loadAQIData();
  }

  Future<void> _fetchSources() async {
    // ดึงข้อมูล source จาก API endpoint ที่เชื่อมต่อกับฐานข้อมูล
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/sources";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          // ดึงรายการ sources จากฐานข้อมูล
          List<dynamic> src = data["sources"];
          setState(() {
            // เพิ่ม "All" เข้าไปเป็นตัวเลือกแรก
            _sources = ["All"] + src.map((e) => e.toString()).toList();
          });
        } else {
          setState(() {
            _sources = ["All"];
          });
        }
      } else {
        setState(() {
          _sources = ["All"];
        });
      }
    } catch (e) {
      setState(() {
        _sources = ["All"];
      });
    }
  }

  Future<void> _fetchNearestStation(Position position) async {
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/nearest-station-aqi";
    // ส่ง parameter "source" เฉพาะเมื่อผู้ใช้เลือก source ที่ไม่ใช่ "All"
    final body = jsonEncode({
      "latitude": position.latitude,
      "longitude": position.longitude,
      if (_selectedSource != "All") "source": _selectedSource,
    });
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() {
            _nearestStation = data["nearest_station"];
            _lastUpdated =
                data["nearest_station"]["timestamp"] ?? "Unknown Time";
          });

          // Now that we have the station info, load AQI data
          // Explicitly check if station_id exists before proceeding
          if (_nearestStation != null &&
              _nearestStation!.containsKey('station_id') &&
              _nearestStation!['station_id'] != null) {
            // Get the station ID
            final stationId = _nearestStation!['station_id'].toString();

            if (stationId.isNotEmpty) {
              // Call the AQI prediction with valid station ID
              getAQIPredictionData(
                location: 'current',
                stationId: stationId,
                config: widget.config,
                onDataGenerated: (aqiData, forecastText, highestAQI) {
                  setState(() {
                    _aqiData = aqiData;
                    _forecastText = forecastText;
                    _highestAQI = highestAQI;
                    _isLoading = false;

                    // Create predictions list from the same data
                    _predictions = [];
                    for (int i = 0; i < aqiData.length; i++) {
                      final DateTime timestamp =
                          DateTime.now().add(Duration(hours: i));
                      _predictions.add({
                        'timestamp': timestamp.toIso8601String(),
                        'aqi': aqiData[i].y.toInt(),
                      });
                    }
                    _isLoadingPredictions = false;
                  });
                },
                onError: (errorMessage) {
                  setState(() {
                    _error = errorMessage;
                    _isLoading = false;
                    _isLoadingPredictions = false;
                  });
                  _showError('Error loading AQI data: $errorMessage');
                },
              );
            } else {
              setState(() {
                _isLoading = false;
                _isLoadingPredictions = false;
              });
              _showError('Invalid station ID received');
            }
          } else {
            // If no station_id is available, use location-based instead
            getAQIPredictionData(
              location: 'current',
              config: widget.config,
              onDataGenerated: (aqiData, forecastText, highestAQI) {
                setState(() {
                  _aqiData = aqiData;
                  _forecastText = forecastText;
                  _highestAQI = highestAQI;
                  _isLoading = false;

                  // Create predictions list from the same data
                  _predictions = [];
                  for (int i = 0; i < aqiData.length; i++) {
                    final DateTime timestamp =
                        DateTime.now().add(Duration(hours: i));
                    _predictions.add({
                      'timestamp': timestamp.toIso8601String(),
                      'aqi': aqiData[i].y.toInt(),
                    });
                  }
                  _isLoadingPredictions = false;
                });
              },
              onError: (errorMessage) {
                setState(() {
                  _error = errorMessage;
                  _isLoading = false;
                  _isLoadingPredictions = false;
                });
                _showError('Error loading AQI data: $errorMessage');
              },
            );
          }
        } else {
          setState(() {
            _isLoading = false;
            _isLoadingPredictions = false;
          });
          _showError("Error fetching nearest station: ${data["error"]}");
        }
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingPredictions = false;
        });
        _showError("Error fetching nearest station: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingPredictions = false;
      });
      _showError("Error fetching nearest station: $e");
    }
  }

  // Keep _loadAQIData for use with the refresh function, but modify it to handle both cases
  void _loadAQIData() {
    setState(() {
      _isLoading = true;
      _isLoadingPredictions = true;
    });

    // Check if we have a station with a valid station_id
    if (_nearestStation != null &&
        _nearestStation!.containsKey('station_id') &&
        _nearestStation!['station_id'] != null) {
      final stationId = _nearestStation!['station_id'].toString();

      if (stationId.isNotEmpty) {
        getAQIPredictionData(
          location: 'current',
          stationId: stationId,
          config: widget.config,
          onDataGenerated: (aqiData, forecastText, highestAQI) {
            // ...existing code...
            setState(() {
              _aqiData = aqiData;
              _forecastText = forecastText;
              _highestAQI = highestAQI;
              _isLoading = false;

              // Create predictions list from the same data
              _predictions = [];
              for (int i = 0; i < aqiData.length; i++) {
                final DateTime timestamp =
                    DateTime.now().add(Duration(hours: i));
                _predictions.add({
                  'timestamp': timestamp.toIso8601String(),
                  'aqi': aqiData[i].y.toInt(),
                });
              }
              _isLoadingPredictions = false;
            });
          },
          onError: (errorMessage) {
            // ...existing code...
            setState(() {
              _error = errorMessage;
              _isLoading = false;
              _isLoadingPredictions = false;
            });
            _showError('Error loading AQI data: $errorMessage');
          },
        );
      } else {
        // Fall back to location-based approach
        _loadLocationBasedAQI();
      }
    } else {
      // Fall back to location-based approach
      _loadLocationBasedAQI();
    }
  }

  // Helper method to avoid code duplication
  void _loadLocationBasedAQI() {
    getAQIPredictionData(
      location: 'current',
      config: widget.config,
      onDataGenerated: (aqiData, forecastText, highestAQI) {
        setState(() {
          _aqiData = aqiData;
          _forecastText = forecastText;
          _highestAQI = highestAQI;
          _isLoading = false;

          // Create predictions list from the same data
          _predictions = [];
          for (int i = 0; i < aqiData.length; i++) {
            final DateTime timestamp = DateTime.now().add(Duration(hours: i));
            _predictions.add({
              'timestamp': timestamp.toIso8601String(),
              'aqi': aqiData[i].y.toInt(),
            });
          }
          _isLoadingPredictions = false;
        });
      },
      onError: (errorMessage) {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
          _isLoadingPredictions = false;
        });
        _showError('Error loading AQI data: $errorMessage');
      },
    );
  }

  void _toggleTheme(bool value) {
    // Update the theme using the provider instead
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme(value);
  }

  void _toggleHistoryMode() {
    setState(() {
      _isHistoryMode = !_isHistoryMode;
    });
    if (_isHistoryMode) {
      _fetchHistoryData();
    }
  }

  Future<void> _fetchHistoryData() async {
    if (_currentPosition == null) return;
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/aqi-history";
    final body = jsonEncode({
      "latitude": _currentPosition!.latitude,
      "longitude": _currentPosition!.longitude,
      "view_by": _selectedHistoryView,
      if (_selectedSource != "All")
        "source": _selectedSource, // ส่ง source ไปที่ backend
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          List history = data["history"];
          List<FlSpot> filledData = [];
          List<String> filledLabels = [];

          for (int i = 0; i < history.length; i++) {
            double aqi = double.tryParse(history[i]["aqi"].toString()) ?? 0;
            filledData.add(FlSpot(i.toDouble(), aqi));

            String label = history[i]["label"]?.toString() ?? "";
            if (label.isEmpty || label == "null") {
              DateTime now = DateTime.now();
              if (_selectedHistoryView == "hour") {
                DateTime labelTime =
                    now.subtract(Duration(hours: history.length - i));
                label = "${labelTime.hour.toString().padLeft(2, '0')}:00";
              } else if (_selectedHistoryView == "day") {
                DateTime labelDate =
                    now.subtract(Duration(days: history.length - i));
                label =
                    "${labelDate.day.toString().padLeft(2, '0')}-${labelDate.month.toString().padLeft(2, '0')}";
              } else if (_selectedHistoryView == "month") {
                DateTime labelMonth =
                    now.subtract(Duration(days: (history.length - i) * 30));
                label =
                    "${labelMonth.year}-${labelMonth.month.toString().padLeft(2, '0')}";
              }
            }
            filledLabels.add(label);
          }

          setState(() {
            _historyData = filledData;
            _historyLabels = filledLabels;
          });
        } else {
          _showError("Error fetching history: ${data["error"]}");
        }
      } else {
        _showError("Error fetching history: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error fetching history: $e");
    }
  }

  void _handleHistoryViewChange(String view) {
    setState(() {
      _selectedHistoryView = view;
    });
    _fetchHistoryData();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme from provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      appBar: buildCustomAppBar(
        isDarkMode: isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
      drawer: buildDrawer(context: context, isDarkMode: isDarkMode),
      body: RefreshIndicator(
          onRefresh: () async {
            _loadAQIData();
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // แสดง AQI Card (สถานีที่ใกล้ที่สุด)
              buildAQICard(
                isDarkMode: isDarkMode, // Use the theme from provider
                nearestStation: _nearestStation,
                lastUpdated: _lastUpdated,
              ),
              const SizedBox(height: 32),
              // ปุ่มเลือก Sources (อยู่ตรงกลางจอ)
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4), // ลดความสูงของปุ่ม
                  decoration: BoxDecoration(
                    color: const Color(0xfff9a72b),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSource,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white),
                      dropdownColor: const Color(0xfff9a72b),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      items: _sources.map((source) {
                        return DropdownMenuItem<String>(
                          value: source,
                          child: Text("Source: $source"),
                        );
                      }).toList(),
                      onChanged: (String? newSource) {
                        setState(() {
                          _selectedSource = newSource!;
                        });
                        if (_currentPosition != null) {
                          _fetchNearestStation(_currentPosition!);
                          _fetchHistoryData();
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(
                  height: 24), // เพิ่มระยะห่างระหว่างปุ่มและ History Graph

              // กราฟพยากรณ์/ประวัติ AQI
              buildAQIGraph(
                context: context,
                isDarkMode: isDarkMode, // Use the theme from provider
                isHistoryMode: _isHistoryMode,
                aqiData: _aqiData,
                historyData: _historyData,
                historyLabels: _historyLabels,
                selectedHistoryView: _selectedHistoryView,
                forecastText: _forecastText,
                onToggleHistoryMode: _toggleHistoryMode,
                onHistoryViewChange: _handleHistoryViewChange,
              ),
              const SizedBox(height: 16),
              // AQI Station map section
              AQIStationMapWidget(
                userPosition: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude, _currentPosition!.longitude)
                    : null,
                nearestStation: _nearestStation,
                isDarkMode: isDarkMode, // Use the theme from provider
              ),
              const SizedBox(height: 16),
              // Key Pollutant Widget (ใช้ helper getNumericValue เพื่อแปลงค่า)
              KeyPollutantWidget(
                pm25: getPollutantNumericValue(_nearestStation?["pm25"]),
                pm10: getPollutantNumericValue(_nearestStation?["pm10"]),
                o3: getPollutantNumericValue(_nearestStation?["o3"]),
                so2: getPollutantNumericValue(_nearestStation?["so2"]),
                dew: getAdditionalNumericValue(_nearestStation?["dew_point"]),
                wind: getAdditionalNumericValue(_nearestStation?["wind_speed"]),
                humidity:
                    getAdditionalNumericValue(_nearestStation?["humidity"]),
                pressure:
                    getAdditionalNumericValue(_nearestStation?["pressure"]),
                temperature:
                    getAdditionalNumericValue(_nearestStation?["temperature"]),
                isDarkMode: isDarkMode, // Use the theme from provider
              ),

              const SizedBox(height: 16),
              // AQI Labels (Legend)
              buildAQILabels(
                  isDarkMode: isDarkMode), // Use the theme from provider

              const SizedBox(height: 16),
            ],
          )),
    );
  }

  // Replace the random prediction data with actual API data
  Widget _buildPredictionCard() {
    // Get the current theme from provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Card(
      // ... existing card properties ...
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AQI Prediction',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingPredictions)
              const Center(child: CircularProgressIndicator())
            else if (_predictionError != null)
              Text(
                'Error: $_predictionError',
                style: TextStyle(color: Colors.red),
              )
            else if (_predictions.isEmpty)
              Text(
                'No prediction data available',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              )
            else
              Column(
                children: [
                  for (var prediction in _predictions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatPredictionTime(prediction['timestamp']),
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[800],
                            ),
                          ),
                          Text(
                            'AQI: ${prediction['aqi']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getAqiColor(prediction['aqi']),
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
    );
  }

  // Helper method to format prediction timestamp
  String _formatPredictionTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    return '${dateTime.hour}:00 ${dateTime.day}/${dateTime.month}';
  }

  // Helper method to get color based on AQI value
  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  double getPollutantNumericValue(dynamic val) {
    if (val == null) return -1.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? -1.0;
    return -1.0;
  }

  double getAdditionalNumericValue(dynamic val) {
    if (val == null) return -999.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? -999.0;
    return -999.0;
  }
}
