import 'package:flutter/material.dart';

/// ฟังก์ชันสำหรับสร้างป้ายสีแสดงระดับค่า AQI
Widget buildAQILabels({required bool isDarkMode}) {
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAQILabel("Good", const Color(0xFFABD162), isDarkMode),
          const SizedBox(width: 15),
          _buildAQILabel("Moderate", const Color(0xFFF8D461), isDarkMode),
          const SizedBox(width: 15),
          _buildAQILabel("Unhealthy (SG)", const Color(0xFFFB9956), isDarkMode),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAQILabel("Unhealthy", const Color(0xFFF6686A), isDarkMode),
          const SizedBox(width: 15),
          _buildAQILabel("Very Unhealthy", const Color(0xFFA47DB8), isDarkMode),
          const SizedBox(width: 15),
          _buildAQILabel("Hazardous", const Color(0xFFA07785), isDarkMode),
        ],
      ),
    ],
  );
}

/// ฟังก์ชันสร้างป้ายสีแต่ละอัน
Widget _buildAQILabel(String text, Color color, bool isDarkMode) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        text,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 12,
        ),
      ),
    ],
  );
}
