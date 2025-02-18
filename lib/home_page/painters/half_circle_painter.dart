import 'dart:math' as math;
import 'package:flutter/material.dart';

class HalfCirclePainter extends CustomPainter {
  final Color color;
  final double progress; // ค่า progress อยู่ในช่วง 0.0 ถึง 1.0

  HalfCirclePainter(this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // วาด arc ครึ่งวงกลม โดยใช้ progress เป็นตัวกำหนดมุมที่วาด
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height * 2),
      math.pi,
      math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
