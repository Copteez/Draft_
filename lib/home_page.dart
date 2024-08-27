import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>> forecastData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchForecast();
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
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

  Future<Map<String, dynamic>> getForecast() async {
    var cityName = "here"; 
    var apiKey = "58619aef51181265b04347c2df10bd62a56995ef";
    var url = "api.waqi.info";
    var path = "/feed/$cityName/";
    var params = {"token": apiKey};
    var uri = Uri.https(url, path, params);
    var response = await http.get(uri);

    if (response.statusCode == 200) {
      var jsonData = jsonDecode(response.body);
      var aqi = jsonData['data']['aqi'];
      var city = jsonData['data']['city']['name'];
      var iaqi = jsonData['data']['iaqi'];
      return {'aqi': aqi, 'city': city, 'iaqi': iaqi};
    } else {
      throw Exception("Failed to load forecast data");
    }
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: forecastData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              var city = snapshot.data!['city'];
              var aqi = snapshot.data!['aqi'];
              var iaqi = snapshot.data!['iaqi'];
              var date = DateTime.now();
              var formattedDate =
                  "${_getDayOfWeek(date.weekday)}, ${date.day} ${_getMonthName(date.month)} ${date.year}";
              var formattedTime =
                  "${date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildAQIBox(city, formattedDate, formattedTime, aqi),
                  const SizedBox(height: 20),
                  _buildCurrentStatBox(iaqi),
                ],
              );
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
          }

          // Show a loading spinner
          return const Center(child: CircularProgressIndicator());
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions),
            label: 'Path Finder',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
        currentIndex: 0,
        selectedItemColor: Color(0xFF77A1C9),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // future tab nav functions
        },
      ),
    );
  }

  Widget _buildAQIBox(String city, String date, String time, int aqi) {
    Color aqiColor;
    String aqiLevel;
    String aqiDescription;

    // Determine AQI color, level, and description based on the value
    if (aqi <= 50) {
      aqiColor = Color(0xFFB5F379);
      aqiLevel = "Good";
      aqiDescription = "Air quality is good. It's a great day to be outside!";
    } else if (aqi <= 100) {
      aqiColor = Color(0xFFFFF47E);
      aqiLevel = "Moderate";
      aqiDescription =
          "Air quality is acceptable. However, there may be a risk for some people, particularly those who are unusually sensitive to air pollution.";
    } else if (aqi <= 150) {
      aqiColor = Color(0xFFFEB14E);
      aqiLevel = "Unhealthy for Sensitive Groups";
      aqiDescription =
          "Members of sensitive groups may experience health effects. The general public is less likely to be affected.";
    } else if (aqi <= 200) {
      aqiColor = Color(0xFFFF6274);
      aqiLevel = "Unhealthy";
      aqiDescription =
          "Everyone may begin to experience health effects; members of sensitive groups may experience more serious health effects.";
    } else if (aqi <= 300) {
      aqiColor = Color(0xFFB46EBC);
      aqiLevel = "Very Unhealthy";
      aqiDescription =
          "Health alert: everyone may experience more serious health effects.";
    } else {
      aqiColor = Color(0xFF975174);
      aqiLevel = "Hazardous";
      aqiDescription =
          "Health warnings of emergency conditions. The entire population is more likely to be affected.";
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
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
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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
              _buildAQICircle(aqi, aqiLevel, aqiColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 50,
                color: aqiColor,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  aqiDescription,
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
                // See more details page
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

  Widget _buildAQICircle(int aqi, String aqiLevel, Color aqiColor) {
    return Container(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: AQICirclePainter(aqi),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "AQI Value",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Text(
                "$aqi",
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
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current stat",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Divider(color: Colors.grey),
          Column(
            children: iaqi.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${entry.key.toUpperCase()}",
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text("${entry.value['v']}",
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getDayOfWeek(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
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
      Color(0xFFB5F379), // Green for AQI 0-50
      Color(0xFFFFF47E), // Yellow for AQI 51-100
      Color(0xFFFEB14E), // Orange for AQI 101-150
      Color(0xFFFF6274), // Red for AQI 151-200
      Color(0xFFB46EBC), // Purple for AQI 201-300
      Color(0xFF975174), // Maroon for AQI 301-500
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
