import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'config.dart';
import 'network_service.dart';

class HomePage extends StatefulWidget {
  final AppConfig config;
  const HomePage({Key? key, required this.config}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Theme Mode
  bool _isDarkMode = true;
  bool _isHistoryMode = false; // โหมด History
  String _selectedHistoryView = "day"; // ค่าเริ่มต้นเลือกดูเป็น day

  // User Location & AQI Data
  Position? _currentPosition;
  Map<String, dynamic>? _nearestStation;
  String _lastUpdated = "Loading...";

  // Colors
  final Color darkBackground = Color(0xFF2C2C47);
  final Color lightBackground = Colors.white;

  // Random AQI Data & Forecast
  List<FlSpot> _aqiData = [];
  String _forecastText = "Loading...";
  double _highestAQI = 0.0; // ใช้สำหรับระบุค่า AQI สูงสุด

  // History Graph Data
  List<FlSpot> _historyData = [];
  List<String> _historyLabels = [];

  // Instance ของ NetworkService
  late final NetworkService networkService;

  @override
  void initState() {
    super.initState();
    networkService = NetworkService(config: widget.config);
    _getLocationAndFetchData();
    _generateRandomAQIData();
  }

  /// ==========================
  /// GENERATE RANDOM AQI DATA (สำหรับ 24 ชั่วโมง Forecast)
  /// ==========================
  void _generateRandomAQIData() {
    _aqiData.clear();
    Random random = Random();
    int maxAQI = 0;
    int maxHour = 0;

    for (int i = 0; i < 24; i++) {
      int aqi = random.nextInt(300) + 1;
      _aqiData.add(FlSpot(i.toDouble(), aqi.toDouble()));
      if (aqi > maxAQI) {
        maxAQI = aqi;
        maxHour = i;
      }
    }

    setState(() {
      _forecastText = "The AQI is expected to reach $maxAQI at ${maxHour}:00";
      _highestAQI = maxAQI.toDouble();
    });
  }

  /// ==========================
  /// FETCH DATA & LOCATION
  /// ==========================
  Future<void> _getLocationAndFetchData() async {
    await _determinePosition();
    await _fetchNearestStation();
  }

  Future<void> _fetchNearestStation() async {
    if (_currentPosition == null) return;

    // ใช้ NetworkService เพื่อเลือก base URL ที่เหมาะสม
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/nearest-station-aqi";
    final body = jsonEncode({
      "latitude": _currentPosition!.latitude,
      "longitude": _currentPosition!.longitude
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
            _lastUpdated = _nearestStation?["timestamp"] ?? "Unknown Time";
          });
        }
      }
    } catch (e) {
      _showError("Error fetching nearest station: $e");
    }
  }

  /// ==========================
  /// FETCH HISTORY DATA (hour/day/month)
  /// ==========================
  Future<void> _fetchHistoryData() async {
    if (_currentPosition == null) return;
    final effectiveBaseUrl = await networkService.getEffectiveBaseUrl();
    final url = "$effectiveBaseUrl/api/aqi-history";
    final body = jsonEncode({
      "latitude": _currentPosition!.latitude,
      "longitude": _currentPosition!.longitude,
      "view_by": _selectedHistoryView, // "hour", "day", "month"
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("History data received: $data");

        if (data["success"] == true) {
          List history = data["history"];
          List<FlSpot> filledData = [];
          List<String> filledLabels = [];
          DateTime now = DateTime.now();

          // กำหนด multiplier สำหรับแกน X (month ใช้ระยะห่างมากขึ้น)
          double xMultiplier = (_selectedHistoryView == "month") ? 2.0 : 1.0;
          if (_selectedHistoryView == "hour") {
            // สร้าง Map สำหรับข้อมูล API โดย key "YYYY-MM-DD HH"
            Map<String, double> hourData = {};
            for (var item in history) {
              String tsStr = item["timestamps"]?.toString() ?? "";
              try {
                var parts = tsStr.split(' ');
                Map<String, String> monthMap = {
                  "Jan": "01",
                  "Feb": "02",
                  "Mar": "03",
                  "Apr": "04",
                  "May": "05",
                  "Jun": "06",
                  "Jul": "07",
                  "Aug": "08",
                  "Sep": "09",
                  "Oct": "10",
                  "Nov": "11",
                  "Dec": "12"
                };
                String day = parts[1];
                String month = monthMap[parts[2]] ?? "01";
                String year = parts[3];
                String hour = parts[4].substring(0, 2);
                String key = "$year-$month-$day $hour";
                double aqi;
                if (item["aqi"] is int) {
                  aqi = (item["aqi"] as int).toDouble();
                } else if (item["aqi"] is double) {
                  aqi = item["aqi"];
                } else if (item["aqi"] is String) {
                  aqi = double.tryParse(item["aqi"]) ?? 0;
                } else {
                  aqi = 0;
                }
                hourData[key] = aqi;
              } catch (e) {
                // ข้ามรายการที่มีปัญหาในการแยกข้อมูล
              }
            }
            // วนลูป 24 ชั่วโมงล่าสุด
            for (int i = 0; i < 24; i++) {
              DateTime hourTime = now.subtract(Duration(hours: 23 - i));
              String day = hourTime.day.toString().padLeft(2, '0');
              String month = hourTime.month.toString().padLeft(2, '0');
              String year = hourTime.year.toString();
              String hour = hourTime.hour.toString().padLeft(2, '0');
              String key = "$year-$month-$day $hour";
              double value = hourData.containsKey(key) ? hourData[key]! : 0;
              String label = "$hour:00";
              double xValue = i * xMultiplier;
              filledData.add(FlSpot(xValue, value));
              filledLabels.add(label);
            }
          } else if (_selectedHistoryView == "day") {
            // สร้าง Map สำหรับข้อมูล API โดย key "YYYY-MM-DD"
            Map<String, double> dayData = {};
            for (var item in history) {
              String dateStr = item["date"]?.toString() ?? "";
              try {
                var parts = dateStr.split(' ');
                Map<String, String> monthMap = {
                  "Jan": "01",
                  "Feb": "02",
                  "Mar": "03",
                  "Apr": "04",
                  "May": "05",
                  "Jun": "06",
                  "Jul": "07",
                  "Aug": "08",
                  "Sep": "09",
                  "Oct": "10",
                  "Nov": "11",
                  "Dec": "12"
                };
                String day = parts[1];
                String month = monthMap[parts[2]] ?? "01";
                String year = parts[3];
                String key = "$year-$month-$day";
                double aqi;
                if (item["aqi"] is int) {
                  aqi = (item["aqi"] as int).toDouble();
                } else if (item["aqi"] is double) {
                  aqi = item["aqi"];
                } else if (item["aqi"] is String) {
                  aqi = double.tryParse(item["aqi"]) ?? 0;
                } else {
                  aqi = 0;
                }
                dayData[key] = aqi;
              } catch (e) {
                // ข้ามรายการที่มีปัญหาในการแยกข้อมูล
              }
            }
            // วนลูป 30 วันล่าสุด
            for (int i = 0; i < 30; i++) {
              DateTime dayTime = now.subtract(Duration(days: 29 - i));
              String day = dayTime.day.toString().padLeft(2, '0');
              String month = dayTime.month.toString().padLeft(2, '0');
              String year = dayTime.year.toString();
              String key = "$year-$month-$day";
              double value = dayData.containsKey(key) ? dayData[key]! : 0;
              String label = "$day-$month";
              double xValue = i * xMultiplier;
              filledData.add(FlSpot(xValue, value));
              filledLabels.add(label);
            }
          } else if (_selectedHistoryView == "month") {
            // สร้าง Map สำหรับข้อมูล API โดย key "YYYY-MM"
            Map<String, double> monthData = {};
            for (var item in history) {
              String monthStr = item["month"]?.toString() ?? "";
              if (monthStr.isNotEmpty) {
                double aqi;
                if (item["aqi"] is int) {
                  aqi = item["aqi"].toDouble();
                } else if (item["aqi"] is double) {
                  aqi = item["aqi"];
                } else if (item["aqi"] is String) {
                  aqi = double.tryParse(item["aqi"]) ?? 0;
                } else {
                  aqi = 0;
                }
                monthData[monthStr] = aqi;
              }
            }
            // วนลูป 12 เดือนล่าสุด
            for (int i = 0; i < 12; i++) {
              DateTime dt = DateTime(now.year, now.month)
                  .subtract(Duration(days: 30 * (11 - i)));
              String key = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";
              double value = monthData.containsKey(key) ? monthData[key]! : 0;
              Map<int, String> monthMap = {
                1: "Jan",
                2: "Feb",
                3: "Mar",
                4: "Apr",
                5: "May",
                6: "Jun",
                7: "Jul",
                8: "Aug",
                9: "Sep",
                10: "Oct",
                11: "Nov",
                12: "Dec"
              };
              String label = "${monthMap[dt.month]} ${dt.year}";
              double xValue = i * xMultiplier;
              filledData.add(FlSpot(xValue, value));
              filledLabels.add(label);
            }
          }

          _historyData = filledData;
          _historyLabels = filledLabels;
          setState(() {});
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

  /// ==========================
  /// LOCATION HANDLING
  /// ==========================
  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError("Location permissions are denied");
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      _showError("Error getting location: $e");
    }
  }

  /// ==========================
  /// UI & THEMING
  /// ==========================
  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void _showError(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// ==========================
  /// BUILD UI
  /// ==========================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        scaffoldBackgroundColor: _isDarkMode ? darkBackground : lightBackground,
      ),
      home: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _isDarkMode ? darkBackground : lightBackground,
        appBar: _buildAppBar(),
        drawer: _buildDrawer(),
        body: RefreshIndicator(
          onRefresh: () async {
            _generateRandomAQIData();
          },
          child: ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              _buildNearestStationCard(),
              SizedBox(height: 32),
              _buildAQIPredictionGraph(),
            ],
          ),
        ),
      ),
    );
  }

  /// ==========================
  /// APP BAR (Dark/Light Mode Toggle)
  /// ==========================
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _isDarkMode ? darkBackground : lightBackground,
      elevation: 0,
      leading: IconButton(
        icon: Icon(CupertinoIcons.bars,
            color: _isDarkMode ? Colors.white : Colors.black),
        onPressed: () => _scaffoldKey.currentState!.openDrawer(),
      ),
      actions: [
        Row(
          children: [
            Icon(
              _isDarkMode
                  ? CupertinoIcons.moon_fill
                  : CupertinoIcons.sun_max_fill,
              color: _isDarkMode ? Colors.white : Colors.black,
              size: 24,
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _isDarkMode,
                onChanged: _toggleTheme,
                activeColor: Colors.orange,
                inactiveThumbColor: Colors.grey,
                activeTrackColor: Colors.orange.withOpacity(0.5),
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
            ),
            SizedBox(width: 10),
          ],
        ),
      ],
    );
  }

  /// ==========================
  /// SIDE MENU (Drawer)
  /// ==========================
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _isDarkMode ? darkBackground : lightBackground,
      child: Column(
        children: [
          SizedBox(height: 50),
          ListTile(
            leading: Icon(CupertinoIcons.house_fill,
                color: _isDarkMode ? Colors.white : Colors.black),
            title: Text("Home",
                style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(CupertinoIcons.location_fill,
                color: _isDarkMode ? Colors.white : Colors.black),
            title: Text("Path Finder",
                style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black)),
            onTap: () {
              Navigator.pop(context); // ปิด Drawer ก่อน
              Navigator.pushNamed(context, '/map');
            },
          ),
          ListTile(
            leading: Icon(CupertinoIcons.heart_fill,
                color: _isDarkMode ? Colors.white : Colors.black),
            title: Text("Favorite Locations",
                style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// ==========================
  /// AQI CARD
  /// ==========================
  Widget _buildNearestStationCard() {
    int aqi = _nearestStation?["aqi"] ?? 0;
    String level = _getAQILevel(aqi);
    String advice = _getAQIAdvice(aqi);
    Color color = _getAQIColor(aqi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _nearestStation?["station_name"] ?? "Unknown",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.time,
                color: _isDarkMode ? Colors.white70 : Colors.black54, size: 18),
            SizedBox(width: 5),
            Text("Updated 1 hours ago",
                style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black54)),
          ],
        ),
        SizedBox(height: 20),
        Container(
          height: 150,
          width: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(190, 100),
                painter: HalfCirclePainter(color, aqi / 300),
              ),
              Positioned(
                bottom: 15,
                child: Column(
                  children: [
                    Text(
                      "$aqi",
                      style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "AQI Index Quality",
                      style: TextStyle(
                        fontSize: 18,
                        color: _isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.privacy_tip, color: color, size: 28),
            SizedBox(width: 5),
            Text(
              level,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          advice,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  /// ==========================
  /// 24 HOURS PREDICTION & HISTORY GRAPH
  /// ==========================
  Widget _buildAQIPredictionGraph() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Color(0xFF545978) : Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Toggle Button (Forecast / History)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isHistoryMode ? "History" : "24 Hours Forecast",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _isHistoryMode = !_isHistoryMode;
                  });
                  if (_isHistoryMode) {
                    // เมื่อเปลี่ยนเป็น History mode ให้ดึงข้อมูลประวัติจาก API
                    _fetchHistoryData();
                  }
                },
                child: Text(
                  _isHistoryMode ? "View forecast" : "View history",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          // Forecast หรือ History Graph Section
          _isHistoryMode ? _buildHistoryGraph() : _buildLineChartPredict(),
          SizedBox(height: 15),
          // AQI Color Labels
          _buildAQILabels(),
        ],
      ),
    );
  }

  /// ==========================
  /// History Graph Section
  /// ==========================
  Widget _buildHistoryGraph() {
    double maxY = (_historyData.isNotEmpty)
        ? ((_historyData.map((spot) => spot.y).reduce(math.max) + 50) / 50)
                .ceil() *
            50.0
        : 300;

    double chartWidth =
        (_historyData.isNotEmpty ? _historyData.last.x + 1 : 10) * 40;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ปุ่มเลือก view (month/day/hour)
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "View by: ",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            _buildHistoryFilterButton("month"),
            _buildHistoryFilterButton("day"),
            _buildHistoryFilterButton("hour"),
          ],
        ),
        SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: math.max(300, chartWidth),
            height: 250,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _historyData.isNotEmpty ? _historyData.last.x + 1 : 10,
                minY: 0,
                maxY: maxY,
                titlesData: FlTitlesData(
                  leftTitles: SideTitles(
                    showTitles: true,
                    interval: 50,
                    getTitles: (value) => value.toInt().toString(),
                    getTextStyles: (context, value) => TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    reservedSize: 40,
                  ),
                  bottomTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 70,
                    interval: 1,
                    getTitles: (value) {
                      int index = value.toInt();
                      if (index < 0 || index >= _historyLabels.length)
                        return '';

                      String rawLabel = _historyLabels[index];
                      String formattedLabel = rawLabel;

                      if (_selectedHistoryView == "month" &&
                          rawLabel.contains("-")) {
                        List<String> parts = rawLabel.split("-");
                        if (parts.length == 2) {
                          Map<String, String> monthMap = {
                            "01": "Jan",
                            "02": "Feb",
                            "03": "Mar",
                            "04": "Apr",
                            "05": "May",
                            "06": "Jun",
                            "07": "Jul",
                            "08": "Aug",
                            "09": "Sep",
                            "10": "Oct",
                            "11": "Nov",
                            "12": "Dec"
                          };
                          formattedLabel =
                              "${monthMap[parts[1]] ?? parts[1]} ${parts[0]}";
                        }
                      }

                      double aqiValue = _historyData[index].y;
                      Color aqiColor = _getAQIColor(aqiValue);

                      return "$formattedLabel\nAQI\n${aqiValue.toInt()}";
                    },
                    getTextStyles: (context, value) {
                      int index = value.toInt();
                      if (index < 0 || index >= _historyData.length)
                        return TextStyle(fontSize: 10);

                      double aqiValue = _historyData[index].y;
                      Color aqiColor = _getAQIColor(aqiValue);

                      return TextStyle(
                        fontSize: 10,
                        color: aqiColor,
                        fontWeight: FontWeight.bold,
                      );
                    },
                    margin: 10,
                  ),
                  topTitles: SideTitles(showTitles: false),
                  rightTitles: SideTitles(showTitles: false),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _historyData,
                    isCurved: true,
                    colors: [_isDarkMode ? Colors.white : Colors.black],
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryFilterButton(String type) {
    bool isSelected = _selectedHistoryView == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedHistoryView = type;
        });
        _fetchHistoryData();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[400],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type.toUpperCase(),
          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  /// ==========================
  /// ฟังก์ชันสุ่มค่าประวัติ AQI (สำหรับ Forecast แบบเก่า)
  /// ==========================
  void _generateRandomHistoryData() {
    _historyData.clear();
    _historyLabels.clear();
    Random random = Random();

    int dataPoints = 24;
    for (int i = 0; i < dataPoints; i++) {
      int aqi = random.nextInt(300) + 1;
      _historyData.add(FlSpot(i.toDouble(), aqi.toDouble()));
      _historyLabels.add("${i}:00");
    }
    setState(() {});
  }

  /// ==========================
  /// ฟังก์ชันแปลงหมายเลขเดือนเป็นชื่อย่อ
  /// ==========================
  String _getMonthShortName(int month) {
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }

  /// ==========================
  /// สร้าง Label สี AQI (รองรับ 2 บรรทัด)
  /// ==========================
  Widget _buildAQILabels() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAQILabel("Good", Color(0xFFABD162)),
            SizedBox(width: 15),
            _buildAQILabel("Moderate", Color(0xFFF8D461)),
            SizedBox(width: 15),
            _buildAQILabel("Unhealthy (SG)", Color(0xFFFB9956)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAQILabel("Unhealthy", Color(0xFFF6686A)),
            SizedBox(width: 15),
            _buildAQILabel("Very Unhealthy", Color(0xFFA47DB8)),
            SizedBox(width: 15),
            _buildAQILabel("Hazardous", Color(0xFFA07785)),
          ],
        ),
      ],
    );
  }

  Widget _buildAQILabel(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLineChartPredict() {
    double maxY = ((_getMaxAQI() + 50) / 50).ceil() * 50.0;
    DateTime now = DateTime.now();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 2500,
        height: 320,
        child: LineChart(
          LineChartData(
            minX: -1,
            maxX: _aqiData.isNotEmpty ? _aqiData.last.x + 2 : 25,
            minY: 0,
            maxY: maxY,
            titlesData: FlTitlesData(
              bottomTitles: SideTitles(
                showTitles: true,
                reservedSize: 70,
                interval: 1,
                getTitles: (value) {
                  int index = value.toInt();
                  if (index < 0 || index >= _aqiData.length) return '';

                  DateTime timeLabel = now.add(Duration(hours: index));
                  bool isCurrentHour = timeLabel.hour == now.hour;

                  double currentAQI =
                      _nearestStation?["aqi"]?.toDouble() ?? 0.0;
                  double aqiValue =
                      isCurrentHour ? currentAQI : _aqiData[index].y;

                  String formattedTime = isCurrentHour
                      ? "${timeLabel.hour}:${timeLabel.minute.toString().padLeft(2, '0')}"
                      : "${timeLabel.hour}:00";

                  return "$formattedTime\nAQI\n${aqiValue.toInt()}";
                },
                getTextStyles: (context, value) {
                  int index = value.toInt();
                  if (index < 0 || index >= _aqiData.length)
                    return TextStyle(fontSize: 12);
                  double currentAQI =
                      _nearestStation?["aqi"]?.toDouble() ?? 0.0;
                  double aqiValue =
                      (index == now.hour) ? currentAQI : _aqiData[index].y;
                  return TextStyle(
                    color: _getAQIColor(aqiValue),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  );
                },
                margin: 10,
              ),
              leftTitles: SideTitles(
                showTitles: true,
                interval: 50,
                getTitles: (value) => value.toInt().toString(),
                getTextStyles: (context, value) => TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                reservedSize: 40,
                margin: 8,
              ),
              topTitles: SideTitles(showTitles: false),
              rightTitles: SideTitles(showTitles: false),
            ),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                color: _isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _aqiData,
                isCurved: true,
                colors: [_isDarkMode ? lightBackground : darkBackground],
                barWidth: 3,
                dotData: FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ==========================
  /// Helper Function to Get Max AQI
  /// ==========================
  double _getMaxAQI() {
    if (_aqiData.isEmpty) return 0.0;
    return _aqiData.map((spot) => spot.y).reduce(max);
  }

  /// ==========================
  /// AQI Lable, Level, Advice, Color
  /// ==========================
  String _getAQILevel(int aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive Groups";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }

  String _getAQIAdvice(int aqi) {
    if (aqi <= 50) return "Air quality is good. No health risk.";
    if (aqi <= 100)
      return "Air is acceptable. Sensitive individuals should be cautious.";
    if (aqi <= 150) return "Sensitive groups should reduce outdoor activity.";
    if (aqi <= 200) return "Everyone should limit outdoor activity.";
    if (aqi <= 300) return "Health warnings issued. Stay indoors.";
    return "Serious health risk. Avoid outdoor activities!";
  }

  Color _getAQIColor(num aqi) {
    if (aqi <= 50) return Color(0xFFABD162);
    if (aqi <= 100) return Color(0xFFF8D461);
    if (aqi <= 150) return Color(0xFFFB9956);
    if (aqi <= 200) return Color(0xFFF6686A);
    if (aqi <= 300) return Color(0xFFA47DB8);
    return Color(0xFFA07785);
  }
}

/// ==========================
/// HALF CIRCLE PAINTER
/// ==========================
class HalfCirclePainter extends CustomPainter {
  final Color color;
  final double progress;

  HalfCirclePainter(this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height * 2),
      math.pi,
      math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
