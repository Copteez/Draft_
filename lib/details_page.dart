import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class DetailsPage extends StatefulWidget {
  final int stationId;

  DetailsPage({required this.stationId});

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late Future<Forecast> forecastData;

  @override
  void initState() {
    super.initState();
    fetchForecast();
  }

  void fetchForecast() {
    setState(() {
      forecastData = getForecast();
    });
  }

  Future<Forecast> getForecast() async {
    var apiKey = "58619aef51181265b04347c2df10bd62a56995ef"; 
    var url = "api.waqi.info";
    var path = "/feed/@${widget.stationId}/";
    var params = {"token": apiKey};
    var uri = Uri.https(url, path, params);
    var response = await http.get(uri);

    if (response.statusCode == 200) {
      var jsonData = jsonDecode(response.body);
      return Forecast.fromJson(jsonData);
    } else {
      throw Exception("Failed to load forecast data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Forecast>(
        future: forecastData,
        builder: buildForecast,
      ),
    );
  }

  Widget buildForecast(BuildContext context, AsyncSnapshot<Forecast> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return Center(child: Text("Error: ${snapshot.error}"));
    } else if (snapshot.hasData) {
      Forecast forecast = snapshot.data!;
      var aqi = forecast.aqi.toDouble();
      var aqiProperties = getAQIProperties(aqi);
      Color backgroundColor = aqiProperties['color'];

      var minutesAgo = DateTime.now().difference(forecast.time).inMinutes;

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with back button and station name
            Container(
              color: backgroundColor,
              padding: EdgeInsets.only(top: 40, bottom: 16),
              child: Column(
                children: [
                  // Back button
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back),
                        color: Colors.white,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  // Station name
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      forecast.city,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // AQI Dashboard
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: boxDecoration,
              margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // AQI Value and Level
                  Text(
                    '${forecast.aqi}',
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: aqiProperties['color'],
                    ),
                  ),
                  Text(
                    aqiProperties['level'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: aqiProperties['color'],
                    ),
                  ),
                  SizedBox(height: 16),
                  // Description
                  Text(
                    aqiProperties['description'],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                  // Updated time
                  Text(
                    'Updated $minutesAgo minutes ago',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Current Stat Box
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildCurrentStatBox(forecast.iaqi),
            ),
            // 24 Hour Prediction Graph
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: _buildMinimal24HourPrediction(),
            ),
            // History Graph
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: _buildHistoryGraph(),
            ),
          ],
        ),
      );
    } else {
      return Center(child: Text("No data available."));
    }
  }

  Widget _buildCurrentStatBox(Map<String, dynamic> iaqi) {
    List<MapEntry<String, dynamic>> entries = iaqi.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: boxDecoration,
      margin: EdgeInsets.only(top: 16.0),
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
              return _buildStatTile(entry.key, entry.value['v']);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String statName, dynamic value) {
    double? doubleValue;
    if (value is num) {
      doubleValue = value.toDouble();
    } else if (value is String) {
      doubleValue = double.tryParse(value);
    } else {
      doubleValue = null;
    }

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
    } else if (value < 15) {
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
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue < 30) {
          condition = 'Very Low';
          barColor = Colors.blue;
          barWidthFactor = doubleValue / 100;
        } else if (doubleValue <= 60) {
          condition = 'Comfortable';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 100;
        } else {
          condition = 'High';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 100;
        }
        break;
      case 'O3':
        fullName = 'Ozone';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue <= 50) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 100;
        } else if (doubleValue <= 100) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = doubleValue / 150;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 200;
        }
        break;
      case 'P':
        fullName = 'Pressure';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue < 1000) {
          condition = 'Low';
          barColor = Colors.orange;
          barWidthFactor = doubleValue / 1100;
        } else if (doubleValue <= 1025) {
          condition = 'Normal';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 1100;
        } else {
          condition = 'High';
          barColor = Colors.blue;
          barWidthFactor = doubleValue / 1100;
        }
        break;
      case 'PM10':
        fullName = 'PM10';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue <= 54) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 200;
        } else if (doubleValue <= 154) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = doubleValue / 200;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 300;
        }
        break;
      case 'PM25':
        fullName = 'PM2.5';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue <= 12) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 100;
        } else if (doubleValue <= 35.4) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = doubleValue / 100;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 150;
        }
        break;
      case 'R':
        fullName = 'Rainfall';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue < 2) {
          condition = 'Light';
          barColor = Colors.blue;
          barWidthFactor = doubleValue / 20;
        } else if (doubleValue <= 10) {
          condition = 'Moderate';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 20;
        } else {
          condition = 'Heavy';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 20;
        }
        break;
      case 'SO2':
        fullName = 'Sulfur Dioxide';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue <= 35) {
          condition = 'Good';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 100;
        } else if (doubleValue <= 75) {
          condition = 'Moderate';
          barColor = Colors.orange;
          barWidthFactor = doubleValue / 100;
        } else {
          condition = 'Unhealthy';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 150;
        }
        break;
      case 'T':
        fullName = 'Temperature';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue < 10) {
          condition = 'Cold';
          barColor = Colors.blue;
          barWidthFactor = doubleValue / 40;
        } else if (doubleValue <= 25) {
          condition = 'Comfortable';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 40;
        } else {
          condition = 'Hot';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 40;
        }
        break;
      case 'W':
        fullName = 'Wind Speed';
        if (doubleValue == null) {
          condition = 'No data';
          barColor = Colors.grey;
        } else if (doubleValue < 5) {
          condition = 'Calm';
          barColor = Colors.blue;
          barWidthFactor = doubleValue / 20;
        } else if (doubleValue <= 10) {
          condition = 'Moderate';
          barColor = Colors.green;
          barWidthFactor = doubleValue / 20;
        } else {
          condition = 'Strong';
          barColor = Colors.red;
          barWidthFactor = doubleValue / 20;
        }
        break;
      default:
        fullName = statName;
        condition = 'No data';
        barColor = Colors.grey;
        barWidthFactor = 0.0;
    }

    return Column(
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
              doubleValue?.toStringAsFixed(2) ?? 'No data',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
        SizedBox(height: 4),
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
          condition,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
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

  Widget _buildHistoryGraph() {
    List<String> labels = [
      "Day 1",
      "Day 2",
      "Day 3",
      "Day 4",
      "Day 5",
      "Day 6",
      "Day 7",
      "Day 8",
      "Day 9",
      "Day 10",
    ];
    List<double> aqiValues =
    List.generate(10, (index) => Random().nextDouble() * 200);
    List<double> pm25Values =
    List.generate(10, (index) => Random().nextDouble() * 150);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "History Graph",
          style: titleTextStyle,
        ),
        SizedBox(height: 10),
        _buildLegend(),
        SizedBox(height: 20),
        Container(
          height: 200, // Adjusted height to match the homepage
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
                rightTitles: SideTitles(showTitles: false),  // Disable the right side titles
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

  LineChartBarData _buildLineBarData(
      List<double> values, Color lineColor, String label) {
    return LineChartBarData(
      spots:
          values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: false,
      colors: [lineColor],
      dotData: FlDotData(show: true),
      belowBarData: BarAreaData(show: false),
      barWidth: 3,
    );
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
        "description":
            "Air quality is acceptable. However, there may be a risk for some people, particularly those who are unusually sensitive to air pollution."
      },
      {
        "max": 150,
        "color": Color(0xFFFEB14E),
        "level": "Unhealthy for Sensitive Groups",
        "description":
            "Members of sensitive groups may experience health effects. The general public is less likely to be affected."
      },
      {
        "max": 200,
        "color": Color(0xFFFF6274),
        "level": "Unhealthy",
        "description":
            "Everyone may begin to experience health effects; members of sensitive groups may experience more serious health effects."
      },
      {
        "max": 300,
        "color": Color(0xFFB46EBC),
        "level": "Very Unhealthy",
        "description":
            "Health alert: everyone may experience more serious health effects."
      },
      {
        "max": double.infinity,
        "color": Color(0xFF975174),
        "level": "Hazardous",
        "description":
            "Health warnings of emergency conditions. The entire population is more likely to be affected."
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

  Forecast(
      {required this.aqi,
      required this.city,
      required this.iaqi,
      required this.stationId,
      required this.time});

  factory Forecast.fromJson(Map<String, dynamic> json) {
    dynamic aqiValue = json['data']['aqi'];
    int aqiInt;

    if (aqiValue is int) {
      aqiInt = aqiValue;
    } else if (aqiValue is String) {
      aqiInt = int.tryParse(aqiValue) ?? 0;
    } else {
      aqiInt = 0;
    }

    Map<String, dynamic> iaqiData = {};
    if (json['data']['iaqi'] != null) {
      json['data']['iaqi'].forEach((key, value) {
        var vValue = value['v'];
        double? vDouble;
        if (vValue is num) {
          vDouble = vValue.toDouble();
        } else if (vValue is String) {
          vDouble = double.tryParse(vValue);
        } else {
          vDouble = null;
        }
        iaqiData[key] = {'v': vDouble};
      });
    }

    return Forecast(
      aqi: aqiInt,
      city: json['data']['city']['name'],
      iaqi: iaqiData,
      stationId: json['data']['idx'],
      time: DateTime.parse(json['data']['time']['s']),
    );
  }
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

final TextStyle titleTextStyle =
    TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
