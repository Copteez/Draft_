import 'package:flutter/material.dart';

class AQICard extends StatelessWidget {
  final bool isDarkMode;

  final String startCity;
  final String endCity;
  final int startAqi;
  final String startAqiLabel;
  final Color startAqiColor;
  final int endAqi;
  final String endAqiLabel;
  final Color endAqiColor;
  final String summaryMessage;

  const AQICard({
    Key? key,
    required this.isDarkMode,
    required this.startCity,
    required this.endCity,
    required this.startAqi,
    required this.startAqiLabel,
    required this.startAqiColor,
    required this.endAqi,
    required this.endAqiLabel,
    required this.endAqiColor,
    required this.summaryMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // กำหนดสีตาม Dark/Light Mode
    final Color cardBgColor =
        isDarkMode ? const Color(0xFF545978) : Colors.white;
    final Color mainTextColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor =
        isDarkMode ? Colors.grey[300]! : Colors.grey[600]!;
    final Color containerBg =
        isDarkMode ? const Color(0xFF444C63) : Colors.grey[100]!;

    return Card(
      color: cardBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title: e.g. "Bangkok → Tokyo, Japan"
            Text(
              "$startCity → $endCity",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: mainTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              "Air Quality Index Transition",
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 20),

            // AQI Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Start AQI
                Column(
                  children: [
                    Text(
                      "$startAqi",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: startAqiColor,
                      ),
                    ),
                    Text(
                      startAqiLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: startAqiColor,
                      ),
                    ),
                  ],
                ),

                // Arrow Icon
                const Icon(
                  Icons.arrow_forward,
                  size: 32,
                  color: Colors.grey,
                ),

                // End AQI
                Column(
                  children: [
                    Text(
                      "$endAqi",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: endAqiColor,
                      ),
                    ),
                    Text(
                      endAqiLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: endAqiColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Summary message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                summaryMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: mainTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
