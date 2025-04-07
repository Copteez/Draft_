import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart'; // Add this import
import 'login.dart';
import 'register.dart';
import 'home_page.dart';
import 'config.dart';
import 'map.dart';
import 'details_page.dart';
import 'favorite_path.dart';
import 'history_path.dart';
import 'history_location.dart';
import 'favorite_location.dart';
import 'map/map_android_notification.dart';
import 'home_page/utils/data_generation.dart' show getAQIPredictionData;
import 'theme_provider.dart'; // Add this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // สร้าง instance ของ AppConfig
  final config = AppConfig.fromDotEnv();

  runApp(
    // Wrap with ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(config: config),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppConfig config;
  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    // Listen to the theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      // Use the correct class name for the navigator key
      navigatorKey: AndroidNotificationService.navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        brightness:
            themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor:
              themeProvider.isDarkMode ? const Color(0xFF2C2C47) : Colors.white,
          foregroundColor:
              themeProvider.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
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
