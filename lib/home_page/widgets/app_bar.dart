import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Add this import
import '../../theme_provider.dart'; // Add this import

/// ฟังก์ชันสำหรับสร้าง AppBar ที่ใช้ในหน้า Home
PreferredSizeWidget buildCustomAppBar({
  required bool isDarkMode,
  required ValueChanged<bool> onThemeToggle,
}) {
  // กำหนดสีพื้นหลังตามธีมที่เลือก
  final Color backgroundColor =
      isDarkMode ? const Color(0xFF2C2C47) : Colors.white;

  return AppBar(
    backgroundColor: backgroundColor,
    elevation: 0,
    // ใช้ Builder เพื่อให้สามารถเรียกใช้ openDrawer() จาก context ของ Scaffold ได้
    leading: Builder(
      builder: (context) => IconButton(
        icon: Icon(
          CupertinoIcons.bars,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    ),
    actions: [
      Row(
        children: [
          Icon(
            isDarkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 24,
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) => Switch(
              value: themeProvider.isDarkMode,
              onChanged: onThemeToggle,
              activeColor: Colors.orange,
              inactiveThumbColor: Colors.grey,
              activeTrackColor: Colors.orange.withOpacity(0.5),
              inactiveTrackColor: Colors.grey.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    ],
  );
}
