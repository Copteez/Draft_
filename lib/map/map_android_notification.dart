import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class AndroidNotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.example.googleroad/notifications');
  static bool _initialized = false;

  // Use a simpler approach - store a GlobalKey that we'll use to access the navigator state
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;

    try {
      print("Initializing Android notification service...");
      await _channel.invokeMethod('initializeNotifications');
      _initialized = true;
      print("Android notification service initialized");
    } catch (e) {
      print("Error initializing Android notifications: $e");
      // We'll still mark as initialized so we don't keep trying
      _initialized = true;
    }
  }

  static Future<void> showRouteProgressNotification({
    required String nearestStationName,
    required int progressPercent,
    required int aqi,
    String? timeToWorstZone,
    String? distanceToWorstZone,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      print(
          "Showing notification: $nearestStationName, $progressPercent%, AQI: $aqi");

      // Add time and distance info to the notification arguments
      await _channel.invokeMethod('showRouteProgressNotification', {
        'stationName': nearestStationName,
        'progress': progressPercent,
        'aqi': aqi,
        'aqiLevel': _getAqiLevel(aqi),
        'timeToWorstZone': timeToWorstZone,
        'distanceToWorstZone': distanceToWorstZone,
      });
    } catch (e) {
      print("Error showing system notification: $e");

      // Instead of using an Overlay, show a simple Snackbar if context is available
      final context = navigatorKey.currentContext;
      if (context != null) {
        print("Showing fallback snackbar notification");
        _showSnackbarNotification(context, nearestStationName, progressPercent,
            aqi, timeToWorstZone, distanceToWorstZone);
      } else {
        print("No context available for fallback notification");
      }
    }
  }

  static void _showSnackbarNotification(
      BuildContext context,
      String stationName,
      int progress,
      int aqi,
      String? timeToWorstZone,
      String? distanceToWorstZone) {
    // Create notification text with time and distance info if available
    String notificationText =
        'Near $stationName ($progress%) - AQI: $aqi (${_getAqiLevel(aqi)})';

    if (timeToWorstZone != null && distanceToWorstZone != null) {
      notificationText +=
          '\nHighest pollution zone in $timeToWorstZone ($distanceToWorstZone ahead)';
    }

    final snackBar = SnackBar(
      content: Text(notificationText),
      backgroundColor: _getAqiSnackbarColor(aqi),
      duration: const Duration(
          seconds: 5), // Increased duration to read the additional info
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Color _getAqiSnackbarColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow.shade700;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  static Future<void> hideRouteProgressNotification() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('hideRouteProgressNotification');
    } catch (e) {
      print("Error hiding Android notification: $e");

      // Clear any snackbars if a context is available
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    }
  }

  static String _getAqiLevel(int aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }
}
