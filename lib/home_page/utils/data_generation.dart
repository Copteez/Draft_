import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

void generateRandomAQIData({
  required void Function(
          List<FlSpot> aqiData, String forecastText, double highestAQI)
      onDataGenerated,
}) {
  List<FlSpot> aqiData = [];
  Random random = Random();
  int maxAQI = 0;
  int maxHour = 0;

  for (int i = 0; i < 24; i++) {
    int aqi = random.nextInt(300) + 1;
    aqiData.add(FlSpot(i.toDouble(), aqi.toDouble()));
    if (aqi > maxAQI) {
      maxAQI = aqi;
      maxHour = i;
    }
  }

  String forecastText = "The AQI is expected to reach $maxAQI at ${maxHour}:00";
  onDataGenerated(aqiData, forecastText, maxAQI.toDouble());
}
