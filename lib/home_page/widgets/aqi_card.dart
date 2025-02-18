import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../painters/half_circle_painter.dart';
import '../utils/aqi_utils.dart';

/// ฟังก์ชันสำหรับสร้างการ์ดแสดงข้อมูล AQI
Widget buildAQICard({
  required bool isDarkMode,
  required Map<String, dynamic>? nearestStation,
  required String lastUpdated,
}) {
  // ดึงค่า AQI จากข้อมูลสถานี ถ้าไม่มีให้ค่าเป็น 0
  int aqi = nearestStation?["aqi"] ?? 0;
  String stationName = nearestStation?["station_name"] ?? "Unknown";

  // ใช้ฟังก์ชันช่วยจาก aqi_utils.dart เพื่อดึงระดับ, คำแนะนำ, และสีตามค่า AQI
  String level = getAQILevel(aqi);
  String advice = getAQIAdvice(aqi);
  Color color = getAQIColor(aqi);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        stationName,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.time,
            color: isDarkMode ? Colors.white70 : Colors.black54,
            size: 18,
          ),
          const SizedBox(width: 5),
          Text(
            "Updated 1 hours ago",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Container(
        height: 150,
        width: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(190, 100),
              painter: HalfCirclePainter(color, aqi / 300),
            ),
            Positioned(
              bottom: 15,
              child: Column(
                children: [
                  Text(
                    "$aqi",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "AQI Index Quality",
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 25),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.privacy_tip, color: color, size: 28),
          const SizedBox(width: 5),
          Text(
            level,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        advice,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    ],
  );
}
