import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/aqi_utils.dart';

/// ฟังก์ชันหลักสำหรับสร้าง widget กราฟ AQI
/// เพิ่ม parameter BuildContext เพื่อคำนวณความกว้างหน้าจอ
Widget buildAQIGraph({
  required BuildContext context,
  required bool isDarkMode,
  required bool isHistoryMode,
  required List<FlSpot> aqiData,
  required List<FlSpot> historyData,
  required List<String> historyLabels,
  required String selectedHistoryView,
  required String forecastText,
  required VoidCallback onToggleHistoryMode,
  required Function(String) onHistoryViewChange,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF545978) : const Color(0xFFEDEDED),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and toggle button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isHistoryMode ? "History" : "24 Hours Forecast",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: onToggleHistoryMode,
              child: Text(
                isHistoryMode ? "View forecast" : "View history",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        isHistoryMode
            ? _buildHistoryGraph(
                context: context,
                isDarkMode: isDarkMode,
                historyData: historyData,
                historyLabels: historyLabels,
                selectedHistoryView: selectedHistoryView,
                onHistoryViewChange: onHistoryViewChange,
              )
            : _buildForecastGraph(context, aqiData, isDarkMode, forecastText),
      ],
    ),
  );
}

/// ฟังก์ชันสำหรับสร้างกราฟ Forecast (24 Hours)
Widget _buildForecastGraph(BuildContext context, List<FlSpot> aqiData,
    bool isDarkMode, String forecastText) {
  double maxY = aqiData.isNotEmpty
      ? aqiData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
      : 300;
  maxY = ((maxY + 50) / 50).ceil() * 50.0;
  DateTime now = DateTime.now();

  // คำนวณความกว้างของกราฟ: หากหน้าจอกว้างกว่าขนาดกราฟที่คำนวณได้ ให้ยืดออกจนพอดี
  double computedWidth = aqiData.isNotEmpty ? (aqiData.last.x + 2) * 40 : 300;
  double screenWidth =
      MediaQuery.of(context).size.width - 32; // 16px padding ทั้งสองด้าน
  double chartWidth = computedWidth < screenWidth ? screenWidth : computedWidth;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: chartWidth,
          height: 320,
          child: LineChart(
            LineChartData(
              minX: -1,
              maxX: aqiData.isNotEmpty ? aqiData.last.x + 2 : 25,
              minY: 0,
              maxY: maxY,
              titlesData: FlTitlesData(
                leftTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 50,
                  getTextStyles: (context, value) => TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  getTitles: (value) => value.toInt().toString(),
                ),
                bottomTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  interval: 1,
                  getTitles: (value) {
                    int index = value.toInt();
                    if (index < 0 || index >= aqiData.length) return '';
                    DateTime timeLabel = now.add(Duration(hours: index));
                    String formattedTime = "${timeLabel.hour}:00";
                    int aqiValue = aqiData[index].y.toInt();
                    return "$formattedTime\nAQI\n$aqiValue";
                  },
                  getTextStyles: (context, value) {
                    int index = value.toInt();
                    if (index < 0 || index >= aqiData.length)
                      return const TextStyle(fontSize: 10);
                    double aqiValue = aqiData[index].y;
                    Color aqiColor = getAQIColor(aqiValue.toInt());
                    return TextStyle(
                      fontSize: 10,
                      color: aqiColor,
                      fontWeight: FontWeight.bold,
                    );
                  },
                  margin: 10,
                ),
                topTitles: SideTitles(showTitles: false),
                rightTitles: SideTitles(showTitles: false),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: aqiData,
                  isCurved: true,
                  colors: [isDarkMode ? Colors.white : Colors.black],
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// ฟังก์ชันสำหรับสร้างกราฟ History พร้อมปุ่ม filter (month/day/hour)
Widget _buildHistoryGraph({
  required BuildContext context,
  required bool isDarkMode,
  required List<FlSpot> historyData,
  required List<String> historyLabels,
  required String selectedHistoryView,
  required Function(String) onHistoryViewChange,
}) {
  double maxY = historyData.isNotEmpty
      ? historyData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
      : 300;
  maxY = ((maxY + 50) / 50).ceil() * 50.0;
  double computedWidth =
      historyData.isNotEmpty ? (historyData.last.x + 1) * 40 : 300;
  double screenWidth = MediaQuery.of(context).size.width - 32;
  double chartWidth = computedWidth < screenWidth ? screenWidth : computedWidth;

  Widget buildFilterButton(String type) {
    bool isSelected = (selectedHistoryView == type);
    return GestureDetector(
      onTap: () => onHistoryViewChange(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[400],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type.toUpperCase(),
          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            "View by: ",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          buildFilterButton("month"),
          buildFilterButton("day"),
          buildFilterButton("hour"),
        ],
      ),
      const SizedBox(height: 15),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: chartWidth,
          height: 250,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: historyData.isNotEmpty ? historyData.last.x + 1 : 10,
              minY: 0,
              maxY: maxY,
              titlesData: FlTitlesData(
                leftTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 50,
                  getTextStyles: (context, value) => TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  getTitles: (value) => value.toInt().toString(),
                ),
                bottomTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  interval: 1,
                  getTitles: (value) {
                    int index = value.toInt();
                    if (index < 0 || index >= historyData.length) return '';
                    String label = historyLabels[index];
                    int aqiValue = historyData[index].y.toInt();
                    return "$label\nAQI\n$aqiValue";
                  },
                  getTextStyles: (context, value) {
                    int index = value.toInt();
                    if (index < 0 || index >= historyData.length)
                      return const TextStyle(fontSize: 10);
                    double aqiValue = historyData[index].y;
                    Color aqiColor = getAQIColor(aqiValue.toInt());
                    return TextStyle(
                      fontSize: 10,
                      color: aqiColor,
                      fontWeight: FontWeight.bold,
                    );
                  },
                  margin: 10,
                ),
                topTitles: SideTitles(showTitles: false),
                rightTitles: SideTitles(showTitles: false),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: historyData,
                  isCurved: true,
                  colors: [isDarkMode ? Colors.white : Colors.black],
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
