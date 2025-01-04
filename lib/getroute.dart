import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

Future<List<String>> getRouteCoordinates(LatLng start, LatLng end, String mode) async {
  PolylinePoints polylinePoints = PolylinePoints();
  String googleApiKey = dotenv.env['GOOGLE_API'] ?? 'API key not found';
  String url = 'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${start.latitude},${start.longitude}&'
      'destination=${end.latitude},${end.longitude}&'
      'mode=$mode&alternatives=true&key=$googleApiKey';
  PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey, PointLatLng(start.latitude, start.longitude),  PointLatLng(end.latitude, end.longitude),
  );
  print('result: $result');
  print('Directions URL: $url');  // Debugging: check the generated URL
  Set<Polyline> polylines = {};
  var response = await http.get(Uri.parse(url));
  print('Response status: ${response.statusCode}');  // Debugging: check the status code
  print('Response body: ${response.body}');  // Debugging: check the response content

  if (response.statusCode == 200) {
    Map data = jsonDecode(response.body);

    if (data['routes'] != null && data['routes'].isNotEmpty) {
      List<String> routes = [];
      for (var route in data['routes'].take(3)) {
        routes.add(route['overview_polyline']['points']);
      }
      print(routes[0]);
      return routes;
    } else {
      throw Exception('No routes found.');
    }
  } else {
    throw Exception('Failed to get directions');
  }
}




List<LatLng> convertToLatLng(String encoded) {
  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }

  return points;
}
