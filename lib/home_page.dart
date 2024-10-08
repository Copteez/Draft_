import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>> forecastData;
  Timer? _timer;
  DateTime lastUpdated = DateTime.now();

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
      lastUpdated = DateTime.now();
    });
  }

Future<Map<String, dynamic>> getForecast() async {
  //current location
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
    var aqi = jsonData['data']['aqi'];
    var city = jsonData['data']['city']['name'];
    var iaqi = jsonData['data']['iaqi'];

    return {'aqi': aqi, 'city': city, 'iaqi': iaqi};
  } else {
    throw Exception("Failed to load forecast data");
  }
}

//location permission
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
      return Future.error('permissions denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('permissions denied, cant request permissions');
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

              var minutesAgo = DateTime.now().difference(lastUpdated).inMinutes;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildAQIBox(city, formattedDate, formattedTime, aqi),
                  const SizedBox(height: 20),
                  _buildLastUpdated(minutesAgo),
                  const SizedBox(height: 20),
                  _build24HourPrediction(),
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

// Main function to build the Current Stat box
Widget _buildCurrentStatBox(Map<String, dynamic> iaqi) {
  List<MapEntry<String, dynamic>> entries = iaqi.entries.toList();

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
          "Current Stat",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            mainAxisSpacing: 16.0, 
            childAspectRatio: 4, 
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            var entry = entries[index];
            return _buildStatTile(entry.key, entry.value['v']);
          },
        ),
      ],
    ),
  );
}

Widget _buildStatTile(String statName, double value) {
  Color barColor = Color(0xFF77A1C9); 

  double barWidthFactor = (value / 100.0).clamp(0.0, 1.0); 

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            statName.toUpperCase(), 
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value.toStringAsFixed(2), 
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ],
      ),
      SizedBox(height: 4),
      // Bar for the value
      Container(
        height: 2,
        width: double.infinity,
        color: Colors.grey[300], 
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: barWidthFactor, 
            child: Container(
              height: 2,
              color: barColor, 
            ),
          ),
        ),
      ),
      SizedBox(height: 4),
      Text(
        "Good", 
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ],
  );
}

  Widget _buildLastUpdated(int minutesAgo) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "Latested update $minutesAgo minutes ago",
        style: TextStyle(color: Colors.black54, fontSize: 14),
      ),
    );
  }

Widget _build24HourPrediction() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "24 Hour Prediction",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 20),
      Container(
        height: 300,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, 
          child: Container(
            width: 24 * 75.0, 
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: 500, 
                minY: 0,
                barGroups: _generatePredictionBarGroups(
                  List<double>.generate(24, (index) => Random().nextDouble() * 500), 
                ),
                titlesData: FlTitlesData(
                  leftTitles: SideTitles(showTitles: false), 
                  rightTitles: SideTitles(showTitles: false),
                  topTitles: SideTitles(showTitles: false),
                  bottomTitles: SideTitles(
                    showTitles: true, 
                    getTitles: (value) {
                      int hour = value.toInt();
                      return '$hour h';
                    },
                    getTextStyles: (context, value) =>
                        TextStyle(color: Colors.grey, fontSize: 12),
                    interval: 1, 
                  ),
                ),
                gridData: FlGridData(
                  show: false, 
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

List<BarChartGroupData> _generatePredictionBarGroups(List<double> predictionData) {
  List<BarChartGroupData> barGroups = [];
  for (int i = 0; i < predictionData.length; i++) {
    double aqi = predictionData[i];
    barGroups.add(
      BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            y: aqi, 
            colors: [_getAQIColor(aqi)], 
            width: 20, 
          ),
        ],
      ),
    );
  }
  return barGroups;
}

Color _getAQIColor(double aqi) {
  if (aqi <= 50) {
    return Color(0xFFB5F379); // Green for good
  } else if (aqi <= 100) {
    return Color(0xFFFFF47E); // Yellow for moderate
  } else if (aqi <= 150) {
    return Color(0xFFFEB14E); // Orange for unhealthy for sensitive groups
  } else if (aqi <= 200) {
    return Color(0xFFFF6274); // Red for unhealthy
  } else if (aqi <= 300) {
    return Color(0xFFB46EBC); // Purple for very unhealthy
  } else {
    return Color(0xFF975174); // Maroon for hazardous
  }
}

Widget _buildHourPredictionTile(int hour) {
  int aqi = Random().nextInt(500); // Random AQI for debug !!DELETE IN FUTURE!!
  Color aqiColor;
  String emoji;

  if (aqi <= 50) {
    aqiColor = Color(0xFFB5F379); 
    emoji = "😊";
  } else if (aqi <= 100) {
    aqiColor = Color(0xFFFFF47E); 
    emoji = "😐";
  } else if (aqi <= 150) {
    aqiColor = Color(0xFFFEB14E); 
    emoji = "😷";
  } else if (aqi <= 200) {
    aqiColor = Color(0xFFFF6274); 
    emoji = "🤢";
  } else if (aqi <= 300) {
    aqiColor = Color(0xFFB46EBC); 
    emoji = "🤮";
  } else {
    aqiColor = Color(0xFF975174); 
    emoji = "☠️";
  }

  return ConstrainedBox( 
    constraints: BoxConstraints(
      minHeight: 120, 
      maxHeight: 120,
    ),

    child: Container(
      width: 80, 
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "$hour h",
            style: TextStyle(color: Colors.black, fontSize: 12), 
          ),
          SizedBox(height: 6), 
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: aqiColor.withOpacity(0.8), 
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$aqi",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14, 
              ),
            ),
          ),
          SizedBox(height: 6), 
          Text(
            emoji,
            style: TextStyle(fontSize: 20), 
          ),
        ],
      ),
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
