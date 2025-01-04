import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'map.dart';
import 'details_page.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Forecast> forecastData;
  Timer? _timer;
  DateTime lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchForecast();
    _timer = Timer.periodic(Duration(minutes: 30), (timer) {
      fetchForecast();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void fetchForecast() {
    setState(() {
      forecastData = getForecast();
    });
  }

  Future<Forecast> getForecast() async {
    try {
      Position userLocation = await _determinePosition();
      double latitude = userLocation.latitude;
      double longitude = userLocation.longitude;

      var apiKey = "58619aef51181265b04347c2df10bd62a56995ef";
      var url = "api.waqi.info";
      var path = "/feed/geo:$latitude;$longitude/";
      var params = {"token": apiKey};
      var uri = Uri.https(url, path, params);

      var response = await http.get(uri);

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        return Forecast.fromJson(jsonData);
      } else {
        throw Exception("Failed to load forecast data");
      }
    } catch (e) {
      throw Exception("Error fetching data: $e");
    }
  }


  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissions denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissions denied, cannot request permissions');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.search),
          onPressed: () {},
        ),
        centerTitle: true,
        title: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFF18966C),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.air, size: 30, color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<Forecast>(
        future: forecastData,
        builder: buildForecast,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map & Path Finder',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: 0,
        selectedItemColor: Color(0xFF77A1C9),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MapPage()),
            );
          }
        },
      ),
    );
  }

  Widget buildForecast(BuildContext context, AsyncSnapshot<Forecast> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return Center(child: Text("Error: \${snapshot.error}"));
    } else if (snapshot.hasData) {
      Forecast forecast = snapshot.data!;
      var date = DateTime.now();
      var formattedDate = DateFormat('EEEE, d MMMM y').format(date);
      var formattedTime = DateFormat('h:mm a').format(date);
      var minutesAgo = DateTime.now().difference(forecast.time).inMinutes;

      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAQIBox(forecast.city, formattedDate, formattedTime, forecast.aqi.toDouble(), forecast.stationId),
          const SizedBox(height: 20),
          _buildLastUpdated(minutesAgo),
          const SizedBox(height: 20),
          _buildMinimal24HourPrediction(),
          const SizedBox(height: 20),
          _buildCurrentStatBox(forecast.iaqi),
        ],
      );
    } else {
      return Center(child: Text("No data available."));
    }
  }

  Widget _buildMinimal24HourPrediction() {
    List<String> labels = [
      "8 AM", "9 AM", "10 AM", "11 AM", "12 PM",
      "1 PM", "2 PM", "3 PM", "4 PM", "5 PM",
    ];
    List<double> aqiValues = [60, 80, 100, 90, 110, 120, 130, 150, 160, 170];
    List<double> pm25Values = [30, 40, 50, 40, 45, 50, 55, 60, 65, 70];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "24 Hour Prediction",
          style: titleTextStyle,
        ),
        SizedBox(height: 10),
        _buildLegend(),
        SizedBox(height: 20),
        Container(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  getTextStyles: (context, value) => TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                  reservedSize: 30,
                  margin: 10,
                ),
                bottomTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  rotateAngle: 45,
                  getTextStyles: (context, value) => TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                  getTitles: (value) {
                    int index = value.toInt();
                    return index >= 0 && index < labels.length
                        ? labels[index]
                        : '';
                  },
                ),
                // Hide the right titles
                rightTitles: SideTitles(showTitles: false),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              minY: 0,
              maxY: 200,
              lineBarsData: [
                _buildLineBarData(aqiValues, Colors.red, "AQI"),
                _buildLineBarData(pm25Values, Colors.blue, "PM2.5"),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.grey[700],
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      return LineTooltipItem(
                        '${touchedSpot.barIndex == 0 ? "AQI" : "PM2.5"}: ${touchedSpot.y.toInt()}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),

        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildLegendItem(Colors.red, "AQI"),
        SizedBox(width: 10),
        _buildLegendItem(Colors.blue, "PM2.5"),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ],
    );
  }

  LineChartBarData _buildLineBarData(List<double> values, Color lineColor, String label) {
    return LineChartBarData(
      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: false,
      colors: [lineColor],
      dotData: FlDotData(show: true),
      belowBarData: BarAreaData(show: false),
      barWidth: 3,
    );
  }

  Widget _buildAQIBox(String city, String date, String time, double aqi, int stationId) {
    var aqiProperties = getAQIProperties(aqi);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: boxDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.black54),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            city,
                            style: titleTextStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(date, style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(time, style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              _buildAQICircle(aqi, aqiProperties['level'], aqiProperties['color']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 50,
                color: aqiProperties['color'],
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  aqiProperties['description'],
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsPage(
                      stationId: stationId,
                    ),
                  ),
                );
              },
              child: Text(
                "See more details >>",
                style: TextStyle(
                  color: Colors.grey,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQICircle(double aqi, String aqiLevel, Color aqiColor) {
    return Container(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: AQICirclePainter(aqi.toInt()),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "AQI Value",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Text(
  "${aqi.toInt()}",
  style: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  ),
),

              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: aqiColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  aqiLevel,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatBox(Map<String, dynamic> iaqi) {
    List<MapEntry<String, dynamic>> entries = iaqi.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: boxDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Stat",
            style: titleTextStyle,
          ),
          SizedBox(height: 8),
          Divider(color: Colors.grey),
          SizedBox(height: 16),
          GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              childAspectRatio: 3,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              var entry = entries[index];
              return _buildStatTile(entry.key, (entry.value['v'] as num).toDouble());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String statName, double? value) {
    String fullName;
    String condition;
    Color barColor;
    double barWidthFactor = 0.0;

    switch (statName.toUpperCase()) {
      case 'DEW':
    fullName = 'Dew Point';
    if (value == null) {
        condition = 'No data';
        barColor = Colors.grey;
    } else if (value < 0) {
        condition = 'Below Freezing';
        barColor = Colors.lightBlue;
        barWidthFactor = (value + 30) / 60; 
        condition = 'Comfortable';
        barColor = Colors.blue;
        barWidthFactor = value / 30;
    } else if (value < 20) {
        condition = 'Moderate';
        barColor = Colors.green;
        barWidthFactor = value / 30;
    } else {
        condition = 'High';
        barColor = Colors.red;
        barWidthFactor = value / 30;
    }
    break;
      case 'H':
        fullName = 'Humidity';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value < 30) {
          condition = 'Very Low';
          barColor = Colors.blue;
          barWidthFactor = value / 100;
        } else if (value <= 60) {
          condition = 'Comfortable';
          barColor = Colors.green;
          barWidthFactor = value / 100;
        } else {
          condition = 'High';
          barColor = Colors.red;
          barWidthFactor = value / 100;
        }
        break;
      case 'O3':
        fullName = 'Ozone';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value <= 50) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = value / 100;
        } else if (value <= 100) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = value / 150;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = value / 200;
        }
        break;
      case 'P':
        fullName = 'Pressure';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value < 1000) {
          condition = 'Low';
          barColor = Colors.orange;
          barWidthFactor = value / 1100;
        } else if (value <= 1025) {
          condition = 'Normal';
          barColor = Colors.green;
          barWidthFactor = value / 1100;
        } else {
          condition = 'High';
          barColor = Colors.blue;
          barWidthFactor = value / 1100;
        }
        break;
      case 'PM10':
        fullName = 'PM10';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value <= 54) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = value / 200;
        } else if (value <= 154) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = value / 200;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = value / 300;
        }
        break;
      case 'PM25':
        fullName = 'PM2.5';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value <= 12) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = value / 100;
        } else if (value <= 35.4) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = value / 100;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = value / 150;
        }
        break;
      case 'R':
        fullName = 'Rainfall';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value < 2) {
          condition = 'Light';
          barColor = Colors.blue;
          barWidthFactor = value / 20;
        } else if (value <= 10) {
          condition = 'Moderate';
          barColor = Colors.green;
          barWidthFactor = value / 20;
        } else {
          condition = 'Heavy';
          barColor = Colors.red;
          barWidthFactor = value / 20;
        }
        break;
      case 'SO2':
        fullName = 'Sulfur Dioxide';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value <= 35) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = value / 100;
        } else if (value <= 75) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = value / 100;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = value / 150;
        }
        break;
      case 'T':
        fullName = 'Temperature';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value < 10) {
          condition = 'Cold';
          barColor = Colors.blue;
          barWidthFactor = value / 40;
        } else if (value <= 25) {
          condition = 'Comfortable';
          barColor = Colors.green;
          barWidthFactor = value / 40;
        } else {
          condition = 'Hot';
          barColor = Colors.red;
          barWidthFactor = value / 40;
        }
        break;
      case 'W':
        fullName = 'Wind Speed';
        if (value == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (value < 5) {
          condition = 'Calm';
          barColor = Colors.blue;
          barWidthFactor = value / 20;
        } else if (value <= 10) {
          condition = 'Moderate';
          barColor = Colors.green;
          barWidthFactor = value / 20;
        } else {
          condition = 'Strong';
          barColor = Colors.red;
          barWidthFactor = value / 20;
        }
        break;
      default:
        fullName = statName;
        condition = 'No data';
        barColor = Colors.grey;
        barWidthFactor = 0.0;
    }

    return SingleChildScrollView(// Wrap the entire Column in a scrollable view
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fullName,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              Text(
                value?.toStringAsFixed(2) ?? 'No data',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ],
          ),
          SizedBox(height: 2),
          Container(
            height: 2,  // Height of the bar
            width: double.infinity,
            color: Colors.grey[300],
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (barWidthFactor != null && barWidthFactor >= 0) ? barWidthFactor : 0.0,
                child: Container(
                  height: 2,
                  color: barColor,
                ),
              ),
            ),
          ),
          SizedBox(height: 2),
          Text(
            condition,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(int minutesAgo) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "Latest update $minutesAgo minutes ago",
        style: TextStyle(color: Colors.black54, fontSize: 14),
      ),
    );
  }

  Color _getAQIColor(double aqi) {
    return getAQIProperties(aqi)['color'];
  }

  Map<String, dynamic> getAQIProperties(double aqi) {
    List<Map<String, dynamic>> aqiLevels = [
      {
        "max": 50,
        "color": Color(0xFFB5F379),
        "level": "Good",
        "description": "Air quality is good. It's a great day to be outside!"
      },
      {
        "max": 100,
        "color": Color(0xFFFFF47E),
        "level": "Moderate",
        "description": "Air quality is acceptable. However, there may be a risk for some people, particularly those who are unusually sensitive to air pollution."
      },
      {
        "max": 150,
        "color": Color(0xFFFEB14E),
        "level": "Less Unhealthy",
        "description": "Members of sensitive groups may experience health effects. The general public is less likely to be affected."
      },
      {
        "max": 200,
        "color": Color(0xFFFF6274),
        "level": "Unhealthy",
        "description": "Everyone may begin to experience health effects; members of sensitive groups may experience more serious health effects."
      },
      {
        "max": 300,
        "color": Color(0xFFB46EBC),
        "level": "Very Unhealthy",
        "description": "Health alert: everyone may experience more serious health effects."
      },
      {
        "max": double.infinity,
        "color": Color(0xFF975174),
        "level": "Hazardous",
        "description": "Health warnings of emergency conditions. The entire population is more likely to be affected."
      },
    ];

    for (var level in aqiLevels) {
      if (aqi <= level["max"]) {
        return level;
      }
    }
    return aqiLevels.last;
  }
}

