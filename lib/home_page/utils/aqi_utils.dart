import 'package:flutter/material.dart';

String getAQILevel(int aqi) {
  if (aqi <= 50) return "Good";
  if (aqi <= 100) return "Moderate";
  if (aqi <= 150) return "Unhealthy for Sensitive Groups";
  if (aqi <= 200) return "Unhealthy";
  if (aqi <= 300) return "Very Unhealthy";
  return "Hazardous";
}

String getAQIAdvice(int aqi) {
  if (aqi <= 50) return "Air quality is good. No health risk.";
  if (aqi <= 100)
    return "Air is acceptable. Sensitive individuals should be cautious.";
  if (aqi <= 150) return "Sensitive groups should reduce outdoor activity.";
  if (aqi <= 200) return "Everyone should limit outdoor activity.";
  if (aqi <= 300) return "Health warnings issued. Stay indoors.";
  return "Serious health risk. Avoid outdoor activities!";
}

Color getAQIColor(int aqi) {
  if (aqi <= 50) return const Color(0xFFABD162);
  if (aqi <= 100) return const Color(0xFFF8D461);
  if (aqi <= 150) return const Color(0xFFFB9956);
  if (aqi <= 200) return const Color(0xFFF6686A);
  if (aqi <= 300) return const Color(0xFFA47DB8);
  return const Color(0xFFA07785);
}

String getMonthShortName(int month) {
  List<String> months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec"
  ];
  return months[month - 1];
}
