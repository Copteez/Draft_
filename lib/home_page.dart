import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatelessWidget{


  Future getForecast() async {
    var city_name = "here";
    var api_key = "58619aef51181265b04347c2df10bd62a56995ef";
    var url = "api.waqi.info";
    var path = "/feed/$city_name/";
    var params = {"token": api_key};
    var uri = Uri.https(url, path, params);
    var response = await http.get(uri);

    if (response.statusCode == 200) {
      print("Success: ${response.body}");
    } else {
      print("Failed: ${response.statusCode}");
    }
  }
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Weather Forecast")),
      body: Center(
        child: ElevatedButton(
          onPressed: getForecast,
          child: Text("Get Forecast"),
        ),
      ),
    );
  }
}