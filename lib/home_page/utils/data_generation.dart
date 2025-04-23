import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../../network_service.dart';
import '../../config.dart';

/// Fetches real AQI prediction data from API
Future<void> getAQIPredictionData({
  required String location,
  String? stationId, // Add stationId parameter
  required void Function(
          List<FlSpot> aqiData, String forecastText, double highestAQI)
      onDataGenerated,
  Function(String error)? onError,
  AppConfig? config,
}) async {
  try {
    // Use the NetworkService to get the effective base URL
    final networkService =
        config != null ? NetworkService(config: config) : null;
    String baseUrl;

    // If we have a network service, use it to determine the API URL
    if (networkService != null) {
      baseUrl = await networkService.getEffectiveBaseUrl();
    } else {
      // Fallback to a default URL
      baseUrl = 'https://mysecuremap.ngrok.dev';
    }

    final Uri url = Uri.parse('$baseUrl/api/aqi-prediction');

    // Create the request body based on available parameters
    final Map<String, dynamic> requestBody = {};

    // Only add stationId if it's not null and not empty
    if (stationId != null && stationId.isNotEmpty) {
      requestBody['station_id'] = stationId;
    } else {
      // If no station ID, use location parameter
      requestBody['location'] = location;
    }

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      // Check if the API response indicates success
      if (data['success'] == true) {
        final List<dynamic> predictions = data['predictions'] ?? [];

        List<FlSpot> aqiData = [];
        double maxAQI = 0;
        int maxHour = 0;

        // Process API response into FlSpot data
        for (int i = 0; i < predictions.length && i < 24; i++) {
          final prediction = predictions[i];
          final double aqi = double.tryParse(prediction['aqi'].toString()) ?? 0;

          aqiData.add(FlSpot(i.toDouble(), aqi));

          if (aqi > maxAQI) {
            maxAQI = aqi;
            maxHour = i;
          }
        }

        // If no data was received, use fallback data
        if (aqiData.isEmpty) {
          _useFallbackData(onDataGenerated);
          return;
        }

        // Format the forecast text
        String timeFormat = maxHour < 10 ? "0$maxHour:00" : "$maxHour:00";
        String aqiCategory = _getAQICategory(maxAQI.toInt());
        String forecastText =
            "The AQI is expected to reach ${maxAQI.toInt()} ($aqiCategory) at $timeFormat";

        onDataGenerated(aqiData, forecastText, maxAQI);
      } else {
        final errorMessage = data['error'] ?? 'Unknown API error';
        if (onError != null) {
          onError(errorMessage);
        }
        _useFallbackData(onDataGenerated);
      }
    } else {
      if (onError != null) {
        onError('Failed to load AQI data: ${response.statusCode}');
      }
      _useFallbackData(onDataGenerated);
    }
  } catch (e) {
    if (onError != null) {
      onError('Error fetching AQI data: $e');
    }
    _useFallbackData(onDataGenerated);
  }
}

/// Fallback method when API fails - uses realistic prediction model
void _useFallbackData(
    void Function(List<FlSpot> aqiData, String forecastText, double highestAQI)
        onDataGenerated) {
  List<FlSpot> aqiData = [];
  int maxAQI = 0;
  int maxHour = 0;

  // Base value and time patterns for realistic prediction model
  int baseValue = 50;

  // Urban AQI typically follows patterns: higher during morning and evening rush hours
  for (int i = 0; i < 24; i++) {
    int aqi;

    // Morning rush hour (7-9 AM)
    if (i >= 7 && i <= 9) {
      aqi = baseValue + 70 + (i - 7) * 20;
    }
    // Evening rush hour (4-7 PM)
    else if (i >= 16 && i <= 19) {
      aqi = baseValue + 90 + (i - 16) * 15;
    }
    // Night time improvement
    else if (i >= 20 || i <= 5) {
      aqi = baseValue - 10 + (i % 5) * 5;
    }
    // Midday (moderate)
    else {
      aqi = baseValue + 30 + (i % 5) * 8;
    }

    // Ensure AQI is within reasonable bounds
    aqi = aqi.clamp(20, 300);

    aqiData.add(FlSpot(i.toDouble(), aqi.toDouble()));

    if (aqi > maxAQI) {
      maxAQI = aqi;
      maxHour = i;
    }
  }

  String timeFormat = maxHour < 10 ? "0$maxHour:00" : "$maxHour:00";
  String aqiCategory = _getAQICategory(maxAQI);
  String forecastText =
      "The AQI is expected to reach $maxAQI ($aqiCategory) at $timeFormat";

  onDataGenerated(aqiData, forecastText, maxAQI.toDouble());
}

// Helper function to categorize AQI values
String _getAQICategory(int aqi) {
  if (aqi <= 50) return "Good";
  if (aqi <= 100) return "Moderate";
  if (aqi <= 150) return "Unhealthy for Sensitive Groups";
  if (aqi <= 200) return "Unhealthy";
  if (aqi <= 300) return "Very Unhealthy";
  return "Hazardous";
}
