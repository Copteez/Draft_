import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ฟังก์ชันสำหรับสร้าง Drawer สำหรับหน้า Home
Widget buildDrawer({required BuildContext context, required bool isDarkMode}) {
  final Color backgroundColor =
      isDarkMode ? const Color(0xFF2C2C47) : Colors.white;
  final Color textColor = isDarkMode ? Colors.white : Colors.black;
  final Color iconColor = isDarkMode ? Colors.white : Colors.black;

  return Drawer(
    backgroundColor: backgroundColor,
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 50),
        ListTile(
          leading: Icon(CupertinoIcons.house_fill, color: iconColor),
          title: Text("Home", style: TextStyle(color: textColor)),
          onTap: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (Route<dynamic> route) => false,
            );
          },
        ),
        ListTile(
          leading: Icon(CupertinoIcons.location_fill, color: iconColor),
          title: Text("Path Finder", style: TextStyle(color: textColor)),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/map');
          },
        ),
        ExpansionTile(
          leading: Icon(CupertinoIcons.heart_fill, color: iconColor),
          title: Text("Favorites", style: TextStyle(color: textColor)),
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.map_fill, color: iconColor),
              title: Text("Favorite Path", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/favorite_path');
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.location_solid, color: iconColor),
              title:
                  Text("Favorite Location", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/favorite_location');
              },
            ),
          ],
        ),
        ExpansionTile(
          leading: Icon(CupertinoIcons.clock, color: iconColor),
          title: Text("History", style: TextStyle(color: textColor)),
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.clock_fill, color: iconColor),
              title: Text("History Paths", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history_path');
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.time, color: iconColor),
              title:
                  Text("History Locations", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history_location');
              },
            ),
          ],
        ),
      ],
    ),
  );
}