class Forecast {
  final int aqi;
  final String city;
  final Map<String, dynamic> iaqi;
  final int stationId;
  final DateTime time;

  Forecast({required this.aqi, required this.city, required this.iaqi, required this.stationId, required this.time});

  factory Forecast.fromJson(Map<String, dynamic> json) {
    return Forecast(
      aqi: json['data']['aqi'],
      city: json['data']['city']['name'],
      iaqi: json['data']['iaqi'],
      stationId: json['data']['idx'],
      time: DateTime.parse(json['data']['time']['s']),
    );
  }
}

class AQICirclePainter extends CustomPainter {
  final int aqi;

  AQICirclePainter(this.aqi);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(0, 0, size.width, size.height);
    final startAngle = 3.14 * 0.75;
    final sweepAngle = 3.14 * 1.5;
    final useCenter = false;

    final colors = [
      Color(0xFFB5F379),
      Color(0xFFFFF47E),
      Color(0xFFFEB14E),
      Color(0xFFFF6274),
      Color(0xFFB46EBC),
      Color(0xFF975174),
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15;

    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      double segmentSweepAngle = sweepAngle / colors.length;
      canvas.drawArc(rect, startAngle + segmentSweepAngle * i, segmentSweepAngle, useCenter, paint);
    }

    int colorIndex;
    if (aqi <= 50) {
      colorIndex = 0;
    } else if (aqi <= 100) {
      colorIndex = 1;
    } else if (aqi <= 150) {
      colorIndex = 2;
    } else if (aqi <= 200) {
      colorIndex = 3;
    } else if (aqi <= 300) {
      colorIndex = 4;
    } else {
      colorIndex = 5;
    }

    double aqiStartAngle = startAngle + (sweepAngle / colors.length) * colorIndex;
    double segmentMiddleAngle = aqiStartAngle + (sweepAngle / colors.length) / 2;

    double radius = (size.width / 2) - 1;

    Offset circleCenter = Offset(
      size.width / 2 + radius * cos(segmentMiddleAngle),
      size.height / 2 + radius * sin(segmentMiddleAngle),
    );

    final whiteCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final whiteCircleBorderPaint = Paint()
      ..color = colors[colorIndex]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(circleCenter, 10, whiteCirclePaint);
    canvas.drawCircle(circleCenter, 10, whiteCircleBorderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

final boxDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(5),
  boxShadow: [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 10,
      spreadRadius: 1,
    ),
  ],
);

final TextStyle titleTextStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
