import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_route_utils.dart';

Future<BitmapDescriptor> createCustomMarker(int aqi) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()..color = getAQIColor(aqi);
  const double radius = 60.0;

  canvas.drawCircle(const Offset(radius, radius), radius, paint);

  TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: aqi.toString(),
      style: const TextStyle(
          fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  textPainter.paint(canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));

  final img = await pictureRecorder
      .endRecording()
      .toImage((radius * 2).toInt(), (radius * 2).toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

Future<BitmapDescriptor> createUserLocationIcon() async {
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);
  const size = Size(140, 140);

  // Draw outer circle (glowing effect)
  final Paint outerPaint = Paint()
    ..color = Colors.blue.withOpacity(0.3)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(70, 70), 70, outerPaint);

  // Draw middle circle
  final Paint middlePaint = Paint()
    ..color = Colors.blue.withOpacity(0.5)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(70, 70), 40, middlePaint);

  // Draw inner circle
  final Paint innerPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(70, 70), 20, innerPaint);

  // Draw white border
  final Paint borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  canvas.drawCircle(const Offset(70, 70), 20, borderPaint);

  final img = await pictureRecorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
  final data = await img.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}
