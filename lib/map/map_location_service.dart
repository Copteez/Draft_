import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

Future<Position> getCurrentPosition() async {
  return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
}

Future<LatLng?> getLatLngFromAddress(
    String address, LatLng? currentLocation) async {
  if (address.trim().toLowerCase() == "your location") {
    return currentLocation;
  }
  try {
    List<Location> locations = await locationFromAddress(address);
    if (locations.isNotEmpty) {
      return LatLng(locations[0].latitude, locations[0].longitude);
    }
  } catch (e) {
    print("Error in geocoding: $e");
  }
  return null;
}
