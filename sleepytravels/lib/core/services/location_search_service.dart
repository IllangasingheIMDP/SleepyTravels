import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:developer' as developer;
class LocationSearchResult {
  final String displayName;
  final String address;
  final LatLng coordinates;
  final String? type;
  final String? importance;

  LocationSearchResult({
    required this.displayName,
    required this.address,
    required this.coordinates,
    this.type,
    this.importance,
  });

  factory LocationSearchResult.fromNominatim(Map<String, dynamic> json) {
    return LocationSearchResult(
      displayName: json['display_name'] ?? '',
      address: json['display_name'] ?? '',
      coordinates: LatLng(double.parse(json['lat']), double.parse(json['lon'])),
      type: json['type'],
      importance: json['importance']?.toString(),
    );
  }
}

class LocationSearchService {
  static final LocationSearchService _instance =
      LocationSearchService._internal();
  factory LocationSearchService() => _instance;
  LocationSearchService._internal();

  static LocationSearchService get instance => _instance;
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<LocationSearchResult>> searchLocation(String query) async {
    if (query.isEmpty || query.length < 3) {
      return [];
    }

    try {
      developer.log(
        'LocationSearchService: Searching for "$query" using Nominatim API',
      );

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '10',
          'countrycodes':
              'lk', // Limit to Sri Lanka, remove this line for worldwide search
          'accept-language': 'en',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'SleepyTravels/1.0 (Flutter App)', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        developer.log(
          'LocationSearchService: Found ${data.length} results from Nominatim',
        );

        return data
            .map((item) => LocationSearchResult.fromNominatim(item))
            .toList();
      } else {
        developer.log(
          'LocationSearchService: Error ${response.statusCode}: ${response.body}',
        );
        return [];
      }
    } catch (e) {
      developer.log('LocationSearchService: Error searching locations: $e');
      return [];
    }
  }

  // Search for places near a specific location
  Future<List<LocationSearchResult>> searchNearby(
    LatLng center,
    String query, {
    double radiusKm = 10.0,
  }) async {
    if (query.isEmpty || query.length < 3) {
      return [];
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '10',
          'lat': center.latitude.toString(),
          'lon': center.longitude.toString(),
          'radius': (radiusKm * 1000).toString(), // Convert km to meters
          'accept-language': 'en',
        },
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SleepyTravels/1.0 (Flutter App)'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => LocationSearchResult.fromNominatim(item))
            .toList();
      } else {
        developer.log(
          'LocationSearchService: Error ${response.statusCode}: ${response.body}',
        );
        return [];
      }
    } catch (e) {
      developer.log('LocationSearchService: Error searching nearby locations: $e');
      return [];
    }
  }
}
