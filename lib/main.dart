// this is the main file of the project
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'register.dart';
import 'home_page.dart';
import 'config.dart';
import 'map.dart';
import 'details_page.dart';
import 'favorite_path.dart';
import 'history_path.dart';
//import 'favorite_location.dart'; // ✅ เพิ่ม Favorite Location
import 'history_location.dart';
import 'favorite_location.dart'; // ✅ เพิ่ม Favorite Location

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // สร้าง instance ของ AppConfig
  final config = AppConfig.fromDotEnv();

  runApp(MyApp(config: config));
}

class MyApp extends StatelessWidget {
  final AppConfig config;
  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    // ตอนนี้ทุกหน้าสามารถรับค่า config นี้ไปใช้งานได้
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(config: config),
        '/login': (context) => LoginScreen(config: config),
        '/register': (context) => RegisterScreen(config: config),
        '/home': (context) => HomePage(config: config),
        '/map': (context) => MapPage(config: config),
        '/favorite_path': (context) => FavoritePathPage(config: config),
        '/favorite_location': (context) => FavoriteLocationPage(config: config),
        '/history_path': (context) => HistoryPathPage(config: config),
        '/history_location': (context) => HistoryLocationPage(config: config),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/details') {
          final station = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => DetailsPage(config: config, station: station),
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  final AppConfig config;
  const SplashScreen({super.key, required this.config});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: Center(
        child: Image.asset("assets/loading.gif"),
      ),
    );
  }
}
