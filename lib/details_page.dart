import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'config.dart';
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
import 'map.dart';

class DetailsPage extends StatefulWidget {
  final AppConfig config;
  final Map<String, dynamic>
      station; // Station details รับมาจากปุ่ม See more details

  const DetailsPage({Key? key, required this.config, required this.station})
      : super(key: key);

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  bool _isDarkMode = true;
  bool _isHistoryMode = false;
  String _selectedHistoryView = "day";

  // สำหรับ dropdown ของ sources
  String _selectedSource = "All";
  List<String> _sources = ["All"];

  // เราจะยังคงเก็บตำแหน่งปัจจุบันไว้เพื่อใช้ในกราฟและแผนที่
  Position? _currentPosition;
  // Station ที่จะแสดงรายละเอียด จะถูกรับมาจาก widget.station
  Map<String, dynamic>? _selectedStation;
  String _lastUpdated = "Loading...";
  List<FlSpot> _aqiData = [];
  List<FlSpot> _historyData = [];
  List<String> _historyLabels = [];
  String _forecastText = "Loading...";
  double _highestAQI = 0.0;

  late final NetworkService networkService;

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    // กำหนด station จาก parameter ที่รับมาจาก previous page
    _selectedStation = widget.station;
    _lastUpdated = widget.station["timestamp"] ?? "Unknown Time";
    _initializeData();
    _fetchSources();
  }

  Future<void> _initializeData() async {
    // กำหนด current position เพื่อใช้ในกราฟและแผนที่ (ไม่ใช้ในการค้นหา station เพราะเราได้ station จาก parameter ไปแล้ว)
    await determinePosition(
      onSuccess: (Position position) async {
        setState(() {
          _currentPosition = position;
        });
      },
      onError: (error) {
        _showError(error);
      },
    );

    generateRandomAQIData(
      onDataGenerated:
          (List<FlSpot> aqiData, String forecastText, double highestAQI) {
        setState(() {
          _aqiData = aqiData;
          _forecastText = forecastText;
          _highestAQI = highestAQI;
        });
      },
    );
  }

  Future<void> _fetchSources() async {
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/sources";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          List<dynamic> src = data["sources"];
          setState(() {
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

  Future<void> _fetchHistoryData() async {
    double? stationLat;
    double? stationLon;

    // ตรวจสอบว่ามีข้อมูล station และดึงค่าพิกัดออกมา
    if (_selectedStation != null) {
      if (_selectedStation!.containsKey("lat") &&
          _selectedStation!.containsKey("lon")) {
        stationLat = double.tryParse(_selectedStation!["lat"].toString());
        stationLon = double.tryParse(_selectedStation!["lon"].toString());
      } else if (_selectedStation!.containsKey("lat_lon")) {
        List<String> parts = _selectedStation!["lat_lon"].toString().split(",");
        if (parts.length == 2) {
          stationLat = double.tryParse(parts[0]);
          stationLon = double.tryParse(parts[1]);
        }
      }
    }

    // ถ้า station ไม่ได้มีค่าพิกัดที่ถูกต้อง fallback ไปใช้ currentPosition
    if (stationLat == null || stationLon == null) {
      if (_currentPosition == null) return;
      stationLat = _currentPosition!.latitude;
      stationLon = _currentPosition!.longitude;
    }

    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/aqi-history";
    final body = jsonEncode({
      "latitude": stationLat,
      "longitude": stationLon,
      "view_by": _selectedHistoryView,
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

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void _toggleHistoryMode() {
    setState(() {
      _isHistoryMode = !_isHistoryMode;
    });
    if (_isHistoryMode) {
      _fetchHistoryData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
      appBar: buildCustomAppBar(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
      drawer: buildDrawer(context: context, isDarkMode: _isDarkMode),
      body: RefreshIndicator(
        onRefresh: () async {
          generateRandomAQIData(
            onDataGenerated:
                (List<FlSpot> aqiData, String forecastText, double highestAQI) {
              setState(() {
                _aqiData = aqiData;
                _forecastText = forecastText;
                _highestAQI = highestAQI;
              });
            },
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // แสดง AQI Card สำหรับ station ที่เลือก
            buildAQICard(
              isDarkMode: _isDarkMode,
              nearestStation: _selectedStation,
              lastUpdated: _lastUpdated,
            ),
            const SizedBox(height: 32),
            // ปุ่มเลือก Sources
            Align(
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xfff9a72b),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSource,
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
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
                      _fetchHistoryData();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // กราฟพยากรณ์/ประวัติ AQI
            buildAQIGraph(
              context: context,
              isDarkMode: _isDarkMode,
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
            // แผนที่แสดง station ที่เลือก
            AQIStationMapWidget(
              userPosition: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : null,
              nearestStation: _selectedStation,
              isDarkMode: _isDarkMode,
            ),
            const SizedBox(height: 16),
            // Key Pollutant Widget
            KeyPollutantWidget(
              pm25: getPollutantNumericValue(_selectedStation?["pm25"]),
              pm10: getPollutantNumericValue(_selectedStation?["pm10"]),
              o3: getPollutantNumericValue(_selectedStation?["o3"]),
              so2: getPollutantNumericValue(_selectedStation?["so2"]),
              dew: getAdditionalNumericValue(_selectedStation?["dew_point"]),
              wind: getAdditionalNumericValue(_selectedStation?["wind_speed"]),
              humidity:
                  getAdditionalNumericValue(_selectedStation?["humidity"]),
              pressure:
                  getAdditionalNumericValue(_selectedStation?["pressure"]),
              temperature:
                  getAdditionalNumericValue(_selectedStation?["temperature"]),
              isDarkMode: _isDarkMode,
            ),
            const SizedBox(height: 16),
            // AQI Labels (Legend)
            buildAQILabels(isDarkMode: _isDarkMode),
          ],
        ),
      ),
    );
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
