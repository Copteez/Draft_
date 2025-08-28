import 'package:flutter/material.dart';

enum MenuAction {
  pathFinder,
  filterStations,
  toggleProgress,
  toggleAlerts,
  reset
}

class FloatingOptions extends StatefulWidget {
  final VoidCallback onPathFinder;
  final VoidCallback onFilter;
  final VoidCallback onReset;
  final VoidCallback onToggleProgress;
  final VoidCallback onToggleAlerts;
  final bool isProgressVisible;
  final bool alertsEnabled;
  final bool hasActiveRoute;
  final bool isDarkMode;

  const FloatingOptions({
    Key? key,
    required this.onPathFinder,
    required this.onFilter,
    required this.onReset,
    required this.onToggleProgress,
    required this.onToggleAlerts,
    required this.isProgressVisible,
    required this.alertsEnabled,
    required this.hasActiveRoute,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _FloatingOptionsState createState() => _FloatingOptionsState();
}

class _FloatingOptionsState extends State<FloatingOptions> {
  final GlobalKey _fabKey = GlobalKey();

  Future<void> _showMenu() async {
    final RenderBox button =
        _fabKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset position =
        button.localToGlobal(Offset(button.size.width, 0), ancestor: overlay);
    final RelativeRect rect = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay.size.width - position.dx,
      overlay.size.height - position.dy,
    );

    final result = await showMenu<MenuAction>(
      context: context,
      position: rect,
      color: const Color(0xFF2D3250),
      items: [
        PopupMenuItem<MenuAction>(
          value: MenuAction.pathFinder,
          child: Row(
            children: const [
              Icon(Icons.directions, color: Colors.white),
              SizedBox(width: 12),
              Text('Path finder', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem<MenuAction>(
          value: MenuAction.filterStations,
          child: Row(
            children: const [
              Icon(Icons.filter_list, color: Colors.white),
              SizedBox(width: 12),
              Text('Filter stations', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem<MenuAction>(
          value: MenuAction.toggleProgress,
          enabled: widget.hasActiveRoute,
          child: Row(
            children: [
              Icon(
                  widget.isProgressVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.isProgressVisible ? 'Hide progress' : 'Show progress',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem<MenuAction>(
          value: MenuAction.toggleAlerts,
          enabled: widget.hasActiveRoute,
          child: Row(
            children: [
              Icon(
                  widget.alertsEnabled
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                  color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.alertsEnabled ? 'Disable alerts' : 'Enable alerts',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<MenuAction>(
          value: MenuAction.reset,
          child: Row(
            children: const [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 12),
              Text('Reset map', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );

    switch (result) {
      case MenuAction.pathFinder:
        widget.onPathFinder();
        break;
      case MenuAction.filterStations:
        widget.onFilter();
        break;
      case MenuAction.toggleProgress:
        widget.onToggleProgress();
        break;
      case MenuAction.toggleAlerts:
        widget.onToggleAlerts();
        break;
      case MenuAction.reset:
        widget.onReset();
        break;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF2D3250);
    const iconColor = Colors.white;

    return FloatingActionButton(
      key: _fabKey,
      heroTag: 'menuFab',
      backgroundColor: backgroundColor,
      onPressed: _showMenu,
      child: Icon(Icons.menu, color: iconColor),
    );
  }
}
