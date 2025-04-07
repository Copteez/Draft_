import 'package:flutter/material.dart';

class FloatingOptions extends StatefulWidget {
  final VoidCallback onRouteSearch;
  final VoidCallback onFilter;
  final VoidCallback onReset;
  final bool isDarkMode;

  const FloatingOptions({
    Key? key,
    required this.onRouteSearch,
    required this.onFilter,
    required this.onReset,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _FloatingOptionsState createState() => _FloatingOptionsState();
}

class _FloatingOptionsState extends State<FloatingOptions> {
  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.isDarkMode ? const Color(0xFF2D3250) : Colors.white;
    final iconColor = widget.isDarkMode ? Colors.white : Colors.black;
    final highlightColor =
        widget.isDarkMode ? Colors.orange[800] : Colors.orange[300];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'routeSearch',
          backgroundColor: backgroundColor,
          highlightElevation: 8,
          splashColor: highlightColor,
          onPressed: widget.onRouteSearch,
          child: Icon(Icons.directions, color: iconColor),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'filter',
          backgroundColor: backgroundColor,
          highlightElevation: 8,
          splashColor: highlightColor,
          onPressed: widget.onFilter,
          child: Icon(Icons.filter_list, color: iconColor),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'reset',
          backgroundColor: backgroundColor,
          highlightElevation: 8,
          splashColor: highlightColor,
          onPressed: widget.onReset,
          child: Icon(Icons.refresh, color: iconColor),
        ),
      ],
    );
  }
}
