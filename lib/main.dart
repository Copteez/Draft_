import 'package:flutter/material.dart';
import 'dart:async';
import 'home_page.dart'; // Verify this path is correct and matches the filename exactly, considering case sensitivity
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

void main() async{
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Load the .env file
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2), // Animation time reduced to 2 seconds
      vsync: this,
    )..addListener(() {
        setState(() {});
      });
    _controller.forward();

    // Automatically navigate to HomePage after 2 seconds
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: CircleWavePainter(_controller.value),
                ),
                Icon(
                  Icons.air,
                  size: 60, // Increase the size of the air symbol
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 20), // Add some spacing below the circle
            Text(
              "Loading",
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF18966C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircleWavePainter extends CustomPainter {
  final double progress;

  CircleWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF18966C)
      ..style = PaintingStyle.fill;

    final circleCenter = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw white circle
    canvas.drawCircle(circleCenter, radius, Paint()..color = Colors.white);

    // Calculate wave height
    final waveHeight = progress * size.height;

    // Draw green wave filling up
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height - waveHeight)
      ..quadraticBezierTo(size.width / 2, size.height - waveHeight - 20,
          size.width, size.height - waveHeight)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: circleCenter, radius: radius)));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
