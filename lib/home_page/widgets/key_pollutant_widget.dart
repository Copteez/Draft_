import 'package:flutter/material.dart';

/// Fixed fractions สำหรับ 6 ระดับสี
List<double> fixedFractions = [0.16, 0.32, 0.48, 0.64, 0.72, 1.0];

/// สีไล่ระดับ 6 สี
List<Color> gradientColors = [
  Colors.green, // Good
  Colors.yellow, // Moderate
  Colors.orange, // Unhealthy (SG)
  Colors.red, // Unhealthy
  Colors.purple, // Very Unhealthy
  Colors.brown, // Hazardous
];

/// กำหนด thresholds สำหรับค่าฝุ่นและค่าทางอุตุนิยมวิทยา (6 ระดับ)
Map<String, List<double>> pollutantThresholds = {
  // ค่าฝุ่นตาม WAQI
  "pm2.5": [12, 35.4, 55.4, 150.4, 250.4, 500.0],
  "pm10": [54, 154, 254, 354, 424, 600.0],
  "o3": [54, 70, 85, 105, 200, 300.0],
  "so2": [35, 75, 185, 304, 604, 1000.0],

  // ค่าทางอุตุนิยมวิทยา (กำหนดเกณฑ์ใหม่)
  "dew": [-5, 5, 10, 15, 20, 25], // Dew Point (°C)
  "wind": [0, 2, 4, 6, 8, 12], // Wind Speed (m/s)
  "humidity": [20, 40, 60, 70, 80, 100], // Humidity (%)
  "pressure": [980, 990, 1010, 1020, 1030, 1040], // Pressure (hPa)
  "temperature": [0, 10, 20, 25, 30, 40], // Temperature (°C)
};

/// คำนวณ progress ของ bar โดยอินเตอร์โพลเลชันแบบ linear ระหว่าง thresholds
double getProgress(String pollutant, double value) {
  if (value == -999) return 0.0;
  List<double>? thresholds = pollutantThresholds[pollutant.toLowerCase()];
  if (thresholds == null || thresholds.isEmpty) return 0.0;
  if (value <= thresholds.first) return fixedFractions.first;
  if (value >= thresholds.last) return fixedFractions.last;
  for (int i = 0; i < thresholds.length - 1; i++) {
    if (value <= thresholds[i + 1]) {
      double fraction = fixedFractions[i] +
          ((value - thresholds[i]) / (thresholds[i + 1] - thresholds[i])) *
              (fixedFractions[i + 1] - fixedFractions[i]);
      return fraction.clamp(0.0, 1.0);
    }
  }
  return fixedFractions.last;
}

/// คืนค่าสีสำหรับค่า pollutant ตามช่วงที่ value ตกอยู่
Color getColor(String pollutant, double value) {
  if (value == -999) return Colors.grey;
  List<double>? thresholds = pollutantThresholds[pollutant.toLowerCase()];
  if (thresholds == null || thresholds.isEmpty) return Colors.grey;
  if (value <= thresholds.first) return gradientColors.first;
  if (value >= thresholds.last) return gradientColors.last;
  for (int i = 0; i < thresholds.length - 1; i++) {
    if (value <= thresholds[i + 1]) {
      return gradientColors[i.clamp(0, gradientColors.length - 1)];
    }
  }
  return gradientColors.last;
}

/// Widget สำหรับแสดงรายละเอียด Key Pollutant และ additional parameters
class KeyPollutantWidget extends StatelessWidget {
  final double pm25, pm10, o3, so2, dew, wind, humidity, pressure, temperature;
  final bool isDarkMode;

  const KeyPollutantWidget({
    Key? key,
    required this.pm25,
    required this.pm10,
    required this.o3,
    required this.so2,
    required this.dew,
    required this.wind,
    required this.humidity,
    required this.pressure,
    required this.temperature,
    required this.isDarkMode,
  }) : super(key: key);

  /// สร้าง row สำหรับแสดงค่าพารามิเตอร์ ถ้าไม่มีข้อมูล (value == -999) ไม่แสดง
  Widget buildRow(String name, double value, String unit) {
    // หากไม่มีข้อมูลสำหรับอุตุนิยม (value == -999) หรือสำหรับค่าฝุ่น (pm2.5, pm10, o3, so2) ที่ค่า -1
    if (value == -999 ||
        (["pm2.5", "pm10", "o3", "so2"].contains(name.toLowerCase()) &&
            value == -1)) return const SizedBox.shrink();
    Color color = getColor(name, value);
    double progress = getProgress(name, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const Spacer(),
            Text(
              "${value.toStringAsFixed(1)} $unit",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF545978) : const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Key Pollutant",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          buildRow("PM2.5", pm25, "µg/m³"),
          buildRow("PM10", pm10, "µg/m³"),
          buildRow("O3", o3, "ppb"),
          buildRow("SO2", so2, "ppb"),
          buildRow("Dew Point", dew, "°C"),
          buildRow("Wind Speed", wind, "m/s"),
          buildRow("Humidity", humidity, "%"),
          buildRow("Pressure", pressure, "hPa"),
          buildRow("Temperature", temperature, "°C"),
        ],
      ),
    );
  }
}
