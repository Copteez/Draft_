import 'package:flutter/material.dart';

// Empty placeholder file - this service is no longer needed
// This class is now completely disabled

class AlternativeNotificationService {
  static Future<void> initialize() async {
    // Completely disabled
  }

  static void showRouteProgressNotification({
    required String nearestStationName,
    required int progressPercent,
    required int aqi,
  }) {
    // Completely disabled
  }

  static String getAqiLevel(int aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }
}
