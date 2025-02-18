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
    child: Column(
      children: [
        const SizedBox(height: 50),
        ListTile(
          leading: Icon(CupertinoIcons.house_fill, color: iconColor),
          title: Text("Home", style: TextStyle(color: textColor)),
          onTap: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home', // ระบุชื่อ route สำหรับหน้า Home
              (Route<dynamic> route) => false, // ลบ route อื่นทั้งหมด
            );
          },
        ),
        ListTile(
          leading: Icon(CupertinoIcons.location_fill, color: iconColor),
          title: Text("Path Finder", style: TextStyle(color: textColor)),
          onTap: () {
            Navigator.pop(context); // ปิด Drawer ก่อน
            Navigator.pushNamed(context, '/map');
          },
        ),
        ListTile(
          leading: Icon(CupertinoIcons.heart_fill, color: iconColor),
          title: Text("Favorite Locations", style: TextStyle(color: textColor)),
          onTap: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
