import 'package:flutter/material.dart';
import 'map_route_models.dart';
import 'map_route_progress.dart' as rp;

class RouteBottomSheet extends StatefulWidget {
  final List<RouteCalculation> stations;
  final String? nearestStationName;
  final double totalRouteDistance;
  final bool isDarkMode;
  final VoidCallback? onClose;
  final DateTime? estimatedArrivalTime;
  final int? predictedDestinationAqi;

  const RouteBottomSheet({
    Key? key,
    required this.stations,
    required this.nearestStationName,
    required this.totalRouteDistance,
    required this.isDarkMode,
    this.onClose,
    this.estimatedArrivalTime,
    this.predictedDestinationAqi,
  }) : super(key: key);

  @override
  _RouteBottomSheetState createState() => _RouteBottomSheetState();
}

class _RouteBottomSheetState extends State<RouteBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return rp.RouteProgressDisplay(
      stations: widget.stations,
      nearestStationName: widget.nearestStationName,
      totalRouteDistance: widget.totalRouteDistance,
      isDarkMode: widget.isDarkMode,
      onClose: () {
        if (widget.onClose != null) {
          widget.onClose!();
        }
      },
      estimatedArrivalTime: widget.estimatedArrivalTime,
      predictedDestinationAqi: widget.predictedDestinationAqi,
    );
  }
}
