import 'package:flutter/material.dart';
import 'map_route_models.dart';
import 'map_route_utils.dart';

class RouteProgressDisplay extends StatefulWidget {
  final List<RouteCalculation> stations;
  final String? nearestStationName;
  final double totalRouteDistance;
  final bool isDarkMode;
  final Function()? onClose;
  final DateTime? estimatedArrivalTime;
  final int? predictedDestinationAqi;
  final int currentProgress;
  // Add new properties for favorites
  final bool isFavorite;
  final Function()? onToggleFavorite;

  const RouteProgressDisplay({
    Key? key,
    required this.stations,
    required this.nearestStationName,
    required this.totalRouteDistance,
    required this.isDarkMode,
    this.onClose,
    this.estimatedArrivalTime,
    this.predictedDestinationAqi,
    this.currentProgress = 0,
    this.isFavorite = false,
    this.onToggleFavorite,
  }) : super(key: key);

  @override
  _RouteProgressDisplayState createState() => _RouteProgressDisplayState();
}

class _RouteProgressDisplayState extends State<RouteProgressDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.isDarkMode ? const Color(0xFF2D3250) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    final dividerColor =
        widget.isDarkMode ? Colors.grey[700] : Colors.grey[300];

    if (widget.stations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: backgroundColor,
      elevation: 8,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Limit the panel to 60% of screen height; remaining content scrolls
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with toggle and close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.navigation,
                        color: widget.isDarkMode ? Colors.orange : Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Route Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Remove star button from here
                      IconButton(
                        icon: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: textColor,
                        ),
                        onPressed: _toggleExpanded,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      if (widget.onClose != null)
                        IconButton(
                          icon: Icon(Icons.close, color: textColor),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Current location summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _buildLocationSummary(textColor, subtitleColor),
            ),

            // Add predicted destination AQI
            if (widget.predictedDestinationAqi != null &&
                widget.estimatedArrivalTime != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? Colors.blueGrey[800]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Predicted AQI at Arrival:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${_formatArrivalTime(widget.estimatedArrivalTime!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDarkMode
                                  ? Colors.white60
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: getAQIColor(widget.predictedDestinationAqi!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${widget.predictedDestinationAqi}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Add Favorite Button Section - NEW SECTION
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InkWell(
                onTap: widget.onToggleFavorite,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? (widget.isFavorite
                            ? Colors.amber.withOpacity(0.2)
                            : Colors.blueGrey[800])
                        : (widget.isFavorite
                            ? Colors.amber.withOpacity(0.1)
                            : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          widget.isFavorite ? Colors.amber : Colors.transparent,
                      width: widget.isFavorite ? 1 : 0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isFavorite ? Icons.star : Icons.star_border,
                        color: widget.isFavorite ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isFavorite
                            ? 'Saved to Favorites'
                            : 'Save to Favorites',
                        style: TextStyle(
                          color: widget.isFavorite
                              ? Colors.amber
                              : (widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[700]),
                          fontWeight: widget.isFavorite
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expanded stations list
            SizeTransition(
              sizeFactor: _animation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(color: dividerColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: _buildProgressStations(textColor, subtitleColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ), // Column
      ), // ConstrainedBox
    ); // Material
  }

  Widget _buildLocationSummary(Color textColor, Color subtitleColor) {
    String currentStation = "Unknown location";
    String progress = "0%";

    if (widget.nearestStationName != null) {
      // Get the current station data
      final station = widget.stations.firstWhere(
        (s) => s.stationName == widget.nearestStationName,
        orElse: () => widget.stations.first,
      );

      currentStation = station.stationName;

      // Calculate progress percentage based on user's actual position relative to full route
      if (widget.totalRouteDistance > 0) {
        // Use the current station's position as the user's approximate position along the route
        double userProgressDistance = station.startDistance;

        // Calculate percentage of total route traversed
        double progressPercentage =
            userProgressDistance / widget.totalRouteDistance;
        progress = "${(progressPercentage * 100).toInt()}%";
      }
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? Colors.blueGrey[800] : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add tooltip to summary display to show full station name
              Tooltip(
                message: currentStation,
                child: Text(
                  currentStation,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "Current progress: $progress of route",
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStations(Color textColor, Color subtitleColor) {
    // Create progress indicator that shows all stations
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Route Stations',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 90, // Decreased height to reduce space requirements
          child: ListView.separated(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: widget.stations.length,
            separatorBuilder: (context, index) => _buildStationConnector(),
            itemBuilder: (context, index) {
              final station = widget.stations[index];
              final isCurrentStation =
                  station.stationName == widget.nearestStationName;

              return _buildStationBubble(
                station,
                isCurrentStation,
                textColor,
                subtitleColor,
                index == 0, // isStart
                index == widget.stations.length - 1, // isEnd
              );
            },
          ),
        ),
        // Route progress bar
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: widget.currentProgress /
              100.0, // Convert percentage to 0.0-1.0 value
          backgroundColor:
              widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.isDarkMode ? Colors.orange : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.currentProgress}% of route completed',
          style: TextStyle(
            fontSize: 12,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStationBubble(
    RouteCalculation station,
    bool isCurrentStation,
    Color textColor,
    Color subtitleColor,
    bool isStart,
    bool isEnd,
  ) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentStation
                  ? widget.isDarkMode
                      ? Colors.orange
                      : Colors.blue
                  : widget.isDarkMode
                      ? Colors.blueGrey[800]
                      : Colors.grey[200],
              border: Border.all(
                color: isCurrentStation
                    ? widget.isDarkMode
                        ? Colors.orangeAccent
                        : Colors.blueAccent
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: isStart
                  ? Icon(Icons.play_arrow,
                      color: isCurrentStation ? Colors.white : subtitleColor)
                  : isEnd
                      ? Icon(Icons.flag,
                          color:
                              isCurrentStation ? Colors.white : subtitleColor)
                      : Icon(Icons.location_on,
                          color:
                              isCurrentStation ? Colors.white : subtitleColor),
            ),
          ),
          const SizedBox(height: 4),
          // Updated station name display - removed fixed height constraint
          Expanded(
            child: Tooltip(
              message: station.stationName,
              child: Text(
                station.stationName,
                style: TextStyle(
                  fontSize: 10, // Slightly smaller font
                  fontWeight:
                      isCurrentStation ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentStation
                      ? (widget.isDarkMode ? Colors.orange : Colors.blue)
                      : textColor,
                ),
                maxLines: 1, // Fixed to 1 line to prevent overflow
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Text(
            'AQI: ${station.aqi}',
            style: TextStyle(
              fontSize: 10,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationConnector() {
    return Container(
      width: 20,
      alignment: Alignment.center,
      child: Container(
        height: 2,
        width: 20,
        color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
      ),
    );
  }

  // Removed unused _calculateRouteProgress helper to reduce warnings

  // Format arrival time in a user-friendly way
  String _formatArrivalTime(DateTime arrivalTime) {
    final now = DateTime.now();
    final difference = arrivalTime.difference(now);
    final bool isSameDay = arrivalTime.day == now.day &&
        arrivalTime.month == now.month &&
        arrivalTime.year == now.year;

    // Format hour and minute
    final String hour = arrivalTime.hour.toString().padLeft(2, '0');
    final String minute = arrivalTime.minute.toString().padLeft(2, '0');
    final String timeStr = '$hour:$minute';

    // For today's arrivals
    if (isSameDay) {
      if (difference.inMinutes < 60) {
        return 'In ${difference.inMinutes} minutes (at $timeStr)';
      } else {
        return 'Today at $timeStr (in ~${difference.inHours} hours)';
      }
    }
    // For tomorrow arrivals
    else if (arrivalTime.day == now.day + 1 &&
        arrivalTime.month == now.month &&
        arrivalTime.year == now.year) {
      return 'Tomorrow at $timeStr';
    }
    // For other days
    else {
      final String day = arrivalTime.day.toString().padLeft(2, '0');
      final String month = arrivalTime.month.toString().padLeft(2, '0');
      return 'On $day/$month at $timeStr';
    }
  }
}
