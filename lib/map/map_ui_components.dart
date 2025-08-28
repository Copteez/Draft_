import 'package:flutter/material.dart';
import 'map_route_models.dart';
import 'map_route_utils.dart';
import 'package:intl/intl.dart';

Widget buildCustomInfoWindow(
  Map<String, dynamic> station,
  bool isDarkMode, {
  VoidCallback? onClose,
  VoidCallback? onSaveFavorite,
  VoidCallback? onViewDetails,
  bool isFavorite = false,
}) {
  final aqi = int.tryParse(station['aqi']?.toString() ?? '0') ?? 0;
  final stationName = station['station_name'] ?? 'Unknown Station';

  // Remove timestamp display

  return Card(
    margin: EdgeInsets.zero, // Remove card margin
    elevation: 0, // Remove card elevation/shadow
    color: isDarkMode
        ? const Color(0xFF2D3250)
        : Colors.white, // Match container color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero, // Remove rounded corners
    ),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stationName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: getAQIColor(aqi),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'AQI: $aqi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 4),
          Row(
            children: [
              if (onSaveFavorite != null)
                OutlinedButton.icon(
                  onPressed: onSaveFavorite,
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: isFavorite
                        ? (isDarkMode ? Colors.amber : Colors.orange)
                        : (isDarkMode ? Colors.amber : Colors.orange),
                  ),
                  label: Text(
                    isFavorite ? 'Remove Favorite' : 'Save to Favorites',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color:
                            isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              const Spacer(),
              if (onViewDetails != null)
                TextButton.icon(
                  onPressed: onViewDetails,
                  icon: Icon(Icons.arrow_forward,
                      size: 16,
                      color: isDarkMode ? Colors.blue[300] : Colors.blue),
                  label: Text(
                    'Details',
                    style: TextStyle(
                      color: isDarkMode ? Colors.blue[300] : Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget buildSegmentItem(
    RouteOption option, int index, bool isDarkMode, String? nearestStation) {
  final calc = option.calculations[index];

  return ListTile(
    leading: calc.stationName == nearestStation
        ? const Icon(Icons.arrow_forward, color: Colors.blue)
        : const SizedBox(width: 24),
    title: Text(
      calc.stationName,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontWeight: calc.stationName == nearestStation
            ? FontWeight.bold
            : FontWeight.normal,
      ),
    ),
    subtitle: Text(
      'AQI: ${calc.aqi}',
      style: TextStyle(
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    ),
  );
}

void showSegmentInfo(BuildContext context, RouteSegment segment) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Segment Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AQI: ${segment.aqi.toStringAsFixed(2)}'),
            if (segment.nearbyStations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Nearest Station:'),
              ListTile(
                title: Text(segment.nearbyStations[0]['name']),
                subtitle: Text(
                  'Distance: ${segment.nearbyStations[0]['distance'].toStringAsFixed(2)} km',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
