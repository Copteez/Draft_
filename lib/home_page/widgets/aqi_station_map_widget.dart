import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AQIStationMapWidget extends StatefulWidget {
  final LatLng? userPosition;
  final Map<String, dynamic>? nearestStation;
  final bool isDarkMode;

  const AQIStationMapWidget({
    Key? key,
    required this.userPosition,
    required this.nearestStation,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _AQIStationMapWidgetState createState() => _AQIStationMapWidgetState();
}

class _AQIStationMapWidgetState extends State<AQIStationMapWidget> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _stationMarkerIcon;

  // JSON style definitions (Light / Dark Mode)
  final String _lightMapStyle = "[]";
  final String _darkMapStyle = '''
  [
    {"elementType": "geometry","stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon","stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke","stylers": [{"color": "#212121"}]},
    {"featureType": "administrative","elementType": "geometry","stylers": [{"color": "#757575"}]},
    {"featureType": "road","elementType": "geometry","stylers": [{"color": "#383838"}]},
    {"featureType": "water","elementType": "geometry","stylers": [{"color": "#000000"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _createStationMarkerIcon();
  }

  @override
  void didUpdateWidget(covariant AQIStationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ถ้าข้อมูล nearestStation เปลี่ยน ให้สร้าง marker icon ใหม่
    if (widget.nearestStation != oldWidget.nearestStation) {
      _createStationMarkerIcon();
    }
    // ถ้า darkMode เปลี่ยน ให้อัปเดต style ของแผนที่
    if (widget.isDarkMode != oldWidget.isDarkMode && _mapController != null) {
      _setMapStyle();
    }
  }

  /// สร้าง Custom Marker Icon เป็นวงกลมสี + ตัวเลข AQI
  Future<BitmapDescriptor> getCustomMarkerIcon(
      String aqiText, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    const double radius = 50.0;

    // วาดวงกลม
    canvas.drawCircle(const Offset(radius, radius), radius, paint);

    // วาดตัวเลข AQI ตรงกลาง
    final textPainter = TextPainter(
      text: TextSpan(
        text: aqiText,
        style: const TextStyle(
            fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final offset = Offset(
      radius - textPainter.width / 2,
      radius - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);

    final img = await pictureRecorder
        .endRecording()
        .toImage((radius * 2).toInt(), (radius * 2).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  /// สร้าง Marker Icon สำหรับสถานี AQI
  Future<void> _createStationMarkerIcon() async {
    if (widget.nearestStation != null &&
        widget.userPosition != null &&
        widget.nearestStation!["distance_km"] != null &&
        (widget.nearestStation!["distance_km"] as num).toDouble() <= 10.0) {
      // สมมติว่าเราต้องการแสดงหมุดในระยะ 10 กม.
      double aqiValue = widget.nearestStation!["aqi"] is num
          ? (widget.nearestStation!["aqi"] as num).toDouble()
          : 0.0;

      // เลือกสีตามค่า AQI (6 ระดับ)
      Color markerColor;
      if (aqiValue < 50) {
        markerColor = Colors.green;
      } else if (aqiValue < 100) {
        markerColor = Colors.yellow;
      } else if (aqiValue < 150) {
        markerColor = Colors.orange;
      } else if (aqiValue < 200) {
        markerColor = Colors.red;
      } else if (aqiValue < 300) {
        markerColor = Colors.purple;
      } else {
        markerColor = Colors.brown;
      }

      // สร้าง icon ด้วยตัวเลข AQI
      _stationMarkerIcon =
          await getCustomMarkerIcon(aqiValue.toStringAsFixed(0), markerColor);
      setState(() {});
    } else {
      _stationMarkerIcon = null;
    }
  }

  /// ตั้งค่า style ของแผนที่ (Dark / Light)
  void _setMapStyle() {
    if (_mapController != null) {
      _mapController!
          .setMapStyle(widget.isDarkMode ? _darkMapStyle : _lightMapStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialCameraPosition = CameraPosition(
      target: widget.userPosition ?? const LatLng(13.7563, 100.5018),
      zoom: 14,
    );

    Set<Marker> markers = {};

    // Marker ของผู้ใช้
    if (widget.userPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: widget.userPosition!,
          infoWindow: const InfoWindow(title: "Your Location"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Marker ของสถานี AQI (เฉพาะในระยะ <= 10 กม.)
    if (widget.nearestStation != null &&
        widget.userPosition != null &&
        widget.nearestStation!["distance_km"] != null &&
        (widget.nearestStation!["distance_km"] as num).toDouble() <= 10.0 &&
        _stationMarkerIcon != null) {
      double lat = widget.nearestStation!["lat"] != null
          ? double.tryParse(widget.nearestStation!["lat"].toString()) ??
              widget.userPosition!.latitude
          : widget.userPosition!.latitude;
      double lon = widget.nearestStation!["lon"] != null
          ? double.tryParse(widget.nearestStation!["lon"].toString()) ??
              widget.userPosition!.longitude
          : widget.userPosition!.longitude;

      markers.add(
        Marker(
          markerId: MarkerId('station_${widget.nearestStation!["station_id"]}'),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(
            title: widget.nearestStation!["station_name"] ?? "AQI Station",
            snippet: "AQI: ${(widget.nearestStation!["aqi"] as num).toInt()}",
          ),
          icon: _stationMarkerIcon!,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF545978)
            : const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // หัวข้อ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "AQI Station map",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff9a72b),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/map');
                },
                child: const Text("View full map",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Google Map
          SizedBox(
            height: 200,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: initialCameraPosition,
              markers: markers,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _setMapStyle();
              },
            ),
          ),
        ],
      ),
    );
  }
}
