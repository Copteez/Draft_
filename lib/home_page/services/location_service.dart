import 'package:geolocator/geolocator.dart';

Future<void> determinePosition({
  required void Function(Position position) onSuccess,
  required void Function(String error) onError,
}) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      onError("Location permissions are denied");
      return;
    }
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    onSuccess(position);
  } catch (e) {
    onError("Error getting location: $e");
  }
}
