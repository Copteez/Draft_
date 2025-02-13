import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  final String waqiApiKey;
  final String googleApiKey;
  final String ngrok;
  final String zerotier;

  AppConfig({
    required this.waqiApiKey,
    required this.googleApiKey,
    required this.ngrok,
    required this.zerotier,
  });

  // get value from .env file
  factory AppConfig.fromDotEnv() {
    return AppConfig(
      waqiApiKey: dotenv.env['WAQIAPIKEY'] ?? '',
      googleApiKey: dotenv.env['GOOGLE_API'] ?? '',
      ngrok: dotenv.env['NGROK'] ?? '',
      zerotier: dotenv.env['ZEROTIER'] ?? '',
    );
  }
}
