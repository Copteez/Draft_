import 'dart:async';
import 'dart:convert';
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
      appBar: AppBar(title: const Text("Weather Forecast")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: forecastData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              var city = snapshot.data!['city'];
              var aqi = snapshot.data!['aqi'];
              var iaqi = snapshot.data!['iaqi'];
              return ListView(
                children: [
                  ListTile(
                    title: Text("City: $city"),
                    subtitle: Text("AQI: $aqi"),
                  ),
                  for (var entry in iaqi.entries)
                    ListTile(
                      title: Text("${entry.key.toUpperCase()}: ${entry.value['v']}"),
                    ),
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
    );
  }
}

class ForcastType {
  final int AQI;
  final String City;

  ForcastType({required this.AQI, required this.City});

  @override
  String toString() {
    return 'ForcastType(AQI: $AQI, City: $City)';
  }
}
