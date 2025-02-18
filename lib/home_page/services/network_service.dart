import 'package:http/http.dart' as http;
import '../../config.dart';

class NetworkService {
  final AppConfig config;
  NetworkService({required this.config});

  Future<bool> checkNgrokConnectivity() async {
    try {
      final response = await http.get(Uri.parse(config.ngrok));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String> getEffectiveBaseUrl() async {
    if (await checkNgrokConnectivity()) {
      return config.ngrok;
    }
    return config.zerotier;
  }
}
